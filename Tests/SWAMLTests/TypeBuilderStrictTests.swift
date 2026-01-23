import XCTest
@testable import SWAML

final class TypeBuilderStrictTests: XCTestCase {

    // MARK: - Dynamic Type Registration

    func testRegisterDynamicType() {
        let tb = TypeBuilder()

        tb.registerDynamicType("MyDynamicEnum")
        XCTAssertTrue(tb.isDynamicType("MyDynamicEnum"))
        XCTAssertFalse(tb.isDynamicType("NotRegistered"))
    }

    func testRegisterDynamicTypeFromBamlTyped() {
        enum DynamicEnum: String, BamlTyped {
            case a
            static var bamlTypeName: String { "DynamicEnum" }
            static var bamlSchema: JSONSchema { .enum(values: ["a"]) }
            static var isDynamic: Bool { true }
        }

        struct NonDynamicStruct: BamlTyped {
            let x: Int
            static var bamlTypeName: String { "NonDynamicStruct" }
            static var bamlSchema: JSONSchema { .object(properties: ["x": .integer], required: ["x"]) }
        }

        let tb = TypeBuilder()

        // Dynamic type gets registered
        tb.registerDynamicType(DynamicEnum.self)
        XCTAssertTrue(tb.isDynamicType("DynamicEnum"))

        // Non-dynamic type does not get registered
        tb.registerDynamicType(NonDynamicStruct.self)
        XCTAssertFalse(tb.isDynamicType("NonDynamicStruct"))
    }

    func testRegisteredDynamicTypes() {
        let tb = TypeBuilder()

        tb.registerDynamicType("A")
        tb.registerDynamicType("B")
        tb.registerDynamicType("C")

        let registered = tb.registeredDynamicTypes
        XCTAssertEqual(registered, ["A", "B", "C"])
    }

    // MARK: - Typed Enum Builder

    func testEnumBuilderForDynamicType() throws {
        enum DynamicEnum: String, BamlTyped {
            case a
            static var bamlTypeName: String { "DynamicEnum" }
            static var bamlSchema: JSONSchema { .enum(values: ["a"]) }
            static var isDynamic: Bool { true }
        }

        let tb = TypeBuilder()
        let builder = try tb.enumBuilder(for: DynamicEnum.self)

        builder.addValue("b")
        builder.addValue("c")

        XCTAssertEqual(builder.allValues, ["b", "c"])

        // Type should be auto-registered
        XCTAssertTrue(tb.isDynamicType("DynamicEnum"))
    }

    func testEnumBuilderForNonDynamicTypeFails() {
        enum NonDynamicEnum: String, BamlTyped {
            case a
            static var bamlTypeName: String { "NonDynamicEnum" }
            static var bamlSchema: JSONSchema { .enum(values: ["a"]) }
            // isDynamic defaults to false
        }

        let tb = TypeBuilder()

        XCTAssertThrowsError(try tb.enumBuilder(for: NonDynamicEnum.self)) { error in
            guard case TypeBuilderError.typeNotDynamic(let name) = error else {
                XCTFail("Expected typeNotDynamic error")
                return
            }
            XCTAssertEqual(name, "NonDynamicEnum")
        }
    }

    // MARK: - Typed Class Builder

    func testClassBuilderForDynamicType() throws {
        struct DynamicClass: BamlTyped {
            let x: Int
            static var bamlTypeName: String { "DynamicClass" }
            static var bamlSchema: JSONSchema { .object(properties: ["x": .integer], required: ["x"]) }
            static var isDynamic: Bool { true }
        }

        let tb = TypeBuilder()
        let builder = try tb.classBuilder(for: DynamicClass.self)

        builder.addProperty("y", .string)
        builder.addProperty("z", .bool)

        XCTAssertEqual(builder.allPropertyNames, ["y", "z"])
        XCTAssertTrue(tb.isDynamicType("DynamicClass"))
    }

    func testClassBuilderForNonDynamicTypeFails() {
        struct NonDynamicClass: BamlTyped {
            let x: Int
            static var bamlTypeName: String { "NonDynamicClass" }
            static var bamlSchema: JSONSchema { .object(properties: ["x": .integer], required: ["x"]) }
        }

        let tb = TypeBuilder()

        XCTAssertThrowsError(try tb.classBuilder(for: NonDynamicClass.self)) { error in
            guard case TypeBuilderError.typeNotDynamic(let name) = error else {
                XCTFail("Expected typeNotDynamic error")
                return
            }
            XCTAssertEqual(name, "NonDynamicClass")
        }
    }

    // MARK: - Strict Extension Methods

    func testExtendEnumStrictWithRegisteredType() throws {
        let tb = TypeBuilder()

        tb.registerDynamicType("MyEnum")
        try tb.extendEnumStrict("MyEnum", values: ["a", "b", "c"])

        XCTAssertEqual(tb.enumBuilder("MyEnum").allValues, ["a", "b", "c"])
    }

    func testExtendEnumStrictWithUnregisteredTypeFails() {
        let tb = TypeBuilder()

        XCTAssertThrowsError(try tb.extendEnumStrict("UnregisteredEnum", values: ["a"])) { error in
            guard case TypeBuilderError.typeNotDynamic(_) = error else {
                XCTFail("Expected typeNotDynamic error")
                return
            }
        }
    }

    func testExtendClassStrictWithRegisteredType() throws {
        let tb = TypeBuilder()

        tb.registerDynamicType("MyClass")
        try tb.extendClassStrict("MyClass", properties: [
            ("name", .string),
            ("age", .int),
            ("active", .bool)
        ])

        let builder = tb.classBuilder("MyClass")
        XCTAssertEqual(builder.allPropertyNames, ["name", "age", "active"])
    }

    func testExtendClassStrictWithUnregisteredTypeFails() {
        let tb = TypeBuilder()

        XCTAssertThrowsError(try tb.extendClassStrict("UnregisteredClass", properties: [("x", .int)])) { error in
            guard case TypeBuilderError.typeNotDynamic(_) = error else {
                XCTFail("Expected typeNotDynamic error")
                return
            }
        }
    }

    // MARK: - Unstrict Methods Still Work

    func testUnstrictEnumBuilderAlwaysWorks() {
        let tb = TypeBuilder()

        // Can always create enum builder without registration
        let builder = tb.enumBuilder("AnyEnum")
        builder.addValue("x")
        builder.addValue("y")

        XCTAssertEqual(builder.allValues, ["x", "y"])
    }

    func testUnstrictClassBuilderAlwaysWorks() {
        let tb = TypeBuilder()

        // Can always create class builder without registration
        let builder = tb.classBuilder("AnyClass")
        builder.addProperty("prop1", .string)

        XCTAssertTrue(builder.hasProperty("prop1"))
    }

    // MARK: - Error Messages

    func testTypeNotDynamicErrorMessage() {
        let error = TypeBuilderError.typeNotDynamic("MyType")
        XCTAssertTrue(error.localizedDescription.contains("MyType"))
        XCTAssertTrue(error.localizedDescription.contains("@BamlDynamic"))
    }

    func testTypeNotRegisteredErrorMessage() {
        let error = TypeBuilderError.typeNotRegistered("MyType")
        XCTAssertTrue(error.localizedDescription.contains("MyType"))
        XCTAssertTrue(error.localizedDescription.contains("not registered"))
    }
}
