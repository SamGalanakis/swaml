import Foundation

/// Configuration for an LLM client
public struct ClientConfig: Sendable {
    public let name: String
    public let provider: LLMProvider
    public let model: String
    public let retryPolicy: RetryPolicy
    public let defaultTemperature: Double?
    public let defaultMaxTokens: Int?

    public init(
        name: String,
        provider: LLMProvider,
        model: String,
        retryPolicy: RetryPolicy = .standard,
        defaultTemperature: Double? = nil,
        defaultMaxTokens: Int? = nil
    ) {
        self.name = name
        self.provider = provider
        self.model = model
        self.retryPolicy = retryPolicy
        self.defaultTemperature = defaultTemperature
        self.defaultMaxTokens = defaultMaxTokens
    }
}

/// Registry for managing LLM client configurations
public actor ClientRegistry {
    private var clients: [String: ClientConfig] = [:]
    private var llmClients: [String: LLMClient] = [:]
    private var defaultClientName: String?

    public init() {}

    /// Register a client configuration
    public func register(_ config: ClientConfig, isDefault: Bool = false) {
        clients[config.name] = config
        if isDefault || defaultClientName == nil {
            defaultClientName = config.name
        }
    }

    /// Register a client with inline configuration
    public func register(
        name: String,
        provider: LLMProvider,
        model: String,
        retryPolicy: RetryPolicy = .standard,
        defaultTemperature: Double? = nil,
        defaultMaxTokens: Int? = nil,
        isDefault: Bool = false
    ) {
        let config = ClientConfig(
            name: name,
            provider: provider,
            model: model,
            retryPolicy: retryPolicy,
            defaultTemperature: defaultTemperature,
            defaultMaxTokens: defaultMaxTokens
        )
        register(config, isDefault: isDefault)
    }

    /// Get a client configuration by name
    public func getConfig(_ name: String) -> ClientConfig? {
        clients[name]
    }

    /// Get the default client configuration
    public func getDefaultConfig() -> ClientConfig? {
        guard let name = defaultClientName else { return nil }
        return clients[name]
    }

    /// Get or create an LLMClient for a configuration
    public func getClient(_ name: String) throws -> LLMClient {
        if let existing = llmClients[name] {
            return existing
        }

        guard let config = clients[name] else {
            throw BamlError.clientNotFound(name)
        }

        let client = LLMClient(provider: config.provider)
        llmClients[name] = client
        return client
    }

    /// Get the default LLMClient
    public func getDefaultClient() throws -> LLMClient {
        guard let name = defaultClientName else {
            throw BamlError.configurationError("No default client configured")
        }
        return try getClient(name)
    }

    /// Set the default client
    public func setDefault(_ name: String) throws {
        guard clients[name] != nil else {
            throw BamlError.clientNotFound(name)
        }
        defaultClientName = name
    }

    /// List all registered client names
    public var clientNames: [String] {
        Array(clients.keys)
    }

    /// Remove a client
    public func remove(_ name: String) {
        clients.removeValue(forKey: name)
        llmClients.removeValue(forKey: name)
        if defaultClientName == name {
            defaultClientName = clients.keys.first
        }
    }

    /// Clear all clients
    public func clear() {
        clients.removeAll()
        llmClients.removeAll()
        defaultClientName = nil
    }
}

// MARK: - Convenience Initializers

extension ClientRegistry {
    /// Create a registry with a single OpenRouter client
    public static func openRouter(apiKey: String, model: String) -> ClientRegistry {
        let registry = ClientRegistry()
        Task {
            await registry.register(
                name: "default",
                provider: .openRouter(apiKey: apiKey),
                model: model,
                isDefault: true
            )
        }
        return registry
    }

    /// Create a registry with a single OpenAI client
    public static func openAI(apiKey: String, model: String = "gpt-4o") -> ClientRegistry {
        let registry = ClientRegistry()
        Task {
            await registry.register(
                name: "default",
                provider: .openAI(apiKey: apiKey),
                model: model,
                isDefault: true
            )
        }
        return registry
    }

    /// Create a registry with a single Anthropic client
    public static func anthropic(apiKey: String, model: String = "claude-sonnet-4-20250514") -> ClientRegistry {
        let registry = ClientRegistry()
        Task {
            await registry.register(
                name: "default",
                provider: .anthropic(apiKey: apiKey),
                model: model,
                isDefault: true
            )
        }
        return registry
    }
}
