import XCTest
@testable import SWAML

final class JSONSchemaTests: XCTestCase {

    // MARK: - Primitive Types

    func testStringSchema() {
        let schema = JSONSchema.string
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "string")
    }

    func testIntegerSchema() {
        let schema = JSONSchema.integer
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "integer")
    }

    func testNumberSchema() {
        let schema = JSONSchema.number
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "number")
    }

    func testBooleanSchema() {
        let schema = JSONSchema.boolean
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "boolean")
    }

    func testNullSchema() {
        let schema = JSONSchema.null
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "null")
    }

    // MARK: - Array Schema

    func testArraySchema() {
        let schema = JSONSchema.array(items: .string)
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "array")
        let items = dict["items"] as? [String: Any]
        XCTAssertEqual(items?["type"] as? String, "string")
    }

    func testNestedArraySchema() {
        let schema = JSONSchema.array(items: .array(items: .integer))
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "array")
        let items = dict["items"] as? [String: Any]
        XCTAssertEqual(items?["type"] as? String, "array")
        let innerItems = items?["items"] as? [String: Any]
        XCTAssertEqual(innerItems?["type"] as? String, "integer")
    }

    // MARK: - Object Schema

    func testObjectSchema() {
        let schema = JSONSchema.object(
            properties: [
                "name": .string,
                "age": .integer
            ],
            required: ["name"]
        )
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "object")

        let properties = dict["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        let nameSchema = properties?["name"] as? [String: Any]
        XCTAssertEqual(nameSchema?["type"] as? String, "string")
        let ageSchema = properties?["age"] as? [String: Any]
        XCTAssertEqual(ageSchema?["type"] as? String, "integer")

        let required = dict["required"] as? [String]
        XCTAssertEqual(required, ["name"])

        XCTAssertEqual(dict["additionalProperties"] as? Bool, false)
    }

    func testObjectSchemaWithAdditionalProperties() {
        let schema = JSONSchema.object(
            properties: ["name": .string],
            required: [],
            additionalProperties: .string
        )
        let dict = schema.toDictionary()

        let additionalProps = dict["additionalProperties"] as? [String: Any]
        XCTAssertEqual(additionalProps?["type"] as? String, "string")
    }

    // MARK: - Enum Schema

    func testEnumSchema() {
        let schema = JSONSchema.enum(values: ["red", "green", "blue"])
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "string")
        let enumValues = dict["enum"] as? [String]
        XCTAssertEqual(enumValues, ["red", "green", "blue"])
    }

    // MARK: - Ref Schema

    func testRefSchema() {
        let schema = JSONSchema.ref("Person")
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["$ref"] as? String, "#/$defs/Person")
    }

    // MARK: - AnyOf Schema

    func testAnyOfSchema() {
        let schema = JSONSchema.anyOf([.string, .integer, .null])
        let dict = schema.toDictionary()

        let anyOf = dict["anyOf"] as? [[String: Any]]
        XCTAssertEqual(anyOf?.count, 3)
        XCTAssertEqual(anyOf?[0]["type"] as? String, "string")
        XCTAssertEqual(anyOf?[1]["type"] as? String, "integer")
        XCTAssertEqual(anyOf?[2]["type"] as? String, "null")
    }

    // MARK: - Helper Methods

    func testArrayOfHelper() {
        let schema = JSONSchema.array(of: .boolean)
        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "array")
        let items = dict["items"] as? [String: Any]
        XCTAssertEqual(items?["type"] as? String, "boolean")
    }

    func testOptionalHelper() {
        let schema = JSONSchema.optional(.string)
        let dict = schema.toDictionary()

        let anyOf = dict["anyOf"] as? [[String: Any]]
        XCTAssertEqual(anyOf?.count, 2)
        XCTAssertEqual(anyOf?[0]["type"] as? String, "string")
        XCTAssertEqual(anyOf?[1]["type"] as? String, "null")
    }

    // MARK: - Object Schema Builder

    func testObjectSchemaBuilder() {
        let schema = JSONSchema.object()
            .property("name", .string)
            .property("email", .string)
            .property("age", .integer, required: false)
            .build()

        if case .object(let properties, let required, _) = schema {
            XCTAssertEqual(properties.count, 3)
            XCTAssertEqual(properties["name"], .string)
            XCTAssertEqual(properties["email"], .string)
            XCTAssertEqual(properties["age"], .integer)
            XCTAssertEqual(required.sorted(), ["email", "name"])
        } else {
            XCTFail("Expected object schema")
        }
    }

    func testObjectSchemaBuilderWithAdditionalProperties() {
        let schema = JSONSchema.object()
            .property("id", .string)
            .additionalProperties(.string)
            .build()

        let dict = schema.toDictionary()
        let additionalProps = dict["additionalProperties"] as? [String: Any]
        XCTAssertEqual(additionalProps?["type"] as? String, "string")
    }

    // MARK: - Document

    func testDocumentWithoutDefinitions() {
        let root = JSONSchema.object(
            properties: ["name": .string],
            required: ["name"]
        )
        let doc = JSONSchema.document(root: root)

        XCTAssertEqual(doc["type"] as? String, "object")
        XCTAssertNil(doc["$defs"])
    }

    func testDocumentWithDefinitions() {
        let root = JSONSchema.object(
            properties: ["person": .ref("Person")],
            required: ["person"]
        )
        let definitions: [String: JSONSchema] = [
            "Person": .object(
                properties: ["name": .string, "age": .integer],
                required: ["name"]
            )
        ]
        let doc = JSONSchema.document(root: root, definitions: definitions)

        XCTAssertEqual(doc["type"] as? String, "object")

        let defs = doc["$defs"] as? [String: Any]
        XCTAssertNotNil(defs)
        let personDef = defs?["Person"] as? [String: Any]
        XCTAssertEqual(personDef?["type"] as? String, "object")
    }

    // MARK: - Complex Nested Schema

    func testComplexNestedSchema() {
        let schema = JSONSchema.object(
            properties: [
                "users": .array(items: .object(
                    properties: [
                        "name": .string,
                        "roles": .array(items: .enum(values: ["admin", "user", "guest"]))
                    ],
                    required: ["name", "roles"]
                )),
                "metadata": .anyOf([.string, .null])
            ],
            required: ["users"]
        )

        let dict = schema.toDictionary()
        XCTAssertEqual(dict["type"] as? String, "object")

        let properties = dict["properties"] as? [String: Any]
        let usersSchema = properties?["users"] as? [String: Any]
        XCTAssertEqual(usersSchema?["type"] as? String, "array")
    }
}
