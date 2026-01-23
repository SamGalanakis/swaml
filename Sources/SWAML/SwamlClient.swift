import Foundation

/// High-level client for making structured LLM calls with Swift-native types.
///
/// SwamlClient provides a simple API for getting typed responses from LLMs using
/// the `BamlTyped` protocol for schema generation and output parsing.
///
/// Example usage:
/// ```swift
/// @BamlType
/// struct Sentiment {
///     @Description("Detected sentiment")
///     let sentiment: String
///     let confidence: Double
/// }
///
/// let client = SwamlClient(provider: .openRouter(apiKey: apiKey))
///
/// let result = try await client.call(
///     model: "openai/gpt-4o-mini",
///     prompt: "Analyze: 'I love this product!'",
///     returnType: Sentiment.self
/// )
/// ```
public actor SwamlClient {
    private let llmClient: LLMClient
    private let typeBuilder: TypeBuilder

    /// Initialize with an LLM provider
    public init(provider: LLMProvider) {
        self.llmClient = LLMClient(provider: provider)
        self.typeBuilder = TypeBuilder()
    }

    /// Initialize with a custom LLM client
    public init(llmClient: LLMClient) {
        self.llmClient = llmClient
        self.typeBuilder = TypeBuilder()
    }

    /// Initialize with a custom LLM client and TypeBuilder
    public init(llmClient: LLMClient, typeBuilder: TypeBuilder) {
        self.llmClient = llmClient
        self.typeBuilder = typeBuilder
    }

    // MARK: - Convenience Initializers

    /// Initialize for OpenRouter
    public static func openRouter(apiKey: String) -> SwamlClient {
        SwamlClient(provider: .openRouter(apiKey: apiKey))
    }

    /// Initialize for OpenAI
    public static func openAI(apiKey: String) -> SwamlClient {
        SwamlClient(provider: .openAI(apiKey: apiKey))
    }

    /// Initialize for Anthropic
    public static func anthropic(apiKey: String) -> SwamlClient {
        SwamlClient(provider: .anthropic(apiKey: apiKey))
    }

    // MARK: - Primary API

    /// Call an LLM with structured output
    ///
    /// - Parameters:
    ///   - model: The model identifier (e.g., "openai/gpt-4o-mini")
    ///   - prompt: The user prompt
    ///   - returnType: The expected return type (must conform to BamlTyped)
    ///   - systemPrompt: Optional additional system prompt (prepended to schema)
    ///   - temperature: Optional temperature (0.0-2.0)
    ///   - maxTokens: Optional max tokens for response
    /// - Returns: Parsed and validated response of the expected type
    public func call<T: BamlTyped>(
        model: String,
        prompt: String,
        returnType: T.Type,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        // 1. Build the schema prompt
        let schemaPrompt = SchemaPromptRenderer.render(
            for: T.self,
            typeBuilder: typeBuilder,
            includeDescriptions: true
        )

        // Combine system prompts if provided
        let fullSystemPrompt: String
        if let additionalPrompt = systemPrompt {
            fullSystemPrompt = "\(additionalPrompt)\n\n\(schemaPrompt)"
        } else {
            fullSystemPrompt = schemaPrompt
        }

        // 2. Call the LLM
        let response = try await llmClient.complete(
            model: model,
            messages: [
                .system(fullSystemPrompt),
                .user(prompt)
            ],
            responseFormat: .jsonObject,
            temperature: temperature,
            maxTokens: maxTokens
        )

        // 3. Parse with schema validation (use Rust parser if available)
        return try parseResponse(response.content, schema: T.bamlSchema, type: T.self)
    }

    /// Call an LLM with structured output and automatic error repair
    ///
    /// If parsing fails, attempts to repair the output by asking the LLM
    /// to fix the malformed JSON.
    ///
    /// - Parameters:
    ///   - model: The model identifier (e.g., "openai/gpt-4o-mini")
    ///   - prompt: The user prompt
    ///   - returnType: The expected return type (must conform to BamlTyped)
    ///   - systemPrompt: Optional additional system prompt
    ///   - temperature: Optional temperature (0.0-2.0)
    ///   - maxTokens: Optional max tokens for response
    ///   - maxRepairAttempts: Maximum repair attempts (default: 1)
    /// - Returns: Parsed and validated response of the expected type
    public func callWithRepair<T: BamlTyped>(
        model: String,
        prompt: String,
        returnType: T.Type,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        maxRepairAttempts: Int = 1
    ) async throws -> T {
        do {
            return try await call(
                model: model,
                prompt: prompt,
                returnType: T.self,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens
            )
        } catch let error as BamlError {
            guard maxRepairAttempts > 0 else { throw error }

            // Extract raw output from error if available
            let rawOutput: String
            switch error {
            case .parseError(let message):
                rawOutput = message
            case .jsonExtractionError(let message):
                rawOutput = message
            default:
                throw error
            }

            // Attempt repair
            let repaired = try await repairOutput(
                model: model,
                originalPrompt: prompt,
                malformedOutput: rawOutput,
                expectedSchema: T.bamlSchema,
                temperature: temperature
            )

            // Retry parsing with repaired output
            return try parseResponse(repaired, schema: T.bamlSchema, type: T.self)
        }
    }

    /// Call an LLM with PromptBuilder for complex prompts
    ///
    /// - Parameters:
    ///   - model: The model identifier
    ///   - prompt: A configured PromptBuilder
    ///   - returnType: The expected return type
    ///   - temperature: Optional temperature
    ///   - maxTokens: Optional max tokens
    /// - Returns: Parsed response
    public func call<T: BamlTyped>(
        model: String,
        prompt: PromptBuilder,
        returnType: T.Type,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        let messages = prompt.build(returnType: T.self, typeBuilder: typeBuilder)

        let response = try await llmClient.complete(
            model: model,
            messages: messages,
            responseFormat: .jsonObject,
            temperature: temperature,
            maxTokens: maxTokens
        )

        return try parseResponse(response.content, schema: T.bamlSchema, type: T.self)
    }

    /// Call an LLM with PromptBuilder and automatic error repair
    public func callWithRepair<T: BamlTyped>(
        model: String,
        prompt: PromptBuilder,
        returnType: T.Type,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        maxRepairAttempts: Int = 1
    ) async throws -> T {
        do {
            return try await call(
                model: model,
                prompt: prompt,
                returnType: T.self,
                temperature: temperature,
                maxTokens: maxTokens
            )
        } catch let error as BamlError {
            guard maxRepairAttempts > 0 else { throw error }

            let rawOutput: String
            switch error {
            case .parseError(let message), .jsonExtractionError(let message):
                rawOutput = message
            default:
                throw error
            }

            let repaired = try await repairOutput(
                model: model,
                originalPrompt: prompt.buildRaw().compactMap { $0.content.textValue }.joined(separator: "\n"),
                malformedOutput: rawOutput,
                expectedSchema: T.bamlSchema,
                temperature: temperature
            )

            return try parseResponse(repaired, schema: T.bamlSchema, type: T.self)
        }
    }

    /// Call an LLM with structured output and custom messages
    ///
    /// - Parameters:
    ///   - model: The model identifier
    ///   - messages: Custom chat messages
    ///   - returnType: The expected return type
    ///   - includeSchema: Whether to automatically add schema instructions
    ///   - temperature: Optional temperature
    ///   - maxTokens: Optional max tokens
    /// - Returns: Parsed response
    public func call<T: BamlTyped>(
        model: String,
        messages: [ChatMessage],
        returnType: T.Type,
        includeSchema: Bool = true,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        var finalMessages = messages

        // Prepend schema prompt if requested
        if includeSchema {
            let schemaPrompt = SchemaPromptRenderer.render(
                for: T.self,
                typeBuilder: typeBuilder
            )

            // Find existing system message or create new one
            if let systemIdx = finalMessages.firstIndex(where: { $0.role == .system }) {
                let existing = finalMessages[systemIdx].content.textValue ?? ""
                finalMessages[systemIdx] = .system("\(existing)\n\n\(schemaPrompt)")
            } else {
                finalMessages.insert(.system(schemaPrompt), at: 0)
            }
        }

        let response = try await llmClient.complete(
            model: model,
            messages: finalMessages,
            responseFormat: .jsonObject,
            temperature: temperature,
            maxTokens: maxTokens
        )

        return try parseResponse(response.content, schema: T.bamlSchema, type: T.self)
    }

    /// Call an LLM and return raw BamlValue (for dynamic schemas)
    ///
    /// - Parameters:
    ///   - model: The model identifier
    ///   - prompt: The user prompt
    ///   - schema: The expected JSON schema
    ///   - systemPrompt: Optional additional system prompt
    ///   - temperature: Optional temperature
    ///   - maxTokens: Optional max tokens
    /// - Returns: Parsed BamlValue
    public func callDynamic(
        model: String,
        prompt: String,
        schema: JSONSchema,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> BamlValue {
        let schemaPrompt = SchemaPromptRenderer.render(
            schema: schema,
            typeBuilder: typeBuilder
        )

        let fullSystemPrompt: String
        if let additionalPrompt = systemPrompt {
            fullSystemPrompt = "\(additionalPrompt)\n\n\(schemaPrompt)"
        } else {
            fullSystemPrompt = schemaPrompt
        }

        let response = try await llmClient.complete(
            model: model,
            messages: [
                .system(fullSystemPrompt),
                .user(prompt)
            ],
            responseFormat: .jsonObject,
            temperature: temperature,
            maxTokens: maxTokens
        )

        return try OutputParser.parseToValue(response.content, schema: schema)
    }

    // MARK: - TypeBuilder Access

    /// Get the TypeBuilder for dynamic type extension
    public nonisolated var types: TypeBuilder {
        typeBuilder
    }

    /// Extend a dynamic enum at runtime
    ///
    /// - Parameters:
    ///   - type: The enum type to extend (must be marked with @BamlDynamic)
    ///   - values: New values to add
    /// - Throws: BamlError if the type is not dynamic
    public func extendEnum<T: BamlTyped>(
        _ type: T.Type,
        with values: [String]
    ) throws {
        guard T.isDynamic else {
            throw BamlError.configurationError(
                "Cannot extend non-dynamic type '\(T.bamlTypeName)'. Add @BamlDynamic to allow runtime extension."
            )
        }

        let builder = typeBuilder.enumBuilder(T.bamlTypeName)
        for value in values {
            builder.addValue(value)
        }
    }

    /// Add a property to a dynamic class at runtime
    ///
    /// - Parameters:
    ///   - type: The class type to extend (must be marked with @BamlDynamic)
    ///   - propertyName: Name of the new property
    ///   - propertyType: Type of the new property
    /// - Throws: BamlError if the type is not dynamic
    public func extendClass<T: BamlTyped>(
        _ type: T.Type,
        property propertyName: String,
        type propertyType: FieldType
    ) throws {
        guard T.isDynamic else {
            throw BamlError.configurationError(
                "Cannot extend non-dynamic type '\(T.bamlTypeName)'. Add @BamlDynamic to allow runtime extension."
            )
        }

        let builder = typeBuilder.classBuilder(T.bamlTypeName)
        builder.addProperty(propertyName, propertyType)
    }

    // MARK: - Raw Response

    /// Call an LLM and return the raw response (no parsing)
    public func rawComplete(
        model: String,
        messages: [ChatMessage],
        responseFormat: ResponseFormat? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> LLMResponse {
        try await llmClient.complete(
            model: model,
            messages: messages,
            responseFormat: responseFormat,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
}

// MARK: - Batch Operations

extension SwamlClient {
    /// Call an LLM multiple times concurrently
    ///
    /// - Parameters:
    ///   - model: The model identifier
    ///   - prompts: Array of user prompts
    ///   - returnType: The expected return type
    ///   - systemPrompt: Optional additional system prompt
    ///   - temperature: Optional temperature
    ///   - maxConcurrency: Maximum concurrent requests (default: 5)
    /// - Returns: Array of results in the same order as prompts
    public func batch<T: BamlTyped>(
        model: String,
        prompts: [String],
        returnType: T.Type,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxConcurrency: Int = 5
    ) async throws -> [Result<T, Error>] {
        try await withThrowingTaskGroup(of: (Int, Result<T, Error>).self) { group in
            var results: [(Int, Result<T, Error>)] = []
            var index = 0

            for prompt in prompts {
                let currentIndex = index
                index += 1

                group.addTask {
                    do {
                        let result = try await self.call(
                            model: model,
                            prompt: prompt,
                            returnType: returnType,
                            systemPrompt: systemPrompt,
                            temperature: temperature
                        )
                        return (currentIndex, .success(result))
                    } catch {
                        return (currentIndex, .failure(error))
                    }
                }

                // Limit concurrency
                if index % maxConcurrency == 0 {
                    if let result = try await group.next() {
                        results.append(result)
                    }
                }
            }

            // Collect remaining results
            for try await result in group {
                results.append(result)
            }

            // Sort by original index and return just the results
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}

// MARK: - Parsing and Repair

extension SwamlClient {
    /// Parse LLM response using the pure Swift jsonish parser
    ///
    /// The parser handles robust LLM output parsing including:
    /// - Trailing commas and comments
    /// - Unquoted keys
    /// - Single quotes
    /// - Markdown code block extraction
    /// - Multiple JSON candidates
    private func parseResponse<T: Codable>(
        _ response: String,
        schema: JSONSchema,
        type: T.Type
    ) throws -> T {
        // Parse with the Swift jsonish parser
        let parsedJSON = try JsonishParser.parse(response)
        guard let data = parsedJSON.data(using: .utf8) else {
            throw BamlError.parseError("Failed to convert parsed JSON to data")
        }

        // Decode with schema coercion - try snake_case first, then raw
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let decoder2 = JSONDecoder()
            return try decoder2.decode(T.self, from: data)
        }
    }

    /// Attempt to repair malformed LLM output
    private func repairOutput(
        model: String,
        originalPrompt: String,
        malformedOutput: String,
        expectedSchema: JSONSchema,
        temperature: Double?
    ) async throws -> String {
        let schemaText = SchemaPromptRenderer.renderSchema(expectedSchema, typeBuilder: typeBuilder)

        let repairPrompt = """
            The following JSON output is malformed or doesn't match the expected schema.
            Please fix it and return only the corrected JSON.

            Expected schema:
            \(schemaText)

            Malformed output:
            \(malformedOutput)

            Return ONLY the corrected JSON, no explanation or markdown.
            """

        let response = try await llmClient.complete(
            model: model,
            messages: [
                .system("You are a JSON repair assistant. Your job is to fix malformed JSON to match the expected schema. Return only valid JSON."),
                .user(repairPrompt)
            ],
            responseFormat: .jsonObject,
            temperature: temperature ?? 0.0,  // Use low temperature for repairs
            maxTokens: nil
        )

        return response.content
    }
}

