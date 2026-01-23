import Foundation

/// Configuration for an LLM client.
/// This provides a simple configuration structure that can be converted to LLMProvider.
public struct LLMClientConfig: Sendable {
    /// Name of the client (for identification)
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

    /// Convert to LLMProvider for use with SwamlClient
    public func toLLMProvider() -> LLMProvider {
        switch provider {
        case "anthropic":
            return .anthropic(apiKey: apiKey)
        case "openai":
            return .openAI(apiKey: apiKey)
        case "openai-generic":
            if let baseUrl = baseUrl, let url = URL(string: baseUrl) {
                return .custom(baseURL: url, apiKey: apiKey, headers: [:])
            }
            // OpenRouter is the most common openai-generic usage
            return .openRouter(apiKey: apiKey)
        default:
            // Default to custom provider
            if let url = URL(string: baseUrl ?? "https://api.openai.com/v1") {
                return .custom(baseURL: url, apiKey: apiKey, headers: [:])
            }
            return .openAI(apiKey: apiKey)
        }
    }
}
