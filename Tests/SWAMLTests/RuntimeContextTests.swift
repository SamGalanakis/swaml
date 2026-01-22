import XCTest
@testable import SWAML

final class RuntimeContextTests: XCTestCase {

    // MARK: - Default Context

    func testDefaultContext() {
        let ctx = RuntimeContext.default

        XCTAssertTrue(ctx.tags.isEmpty)
        XCTAssertNil(ctx.clientName)
        XCTAssertNil(ctx.temperature)
        XCTAssertNil(ctx.maxTokens)
        XCTAssertNil(ctx.responseFormat)
        XCTAssertTrue(ctx.customHeaders.isEmpty)
        XCTAssertNil(ctx.timeout)
    }

    // MARK: - Direct Initialization

    func testDirectInitialization() {
        let ctx = RuntimeContext(
            tags: ["env": "test", "user": "123"],
            clientName: "fast",
            temperature: 0.7,
            maxTokens: 1000,
            responseFormat: .jsonObject,
            customHeaders: ["X-Custom": "value"],
            timeout: 30.0
        )

        XCTAssertEqual(ctx.tags["env"], "test")
        XCTAssertEqual(ctx.tags["user"], "123")
        XCTAssertEqual(ctx.clientName, "fast")
        XCTAssertEqual(ctx.temperature, 0.7)
        XCTAssertEqual(ctx.maxTokens, 1000)
        XCTAssertEqual(ctx.customHeaders["X-Custom"], "value")
        XCTAssertEqual(ctx.timeout, 30.0)

        if case .jsonObject = ctx.responseFormat {
            // Success
        } else {
            XCTFail("Expected jsonObject response format")
        }
    }

    // MARK: - Convenience Initializers

    func testWithClient() {
        let ctx = RuntimeContext.withClient("smart")

        XCTAssertEqual(ctx.clientName, "smart")
        XCTAssertTrue(ctx.tags.isEmpty)
    }

    func testWithTags() {
        let ctx = RuntimeContext.withTags(["request_id": "abc123"])

        XCTAssertEqual(ctx.tags["request_id"], "abc123")
        XCTAssertNil(ctx.clientName)
    }

    // MARK: - Builder Pattern

    func testBuilderBasic() {
        let ctx = RuntimeContext.builder()
            .client("fast")
            .temperature(0.5)
            .maxTokens(500)
            .build()

        XCTAssertEqual(ctx.clientName, "fast")
        XCTAssertEqual(ctx.temperature, 0.5)
        XCTAssertEqual(ctx.maxTokens, 500)
    }

    func testBuilderTags() {
        let ctx = RuntimeContext.builder()
            .tag("user_id", "123")
            .tag("session", "abc")
            .build()

        XCTAssertEqual(ctx.tags["user_id"], "123")
        XCTAssertEqual(ctx.tags["session"], "abc")
    }

    func testBuilderBulkTags() {
        let ctx = RuntimeContext.builder()
            .tags(["a": "1", "b": "2"])
            .tag("c", "3")
            .build()

        XCTAssertEqual(ctx.tags["a"], "1")
        XCTAssertEqual(ctx.tags["b"], "2")
        XCTAssertEqual(ctx.tags["c"], "3")
    }

    func testBuilderHeaders() {
        let ctx = RuntimeContext.builder()
            .header("Authorization", "Bearer token")
            .header("X-Request-ID", "req-123")
            .build()

        XCTAssertEqual(ctx.customHeaders["Authorization"], "Bearer token")
        XCTAssertEqual(ctx.customHeaders["X-Request-ID"], "req-123")
    }

    func testBuilderResponseFormat() {
        let ctx = RuntimeContext.builder()
            .responseFormat(.jsonObject)
            .build()

        if case .jsonObject = ctx.responseFormat {
            // Success
        } else {
            XCTFail("Expected jsonObject response format")
        }
    }

    func testBuilderTimeout() {
        let ctx = RuntimeContext.builder()
            .timeout(60.0)
            .build()

        XCTAssertEqual(ctx.timeout, 60.0)
    }

    func testBuilderChaining() {
        let ctx = RuntimeContext.builder()
            .client("smart")
            .temperature(0.8)
            .maxTokens(2000)
            .tag("env", "production")
            .header("X-API-Version", "v2")
            .timeout(120.0)
            .build()

        XCTAssertEqual(ctx.clientName, "smart")
        XCTAssertEqual(ctx.temperature, 0.8)
        XCTAssertEqual(ctx.maxTokens, 2000)
        XCTAssertEqual(ctx.tags["env"], "production")
        XCTAssertEqual(ctx.customHeaders["X-API-Version"], "v2")
        XCTAssertEqual(ctx.timeout, 120.0)
    }

    // MARK: - Child Context

    func testChildContextInheritsValues() {
        let parent = RuntimeContext(
            tags: ["parent": "tag"],
            clientName: "default",
            temperature: 0.5,
            maxTokens: 1000,
            customHeaders: ["X-Parent": "value"]
        )

        let child = parent.child()

        XCTAssertEqual(child.tags["parent"], "tag")
        XCTAssertEqual(child.clientName, "default")
        XCTAssertEqual(child.temperature, 0.5)
        XCTAssertEqual(child.maxTokens, 1000)
        XCTAssertEqual(child.customHeaders["X-Parent"], "value")
    }

    func testChildContextOverridesValues() {
        let parent = RuntimeContext(
            tags: ["env": "dev"],
            clientName: "default",
            temperature: 0.5,
            maxTokens: 1000
        )

        let child = parent.child(
            clientName: "fast",
            temperature: 0.9
        )

        XCTAssertEqual(child.clientName, "fast")
        XCTAssertEqual(child.temperature, 0.9)
        // Inherited values
        XCTAssertEqual(child.tags["env"], "dev")
        XCTAssertEqual(child.maxTokens, 1000)
    }

    func testChildContextMergesTags() {
        let parent = RuntimeContext(
            tags: ["a": "1", "b": "2"]
        )

        let child = parent.child(
            tags: ["b": "overridden", "c": "3"]
        )

        XCTAssertEqual(child.tags["a"], "1")
        XCTAssertEqual(child.tags["b"], "overridden")
        XCTAssertEqual(child.tags["c"], "3")
    }

    func testChildContextMergesHeaders() {
        let parent = RuntimeContext(
            customHeaders: ["X-A": "1", "X-B": "2"]
        )

        let child = parent.child(
            customHeaders: ["X-B": "overridden", "X-C": "3"]
        )

        XCTAssertEqual(child.customHeaders["X-A"], "1")
        XCTAssertEqual(child.customHeaders["X-B"], "overridden")
        XCTAssertEqual(child.customHeaders["X-C"], "3")
    }

    func testChildContextPreservesTimeout() {
        let parent = RuntimeContext(timeout: 30.0)
        let child = parent.child()

        XCTAssertEqual(child.timeout, 30.0)
    }

    // MARK: - Multiple Generations

    func testMultipleChildGenerations() {
        let root = RuntimeContext.builder()
            .tag("level", "root")
            .client("default")
            .build()

        let child1 = root.child(
            tags: ["level": "child1"],
            temperature: 0.5
        )

        let child2 = child1.child(
            tags: ["level": "child2"],
            maxTokens: 500
        )

        XCTAssertEqual(child2.tags["level"], "child2")
        XCTAssertEqual(child2.clientName, "default")
        XCTAssertEqual(child2.temperature, 0.5)
        XCTAssertEqual(child2.maxTokens, 500)
    }
}
