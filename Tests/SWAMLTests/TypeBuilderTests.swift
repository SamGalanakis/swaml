import XCTest
@testable import SWAML

final class TypeBuilderTests: XCTestCase {

    // MARK: - FieldType Primitives

    func testFieldTypePrimitives() {
        XCTAssertEqual(FieldType.string, .string)
        XCTAssertEqual(FieldType.int, .int)
        XCTAssertEqual(FieldType.float, .float)
        XCTAssertEqual(FieldType.bool, .bool)
        XCTAssertEqual(FieldType.null, .null)
    }

    func testFieldTypeLiterals() {
        let literalStr = FieldType.literalString("hello")
        let literalInt = FieldType.literalInt(42)
        let literalBool = FieldType.literalBool(true)

        if case .literalString(let value) = literalStr {
            XCTAssertEqual(value, "hello")
        } else {
            XCTFail("Expected literalString")
        }

        if case .literalInt(let value) = literalInt {
            XCTAssertEqual(value, 42)
        } else {
            XCTFail("Expected literalInt")
        }

        if case .literalBool(let value) = literalBool {
            XCTAssertTrue(value)
        } else {
            XCTFail("Expected literalBool")
        }
    }

    func testFieldTypeChaining() {
        // Test .list() chaining
        let listOfStrings = FieldType.string.list()
        if case .list(let inner) = listOfStrings {
            XCTAssertEqual(inner, .string)
        } else {
            XCTFail("Expected list type")
        }

        // Test .optional() chaining
        let optionalInt = FieldType.int.optional()
        if case .optional(let inner) = optionalInt {
            XCTAssertEqual(inner, .int)
        } else {
            XCTFail("Expected optional type")
        }

        // Test chaining multiple modifiers
        let optionalListOfStrings = FieldType.string.list().optional()
        if case .optional(let inner) = optionalListOfStrings {
            if case .list(let innerInner) = inner {
                XCTAssertEqual(innerInner, .string)
            } else {
                XCTFail("Expected list inside optional")
            }
        } else {
            XCTFail("Expected optional type")
        }
    }

    func testFieldTypeReference() {
        let ref = FieldType.reference("MyClass")
        if case .reference(let name) = ref {
            XCTAssertEqual(name, "MyClass")
        } else {
            XCTFail("Expected reference type")
        }
    }

    func testFieldTypeComposite() {
        // Test list static factory
        let list = FieldType.list(.string)
        if case .list(let inner) = list {
            XCTAssertEqual(inner, .string)
        } else {
            XCTFail("Expected list type")
        }

        // Test map
        let map = FieldType.map(key: .string, value: .int)
        if case .map(let key, let value) = map {
            XCTAssertEqual(key, .string)
            XCTAssertEqual(value, .int)
        } else {
            XCTFail("Expected map type")
        }

        // Test union
        let union = FieldType.union([.string, .int])
        if case .union(let types) = union {
            XCTAssertEqual(types.count, 2)
            XCTAssertEqual(types[0], .string)
            XCTAssertEqual(types[1], .int)
        } else {
            XCTFail("Expected union type")
        }
    }

    func testFieldTypeSerialization() {
        let stringType = FieldType.string.toSerializable()
        XCTAssertEqual(stringType["type"] as? String, "string")

        let listType = FieldType.string.list().toSerializable()
        XCTAssertEqual(listType["type"] as? String, "list")
        let inner = listType["inner"] as? [String: Any]
        XCTAssertEqual(inner?["type"] as? String, "string")

        let refType = FieldType.reference("MyEnum").toSerializable()
        XCTAssertEqual(refType["type"] as? String, "ref")
        XCTAssertEqual(refType["name"] as? String, "MyEnum")
    }

    func testFieldTypeToJSONSchema() {
        XCTAssertEqual(FieldType.string.toJSONSchema(), .string)
        XCTAssertEqual(FieldType.int.toJSONSchema(), .integer)
        XCTAssertEqual(FieldType.float.toJSONSchema(), .number)
        XCTAssertEqual(FieldType.bool.toJSONSchema(), .boolean)
        XCTAssertEqual(FieldType.null.toJSONSchema(), .null)
    }

    func testFieldTypeToSwiftType() {
        XCTAssertEqual(FieldType.string.toSwiftType(), "String")
        XCTAssertEqual(FieldType.int.toSwiftType(), "Int")
        XCTAssertEqual(FieldType.float.toSwiftType(), "Double")
        XCTAssertEqual(FieldType.bool.toSwiftType(), "Bool")
        XCTAssertEqual(FieldType.string.list().toSwiftType(), "[String]")
        XCTAssertEqual(FieldType.int.optional().toSwiftType(), "Int?")
        XCTAssertEqual(FieldType.reference("Person").toSwiftType(), "Person")
    }

    // MARK: - Enum Value Builder

    func testEnumValueBuilder() {
        let builder = EnumValueBuilder(name: "ACTIVE")
            .description("Currently active")
            .alias("active")

        XCTAssertEqual(builder.name, "ACTIVE")
        XCTAssertEqual(builder.descriptionValue, "Currently active")
        XCTAssertEqual(builder.aliasValue, "active")
    }

    func testEnumValueBuilderSerialization() {
        let builder = EnumValueBuilder(name: "TECH")
            .description("Technology topics")
            .alias("tech")

        let serialized = builder.toSerializable()
        XCTAssertEqual(serialized["name"] as? String, "TECH")
        XCTAssertEqual(serialized["description"] as? String, "Technology topics")
        XCTAssertEqual(serialized["alias"] as? String, "tech")
    }

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

    func testDynamicEnumBuilderWithMetadata() {
        let builder = DynamicEnumBuilder(name: "Category")
        builder.addValue("TECH").description("Technology topics").alias("tech")
        builder.addValue("SPORTS").description("Sports related")

        XCTAssertEqual(builder.count, 2)

        let valueBuilders = builder.allValueBuilders
        XCTAssertEqual(valueBuilders.count, 2)
        XCTAssertEqual(valueBuilders[0].descriptionValue, "Technology topics")
        XCTAssertEqual(valueBuilders[0].aliasValue, "tech")
        XCTAssertEqual(valueBuilders[1].descriptionValue, "Sports related")
        XCTAssertNil(valueBuilders[1].aliasValue)
    }

    func testDynamicEnumBuilderType() {
        let builder = DynamicEnumBuilder(name: "Status")
        let fieldType = builder.type()

        if case .reference(let name) = fieldType {
            XCTAssertEqual(name, "Status")
        } else {
            XCTFail("Expected reference type")
        }
    }

    func testDynamicEnumBuilderSerialization() {
        let builder = DynamicEnumBuilder(name: "Category")
        builder.addValue("TECH").description("Technology").alias("tech")
        builder.addValue("SPORTS")

        let serialized = builder.toSerializable()
        XCTAssertEqual(serialized["name"] as? String, "Category")

        let values = serialized["values"] as? [[String: Any]]
        XCTAssertEqual(values?.count, 2)
        XCTAssertEqual(values?[0]["name"] as? String, "TECH")
        XCTAssertEqual(values?[0]["description"] as? String, "Technology")
        XCTAssertEqual(values?[0]["alias"] as? String, "tech")
        XCTAssertEqual(values?[1]["name"] as? String, "SPORTS")
    }

    // MARK: - Class Property Builder

    func testClassPropertyBuilder() {
        let builder = ClassPropertyBuilder(name: "email", type: .string)
            .description("User email address")
            .alias("emailAddress")

        XCTAssertEqual(builder.name, "email")
        XCTAssertEqual(builder.fieldType, .string)
        XCTAssertEqual(builder.descriptionValue, "User email address")
        XCTAssertEqual(builder.aliasValue, "emailAddress")
    }

    func testClassPropertyBuilderSerialization() {
        let builder = ClassPropertyBuilder(name: "age", type: .int.optional())
            .description("User age")

        let serialized = builder.toSerializable()
        XCTAssertEqual(serialized["name"] as? String, "age")
        XCTAssertEqual(serialized["description"] as? String, "User age")

        let typeDict = serialized["type"] as? [String: Any]
        XCTAssertEqual(typeDict?["type"] as? String, "optional")
    }

    // MARK: - Dynamic Class Builder

    func testDynamicClassBuilder() {
        let builder = DynamicClassBuilder(name: "Person")
        builder.addProperty("name", .string)
        builder.addProperty("age", .int.optional())
        builder.addProperty("email", .string)

        XCTAssertEqual(builder.name, "Person")
        XCTAssertEqual(builder.count, 3)
        XCTAssertEqual(builder.allPropertyNames, ["name", "age", "email"])
        XCTAssertTrue(builder.hasProperty("name"))
        XCTAssertFalse(builder.hasProperty("address"))
    }

    func testDynamicClassBuilderWithMetadata() {
        let builder = DynamicClassBuilder(name: "User")
        builder.addProperty("name", .string).description("Full name")
        builder.addProperty("age", .int).alias("userAge")

        let props = builder.allPropertyBuilders
        XCTAssertEqual(props.count, 2)
        XCTAssertEqual(props[0].descriptionValue, "Full name")
        XCTAssertEqual(props[1].aliasValue, "userAge")
    }

    func testDynamicClassBuilderNoDuplicates() {
        let builder = DynamicClassBuilder(name: "Test")
        builder.addProperty("field", .string)
        builder.addProperty("field", .int) // duplicate - should return existing

        XCTAssertEqual(builder.count, 1)
        // Type should be the original (string), not the second call
        XCTAssertEqual(builder.allPropertyBuilders[0].fieldType, .string)
    }

    func testDynamicClassBuilderType() {
        let builder = DynamicClassBuilder(name: "Person")
        let fieldType = builder.type()

        if case .reference(let name) = fieldType {
            XCTAssertEqual(name, "Person")
        } else {
            XCTFail("Expected reference type")
        }
    }

    func testDynamicClassBuilderSerialization() {
        let builder = DynamicClassBuilder(name: "Person")
        builder.addProperty("name", .string).description("Full name")
        builder.addProperty("age", .int.optional())

        let serialized = builder.toSerializable()
        XCTAssertEqual(serialized["name"] as? String, "Person")

        let properties = serialized["properties"] as? [[String: Any]]
        XCTAssertEqual(properties?.count, 2)
        XCTAssertEqual(properties?[0]["name"] as? String, "name")
        XCTAssertEqual(properties?[0]["description"] as? String, "Full name")
        XCTAssertEqual(properties?[1]["name"] as? String, "age")
    }

    func testDynamicClassBuilderSchema() {
        let builder = DynamicClassBuilder(name: "Person")
        builder.addProperty("name", .string)
        builder.addProperty("age", .int.optional())

        let schema = builder.buildSchema()

        if case .object(let properties, let required, _) = schema {
            XCTAssertEqual(properties.count, 2)
            XCTAssertEqual(required, ["name"]) // age is optional
            XCTAssertEqual(properties["name"], .string)
        } else {
            XCTFail("Expected object schema")
        }
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

    func testTypeBuilderFluentAPI() {
        let tb = TypeBuilder()

        // Test primitive type factories
        XCTAssertEqual(tb.string(), .string)
        XCTAssertEqual(tb.int(), .int)
        XCTAssertEqual(tb.float(), .float)
        XCTAssertEqual(tb.bool(), .bool)
        XCTAssertEqual(tb.null(), .null)

        // Test literal type factories
        if case .literalString(let value) = tb.literalString("hello") {
            XCTAssertEqual(value, "hello")
        } else {
            XCTFail("Expected literalString")
        }

        // Test composite type factories
        let listType = tb.list(tb.string())
        if case .list(let inner) = listType {
            XCTAssertEqual(inner, .string)
        } else {
            XCTFail("Expected list type")
        }

        let mapType = tb.map(key: tb.string(), value: tb.int())
        if case .map(let key, let value) = mapType {
            XCTAssertEqual(key, .string)
            XCTAssertEqual(value, .int)
        } else {
            XCTFail("Expected map type")
        }

        let unionType = tb.union(tb.string(), tb.int())
        if case .union(let types) = unionType {
            XCTAssertEqual(types.count, 2)
        } else {
            XCTFail("Expected union type")
        }
    }

    func testTypeBuilderAddClass() {
        let tb = TypeBuilder()

        let person = tb.addClass("Person")
        person.addProperty("name", tb.string())
        person.addProperty("age", tb.int().optional())

        // Get same class builder again
        let samePerson = tb.addClass("Person")
        samePerson.addProperty("email", tb.string())

        // Should be the same instance
        XCTAssertEqual(person.count, 3)
        XCTAssertEqual(samePerson.count, 3)

        // Test allClassBuilders
        XCTAssertEqual(tb.allClassBuilders.count, 1)
        XCTAssertNotNil(tb.allClassBuilders["Person"])
    }

    func testTypeBuilderAddEnum() {
        let tb = TypeBuilder()

        let status = tb.addEnum("Status")
        status.addValue("ACTIVE")
        status.addValue("INACTIVE")

        // Should be same as enumBuilder
        XCTAssertEqual(tb.enumBuilder("Status").count, 2)
    }

    func testTypeBuilderBuildClassSchema() {
        let tb = TypeBuilder()

        let person = tb.addClass("Person")
        person.addProperty("name", tb.string())
        person.addProperty("age", tb.int())

        let schema = tb.buildClassSchema("Person")
        XCTAssertNotNil(schema)

        if case .object(let properties, let required, _) = schema {
            XCTAssertEqual(properties.count, 2)
            XCTAssertTrue(required.contains("name"))
            XCTAssertTrue(required.contains("age"))
        } else {
            XCTFail("Expected object schema")
        }

        // Test non-existent class
        XCTAssertNil(tb.buildClassSchema("DoesNotExist"))
    }

    func testTypeBuilderDynamicEnumValues() {
        let tb = TypeBuilder()

        let momentEnum = tb.enumBuilder("MomentId")
        momentEnum.addValue("m1")
        momentEnum.addValue("m2")
        tb.enumBuilder("PatternId").addValue("p1")

        let values = tb.dynamicEnumValues()
        XCTAssertEqual(values["MomentId"], ["m1", "m2"])
        XCTAssertEqual(values["PatternId"], ["p1"])
    }

    func testTypeBuilderBuildEnumSchema() {
        let tb = TypeBuilder()

        let testEnum = tb.enumBuilder("TestEnum")
        testEnum.addValue("A")
        testEnum.addValue("B")
        testEnum.addValue("C")

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

    // MARK: - TypeBuilder Serialization

    func testTypeBuilderSerialization() {
        let tb = TypeBuilder()

        // Add an enum with metadata
        tb.addEnum("Category")
            .addValue("TECH").description("Technology").alias("tech")
        tb.addEnum("Category")
            .addValue("SPORTS")

        // Add a class
        let person = tb.addClass("Person")
        person.addProperty("name", tb.string()).description("Full name")
        person.addProperty("age", tb.int().optional())

        let serialized = tb.toSerializable()

        // Check enums
        let enums = serialized["enums"] as? [[String: Any]]
        XCTAssertEqual(enums?.count, 1)
        XCTAssertEqual(enums?[0]["name"] as? String, "Category")

        let enumValues = enums?[0]["values"] as? [[String: Any]]
        XCTAssertEqual(enumValues?.count, 2)

        // Check classes
        let classes = serialized["classes"] as? [[String: Any]]
        XCTAssertEqual(classes?.count, 1)
        XCTAssertEqual(classes?[0]["name"] as? String, "Person")

        let classProps = classes?[0]["properties"] as? [[String: Any]]
        XCTAssertEqual(classProps?.count, 2)
    }

    func testTypeBuilderToJSON() throws {
        let tb = TypeBuilder()
        tb.addEnum("Status").addValue("ACTIVE")
        tb.addClass("Item").addProperty("id", tb.string())

        let jsonData = try tb.toJSON()
        XCTAssertFalse(jsonData.isEmpty)

        // Verify it's valid JSON
        let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(decoded?["enums"])
        XCTAssertNotNil(decoded?["classes"])
    }

    func testTypeBuilderToJSONString() throws {
        let tb = TypeBuilder()
        tb.addEnum("Status").addValue("ACTIVE")

        let jsonString = try tb.toJSONString()
        XCTAssertTrue(jsonString.contains("Status"))
        XCTAssertTrue(jsonString.contains("ACTIVE"))

        // Test pretty printed
        let prettyJSON = try tb.toJSONString(prettyPrinted: true)
        XCTAssertTrue(prettyJSON.contains("\n"))
    }

    func testTypeBuilderEmptySerialization() {
        let tb = TypeBuilder()

        // Create builders but don't add values/properties
        _ = tb.enumBuilder("EmptyEnum")
        _ = tb.addClass("EmptyClass")

        let serialized = tb.toSerializable()

        // Empty builders should not be included
        let enums = serialized["enums"] as? [[String: Any]]
        XCTAssertEqual(enums?.count, 0)

        let classes = serialized["classes"] as? [[String: Any]]
        XCTAssertEqual(classes?.count, 0)
    }

    // MARK: - EnumValue

    func testEnumValue() {
        let withAlias = EnumValue(name: "HAPPY", alias: "Happy")
        let withoutAlias = EnumValue(name: "SAD")

        XCTAssertEqual(withAlias.stringValue, "Happy")
        XCTAssertEqual(withoutAlias.stringValue, "SAD")
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
