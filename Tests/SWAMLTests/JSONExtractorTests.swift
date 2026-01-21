import XCTest
@testable import SWAML

final class JSONExtractorTests: XCTestCase {

    // MARK: - Basic Extraction

    func testExtractPlainJSON() throws {
        let input = """
        {"name": "Alice", "age": 30}
        """
        let extracted = try JSONExtractor.extract(from: input)

        XCTAssertTrue(extracted.contains("\"name\""))
        XCTAssertTrue(extracted.contains("\"Alice\""))
    }

    func testExtractWithWhitespace() throws {
        let input = """

            {"name": "Bob"}

        """
        let extracted = try JSONExtractor.extract(from: input)
        XCTAssertTrue(extracted.contains("\"name\""))
    }

    // MARK: - Markdown Code Blocks

    func testExtractFromMarkdownJSONBlock() throws {
        let input = """
        Here's the result:

        ```json
        {"status": "success", "count": 42}
        ```

        That's the output.
        """
        let extracted = try JSONExtractor.extract(from: input)

        XCTAssertTrue(extracted.contains("\"status\""))
        XCTAssertTrue(extracted.contains("\"success\""))
        XCTAssertTrue(extracted.contains("42"))
    }

    func testExtractFromPlainMarkdownBlock() throws {
        let input = """
        Response:
        ```
        {"result": true}
        ```
        """
        let extracted = try JSONExtractor.extract(from: input)
        XCTAssertTrue(extracted.contains("\"result\""))
    }

    // MARK: - Embedded JSON

    func testExtractEmbeddedObject() throws {
        let input = """
        The analysis shows: {"score": 0.95, "label": "positive"} which is good.
        """
        let extracted = try JSONExtractor.extract(from: input)

        XCTAssertTrue(extracted.contains("\"score\""))
        XCTAssertTrue(extracted.contains("0.95"))
    }

    func testExtractEmbeddedArray() throws {
        let input = """
        Results: [1, 2, 3, 4, 5]
        """
        let extracted = try JSONExtractor.extract(from: input)
        XCTAssertEqual(extracted, "[1, 2, 3, 4, 5]")
    }

    // MARK: - Nested Structures

    func testExtractNestedObject() throws {
        let input = """
        {"outer": {"inner": {"deep": "value"}}}
        """
        let extracted = try JSONExtractor.extract(from: input)
        let value = try BamlValue.fromJSONString(extracted)

        XCTAssertEqual(value["outer"]?["inner"]?["deep"]?.stringValue, "value")
    }

    // MARK: - Error Cases

    func testExtractNoJSON() {
        let input = "This is just plain text with no JSON."

        XCTAssertThrowsError(try JSONExtractor.extract(from: input)) { error in
            guard case BamlError.jsonExtractionError = error else {
                XCTFail("Expected jsonExtractionError")
                return
            }
        }
    }

    // MARK: - JSON Repair

    func testRepairTrailingComma() {
        let malformed = #"{"name": "Alice", "age": 30,}"#
        let repaired = JSONExtractor.repair(malformed)

        XCTAssertNotNil(repaired)
        XCTAssertFalse(repaired!.contains(",}"))
    }

    func testRepairTrailingCommaInArray() {
        let malformed = #"[1, 2, 3,]"#
        let repaired = JSONExtractor.repair(malformed)

        XCTAssertNotNil(repaired)
        XCTAssertFalse(repaired!.contains(",]"))
    }

    func testRepairSingleQuotes() {
        let malformed = """
        {'name': 'Alice'}
        """
        let repaired = JSONExtractor.repair(malformed)

        XCTAssertNotNil(repaired)
        XCTAssertTrue(repaired!.contains("\"name\""))
    }
}
