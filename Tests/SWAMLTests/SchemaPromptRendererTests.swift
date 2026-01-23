import XCTest
@testable import SWAML

final class SchemaPromptRendererTests: XCTestCase {

    // MARK: - Basic Schema Rendering

    func testRenderStringSchema() {
        let result = SchemaPromptRenderer.renderSchema(.string)
        XCTAssertEqual(result, "string")
    }

    func testRenderIntegerSchema() {
        let result = SchemaPromptRenderer.renderSchema(.integer)
        XCTAssertEqual(result, "int")
    }

    func testRenderNumberSchema() {
        let result = SchemaPromptRenderer.renderSchema(.number)
        XCTAssertEqual(result, "float")
    }

    func testRenderBooleanSchema() {
        let result = SchemaPromptRenderer.renderSchema(.boolean)
        XCTAssertEqual(result, "bool")
    }

    func testRenderNullSchema() {
        let result = SchemaPromptRenderer.renderSchema(.null)
        XCTAssertEqual(result, "null")
    }

    // MARK: - Array Schema (BAML style: type[])

    func testRenderArraySchema() {
        let schema = JSONSchema.array(items: .string)
        let result = SchemaPromptRenderer.renderSchema(schema)
        XCTAssertEqual(result, "string[]")
    }

    func testRenderNestedArraySchema() {
        let schema = JSONSchema.array(items: .array(items: .integer))
        let result = SchemaPromptRenderer.renderSchema(schema)
        XCTAssertEqual(result, "int[][]")
    }

    // MARK: - Enum Schema

    func testRenderEnumSchema() {
        let schema = JSONSchema.enum(values: ["active", "inactive"])
        let result = SchemaPromptRenderer.renderSchema(schema)
        XCTAssertEqual(result, "\"active\" | \"inactive\"")
    }

    func testRenderSingleValueEnum() {
        let schema = JSONSchema.enum(values: ["only"])
        let result = SchemaPromptRenderer.renderSchema(schema)
        XCTAssertEqual(result, "\"only\"")
    }

    // MARK: - Object Schema (BAML style: unquoted field names)

    func testRenderEmptyObjectSchema() {
        let schema = JSONSchema.object(properties: [:], required: [])
        let result = SchemaPromptRenderer.renderSchema(schema)
        XCTAssertEqual(result, "{}")
    }

    func testRenderSimpleObjectSchema() {
        let schema = JSONSchema.object(
            properties: [
                "name": .string,
                "age": .integer
            ],
            required: ["name", "age"]
        )
        let result = SchemaPromptRenderer.renderSchema(schema)

        // BAML style: unquoted field names
        XCTAssertTrue(result.contains("name: string"))
        XCTAssertTrue(result.contains("age: int"))
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertTrue(result.hasSuffix("}"))
    }

    func testRenderObjectWithOptional() {
        let schema = JSONSchema.object(
            properties: [
                "name": .string,
                "bio": .string
            ],
            required: ["name"]
        )
        let result = SchemaPromptRenderer.renderSchema(schema)

        XCTAssertTrue(result.contains("name: string"))
        XCTAssertTrue(result.contains("bio?: string"))  // Optional marker
    }

    func testRenderObjectWithDescriptions() {
        let schema = JSONSchema.object(
            properties: [
                "name": .string,
                "age": .integer
            ],
            required: ["name", "age"]
        )
        let descriptions = ["name": "User's full name", "age": "Age in years"]
        let result = SchemaPromptRenderer.renderSchema(schema, descriptions: descriptions)

        // BAML style: descriptions as comments above fields
        XCTAssertTrue(result.contains("// User's full name"))
        XCTAssertTrue(result.contains("// Age in years"))
    }

    // MARK: - Optional/Union Schema

    func testRenderOptionalPattern() {
        let schema = JSONSchema.anyOf([.string, .null])
        let result = SchemaPromptRenderer.renderSchema(schema)
        XCTAssertEqual(result, "string | null")
    }

    func testRenderUnionSchema() {
        let schema = JSONSchema.anyOf([.string, .integer, .boolean])
        let result = SchemaPromptRenderer.renderSchema(schema)
        XCTAssertEqual(result, "string | int | bool")
    }

    // MARK: - Full Prompt Rendering

    func testRenderFullPrompt() {
        let schema = JSONSchema.object(
            properties: ["sentiment": .string, "confidence": .number],
            required: ["sentiment", "confidence"]
        )
        let result = SchemaPromptRenderer.render(schema: schema)

        XCTAssertTrue(result.hasPrefix("Answer in JSON using this schema:"))
        XCTAssertTrue(result.contains("sentiment: string"))
        XCTAssertTrue(result.contains("confidence: float"))
    }

    // MARK: - TypeBuilder Integration

    func testRenderWithDynamicEnum() {
        let typeBuilder = TypeBuilder()
        let enumBuilder = typeBuilder.enumBuilder("Status")
        enumBuilder.addValue("active")
        enumBuilder.addValue("inactive")
        enumBuilder.addValue("pending")

        let result = SchemaPromptRenderer.renderSchema(.ref("Status"), typeBuilder: typeBuilder)
        XCTAssertEqual(result, "\"active\" | \"inactive\" | \"pending\"")
    }

    // MARK: - Primitive Type Conformance

    func testRenderForStringType() {
        // For plain strings, BAML doesn't add any special prompt
        // (the LLM just responds with text)
        let result = SchemaPromptRenderer.render(for: String.self)
        XCTAssertEqual(result, "")
    }

    func testRenderForIntType() {
        let result = SchemaPromptRenderer.render(for: Int.self)
        XCTAssertTrue(result.contains("int"))
    }

    func testRenderForBoolType() {
        let result = SchemaPromptRenderer.render(for: Bool.self)
        XCTAssertTrue(result.contains("bool"))
    }

    // MARK: - FieldType Extension

    func testFieldTypeToSchemaText() {
        let fieldType = FieldType.list(.string)
        let result = fieldType.toSchemaText()
        XCTAssertEqual(result, "string[]")
    }

    // MARK: - JSONSchema Extension

    func testJSONSchemaToSchemaText() {
        let schema = JSONSchema.enum(values: ["a", "b", "c"])
        let result = schema.toSchemaText()
        XCTAssertEqual(result, "\"a\" | \"b\" | \"c\"")
    }

    // MARK: - Reference Resolution

    func testRefWithoutTypeBuilderReturnsName() {
        let schema = JSONSchema.ref("MyType")
        let result = SchemaPromptRenderer.renderSchema(schema)
        XCTAssertEqual(result, "MyType")
    }

    func testRefWithTypeBuilderResolvesEnum() {
        let tb = TypeBuilder()
        let enumBuilder = tb.enumBuilder("MyEnum")
        enumBuilder.addValue("x")
        enumBuilder.addValue("y")

        let result = SchemaPromptRenderer.renderSchema(.ref("MyEnum"), typeBuilder: tb)
        XCTAssertEqual(result, "\"x\" | \"y\"")
    }

    func testRefWithTypeBuilderUnknownReturnsName() {
        let tb = TypeBuilder()

        let result = SchemaPromptRenderer.renderSchema(.ref("UnknownType"), typeBuilder: tb)
        XCTAssertEqual(result, "UnknownType")
    }

    // MARK: - Document Rendering

    func testRenderDocument() {
        let root = JSONSchema.object(
            properties: ["status": .ref("Status")],
            required: ["status"]
        )
        let definitions: [String: JSONSchema] = [
            "Status": .enum(values: ["active", "inactive"])
        ]

        let result = SchemaPromptRenderer.renderDocument(
            root: root,
            definitions: definitions
        )

        XCTAssertTrue(result.contains("Type definitions:"))
        XCTAssertTrue(result.contains("Status"))
        XCTAssertTrue(result.contains("Answer in JSON using this schema:"))
    }

    func testRenderDocumentWithTypeBuilder() {
        let tb = TypeBuilder()
        let priority = tb.enumBuilder("Priority")
        priority.addValue("high")
        priority.addValue("low")

        let root = JSONSchema.object(
            properties: ["priority": .ref("Priority")],
            required: ["priority"]
        )

        let result = SchemaPromptRenderer.renderDocument(root: root, typeBuilder: tb)

        XCTAssertTrue(result.contains("Type definitions:"))
        XCTAssertTrue(result.contains("Priority"))
        XCTAssertTrue(result.contains("\"high\""))
    }

    // MARK: - Complex Nested Schemas

    func testComplexNestedSchema() {
        let schema = JSONSchema.object(
            properties: [
                "users": .array(items: .object(
                    properties: [
                        "name": .string,
                        "roles": .array(items: .enum(values: ["admin", "user"]))
                    ],
                    required: ["name", "roles"]
                ))
            ],
            required: ["users"]
        )

        let result = SchemaPromptRenderer.renderSchema(schema)

        // BAML style: type[] for arrays, unquoted field names
        XCTAssertTrue(result.contains("users: {"))
        XCTAssertTrue(result.contains("name: string"))
        XCTAssertTrue(result.contains("\"admin\" | \"user\""))
    }

    // MARK: - BamlTyped Rendering

    func testRenderForCustomBamlTyped() {
        struct TestType: BamlTyped {
            let value: Int

            static var bamlTypeName: String { "TestType" }
            static var bamlSchema: JSONSchema {
                .object(properties: ["value": .integer], required: ["value"])
            }
            static var fieldDescriptions: [String: String] {
                ["value": "A test value"]
            }
        }

        let result = SchemaPromptRenderer.render(for: TestType.self, includeDescriptions: true)

        XCTAssertTrue(result.contains("Answer in JSON using this schema:"))
        XCTAssertTrue(result.contains("value: int"))
        XCTAssertTrue(result.contains("// A test value"))
    }

    func testRenderWithoutDescriptions() {
        struct DescribedType: BamlTyped {
            let x: Int

            static var bamlTypeName: String { "DescribedType" }
            static var bamlSchema: JSONSchema {
                .object(properties: ["x": .integer], required: ["x"])
            }
            static var fieldDescriptions: [String: String] {
                ["x": "Should not appear"]
            }
        }

        let result = SchemaPromptRenderer.render(for: DescribedType.self, includeDescriptions: false)

        XCTAssertFalse(result.contains("Should not appear"))
    }

    // MARK: - Render from Class Name

    func testRenderFromClassName() {
        let tb = TypeBuilder()
        let classBuilder = tb.addClass("MyClass")
        classBuilder.addProperty("name", .string).description("The name")
        classBuilder.addProperty("count", .int)

        let result = SchemaPromptRenderer.render(className: "MyClass", from: tb)

        XCTAssertTrue(result.contains("Answer in JSON using this schema:"))
        XCTAssertTrue(result.contains("name: string"))
        XCTAssertTrue(result.contains("count: int"))
        XCTAssertTrue(result.contains("// The name"))
    }

    func testRenderFromUnknownClassNameFallback() {
        let tb = TypeBuilder()

        let result = SchemaPromptRenderer.render(className: "Unknown", from: tb)

        XCTAssertEqual(result, "Answer in JSON.")
    }
}
