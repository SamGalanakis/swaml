import Foundation

/// Errors that can occur during BAML operations
public enum BamlError: Error, LocalizedError, Sendable {
    /// Network-related error
    case networkError(String)

    /// API returned an error response
    case apiError(statusCode: Int, message: String)

    /// Failed to parse LLM output
    case parseError(String)

    /// JSON extraction failed
    case jsonExtractionError(String)

    /// Type coercion failed
    case typeCoercionError(expected: String, actual: String)

    /// Schema validation failed
    case schemaValidationError(String)

    /// Invalid function call
    case invalidFunctionCall(name: String, reason: String)

    /// Client not found in registry
    case clientNotFound(String)

    /// Retry limit exceeded
    case retryLimitExceeded(attempts: Int, lastError: String)

    /// Configuration error
    case configurationError(String)

    /// Internal error
    case internalError(String)

    /// FFI runtime creation failed
    case runtimeCreationFailed(String)

    /// FFI function call failed
    case ffiError(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .jsonExtractionError(let message):
            return "JSON extraction error: \(message)"
        case .typeCoercionError(let expected, let actual):
            return "Type coercion error: expected \(expected), got \(actual)"
        case .schemaValidationError(let message):
            return "Schema validation error: \(message)"
        case .invalidFunctionCall(let name, let reason):
            return "Invalid function call '\(name)': \(reason)"
        case .clientNotFound(let name):
            return "Client not found: \(name)"
        case .retryLimitExceeded(let attempts, let lastError):
            return "Retry limit exceeded after \(attempts) attempts. Last error: \(lastError)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        case .runtimeCreationFailed(let message):
            return "Failed to create BAML runtime: \(message)"
        case .ffiError(let message):
            return "FFI error: \(message)"
        }
    }
}
