import XCTest
@testable import SWAML

final class BamlTypedTests: XCTestCase {

    // MARK: - Primitive Types

    func testStringBamlTyped() {
        XCTAssertEqual(String.bamlTypeName, "string")
        XCTAssertEqual(String.bamlSchema, .string)
        XCTAssertFalse(String.isDynamic)
    }

    func testIntBamlTyped() {
        XCTAssertEqual(Int.bamlTypeName, "int")
        XCTAssertEqual(Int.bamlSchema, .integer)
    }

    func testDoubleBamlTyped() {
        XCTAssertEqual(Double.bamlTypeName, "float")
        XCTAssertEqual(Double.bamlSchema, .number)
    }

    func testFloatBamlTyped() {
        XCTAssertEqual(Float.bamlTypeName, "float")
        XCTAssertEqual(Float.bamlSchema, .number)
    }

    func testBoolBamlTyped() {
        XCTAssertEqual(Bool.bamlTypeName, "bool")
        XCTAssertEqual(Bool.bamlSchema, .boolean)
    }

    // MARK: - Array Types

    func testStringArrayBamlTyped() {
        XCTAssertEqual([String].bamlTypeName, "[string]")
        XCTAssertEqual([String].bamlSchema, .array(items: .string))
    }

    func testIntArrayBamlTyped() {
        XCTAssertEqual([Int].bamlTypeName, "[int]")
        XCTAssertEqual([Int].bamlSchema, .array(items: .integer))
    }

    func testNestedArrayBamlTyped() {
        XCTAssertEqual([[String]].bamlTypeName, "[[string]]")
        XCTAssertEqual([[String]].bamlSchema, .array(items: .array(items: .string)))
    }

    // MARK: - Optional Types

    func testOptionalStringBamlTyped() {
        XCTAssertEqual(String?.bamlTypeName, "string?")
        XCTAssertEqual(String?.bamlSchema, .anyOf([.string, .null]))
    }

    func testOptionalIntBamlTyped() {
        XCTAssertEqual(Int?.bamlTypeName, "int?")
        XCTAssertEqual(Int?.bamlSchema, .anyOf([.integer, .null]))
    }

    // MARK: - Dictionary Types

    func testStringDictionaryBamlTyped() {
        XCTAssertEqual([String: String].bamlTypeName, "map<string, string>")
        if case .object(let props, let required, let additional) = [String: String].bamlSchema {
            XCTAssertTrue(props.isEmpty)
            XCTAssertTrue(required.isEmpty)
            XCTAssertEqual(additional, .string)
        } else {
            XCTFail("Expected object schema")
        }
    }

    func testIntDictionaryBamlTyped() {
        XCTAssertEqual([String: Int].bamlTypeName, "map<string, int>")
    }

    // MARK: - BamlTypeInfo

    func testBamlTypeInfo() {
        let info = BamlTypeInfo(for: String.self)
        XCTAssertEqual(info.name, "string")
        XCTAssertEqual(info.schema, .string)
        XCTAssertFalse(info.isDynamic)
        XCTAssertTrue(info.fieldDescriptions.isEmpty)
    }

    func testManualBamlTypeInfo() {
        let info = BamlTypeInfo(
            name: "CustomType",
            schema: .object(properties: ["x": .integer], required: ["x"]),
            isDynamic: true,
            fieldDescriptions: ["x": "The x value"]
        )

        XCTAssertEqual(info.name, "CustomType")
        XCTAssertTrue(info.isDynamic)
        XCTAssertEqual(info.fieldDescriptions["x"], "The x value")
    }

    // MARK: - BamlTypeRegistry

    func testTypeRegistryBasics() {
        let registry = BamlTypeRegistry.shared
        registry.clear()

        // Register a type manually
        let info = BamlTypeInfo(
            name: "TestEnum",
            schema: .enum(values: ["a", "b"]),
            isDynamic: true
        )
        // Note: BamlTypeRegistry uses BamlTyped types, not manual info
        // So we test with primitives which auto-conform
        registry.register(String.self)

        // String is not dynamic
        XCTAssertFalse(registry.isDynamic("string"))
    }

    func testTypeRegistryExtendNonDynamic() {
        let registry = BamlTypeRegistry.shared
        registry.clear()

        // Can't extend unregistered type
        XCTAssertThrowsError(try registry.extendEnum("UnknownType", with: ["x"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("not registered"))
        }
    }

    // MARK: - Custom BamlTyped Conformance

    func testCustomBamlTypedConformance() {
        // Test that a manually conforming type works
        struct CustomStruct: BamlTyped {
            let value: String

            static var bamlTypeName: String { "CustomStruct" }
            static var bamlSchema: JSONSchema {
                .object(properties: ["value": .string], required: ["value"])
            }
        }

        XCTAssertEqual(CustomStruct.bamlTypeName, "CustomStruct")
        XCTAssertFalse(CustomStruct.isDynamic) // Default
        XCTAssertTrue(CustomStruct.fieldDescriptions.isEmpty) // Default
    }

    func testDynamicBamlTypedConformance() {
        // Test a type that declares itself as dynamic
        enum DynamicEnum: String, BamlTyped {
            case a, b

            static var bamlTypeName: String { "DynamicEnum" }
            static var bamlSchema: JSONSchema { .enum(values: ["a", "b"]) }
            static var isDynamic: Bool { true }
        }

        XCTAssertTrue(DynamicEnum.isDynamic)
        XCTAssertEqual(DynamicEnum.bamlTypeName, "DynamicEnum")
    }
}
