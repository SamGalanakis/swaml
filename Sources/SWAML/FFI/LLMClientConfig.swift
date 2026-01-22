import Foundation

#if BAML_FFI_ENABLED

/// Configuration for an LLM client used in BAML function calls.
/// This allows setting API key, model, temperature, etc. per-request.
public struct LLMClientConfig: Sendable {
    /// Name of the client to override (must match a client defined in BAML, e.g., "TextClient")
    public let clientName: String

    /// Provider string (e.g., "openai-generic", "anthropic", "openai")
    public let provider: String

    /// API key for the provider
    public let apiKey: String

    /// Model to use (e.g., "gpt-4o", "claude-sonnet-4-20250514")
    public let model: String

    /// Base URL for the API (optional, for OpenRouter or custom endpoints)
    public let baseUrl: String?

    /// Temperature for generation (optional)
    public let temperature: Double?

    /// Maximum tokens to generate (optional)
    public let maxTokens: Int?

    public init(
        clientName: String = "TextClient",
        provider: String = "openai-generic",
        apiKey: String,
        model: String,
        baseUrl: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.clientName = clientName
        self.provider = provider
        self.apiKey = apiKey
        self.model = model
        self.baseUrl = baseUrl
        self.temperature = temperature
        self.maxTokens = maxTokens
    }

    /// Create an OpenRouter configuration
    public static func openRouter(
        apiKey: String,
        model: String = "google/gemini-2.5-flash-preview-05-20",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> LLMClientConfig {
        LLMClientConfig(
            clientName: "TextClient",
            provider: "openai-generic",
            apiKey: apiKey,
            model: model,
            baseUrl: "https://openrouter.ai/api/v1",
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// Create an OpenAI configuration
    public static func openAI(
        apiKey: String,
        model: String = "gpt-4o",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> LLMClientConfig {
        LLMClientConfig(
            clientName: "TextClient",
            provider: "openai",
            apiKey: apiKey,
            model: model,
            baseUrl: nil,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// Create an Anthropic configuration
    public static func anthropic(
        apiKey: String,
        model: String = "claude-sonnet-4-20250514",
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) -> LLMClientConfig {
        LLMClientConfig(
            clientName: "TextClient",
            provider: "anthropic",
            apiKey: apiKey,
            model: model,
            baseUrl: nil,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// Convert to HostClientRegistry for protobuf
    /// Note: Uses proper types (string, float, int) for API compatibility
    func toHostClientRegistry() -> HostClientRegistry {
        var clientProperty = HostClientProperty()
        clientProperty.name = clientName
        clientProperty.provider = provider

        // String options
        clientProperty.options.append(HostMapEntry(stringKey: "api_key", value: .string(apiKey)))
        clientProperty.options.append(HostMapEntry(stringKey: "model", value: .string(model)))

        if let baseUrl = baseUrl {
            clientProperty.options.append(HostMapEntry(stringKey: "base_url", value: .string(baseUrl)))
        }

        // Numeric options - must use proper types, not strings
        if let temperature = temperature {
            clientProperty.options.append(HostMapEntry(stringKey: "temperature", value: .float(temperature)))
        }
        if let maxTokens = maxTokens {
            clientProperty.options.append(HostMapEntry(stringKey: "max_tokens", value: .int(Int64(maxTokens))))
        }

        var registry = HostClientRegistry()
        registry.clients.append(clientProperty)
        registry.primary = clientName
        return registry
    }
}

// MARK: - BamlArgumentsBuilder Extension

extension BamlArgumentsBuilder {
    /// Set the LLM client configuration for this call
    public mutating func setLLMClient(_ config: LLMClientConfig) {
        setClientRegistry(config.toHostClientRegistry())
    }
}

#endif // BAML_FFI_ENABLED
