import XCTest
@testable import SWAML

final class TypeCoercionTests: XCTestCase {

    // MARK: - String Coercion

    func testStringToString() throws {
        let value = SwamlValue.string("hello")
        let result = try TypeCoercion.coerce(value, to: .string)
        XCTAssertEqual(result.stringValue, "hello")
    }

    func testIntToString() throws {
        let value = SwamlValue.int(42)
        let result = try TypeCoercion.coerce(value, to: .string)
        XCTAssertEqual(result.stringValue, "42")
    }

    func testFloatToString() throws {
        let value = SwamlValue.float(3.14)
        let result = try TypeCoercion.coerce(value, to: .string)
        XCTAssertEqual(result.stringValue, "3.14")
    }

    func testBoolToString() throws {
        let trueVal = SwamlValue.bool(true)
        let falseVal = SwamlValue.bool(false)

        XCTAssertEqual(try TypeCoercion.coerce(trueVal, to: .string).stringValue, "true")
        XCTAssertEqual(try TypeCoercion.coerce(falseVal, to: .string).stringValue, "false")
    }

    func testNullToStringFails() {
        let value = SwamlValue.null
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .string))
    }

    func testArrayToStringFails() {
        let value = SwamlValue.array([.string("a")])
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .string))
    }

    // MARK: - Int Coercion

    func testIntToInt() throws {
        let value = SwamlValue.int(42)
        let result = try TypeCoercion.coerce(value, to: .int)
        XCTAssertEqual(result.intValue, 42)
    }

    func testWholeFloatToInt() throws {
        let value = SwamlValue.float(42.0)
        let result = try TypeCoercion.coerce(value, to: .int)
        XCTAssertEqual(result.intValue, 42)
    }

    func testDecimalFloatToIntFails() {
        let value = SwamlValue.float(42.5)
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .int))
    }

    func testStringToInt() throws {
        let value = SwamlValue.string("123")
        let result = try TypeCoercion.coerce(value, to: .int)
        XCTAssertEqual(result.intValue, 123)
    }

    func testStringWholeFloatToInt() throws {
        let value = SwamlValue.string("42.0")
        let result = try TypeCoercion.coerce(value, to: .int)
        XCTAssertEqual(result.intValue, 42)
    }

    func testInvalidStringToIntFails() {
        let value = SwamlValue.string("not a number")
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .int))
    }

    func testStringDecimalToIntFails() {
        let value = SwamlValue.string("42.5")
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .int))
    }

    func testBoolToInt() throws {
        let trueVal = SwamlValue.bool(true)
        let falseVal = SwamlValue.bool(false)

        XCTAssertEqual(try TypeCoercion.coerce(trueVal, to: .int).intValue, 1)
        XCTAssertEqual(try TypeCoercion.coerce(falseVal, to: .int).intValue, 0)
    }

    func testNullToIntFails() {
        let value = SwamlValue.null
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .int))
    }

    // MARK: - Float Coercion

    func testFloatToFloat() throws {
        let value = SwamlValue.float(3.14)
        let result = try TypeCoercion.coerce(value, to: .float)
        XCTAssertEqual(result.doubleValue, 3.14)
    }

    func testIntToFloat() throws {
        let value = SwamlValue.int(42)
        let result = try TypeCoercion.coerce(value, to: .float)
        XCTAssertEqual(result.doubleValue, 42.0)
    }

    func testStringToFloat() throws {
        let value = SwamlValue.string("3.14159")
        let result = try TypeCoercion.coerce(value, to: .float)
        XCTAssertEqual(result.doubleValue!, 3.14159, accuracy: 0.00001)
    }

    func testInvalidStringToFloatFails() {
        let value = SwamlValue.string("not a float")
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .float))
    }

    func testBoolToFloatFails() {
        let value = SwamlValue.bool(true)
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .float))
    }

    // MARK: - Bool Coercion

    func testBoolToBool() throws {
        let trueVal = SwamlValue.bool(true)
        let falseVal = SwamlValue.bool(false)

        XCTAssertEqual(try TypeCoercion.coerce(trueVal, to: .bool).boolValue, true)
        XCTAssertEqual(try TypeCoercion.coerce(falseVal, to: .bool).boolValue, false)
    }

    func testIntToBool() throws {
        let zero = SwamlValue.int(0)
        let one = SwamlValue.int(1)
        let negative = SwamlValue.int(-5)

        XCTAssertEqual(try TypeCoercion.coerce(zero, to: .bool).boolValue, false)
        XCTAssertEqual(try TypeCoercion.coerce(one, to: .bool).boolValue, true)
        XCTAssertEqual(try TypeCoercion.coerce(negative, to: .bool).boolValue, true)
    }

    func testStringToBool() throws {
        let trueStrings = ["true", "True", "TRUE", "1", "yes", "Yes", "YES"]
        let falseStrings = ["false", "False", "FALSE", "0", "no", "No", "NO"]

        for str in trueStrings {
            let value = SwamlValue.string(str)
            XCTAssertEqual(try TypeCoercion.coerce(value, to: .bool).boolValue, true, "'\(str)' should be true")
        }

        for str in falseStrings {
            let value = SwamlValue.string(str)
            XCTAssertEqual(try TypeCoercion.coerce(value, to: .bool).boolValue, false, "'\(str)' should be false")
        }
    }

    func testInvalidStringToBoolFails() {
        let value = SwamlValue.string("maybe")
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .bool))
    }

    func testFloatToBoolFails() {
        let value = SwamlValue.float(1.0)
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .bool))
    }

    // MARK: - Null Coercion

    func testNullToNull() throws {
        let value = SwamlValue.null
        let result = try TypeCoercion.coerce(value, to: .null)
        XCTAssertTrue(result.isNull)
    }

    func testNonNullToNullFails() {
        let value = SwamlValue.string("not null")
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .null))
    }

    // MARK: - Optional Coercion

    func testNullToOptional() throws {
        let value = SwamlValue.null
        let result = try TypeCoercion.coerce(value, to: .optional(.string))
        XCTAssertTrue(result.isNull)
    }

    func testValueToOptional() throws {
        let value = SwamlValue.string("hello")
        let result = try TypeCoercion.coerce(value, to: .optional(.string))
        XCTAssertEqual(result.stringValue, "hello")
    }

    func testCoercedValueToOptional() throws {
        let value = SwamlValue.int(42)
        let result = try TypeCoercion.coerce(value, to: .optional(.string))
        XCTAssertEqual(result.stringValue, "42")
    }

    // MARK: - Array Coercion

    func testArrayToArray() throws {
        let value = SwamlValue.array([.string("a"), .string("b")])
        let result = try TypeCoercion.coerce(value, to: .list(.string))

        guard let array = result.arrayValue else {
            XCTFail("Expected array")
            return
        }

        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(array[0].stringValue, "a")
        XCTAssertEqual(array[1].stringValue, "b")
    }

    func testArrayCoercesElements() throws {
        let value = SwamlValue.array([.int(1), .int(2), .int(3)])
        let result = try TypeCoercion.coerce(value, to: .list(.string))

        guard let array = result.arrayValue else {
            XCTFail("Expected array")
            return
        }

        XCTAssertEqual(array.map { $0.stringValue }, ["1", "2", "3"])
    }

    func testNonArrayToArrayFails() {
        let value = SwamlValue.string("not an array")
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .list(.string)))
    }

    // MARK: - Map Coercion

    func testMapToMap() throws {
        let value = SwamlValue.map(["a": .string("1"), "b": .string("2")])
        let result = try TypeCoercion.coerce(value, to: .map(key: .string, value: .string))

        guard let map = result.mapValue else {
            XCTFail("Expected map")
            return
        }

        XCTAssertEqual(map["a"]?.stringValue, "1")
        XCTAssertEqual(map["b"]?.stringValue, "2")
    }

    func testMapCoercesValues() throws {
        let value = SwamlValue.map(["x": .int(10), "y": .int(20)])
        let result = try TypeCoercion.coerce(value, to: .map(key: .string, value: .string))

        guard let map = result.mapValue else {
            XCTFail("Expected map")
            return
        }

        XCTAssertEqual(map["x"]?.stringValue, "10")
        XCTAssertEqual(map["y"]?.stringValue, "20")
    }

    func testNonMapToMapFails() {
        let value = SwamlValue.array([.string("a")])
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .map(key: .string, value: .string)))
    }

    // MARK: - Union Coercion

    func testUnionFirstTypeMatches() throws {
        let value = SwamlValue.string("hello")
        let result = try TypeCoercion.coerce(value, to: .union([.string, .int]))
        XCTAssertEqual(result.stringValue, "hello")
    }

    func testUnionSecondTypeMatches() throws {
        // Use array which can't be coerced to string, so it falls through to the second type
        let value = SwamlValue.array([.int(1), .int(2)])
        let result = try TypeCoercion.coerce(value, to: .union([.string, .list(.int)]))

        guard let array = result.arrayValue else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(array.count, 2)
    }

    func testUnionCoerces() throws {
        let value = SwamlValue.int(42)
        // Int can be coerced to string, so this should work
        let result = try TypeCoercion.coerce(value, to: .union([.string]))
        XCTAssertEqual(result.stringValue, "42")
    }

    func testUnionNoMatchFails() {
        let value = SwamlValue.array([.string("a")])
        XCTAssertThrowsError(try TypeCoercion.coerce(value, to: .union([.string, .int])))
    }

    func testOptionalUnion() throws {
        // Common pattern: string | null
        let nullVal = SwamlValue.null
        let stringVal = SwamlValue.string("test")

        let nullResult = try TypeCoercion.coerce(nullVal, to: .union([.string, .null]))
        XCTAssertTrue(nullResult.isNull)

        let stringResult = try TypeCoercion.coerce(stringVal, to: .union([.string, .null]))
        XCTAssertEqual(stringResult.stringValue, "test")
    }

    // MARK: - Reference Type

    func testReferencePassThrough() throws {
        let value = SwamlValue.map(["name": .string("Test")])
        let result = try TypeCoercion.coerce(value, to: .reference("Person"))

        // References pass through without validation
        XCTAssertEqual(result.mapValue?["name"]?.stringValue, "Test")
    }

    // MARK: - Literal Types

    func testLiteralString() throws {
        let value = SwamlValue.string("active")
        let result = try TypeCoercion.coerce(value, to: .literalString("active"))
        XCTAssertEqual(result.stringValue, "active")
    }

    func testLiteralInt() throws {
        let value = SwamlValue.int(42)
        let result = try TypeCoercion.coerce(value, to: .literalInt(42))
        XCTAssertEqual(result.intValue, 42)
    }

    func testLiteralBool() throws {
        let value = SwamlValue.bool(true)
        let result = try TypeCoercion.coerce(value, to: .literalBool(true))
        XCTAssertEqual(result.boolValue, true)
    }

    // MARK: - Complex Nested Coercion

    func testNestedArrayCoercion() throws {
        let value = SwamlValue.array([
            .array([.int(1), .int(2)]),
            .array([.int(3), .int(4)])
        ])
        let result = try TypeCoercion.coerce(value, to: .list(.list(.string)))

        guard let outer = result.arrayValue else {
            XCTFail("Expected outer array")
            return
        }

        XCTAssertEqual(outer.count, 2)
        XCTAssertEqual(outer[0].arrayValue?[0].stringValue, "1")
        XCTAssertEqual(outer[1].arrayValue?[1].stringValue, "4")
    }

    func testMapOfArraysCoercion() throws {
        let value = SwamlValue.map([
            "nums": .array([.int(1), .int(2)]),
            "more": .array([.int(3)])
        ])
        let result = try TypeCoercion.coerce(value, to: .map(key: .string, value: .list(.string)))

        guard let map = result.mapValue else {
            XCTFail("Expected map")
            return
        }

        XCTAssertEqual(map["nums"]?.arrayValue?.map { $0.stringValue }, ["1", "2"])
    }

    // MARK: - SwamlValue TypeName

    func testTypeNames() {
        XCTAssertEqual(SwamlValue.null.typeName, "null")
        XCTAssertEqual(SwamlValue.bool(true).typeName, "bool")
        XCTAssertEqual(SwamlValue.int(1).typeName, "int")
        XCTAssertEqual(SwamlValue.float(1.0).typeName, "float")
        XCTAssertEqual(SwamlValue.string("").typeName, "string")
        XCTAssertEqual(SwamlValue.array([]).typeName, "array")
        XCTAssertEqual(SwamlValue.map([:]).typeName, "map")
    }
}
