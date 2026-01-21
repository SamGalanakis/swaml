import XCTest
@testable import SWAML

final class OutputParserTests: XCTestCase {

    // MARK: - Simple Types

    func testParseString() {
        let result = OutputParser.parseString("  hello world  ")
        XCTAssertEqual(result, "hello world")
    }

    func testParseBool() throws {
        XCTAssertEqual(try OutputParser.parseBool("true"), true)
        XCTAssertEqual(try OutputParser.parseBool("TRUE"), true)
        XCTAssertEqual(try OutputParser.parseBool("yes"), true)
        XCTAssertEqual(try OutputParser.parseBool("1"), true)
        XCTAssertEqual(try OutputParser.parseBool("false"), false)
        XCTAssertEqual(try OutputParser.parseBool("no"), false)
        XCTAssertEqual(try OutputParser.parseBool("0"), false)
    }

    func testParseInt() throws {
        XCTAssertEqual(try OutputParser.parseInt("42"), 42)
        XCTAssertEqual(try OutputParser.parseInt("  -17  "), -17)
    }

    func testParseFloat() throws {
        XCTAssertEqual(try OutputParser.parseFloat("3.14"), 3.14)
        XCTAssertEqual(try OutputParser.parseFloat("  -2.5  "), -2.5)
    }

    // MARK: - Codable Parsing

    struct TestPerson: Codable, Equatable {
        let name: String
        let age: Int
    }

    func testParseCodable() throws {
        let json = """
        {"name": "Alice", "age": 30}
        """
        let person: TestPerson = try OutputParser.parse(json, type: TestPerson.self)

        XCTAssertEqual(person.name, "Alice")
        XCTAssertEqual(person.age, 30)
    }

    func testParseCodableFromMarkdown() throws {
        let output = """
        Here's the result:

        ```json
        {"name": "Bob", "age": 25}
        ```
        """
        let person: TestPerson = try OutputParser.parse(output, type: TestPerson.self)

        XCTAssertEqual(person.name, "Bob")
        XCTAssertEqual(person.age, 25)
    }

    // MARK: - Schema Validation

    func testParseWithSchema() throws {
        let schema = JSONSchema.object(
            properties: [
                "name": .string,
                "score": .number
            ],
            required: ["name", "score"]
        )

        let json = """
        {"name": "Test", "score": 95.5}
        """
        let value = try OutputParser.parseToValue(json, schema: schema)

        XCTAssertEqual(value["name"]?.stringValue, "Test")
        XCTAssertEqual(value["score"]?.doubleValue, 95.5)
    }

    // MARK: - Type Coercion

    func testCoerceIntToFloat() throws {
        let schema = JSONSchema.object(
            properties: ["value": .number],
            required: ["value"]
        )

        let json = """
        {"value": 42}
        """
        let value = try OutputParser.parseToValue(json, schema: schema)

        // Int should be coerced to number
        XCTAssertNotNil(value["value"]?.doubleValue)
    }

    func testCoerceStringToInt() throws {
        let coerced = try TypeCoercion.coerce(.string("42"), to: .int)
        XCTAssertEqual(coerced.intValue, 42)
    }

    // MARK: - Complex Types

    struct NestedResult: Codable, Equatable {
        let items: [Item]
        let metadata: Metadata?

        struct Item: Codable, Equatable {
            let id: Int
            let name: String
        }

        struct Metadata: Codable, Equatable {
            let source: String
        }
    }

    func testParseNestedCodable() throws {
        let json = #"{"items":[{"id":1,"name":"First"},{"id":2,"name":"Second"}],"metadata":{"source":"test"}}"#
        let result: NestedResult = try OutputParser.parse(json, type: NestedResult.self)

        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].id, 1)
        XCTAssertEqual(result.items[0].name, "First")
        XCTAssertEqual(result.metadata?.source, "test")
    }

    // MARK: - Error Cases

    func testParseInvalidJSON() {
        let invalid = "not json at all"

        XCTAssertThrowsError(try OutputParser.parse(invalid, type: TestPerson.self))
    }

    func testParseMissingField() {
        let json = """
        {"name": "Alice"}
        """

        XCTAssertThrowsError(try OutputParser.parse(json, type: TestPerson.self))
    }
}
