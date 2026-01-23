import XCTest
@testable import SWAML

final class RetryPolicyTests: XCTestCase {

    // MARK: - Delay Calculation

    func testDelayForAttempt() {
        let policy = RetryPolicy(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 60.0,
            multiplier: 2.0,
            jitter: false
        )

        XCTAssertEqual(policy.delayForAttempt(0), 1.0)
        XCTAssertEqual(policy.delayForAttempt(1), 2.0)
        XCTAssertEqual(policy.delayForAttempt(2), 4.0)
        XCTAssertEqual(policy.delayForAttempt(3), 8.0)
    }

    func testDelayRespectsMaxDelay() {
        let policy = RetryPolicy(
            maxRetries: 10,
            initialDelay: 1.0,
            maxDelay: 5.0,
            multiplier: 2.0,
            jitter: false
        )

        // After several attempts, should be capped at maxDelay
        XCTAssertEqual(policy.delayForAttempt(10), 5.0)
    }

    func testDelayWithJitter() {
        let policy = RetryPolicy(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 60.0,
            multiplier: 2.0,
            jitter: true
        )

        let delay = policy.delayForAttempt(0)

        // With jitter, delay should be between base and base * 1.25
        XCTAssertGreaterThanOrEqual(delay, 1.0)
        XCTAssertLessThanOrEqual(delay, 1.25)
    }

    // MARK: - Should Retry

    func testShouldRetryOnRateLimitError() {
        let policy = RetryPolicy.standard

        let error = SwamlError.apiError(statusCode: 429, message: "Rate limited")
        XCTAssertTrue(policy.shouldRetry(error: error, attempt: 0))
    }

    func testShouldRetryOnServerError() {
        let policy = RetryPolicy.standard

        let error500 = SwamlError.apiError(statusCode: 500, message: "Internal error")
        let error502 = SwamlError.apiError(statusCode: 502, message: "Bad gateway")
        let error503 = SwamlError.apiError(statusCode: 503, message: "Service unavailable")

        XCTAssertTrue(policy.shouldRetry(error: error500, attempt: 0))
        XCTAssertTrue(policy.shouldRetry(error: error502, attempt: 0))
        XCTAssertTrue(policy.shouldRetry(error: error503, attempt: 0))
    }

    func testShouldNotRetryOnClientError() {
        let policy = RetryPolicy.standard

        let error400 = SwamlError.apiError(statusCode: 400, message: "Bad request")
        let error401 = SwamlError.apiError(statusCode: 401, message: "Unauthorized")
        let error404 = SwamlError.apiError(statusCode: 404, message: "Not found")

        XCTAssertFalse(policy.shouldRetry(error: error400, attempt: 0))
        XCTAssertFalse(policy.shouldRetry(error: error401, attempt: 0))
        XCTAssertFalse(policy.shouldRetry(error: error404, attempt: 0))
    }

    func testShouldRetryOnNetworkError() {
        let policy = RetryPolicy.standard

        let error = SwamlError.networkError("Connection failed")
        XCTAssertTrue(policy.shouldRetry(error: error, attempt: 0))
    }

    func testShouldNotRetryOnParseError() {
        let policy = RetryPolicy.standard

        let error = SwamlError.parseError("Invalid JSON")
        XCTAssertFalse(policy.shouldRetry(error: error, attempt: 0))
    }

    func testShouldNotRetryAfterMaxAttempts() {
        let policy = RetryPolicy(maxRetries: 3)

        let error = SwamlError.apiError(statusCode: 500, message: "Server error")

        XCTAssertTrue(policy.shouldRetry(error: error, attempt: 0))
        XCTAssertTrue(policy.shouldRetry(error: error, attempt: 1))
        XCTAssertTrue(policy.shouldRetry(error: error, attempt: 2))
        XCTAssertFalse(policy.shouldRetry(error: error, attempt: 3)) // Max reached
    }

    // MARK: - Preset Policies

    func testNonePolicy() {
        let policy = RetryPolicy.none

        XCTAssertEqual(policy.maxRetries, 0)

        let error = SwamlError.apiError(statusCode: 500, message: "Error")
        XCTAssertFalse(policy.shouldRetry(error: error, attempt: 0))
    }

    func testStandardPolicy() {
        let policy = RetryPolicy.standard

        XCTAssertEqual(policy.maxRetries, 3)
        XCTAssertEqual(policy.initialDelay, 1.0)
        XCTAssertTrue(policy.jitter)
    }

    func testAggressivePolicy() {
        let policy = RetryPolicy.aggressive

        XCTAssertEqual(policy.maxRetries, 5)
        XCTAssertEqual(policy.initialDelay, 0.5)
        XCTAssertEqual(policy.maxDelay, 120.0)
    }
}
