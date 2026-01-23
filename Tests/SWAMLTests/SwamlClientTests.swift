import XCTest
@testable import SWAML

final class SwamlClientTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithProvider() async {
        let client = SwamlClient(provider: .openAI(apiKey: "test-key"))
        // Should create without error
        XCTAssertNotNil(client)
    }

    func testConvenienceInitializers() async {
        let openRouter = SwamlClient.openRouter(apiKey: "test")
        XCTAssertNotNil(openRouter)

        let openAI = SwamlClient.openAI(apiKey: "test")
        XCTAssertNotNil(openAI)

        let anthropic = SwamlClient.anthropic(apiKey: "test")
        XCTAssertNotNil(anthropic)
    }

    // MARK: - TypeBuilder Access Tests

    func testTypesAccessor() async {
        let client = SwamlClient(provider: .openAI(apiKey: "test"))
        let types = client.types

        // Should return a TypeBuilder
        XCTAssertNotNil(types)

        // Can add enums
        let enumBuilder = types.enumBuilder("TestEnum")
        enumBuilder.addValue("a")
        enumBuilder.addValue("b")

        XCTAssertEqual(types.allEnumBuilders["TestEnum"]?.allValues, ["a", "b"])
    }

    // MARK: - Extend Enum Tests

    func testExtendEnumNonDynamicFails() async {
        let client = SwamlClient(provider: .openAI(apiKey: "test"))

        // String is not dynamic
        do {
            try await client.extendEnum(String.self, with: ["x"])
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("non-dynamic"))
        }
    }

    func testExtendEnumDynamicSucceeds() async throws {
        // Create a dynamic type for testing
        enum DynamicTestEnum: String, SwamlTyped {
            case a, b

            static var swamlTypeName: String { "DynamicTestEnum" }
            static var swamlSchema: JSONSchema { .enum(values: ["a", "b"]) }
            static var isDynamic: Bool { true }
        }

        let client = SwamlClient(provider: .openAI(apiKey: "test"))
        try await client.extendEnum(DynamicTestEnum.self, with: ["c", "d"])

        let values = client.types.enumBuilder(DynamicTestEnum.swamlTypeName).allValues
        XCTAssertEqual(values, ["c", "d"])
    }

    // MARK: - Extend Class Tests

    func testExtendClassNonDynamicFails() async {
        struct NonDynamicClass: SwamlTyped {
            let x: Int
            static var swamlTypeName: String { "NonDynamicClass" }
            static var swamlSchema: JSONSchema {
                .object(properties: ["x": .integer], required: ["x"])
            }
        }

        let client = SwamlClient(provider: .openAI(apiKey: "test"))

        do {
            try await client.extendClass(NonDynamicClass.self, property: "y", type: .string)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("non-dynamic"))
        }
    }

    func testExtendClassDynamicSucceeds() async throws {
        struct DynamicClass: SwamlTyped {
            let x: Int
            static var swamlTypeName: String { "DynamicClass" }
            static var swamlSchema: JSONSchema {
                .object(properties: ["x": .integer], required: ["x"])
            }
            static var isDynamic: Bool { true }
        }

        let client = SwamlClient(provider: .openAI(apiKey: "test"))
        try await client.extendClass(DynamicClass.self, property: "y", type: .string)
        try await client.extendClass(DynamicClass.self, property: "z", type: .bool)

        let classBuilder = client.types.classBuilder(DynamicClass.swamlTypeName)
        XCTAssertTrue(classBuilder.hasProperty("y"))
        XCTAssertTrue(classBuilder.hasProperty("z"))
    }
}

// MARK: - Schema Generation Tests

final class SwamlClientSchemaTests: XCTestCase {

    func testSwamlTypedPrimitivesGenerateCorrectSchema() {
        XCTAssertEqual(String.swamlSchema, .string)
        XCTAssertEqual(Int.swamlSchema, .integer)
        XCTAssertEqual(Double.swamlSchema, .number)
        XCTAssertEqual(Bool.swamlSchema, .boolean)
    }

    func testArrayGeneratesCorrectSchema() {
        let schema = [String].swamlSchema
        if case .array(let items) = schema {
            XCTAssertEqual(items, .string)
        } else {
            XCTFail("Expected array schema")
        }
    }

    func testOptionalGeneratesCorrectSchema() {
        let schema = Int?.swamlSchema
        if case .anyOf(let schemas) = schema {
            XCTAssertEqual(schemas.count, 2)
            XCTAssertTrue(schemas.contains(.integer))
            XCTAssertTrue(schemas.contains(.null))
        } else {
            XCTFail("Expected anyOf schema")
        }
    }

    func testDictionaryGeneratesCorrectSchema() {
        let schema = [String: Int].swamlSchema
        if case .object(_, _, let additionalProperties) = schema {
            XCTAssertEqual(additionalProperties, .integer)
        } else {
            XCTFail("Expected object schema")
        }
    }
}
