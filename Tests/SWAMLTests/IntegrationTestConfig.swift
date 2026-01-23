import Foundation
@testable import SWAML

/// Central configuration for integration tests
enum IntegrationTestConfig {
    /// The model to use for all integration tests
    static let model = "google/gemini-2.5-flash"

    /// Get the OpenRouter API key from environment
    static var apiKey: String? {
        ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
    }

    /// Check if integration tests can run
    static var canRunIntegrationTests: Bool {
        apiKey != nil
    }

    /// Create a configured SwamlClient for tests
    static func createClient() -> SwamlClient? {
        guard let key = apiKey else { return nil }
        return SwamlClient(provider: .openRouter(apiKey: key))
    }

    /// Create a configured LLMClient for tests
    static func createLLMClient() -> LLMClient? {
        guard let key = apiKey else { return nil }
        return LLMClient(provider: .openRouter(apiKey: key))
    }

    /// Skip message for tests that require API key
    static let skipMessage = "Skipping: OPENROUTER_API_KEY not set"
}
