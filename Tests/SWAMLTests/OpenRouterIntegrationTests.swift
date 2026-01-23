import XCTest
@testable import SWAML

/// Integration tests that require OPENROUTER_API_KEY environment variable.
/// These tests make real API calls to verify end-to-end functionality.
///
/// To run: OPENROUTER_API_KEY=your-key swift test --filter OpenRouterIntegration
final class OpenRouterIntegrationTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        try XCTSkipUnless(
            IntegrationTestConfig.canRunIntegrationTests,
            IntegrationTestConfig.skipMessage
        )
    }

    // MARK: - Basic LLM Client Tests

    func testBasicCompletion() async throws {
        let client = IntegrationTestConfig.createLLMClient()!

        let response = try await client.complete(
            model: IntegrationTestConfig.model,
            messages: [.user("Reply with exactly: hello")]
        )

        XCTAssertFalse(response.content.isEmpty)
        XCTAssertTrue(response.content.lowercased().contains("hello"))
    }

    func testJSONResponseFormat() async throws {
        let client = IntegrationTestConfig.createLLMClient()!

        let response = try await client.complete(
            model: IntegrationTestConfig.model,
            messages: [
                .system("Reply with JSON only. No markdown."),
                .user("Return: {\"value\": 42}")
            ],
            responseFormat: .jsonObject
        )

        // Should be valid JSON
        let data = response.content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
    }

    // MARK: - SwamlClient Tests

    func testSwamlClientCall() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct SimpleResult: BamlTyped {
            let number: Int

            static var bamlTypeName: String { "SimpleResult" }
            static var bamlSchema: JSONSchema {
                .object(properties: ["number": .integer], required: ["number"])
            }
        }

        let result = try await client.call(
            model: IntegrationTestConfig.model,
            prompt: "Return the number 42",
            returnType: SimpleResult.self
        )

        XCTAssertEqual(result.number, 42)
    }

    func testSwamlClientWithStringOutput() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct WordResult: BamlTyped {
            let word: String

            static var bamlTypeName: String { "WordResult" }
            static var bamlSchema: JSONSchema {
                .object(properties: ["word": .string], required: ["word"])
            }
        }

        let result = try await client.call(
            model: IntegrationTestConfig.model,
            prompt: "Return the word 'cat'",
            returnType: WordResult.self
        )

        XCTAssertEqual(result.word.lowercased(), "cat")
    }

    func testSwamlClientWithArray() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct ListResult: BamlTyped {
            let items: [String]

            static var bamlTypeName: String { "ListResult" }
            static var bamlSchema: JSONSchema {
                .object(properties: ["items": .array(items: .string)], required: ["items"])
            }
        }

        let result = try await client.call(
            model: IntegrationTestConfig.model,
            prompt: "Return items: [\"a\", \"b\", \"c\"]",
            returnType: ListResult.self
        )

        XCTAssertEqual(result.items, ["a", "b", "c"])
    }

    func testSwamlClientWithOptional() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct OptionalResult: BamlTyped {
            let name: String
            let age: Int?

            static var bamlTypeName: String { "OptionalResult" }
            static var bamlSchema: JSONSchema {
                .object(
                    properties: [
                        "name": .string,
                        "age": .anyOf([.integer, .null])
                    ],
                    required: ["name"]
                )
            }
        }

        let result = try await client.call(
            model: IntegrationTestConfig.model,
            prompt: "Return name='test' with no age",
            returnType: OptionalResult.self
        )

        XCTAssertEqual(result.name, "test")
        XCTAssertNil(result.age)
    }

    func testSwamlClientWithEnum() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct EnumResult: BamlTyped {
            let color: String

            static var bamlTypeName: String { "EnumResult" }
            static var bamlSchema: JSONSchema {
                .object(
                    properties: ["color": .enum(values: ["red", "green", "blue"])],
                    required: ["color"]
                )
            }
        }

        let result = try await client.call(
            model: IntegrationTestConfig.model,
            prompt: "Return color='red'",
            returnType: EnumResult.self
        )

        XCTAssertEqual(result.color, "red")
    }

    // MARK: - Dynamic Schema Tests

    func testCallDynamic() async throws {
        let client = IntegrationTestConfig.createClient()!

        let schema = JSONSchema.object(
            properties: ["x": .integer, "y": .integer],
            required: ["x", "y"]
        )

        let result = try await client.callDynamic(
            model: IntegrationTestConfig.model,
            prompt: "Return x=10, y=20",
            schema: schema
        )

        XCTAssertEqual(result["x"]?.intValue, 10)
        XCTAssertEqual(result["y"]?.intValue, 20)
    }

    // MARK: - Schema Prompt Tests

    func testSchemaPromptIncludedInRequest() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct BoolResult: BamlTyped {
            let flag: Bool

            static var bamlTypeName: String { "BoolResult" }
            static var bamlSchema: JSONSchema {
                .object(properties: ["flag": .boolean], required: ["flag"])
            }
        }

        // The schema prompt tells the LLM what format to use
        let result = try await client.call(
            model: IntegrationTestConfig.model,
            prompt: "Return flag=true",
            returnType: BoolResult.self
        )

        XCTAssertTrue(result.flag)
    }

    // MARK: - TypeBuilder Integration

    func testDynamicEnumExtension() async throws {
        let client = IntegrationTestConfig.createClient()!

        enum DynamicStatus: String, BamlTyped {
            case active

            static var bamlTypeName: String { "DynamicStatus" }
            static var bamlSchema: JSONSchema { .enum(values: ["active"]) }
            static var isDynamic: Bool { true }
        }

        // Extend the enum with new values
        try await client.extendEnum(DynamicStatus.self, with: ["inactive", "pending"])

        // Verify the extension
        let values = client.types.enumBuilder(DynamicStatus.bamlTypeName).allValues
        XCTAssertEqual(values, ["inactive", "pending"])
    }

    // MARK: - Error Handling

    func testInvalidModelReturnsError() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct SimpleResult: BamlTyped {
            let x: Int
            static var bamlTypeName: String { "SimpleResult" }
            static var bamlSchema: JSONSchema {
                .object(properties: ["x": .integer], required: ["x"])
            }
        }

        do {
            _ = try await client.call(
                model: "invalid/nonexistent-model-12345",
                prompt: "test",
                returnType: SimpleResult.self
            )
            XCTFail("Should have thrown an error")
        } catch {
            // Expected - invalid model should fail
            XCTAssertTrue(error is BamlError)
        }
    }

    // MARK: - Nested Types

    func testNestedObject() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct Inner: Codable {
            let value: Int
        }

        struct Outer: BamlTyped {
            let inner: Inner

            static var bamlTypeName: String { "Outer" }
            static var bamlSchema: JSONSchema {
                .object(
                    properties: [
                        "inner": .object(
                            properties: ["value": .integer],
                            required: ["value"]
                        )
                    ],
                    required: ["inner"]
                )
            }
        }

        let result = try await client.call(
            model: IntegrationTestConfig.model,
            prompt: "Return inner.value=99",
            returnType: Outer.self
        )

        XCTAssertEqual(result.inner.value, 99)
    }

    // MARK: - Multiple Fields

    func testMultipleFields() async throws {
        let client = IntegrationTestConfig.createClient()!

        struct Person: BamlTyped {
            let name: String
            let age: Int
            let active: Bool

            static var bamlTypeName: String { "Person" }
            static var bamlSchema: JSONSchema {
                .object(
                    properties: [
                        "name": .string,
                        "age": .integer,
                        "active": .boolean
                    ],
                    required: ["name", "age", "active"]
                )
            }
        }

        let result = try await client.call(
            model: IntegrationTestConfig.model,
            prompt: "Return name='Alice', age=30, active=true",
            returnType: Person.self
        )

        XCTAssertEqual(result.name, "Alice")
        XCTAssertEqual(result.age, 30)
        XCTAssertTrue(result.active)
    }
}
