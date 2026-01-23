import XCTest
@testable import SWAML

final class SwamlValueTests: XCTestCase {

    // MARK: - Basic Types

    func testStringValue() {
        let value: SwamlValue = "hello"
        XCTAssertTrue(value.isString)
        XCTAssertEqual(value.stringValue, "hello")
    }

    func testIntValue() {
        let value: SwamlValue = 42
        XCTAssertTrue(value.isInt)
        XCTAssertEqual(value.intValue, 42)
    }

    func testFloatValue() {
        let value: SwamlValue = 3.14
        XCTAssertTrue(value.isFloat)
        XCTAssertEqual(value.doubleValue, 3.14)
    }

    func testBoolValue() {
        let trueValue: SwamlValue = true
        let falseValue: SwamlValue = false

        XCTAssertTrue(trueValue.isBool)
        XCTAssertEqual(trueValue.boolValue, true)
        XCTAssertEqual(falseValue.boolValue, false)
    }

    func testNullValue() {
        let value: SwamlValue = nil
        XCTAssertTrue(value.isNull)
    }

    // MARK: - Collections

    func testArrayValue() {
        let value: SwamlValue = [1, 2, 3]
        XCTAssertTrue(value.isArray)
        XCTAssertEqual(value.arrayValue?.count, 3)
        XCTAssertEqual(value[0]?.intValue, 1)
        XCTAssertEqual(value[1]?.intValue, 2)
        XCTAssertEqual(value[2]?.intValue, 3)
    }

    func testMapValue() {
        let value: SwamlValue = ["name": "Alice", "age": 30]
        XCTAssertTrue(value.isMap)
        XCTAssertEqual(value["name"]?.stringValue, "Alice")
        XCTAssertEqual(value["age"]?.intValue, 30)
    }

    // MARK: - JSON Conversion

    func testToJSONString() throws {
        let value: SwamlValue = ["name": "Bob", "scores": [1, 2, 3]]
        let json = try value.toJSONString()

        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("\"Bob\""))
        XCTAssertTrue(json.contains("\"scores\""))
    }

    func testFromJSONString() throws {
        let json = """
        {"name": "Charlie", "age": 25, "active": true}
        """
        let value = try SwamlValue.fromJSONString(json)

        XCTAssertEqual(value["name"]?.stringValue, "Charlie")
        XCTAssertEqual(value["age"]?.intValue, 25)
        XCTAssertEqual(value["active"]?.boolValue, true)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original: SwamlValue = [
            "string": "hello",
            "int": 42,
            "float": 3.14,
            "bool": true,
            "null": nil,
            "array": [1, 2, 3],
            "nested": ["key": "value"]
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SwamlValue.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Type Coercion

    func testIntToDouble() {
        let value: SwamlValue = 42
        XCTAssertEqual(value.doubleValue, 42.0)
    }

    func testDoubleToInt() {
        let value: SwamlValue = 42.0
        XCTAssertEqual(value.intValue, 42)
    }
}
