import Foundation

/// Core SWAML runtime for executing functions
public actor SwamlRuntime {
    public let clientRegistry: ClientRegistry
    public let defaultRetryPolicy: RetryPolicy

    public init(
        clientRegistry: ClientRegistry,
        defaultRetryPolicy: RetryPolicy = .standard
    ) {
        self.clientRegistry = clientRegistry
        self.defaultRetryPolicy = defaultRetryPolicy
    }

    /// Call a SWAML function with the given arguments
    public func callFunction(
        _ name: String,
        args: [String: SwamlValue],
        prompt: String,
        outputSchema: JSONSchema? = nil,
        typeBuilder: TypeBuilder? = nil,
        ctx: RuntimeContext = .default
    ) async throws -> SwamlValue {
        // Get the client configuration
        let clientConfig: ClientConfig
        if let clientName = ctx.clientName {
            guard let config = await clientRegistry.getConfig(clientName) else {
                throw SwamlError.clientNotFound(clientName)
            }
            clientConfig = config
        } else {
            guard let config = await clientRegistry.getDefaultConfig() else {
                throw SwamlError.configurationError("No default client configured")
            }
            clientConfig = config
        }

        // Get the LLM client
        let client = try await clientRegistry.getClient(clientConfig.name)

        // Build messages
        let messages = [ChatMessage.user(prompt)]

        // Merge TypeBuilder schemas with output schema
        let finalSchema = mergeSchemaWithTypeBuilder(outputSchema, typeBuilder: typeBuilder)

        // Determine response format - always use JSON when we have a schema or typed output
        let responseFormat: ResponseFormat?
        if let schema = finalSchema {
            responseFormat = .jsonSchema(
                name: name,
                schema: schema.toDictionary(),
                strict: true
            )
        } else if ctx.responseFormat != nil {
            responseFormat = ctx.responseFormat
        } else {
            // Default to JSON object format for typed outputs
            responseFormat = .jsonObject
        }

        // Execute with retry
        let retryExecutor = RetryExecutor(policy: clientConfig.retryPolicy)

        let response = try await retryExecutor.execute {
            try await client.complete(
                model: clientConfig.model,
                messages: messages,
                responseFormat: responseFormat,
                temperature: ctx.temperature ?? clientConfig.defaultTemperature,
                maxTokens: ctx.maxTokens ?? clientConfig.defaultMaxTokens
            )
        }

        // Parse the response
        return try OutputParser.parseToValue(response.content, schema: finalSchema)
    }

    /// Call a function with typed output
    public func callFunction<T: Codable>(
        _ name: String,
        args: [String: SwamlValue],
        prompt: String,
        outputSchema: JSONSchema? = nil,
        outputType: T.Type,
        typeBuilder: TypeBuilder? = nil,
        ctx: RuntimeContext = .default
    ) async throws -> T {
        // Get the client configuration
        let clientConfig: ClientConfig
        if let clientName = ctx.clientName {
            guard let config = await clientRegistry.getConfig(clientName) else {
                throw SwamlError.clientNotFound(clientName)
            }
            clientConfig = config
        } else {
            guard let config = await clientRegistry.getDefaultConfig() else {
                throw SwamlError.configurationError("No default client configured")
            }
            clientConfig = config
        }

        // Get the LLM client
        let client = try await clientRegistry.getClient(clientConfig.name)

        // Build messages
        let messages = [ChatMessage.user(prompt)]

        // Merge TypeBuilder schemas with output schema
        let finalSchema = mergeSchemaWithTypeBuilder(outputSchema, typeBuilder: typeBuilder)

        // Determine response format - always use JSON when we have a schema or typed output
        let responseFormat: ResponseFormat?
        if let schema = finalSchema {
            responseFormat = .jsonSchema(
                name: name,
                schema: schema.toDictionary(),
                strict: true
            )
        } else if ctx.responseFormat != nil {
            responseFormat = ctx.responseFormat
        } else {
            // Default to JSON object format for typed outputs
            responseFormat = .jsonObject
        }

        // Execute with retry
        let retryExecutor = RetryExecutor(policy: clientConfig.retryPolicy)

        let response = try await retryExecutor.execute {
            try await client.complete(
                model: clientConfig.model,
                messages: messages,
                responseFormat: responseFormat,
                temperature: ctx.temperature ?? clientConfig.defaultTemperature,
                maxTokens: ctx.maxTokens ?? clientConfig.defaultMaxTokens
            )
        }

        // Parse the response
        return try OutputParser.parse(response.content, schema: finalSchema, type: T.self)
    }

    /// Execute a raw completion (no function abstraction)
    public func complete(
        messages: [ChatMessage],
        clientName: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        responseFormat: ResponseFormat? = nil
    ) async throws -> LLMResponse {
        // Get the client configuration
        let clientConfig: ClientConfig
        if let name = clientName {
            guard let config = await clientRegistry.getConfig(name) else {
                throw SwamlError.clientNotFound(name)
            }
            clientConfig = config
        } else {
            guard let config = await clientRegistry.getDefaultConfig() else {
                throw SwamlError.configurationError("No default client configured")
            }
            clientConfig = config
        }

        // Get the LLM client
        let client = try await clientRegistry.getClient(clientConfig.name)

        // Execute with retry
        let retryExecutor = RetryExecutor(policy: clientConfig.retryPolicy)

        return try await retryExecutor.execute {
            try await client.complete(
                model: clientConfig.model,
                messages: messages,
                responseFormat: responseFormat,
                temperature: temperature ?? clientConfig.defaultTemperature,
                maxTokens: maxTokens ?? clientConfig.defaultMaxTokens
            )
        }
    }

    // MARK: - Private Helpers

    /// Merge TypeBuilder's dynamic enum values into the output schema
    private func mergeSchemaWithTypeBuilder(_ schema: JSONSchema?, typeBuilder: TypeBuilder?) -> JSONSchema? {
        guard let schema = schema, let tb = typeBuilder else {
            return schema
        }

        let dynamicEnums = tb.dynamicEnumValues()
        if dynamicEnums.isEmpty {
            return schema
        }

        // Recursively update the schema to replace dynamic enum references
        return updateSchemaWithDynamicEnums(schema, dynamicEnums: dynamicEnums)
    }

    /// Recursively update schema to include dynamic enum values
    private func updateSchemaWithDynamicEnums(_ schema: JSONSchema, dynamicEnums: [String: [String]]) -> JSONSchema {
        switch schema {
        case .ref(let name):
            // If this is a reference to a dynamic enum, replace with enum schema
            if let values = dynamicEnums[name] {
                return .enum(values: values)
            }
            return schema

        case .object(let properties, let required, let additionalProps):
            // Recursively update properties
            var updatedProps: [String: JSONSchema] = [:]
            for (key, propSchema) in properties {
                updatedProps[key] = updateSchemaWithDynamicEnums(propSchema, dynamicEnums: dynamicEnums)
            }
            let updatedAdditional = additionalProps.map { updateSchemaWithDynamicEnums($0, dynamicEnums: dynamicEnums) }
            return .object(properties: updatedProps, required: required, additionalProperties: updatedAdditional)

        case .array(let items):
            return .array(items: updateSchemaWithDynamicEnums(items, dynamicEnums: dynamicEnums))

        case .anyOf(let schemas):
            return .anyOf(schemas.map { updateSchemaWithDynamicEnums($0, dynamicEnums: dynamicEnums) })

        default:
            return schema
        }
    }
}

// MARK: - Convenience Initializers

extension SwamlRuntime {
    /// Create a runtime with a single OpenRouter client
    public static func openRouter(apiKey: String, model: String) async -> SwamlRuntime {
        let registry = ClientRegistry()
        await registry.register(
            name: "default",
            provider: .openRouter(apiKey: apiKey),
            model: model,
            isDefault: true
        )
        return SwamlRuntime(clientRegistry: registry)
    }

    /// Create a runtime with a single OpenAI client
    public static func openAI(apiKey: String, model: String = "gpt-4o") async -> SwamlRuntime {
        let registry = ClientRegistry()
        await registry.register(
            name: "default",
            provider: .openAI(apiKey: apiKey),
            model: model,
            isDefault: true
        )
        return SwamlRuntime(clientRegistry: registry)
    }

    /// Create a runtime with a single Anthropic client
    public static func anthropic(apiKey: String, model: String = "claude-sonnet-4-20250514") async -> SwamlRuntime {
        let registry = ClientRegistry()
        await registry.register(
            name: "default",
            provider: .anthropic(apiKey: apiKey),
            model: model,
            isDefault: true
        )
        return SwamlRuntime(clientRegistry: registry)
    }
}
