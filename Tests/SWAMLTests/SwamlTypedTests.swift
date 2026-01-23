import XCTest
@testable import SWAML

final class SwamlTypedTests: XCTestCase {

    // MARK: - Primitive Types

    func testStringSwamlTyped() {
        XCTAssertEqual(String.swamlTypeName, "string")
        XCTAssertEqual(String.swamlSchema, .string)
        XCTAssertFalse(String.isDynamic)
    }

    func testIntSwamlTyped() {
        XCTAssertEqual(Int.swamlTypeName, "int")
        XCTAssertEqual(Int.swamlSchema, .integer)
    }

    func testDoubleSwamlTyped() {
        XCTAssertEqual(Double.swamlTypeName, "float")
        XCTAssertEqual(Double.swamlSchema, .number)
    }

    func testFloatSwamlTyped() {
        XCTAssertEqual(Float.swamlTypeName, "float")
        XCTAssertEqual(Float.swamlSchema, .number)
    }

    func testBoolSwamlTyped() {
        XCTAssertEqual(Bool.swamlTypeName, "bool")
        XCTAssertEqual(Bool.swamlSchema, .boolean)
    }

    // MARK: - Array Types

    func testStringArraySwamlTyped() {
        XCTAssertEqual([String].swamlTypeName, "[string]")
        XCTAssertEqual([String].swamlSchema, .array(items: .string))
    }

    func testIntArraySwamlTyped() {
        XCTAssertEqual([Int].swamlTypeName, "[int]")
        XCTAssertEqual([Int].swamlSchema, .array(items: .integer))
    }

    func testNestedArraySwamlTyped() {
        XCTAssertEqual([[String]].swamlTypeName, "[[string]]")
        XCTAssertEqual([[String]].swamlSchema, .array(items: .array(items: .string)))
    }

    // MARK: - Optional Types

    func testOptionalStringSwamlTyped() {
        XCTAssertEqual(String?.swamlTypeName, "string?")
        XCTAssertEqual(String?.swamlSchema, .anyOf([.string, .null]))
    }

    func testOptionalIntSwamlTyped() {
        XCTAssertEqual(Int?.swamlTypeName, "int?")
        XCTAssertEqual(Int?.swamlSchema, .anyOf([.integer, .null]))
    }

    // MARK: - Dictionary Types

    func testStringDictionarySwamlTyped() {
        XCTAssertEqual([String: String].swamlTypeName, "map<string, string>")
        if case .object(let props, let required, let additional) = [String: String].swamlSchema {
            XCTAssertTrue(props.isEmpty)
            XCTAssertTrue(required.isEmpty)
            XCTAssertEqual(additional, .string)
        } else {
            XCTFail("Expected object schema")
        }
    }

    func testIntDictionarySwamlTyped() {
        XCTAssertEqual([String: Int].swamlTypeName, "map<string, int>")
    }

    // MARK: - SwamlTypeInfo

    func testSwamlTypeInfo() {
        let info = SwamlTypeInfo(for: String.self)
        XCTAssertEqual(info.name, "string")
        XCTAssertEqual(info.schema, .string)
        XCTAssertFalse(info.isDynamic)
        XCTAssertTrue(info.fieldDescriptions.isEmpty)
    }

    func testManualSwamlTypeInfo() {
        let info = SwamlTypeInfo(
            name: "CustomType",
            schema: .object(properties: ["x": .integer], required: ["x"]),
            isDynamic: true,
            fieldDescriptions: ["x": "The x value"]
        )

        XCTAssertEqual(info.name, "CustomType")
        XCTAssertTrue(info.isDynamic)
        XCTAssertEqual(info.fieldDescriptions["x"], "The x value")
    }

    // MARK: - SwamlTypeRegistry

    func testTypeRegistryBasics() {
        let registry = SwamlTypeRegistry.shared
        registry.clear()

        // Register a type manually
        let info = SwamlTypeInfo(
            name: "TestEnum",
            schema: .enum(values: ["a", "b"]),
            isDynamic: true
        )
        // Note: SwamlTypeRegistry uses SwamlTyped types, not manual info
        // So we test with primitives which auto-conform
        registry.register(String.self)

        // String is not dynamic
        XCTAssertFalse(registry.isDynamic("string"))
    }

    func testTypeRegistryExtendNonDynamic() {
        let registry = SwamlTypeRegistry.shared
        registry.clear()

        // Can't extend unregistered type
        XCTAssertThrowsError(try registry.extendEnum("UnknownType", with: ["x"])) { error in
            XCTAssertTrue(error.localizedDescription.contains("not registered"))
        }
    }

    // MARK: - Custom SwamlTyped Conformance

    func testCustomSwamlTypedConformance() {
        // Test that a manually conforming type works
        struct CustomStruct: SwamlTyped {
            let value: String

            static var swamlTypeName: String { "CustomStruct" }
            static var swamlSchema: JSONSchema {
                .object(properties: ["value": .string], required: ["value"])
            }
        }

        XCTAssertEqual(CustomStruct.swamlTypeName, "CustomStruct")
        XCTAssertFalse(CustomStruct.isDynamic) // Default
        XCTAssertTrue(CustomStruct.fieldDescriptions.isEmpty) // Default
    }

    func testDynamicSwamlTypedConformance() {
        // Test a type that declares itself as dynamic
        enum DynamicEnum: String, SwamlTyped {
            case a, b

            static var swamlTypeName: String { "DynamicEnum" }
            static var swamlSchema: JSONSchema { .enum(values: ["a", "b"]) }
            static var isDynamic: Bool { true }
        }

        XCTAssertTrue(DynamicEnum.isDynamic)
        XCTAssertEqual(DynamicEnum.swamlTypeName, "DynamicEnum")
    }
}
