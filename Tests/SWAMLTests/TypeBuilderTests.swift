import XCTest
@testable import SWAML

final class TypeBuilderTests: XCTestCase {

    // MARK: - Class Builder

    func testClassBuilder() {
        let builder = ClassBuilder(name: "Person")
            .addProperty("name", type: .string)
            .addProperty("age", type: .int)
            .addProperty("email", type: .optional(.string))

        XCTAssertEqual(builder.name, "Person")
        XCTAssertEqual(builder.allProperties.count, 3)
    }

    func testClassBuilderSchema() {
        let builder = ClassBuilder(name: "Person")
            .addProperty("name", type: .string)
            .addProperty("age", type: .int)

        let schema = builder.buildSchema()

        if case .object(let properties, let required, _) = schema {
            XCTAssertEqual(properties.count, 2)
            XCTAssertTrue(required.contains("name"))
            XCTAssertTrue(required.contains("age"))
        } else {
            XCTFail("Expected object schema")
        }
    }

    func testClassBuilderOptionalNotRequired() {
        let builder = ClassBuilder(name: "User")
            .addProperty("id", type: .int)
            .addProperty("nickname", type: .optional(.string))

        let schema = builder.buildSchema()

        if case .object(_, let required, _) = schema {
            XCTAssertTrue(required.contains("id"))
            XCTAssertFalse(required.contains("nickname"))
        } else {
            XCTFail("Expected object schema")
        }
    }

    // MARK: - Enum Builder

    func testEnumBuilder() {
        let builder = EnumBuilder(name: "Status")
            .addValue("pending")
            .addValue("active")
            .addValue("completed")

        XCTAssertEqual(builder.name, "Status")
        XCTAssertEqual(builder.valueStrings, ["pending", "active", "completed"])
    }

    func testEnumBuilderWithAlias() {
        let builder = EnumBuilder(name: "Color")
            .addValue("RED", alias: "Red")
            .addValue("GREEN", alias: "Green")

        let values = builder.allValues
        XCTAssertEqual(values[0].alias, "Red")
        XCTAssertEqual(values[1].alias, "Green")
    }

    func testEnumBuilderSchema() {
        let builder = EnumBuilder(name: "Priority")
            .addValue("low")
            .addValue("medium")
            .addValue("high")

        let schema = builder.buildSchema()

        if case .enum(let values) = schema {
            XCTAssertEqual(values, ["low", "medium", "high"])
        } else {
            XCTFail("Expected enum schema")
        }
    }

    // MARK: - Type Builder

    func testTypeBuilder() {
        let tb = TypeBuilder()

        tb.addClass("Person")
            .addProperty("name", type: .string)
            .addProperty("age", type: .int)

        tb.addEnum("Status")
            .addValue("active")
            .addValue("inactive")

        XCTAssertEqual(tb.classNames.count, 1)
        XCTAssertEqual(tb.enumNames.count, 1)
        XCTAssertNotNil(tb.getClass("Person"))
        XCTAssertNotNil(tb.getEnum("Status"))
    }

    func testTypeBuilderBuildSchema() throws {
        let tb = TypeBuilder()

        tb.addClass("Response")
            .addProperty("score", type: .float)
            .addProperty("labels", type: .array(.string))

        let schema = try tb.buildSchema(root: "Response")

        XCTAssertNotNil(schema["type"])
        XCTAssertNotNil(schema["properties"])
    }

    func testTypeBuilderSimpleHelpers() {
        let tb = TypeBuilder()

        tb.addSimpleClass("Point", properties: [
            "x": .float,
            "y": .float
        ])

        tb.addSimpleEnum("Direction", values: ["north", "south", "east", "west"])

        XCTAssertNotNil(tb.getClass("Point"))
        XCTAssertNotNil(tb.getEnum("Direction"))
        XCTAssertEqual(tb.getEnum("Direction")?.valueStrings.count, 4)
    }

    // MARK: - Schema Generation

    func testSchemaWithReferences() throws {
        let tb = TypeBuilder()

        tb.addClass("Address")
            .addProperty("street", type: .string)
            .addProperty("city", type: .string)

        tb.addClass("Person")
            .addProperty("name", type: .string)
            .addProperty("address", type: .reference("Address"))

        let schema = try tb.buildSchema(root: "Person")

        XCTAssertNotNil(schema["$defs"])
    }

    // MARK: - Swift Code Generation

    func testGenerateSwiftStruct() {
        let builder = ClassBuilder(name: "User")
            .addProperty("id", type: .int, description: "Unique identifier")
            .addProperty("name", type: .string)
            .addProperty("scores", type: .array(.float))

        let code = builder.generateSwiftStruct()

        XCTAssertTrue(code.contains("public struct User"))
        XCTAssertTrue(code.contains("public let id: Int"))
        XCTAssertTrue(code.contains("public let name: String"))
        XCTAssertTrue(code.contains("public let scores: [Double]"))
    }

    func testGenerateSwiftEnum() {
        let builder = EnumBuilder(name: "Priority")
            .addValue("LOW")
            .addValue("MEDIUM")
            .addValue("HIGH")

        let code = builder.generateSwiftEnum()

        XCTAssertTrue(code.contains("public enum Priority"))
        XCTAssertTrue(code.contains("case low"))
        XCTAssertTrue(code.contains("case medium"))
        XCTAssertTrue(code.contains("case high"))
    }
}
