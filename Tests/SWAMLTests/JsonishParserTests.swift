import XCTest
@testable import SWAML

final class JsonishParserTests: XCTestCase {

    // MARK: - Valid JSON (pass through)

    func testValidJSONObject() throws {
        let input = #"{"name": "test", "value": 42}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }

    func testValidJSONArray() throws {
        let input = #"["a", "b", "c"]"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }

    func testValidNestedJSON() throws {
        let input = #"{"user": {"name": "Alice", "age": 30}, "active": true}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }

    // MARK: - Markdown Code Blocks

    func testMarkdownJSONCodeBlock() throws {
        let input = """
            Here is the result:
            ```json
            {"sentiment": "positive"}
            ```
            """
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"sentiment": "positive"}"#)
    }

    func testMarkdownGenericCodeBlock() throws {
        let input = """
            ```
            {"value": 123}
            ```
            """
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"value": 123}"#)
    }

    func testMarkdownCodeBlockWithNewlines() throws {
        let input = """
            ```json
            {
              "name": "test",
              "count": 5
            }
            ```
            """
        let result = try JsonishParser.parse(input)
        XCTAssertTrue(result.contains("\"name\": \"test\""))
        XCTAssertTrue(result.contains("\"count\": 5"))
    }

    // MARK: - Trailing Commas

    func testTrailingCommaInObject() throws {
        let input = #"{"a": 1, "b": 2,}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"a": 1, "b": 2}"#)
    }

    func testTrailingCommaInArray() throws {
        let input = #"[1, 2, 3,]"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, "[1, 2, 3]")
    }

    func testMultipleTrailingCommas() throws {
        let input = #"{"items": [1, 2,], "count": 2,}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"items": [1, 2], "count": 2}"#)
    }

    func testTrailingCommaWithWhitespace() throws {
        let input = """
            {
              "name": "test",
              "value": 42,
            }
            """
        let result = try JsonishParser.parse(input)
        XCTAssertTrue(result.contains("\"name\": \"test\""))
        XCTAssertFalse(result.contains(",}"))
    }

    // MARK: - Comments

    func testLineComment() throws {
        let input = """
            {
              "name": "test", // this is the name
              "value": 42
            }
            """
        let result = try JsonishParser.parse(input)
        XCTAssertFalse(result.contains("//"))
        XCTAssertTrue(result.contains("\"name\": \"test\""))
    }

    func testBlockComment() throws {
        let input = """
            {
              /* the user's name */
              "name": "test",
              "value": /* the count */ 42
            }
            """
        let result = try JsonishParser.parse(input)
        XCTAssertFalse(result.contains("/*"))
        XCTAssertFalse(result.contains("*/"))
    }

    // MARK: - Unquoted Keys

    func testUnquotedKeys() throws {
        let input = #"{name: "test", value: 42}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"name": "test", "value": 42}"#)
    }

    func testMixedQuotedUnquotedKeys() throws {
        let input = #"{"name": "test", value: 42}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"name": "test", "value": 42}"#)
    }

    func testUnquotedKeysWithUnderscore() throws {
        let input = #"{user_name: "Alice", is_active: true}"#
        let result = try JsonishParser.parse(input)
        XCTAssertTrue(result.contains("\"user_name\":"))
        XCTAssertTrue(result.contains("\"is_active\":"))
    }

    // MARK: - Single Quotes

    func testSingleQuotedStrings() throws {
        let input = #"{'name': 'test', 'value': 42}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"name": "test", "value": 42}"#)
    }

    func testMixedQuotes() throws {
        let input = #"{"name": 'test', 'count': 5}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"name": "test", "count": 5}"#)
    }

    // MARK: - Extra Text

    func testJSONWithLeadingText() throws {
        let input = """
            Here is the JSON you requested:
            {"result": "success"}
            """
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"result": "success"}"#)
    }

    func testJSONWithTrailingText() throws {
        let input = """
            {"result": "success"}
            I hope this helps!
            """
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"result": "success"}"#)
    }

    func testJSONBetweenText() throws {
        let input = """
            Based on my analysis:
            {"sentiment": "positive", "confidence": 0.95}
            Let me know if you need more details.
            """
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"{"sentiment": "positive", "confidence": 0.95}"#)
    }

    // MARK: - Complex Combined Cases

    func testCombinedFixes() throws {
        let input = """
            ```json
            {
              // User details
              name: 'Alice',
              age: 30,
              active: true,
            }
            ```
            """
        let result = try JsonishParser.parse(input)
        XCTAssertFalse(result.contains("//"))
        XCTAssertFalse(result.contains("'"))
        XCTAssertTrue(result.contains("\"name\":"))
        XCTAssertFalse(result.contains(",}"))
    }

    func testRealWorldLLMOutput() throws {
        let input = """
            I've analyzed the sentiment of your text. Here's my analysis:

            ```json
            {
              "sentiment": "positive",
              "confidence": 0.92,
              "keywords": ["love", "great", "amazing"],
            }
            ```

            The overall sentiment is positive with high confidence.
            """
        let result = try JsonishParser.parse(input)

        // Verify it's valid JSON by parsing it
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["sentiment"] as? String, "positive")
        XCTAssertEqual(json["confidence"] as? Double, 0.92)
        XCTAssertEqual((json["keywords"] as? [String])?.count, 3)
    }

    // MARK: - Streaming Support

    func testStreamingPartialJSON() throws {
        let input = #"{"name": "test"#  // Incomplete
        let result = try JsonishParser.parse(input, isDone: false)
        // Should close the incomplete string and object
        XCTAssertTrue(result.hasSuffix("}"))
    }

    func testStreamingCompleteJSON() throws {
        let input = #"{"name": "test"}"#
        let result = try JsonishParser.parse(input, isDone: true)
        XCTAssertEqual(result, input)
    }

    // MARK: - Error Cases

    func testNoJSONThrows() {
        XCTAssertThrowsError(try JsonishParser.parse("Hello, world!")) { error in
            XCTAssertTrue(error is SwamlError)
        }
    }

    func testEmptyInputThrows() {
        XCTAssertThrowsError(try JsonishParser.parse("")) { error in
            XCTAssertTrue(error is SwamlError)
        }
    }

    // MARK: - Newlines in Strings

    func testNewlinesInStrings() throws {
        let input = "{\"text\": \"line1\nline2\"}"
        let result = try JsonishParser.parse(input)
        XCTAssertTrue(result.contains("\\n"))
    }

    // MARK: - Arrays

    func testArrayExtraction() throws {
        let input = """
            Here are the results:
            ["apple", "banana", "cherry"]
            """
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, #"["apple", "banana", "cherry"]"#)
    }

    func testNestedArrays() throws {
        let input = #"[[1, 2], [3, 4], [5, 6]]"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }

    // MARK: - Edge Cases

    func testDeepNesting() throws {
        let input = #"{"a": {"b": {"c": {"d": "deep"}}}}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }

    func testSpecialCharactersInStrings() throws {
        let input = #"{"text": "Hello \"world\" with \\ backslash"}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }

    func testUnicodeInStrings() throws {
        let input = #"{"emoji": "👋 Hello 世界"}"#
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }

    func testEmptyObject() throws {
        let input = "{}"
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }

    func testEmptyArray() throws {
        let input = "[]"
        let result = try JsonishParser.parse(input)
        XCTAssertEqual(result, input)
    }
}
