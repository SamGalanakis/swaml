import Foundation

/// Configuration for retry behavior
public struct RetryPolicy: Sendable {
    /// Maximum number of retry attempts
    public let maxRetries: Int

    /// Initial delay between retries (in seconds)
    public let initialDelay: TimeInterval

    /// Maximum delay between retries (in seconds)
    public let maxDelay: TimeInterval

    /// Multiplier for exponential backoff
    public let multiplier: Double

    /// Whether to add random jitter to delays
    public let jitter: Bool

    /// HTTP status codes that should trigger a retry
    public let retryableStatusCodes: Set<Int>

    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        multiplier: Double = 2.0,
        jitter: Bool = true,
        retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitter = jitter
        self.retryableStatusCodes = retryableStatusCodes
    }

    /// Calculate delay for a given attempt number (0-indexed)
    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt))
        var delay = min(exponentialDelay, maxDelay)

        if jitter {
            // Add random jitter of up to 25%
            let jitterAmount = delay * 0.25 * Double.random(in: 0...1)
            delay += jitterAmount
        }

        return delay
    }

    /// Check if an error should be retried
    public func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }

        if let bamlError = error as? BamlError {
            switch bamlError {
            case .apiError(let statusCode, _):
                return retryableStatusCodes.contains(statusCode)
            case .networkError:
                return true
            default:
                return false
            }
        }

        // Retry on URL errors (network issues)
        if (error as NSError).domain == NSURLErrorDomain {
            return true
        }

        return false
    }

    /// Default policy with no retries
    public static let none = RetryPolicy(maxRetries: 0)

    /// Default policy with standard settings
    public static let standard = RetryPolicy()

    /// Aggressive retry policy for critical operations
    public static let aggressive = RetryPolicy(
        maxRetries: 5,
        initialDelay: 0.5,
        maxDelay: 120.0,
        multiplier: 2.0,
        jitter: true
    )
}

// MARK: - Retry Executor

/// Executes operations with retry logic
public struct RetryExecutor {
    public let policy: RetryPolicy

    public init(policy: RetryPolicy = .standard) {
        self.policy = policy
    }

    /// Execute an async operation with retries
    public func execute<T>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...policy.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                if !policy.shouldRetry(error: error, attempt: attempt) {
                    throw error
                }

                if attempt < policy.maxRetries {
                    let delay = policy.delayForAttempt(attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw BamlError.retryLimitExceeded(
            attempts: policy.maxRetries + 1,
            lastError: lastError?.localizedDescription ?? "Unknown error"
        )
    }
}
