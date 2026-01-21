import Foundation

/// Represents different LLM API providers
public enum LLMProvider: Sendable {
    case openRouter(apiKey: String)
    case openAI(apiKey: String)
    case anthropic(apiKey: String)
    case custom(baseURL: URL, apiKey: String, headers: [String: String] = [:])

    /// The base URL for API requests
    public var baseURL: URL {
        switch self {
        case .openRouter:
            return URL(string: "https://openrouter.ai/api/v1")!
        case .openAI:
            return URL(string: "https://api.openai.com/v1")!
        case .anthropic:
            return URL(string: "https://api.anthropic.com/v1")!
        case .custom(let baseURL, _, _):
            return baseURL
        }
    }

    /// The authorization header name and value
    public var authHeader: (name: String, value: String) {
        switch self {
        case .openRouter(let apiKey):
            return ("Authorization", "Bearer \(apiKey)")
        case .openAI(let apiKey):
            return ("Authorization", "Bearer \(apiKey)")
        case .anthropic(let apiKey):
            return ("x-api-key", apiKey)
        case .custom(_, let apiKey, _):
            return ("Authorization", "Bearer \(apiKey)")
        }
    }

    /// Additional headers required by the provider
    public var additionalHeaders: [String: String] {
        switch self {
        case .openRouter:
            return [
                "HTTP-Referer": "https://swaml.dev",
                "X-Title": "SWAML"
            ]
        case .openAI:
            return [:]
        case .anthropic:
            return [
                "anthropic-version": "2023-06-01",
                "content-type": "application/json"
            ]
        case .custom(_, _, let headers):
            return headers
        }
    }

    /// Whether this provider uses OpenAI-compatible API format
    public var isOpenAICompatible: Bool {
        switch self {
        case .openRouter, .openAI:
            return true
        case .anthropic:
            return false
        case .custom:
            return true // Assume OpenAI-compatible for custom providers
        }
    }

    /// The chat completions endpoint path
    public var chatCompletionsPath: String {
        switch self {
        case .anthropic:
            return "/messages"
        default:
            return "/chat/completions"
        }
    }
}
