import Foundation

/// Core BAML runtime for executing functions
public actor BamlRuntime {
    public let clientRegistry: ClientRegistry
    public let defaultRetryPolicy: RetryPolicy

    public init(
        clientRegistry: ClientRegistry,
        defaultRetryPolicy: RetryPolicy = .standard
    ) {
        self.clientRegistry = clientRegistry
        self.defaultRetryPolicy = defaultRetryPolicy
    }

    /// Call a BAML function with the given arguments
    public func callFunction(
        _ name: String,
        args: [String: BamlValue],
        prompt: String,
        outputSchema: JSONSchema? = nil,
        ctx: RuntimeContext = .default
    ) async throws -> BamlValue {
        // Get the client configuration
        let clientConfig: ClientConfig
        if let clientName = ctx.clientName {
            guard let config = await clientRegistry.getConfig(clientName) else {
                throw BamlError.clientNotFound(clientName)
            }
            clientConfig = config
        } else {
            guard let config = await clientRegistry.getDefaultConfig() else {
                throw BamlError.configurationError("No default client configured")
            }
            clientConfig = config
        }

        // Get the LLM client
        let client = try await clientRegistry.getClient(clientConfig.name)

        // Build messages
        let messages = [ChatMessage.user(prompt)]

        // Determine response format
        let responseFormat: ResponseFormat?
        if let schema = outputSchema {
            responseFormat = .jsonSchema(
                name: name,
                schema: schema.toDictionary(),
                strict: true
            )
        } else {
            responseFormat = ctx.responseFormat
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
        return try OutputParser.parseToValue(response.content, schema: outputSchema)
    }

    /// Call a function with typed output
    public func callFunction<T: Codable>(
        _ name: String,
        args: [String: BamlValue],
        prompt: String,
        outputSchema: JSONSchema? = nil,
        outputType: T.Type,
        ctx: RuntimeContext = .default
    ) async throws -> T {
        // Get the client configuration
        let clientConfig: ClientConfig
        if let clientName = ctx.clientName {
            guard let config = await clientRegistry.getConfig(clientName) else {
                throw BamlError.clientNotFound(clientName)
            }
            clientConfig = config
        } else {
            guard let config = await clientRegistry.getDefaultConfig() else {
                throw BamlError.configurationError("No default client configured")
            }
            clientConfig = config
        }

        // Get the LLM client
        let client = try await clientRegistry.getClient(clientConfig.name)

        // Build messages
        let messages = [ChatMessage.user(prompt)]

        // Determine response format
        let responseFormat: ResponseFormat?
        if let schema = outputSchema {
            responseFormat = .jsonSchema(
                name: name,
                schema: schema.toDictionary(),
                strict: true
            )
        } else {
            responseFormat = ctx.responseFormat
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
        return try OutputParser.parse(response.content, schema: outputSchema, type: T.self)
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
                throw BamlError.clientNotFound(name)
            }
            clientConfig = config
        } else {
            guard let config = await clientRegistry.getDefaultConfig() else {
                throw BamlError.configurationError("No default client configured")
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
}

// MARK: - Convenience Initializers

extension BamlRuntime {
    /// Create a runtime with a single OpenRouter client
    public static func openRouter(apiKey: String, model: String) async -> BamlRuntime {
        let registry = ClientRegistry()
        await registry.register(
            name: "default",
            provider: .openRouter(apiKey: apiKey),
            model: model,
            isDefault: true
        )
        return BamlRuntime(clientRegistry: registry)
    }

    /// Create a runtime with a single OpenAI client
    public static func openAI(apiKey: String, model: String = "gpt-4o") async -> BamlRuntime {
        let registry = ClientRegistry()
        await registry.register(
            name: "default",
            provider: .openAI(apiKey: apiKey),
            model: model,
            isDefault: true
        )
        return BamlRuntime(clientRegistry: registry)
    }

    /// Create a runtime with a single Anthropic client
    public static func anthropic(apiKey: String, model: String = "claude-sonnet-4-20250514") async -> BamlRuntime {
        let registry = ClientRegistry()
        await registry.register(
            name: "default",
            provider: .anthropic(apiKey: apiKey),
            model: model,
            isDefault: true
        )
        return BamlRuntime(clientRegistry: registry)
    }
}
