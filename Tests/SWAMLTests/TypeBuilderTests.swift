import XCTest
@testable import SWAML

final class TypeBuilderTests: XCTestCase {

    // MARK: - Dynamic Enum Builder

    func testDynamicEnumBuilder() {
        let builder = DynamicEnumBuilder(name: "MomentId")
        builder.addValue("moment_1")
        builder.addValue("moment_2")
        builder.addValue("moment_3")

        XCTAssertEqual(builder.name, "MomentId")
        XCTAssertEqual(builder.allValues, ["moment_1", "moment_2", "moment_3"])
        XCTAssertEqual(builder.count, 3)
        XCTAssertTrue(builder.hasValue("moment_1"))
        XCTAssertFalse(builder.hasValue("moment_999"))
    }

    func testDynamicEnumBuilderNoDuplicates() {
        let builder = DynamicEnumBuilder(name: "PatternId")
        builder.addValue("pattern_1")
        builder.addValue("pattern_1") // duplicate
        builder.addValue("pattern_2")

        XCTAssertEqual(builder.count, 2)
        XCTAssertEqual(builder.allValues, ["pattern_1", "pattern_2"])
    }

    func testDynamicEnumBuilderChaining() {
        let builder = DynamicEnumBuilder(name: "TestEnum")
            .addValue("a")
            .addValue("b")
            .addValue("c")

        XCTAssertEqual(builder.count, 3)
    }

    // MARK: - Static Enum Viewer

    func testStaticEnumViewer() {
        let viewer = StaticEnumViewer(
            name: "Status",
            values: [
                EnumValue(name: "ACTIVE", alias: "Active"),
                EnumValue(name: "INACTIVE", alias: "Inactive"),
                EnumValue(name: "PENDING")
            ]
        )

        XCTAssertEqual(viewer.name, "Status")
        XCTAssertEqual(viewer.values.count, 3)
        XCTAssertTrue(viewer.hasValue("ACTIVE"))
        XCTAssertFalse(viewer.hasValue("Unknown"))
        XCTAssertEqual(viewer.value("ACTIVE")?.stringValue, "Active")
        XCTAssertEqual(viewer.value("PENDING")?.stringValue, "PENDING")
    }

    // MARK: - TypeBuilder

    func testTypeBuilder() {
        let tb = TypeBuilder()

        // Get enum builder (creates if not exists)
        let momentBuilder = tb.enumBuilder("MomentId")
        momentBuilder.addValue("moment_1")
        momentBuilder.addValue("moment_2")

        // Get same enum builder again
        let sameBuilder = tb.enumBuilder("MomentId")
        sameBuilder.addValue("moment_3")

        // Should be the same instance
        XCTAssertEqual(momentBuilder.count, 3)
        XCTAssertEqual(sameBuilder.count, 3)
    }

    func testTypeBuilderDynamicEnumValues() {
        let tb = TypeBuilder()

        tb.enumBuilder("MomentId").addValue("m1").addValue("m2")
        tb.enumBuilder("PatternId").addValue("p1")

        let values = tb.dynamicEnumValues()
        XCTAssertEqual(values["MomentId"], ["m1", "m2"])
        XCTAssertEqual(values["PatternId"], ["p1"])
    }

    func testTypeBuilderBuildEnumSchema() {
        let tb = TypeBuilder()

        tb.enumBuilder("TestEnum").addValue("A").addValue("B").addValue("C")

        let schema = tb.buildEnumSchema("TestEnum")
        XCTAssertNotNil(schema)

        if case .enum(let values) = schema {
            XCTAssertEqual(values, ["A", "B", "C"])
        } else {
            XCTFail("Expected enum schema")
        }
    }

    func testTypeBuilderEmptyEnumSchema() {
        let tb = TypeBuilder()

        // Enum exists but has no values
        _ = tb.enumBuilder("EmptyEnum")

        let schema = tb.buildEnumSchema("EmptyEnum")
        XCTAssertNil(schema) // Should be nil when no values
    }

    func testTypeBuilderNonExistentEnumSchema() {
        let tb = TypeBuilder()

        let schema = tb.buildEnumSchema("DoesNotExist")
        XCTAssertNil(schema)
    }

    // MARK: - EnumValue

    func testEnumValue() {
        let withAlias = EnumValue(name: "HAPPY", alias: "Happy")
        let withoutAlias = EnumValue(name: "SAD")

        XCTAssertEqual(withAlias.stringValue, "Happy")
        XCTAssertEqual(withoutAlias.stringValue, "SAD")
    }

    // MARK: - Legacy Class Builder

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

    // MARK: - Legacy Enum Builder

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

    // MARK: - Thread Safety

    func testDynamicEnumBuilderThreadSafety() async {
        let builder = DynamicEnumBuilder(name: "ThreadTest")

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    builder.addValue("value_\(i)")
                }
            }
        }

        // Should have all unique values
        XCTAssertEqual(builder.count, 100)
    }

    func testTypeBuilderThreadSafety() async {
        let tb = TypeBuilder()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    tb.enumBuilder("Enum\(i % 5)").addValue("value_\(i)")
                }
            }
        }

        // Should have 5 enum builders
        XCTAssertEqual(tb.allEnumBuilders.count, 5)

        // Each should have 10 values
        for i in 0..<5 {
            XCTAssertEqual(tb.enumBuilder("Enum\(i)").count, 10)
        }
    }
}
