import Foundation

/// A dynamic value type that can represent any BAML value
public enum BamlValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case float(Double)
    case string(String)
    case array([BamlValue])
    case map([String: BamlValue])

    // MARK: - Convenience Initializers

    public init(_ value: Bool) { self = .bool(value) }
    public init(_ value: Int) { self = .int(value) }
    public init(_ value: Double) { self = .float(value) }
    public init(_ value: String) { self = .string(value) }
    public init(_ value: [BamlValue]) { self = .array(value) }
    public init(_ value: [String: BamlValue]) { self = .map(value) }

    // MARK: - Type Checking

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public var isBool: Bool {
        if case .bool = self { return true }
        return false
    }

    public var isInt: Bool {
        if case .int = self { return true }
        return false
    }

    public var isFloat: Bool {
        if case .float = self { return true }
        return false
    }

    public var isNumber: Bool {
        return isInt || isFloat
    }

    public var isString: Bool {
        if case .string = self { return true }
        return false
    }

    public var isArray: Bool {
        if case .array = self { return true }
        return false
    }

    public var isMap: Bool {
        if case .map = self { return true }
        return false
    }

    // MARK: - Value Extraction

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .float(let value): return Int(value)
        default: return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .float(let value): return value
        case .int(let value): return Double(value)
        default: return nil
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var arrayValue: [BamlValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var mapValue: [String: BamlValue]? {
        if case .map(let value) = self { return value }
        return nil
    }

    // MARK: - Subscript Access

    /// Access array element by index
    public subscript(index: Int) -> BamlValue? {
        guard case .array(let array) = self, index >= 0, index < array.count else {
            return nil
        }
        return array[index]
    }

    /// Access map value by key
    public subscript(key: String) -> BamlValue? {
        guard case .map(let map) = self else { return nil }
        return map[key]
    }

    // MARK: - JSON Conversion

    /// Convert to a JSON-compatible Any value
    public var toJSONValue: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .float(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map { $0.toJSONValue }
        case .map(let dict):
            return dict.mapValues { $0.toJSONValue }
        }
    }

    /// Create from a JSON-compatible Any value
    public static func fromJSON(_ value: Any) -> BamlValue {
        switch value {
        case is NSNull:
            return .null
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map { fromJSON($0) })
        case let dict as [String: Any]:
            return .map(dict.mapValues { fromJSON($0) })
        case let number as NSNumber:
            // Check objCType to distinguish types
            let objCType = String(cString: number.objCType)

            // On Linux, true/false booleans have objCType "B"
            // Numbers have types like "i", "d", "q", etc.
            // We must be careful: "c" could be bool OR small int

            // First check for explicit float types
            if objCType == "d" || objCType == "f" {
                return .float(number.doubleValue)
            }

            // Check for integer types (not 'c' or 'B' which could be bool)
            if objCType == "i" || objCType == "l" || objCType == "q" ||
               objCType == "I" || objCType == "L" || objCType == "Q" ||
               objCType == "s" || objCType == "S" {
                return .int(number.intValue)
            }

            // For 'c' and 'B' types - these could be bool
            // But only treat as bool if the value is exactly 0 or 1 AND we're confident it's a bool
            // On Linux JSONSerialization, actual JSON numbers don't use 'c' or 'B'
            if objCType == "B" {
                // 'B' is definitely boolean on Linux
                return .bool(number.boolValue)
            }

            if objCType == "c" {
                // 'c' could be bool (macOS) - check if it's 0 or 1
                let val = number.intValue
                if val == 0 || val == 1 {
                    return .bool(val == 1)
                }
                return .int(val)
            }

            // Fallback: check if it's an integer or float by value
            let doubleVal = number.doubleValue
            if doubleVal.truncatingRemainder(dividingBy: 1) == 0 &&
               doubleVal >= Double(Int.min) && doubleVal <= Double(Int.max) {
                return .int(Int(doubleVal))
            }
            return .float(doubleVal)
        default:
            return .string(String(describing: value))
        }
    }

    /// Convert to JSON string
    public func toJSONString(prettyPrint: Bool = false) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: toJSONValue,
            options: prettyPrint ? [.prettyPrinted, .sortedKeys] : []
        )
        guard let string = String(data: data, encoding: .utf8) else {
            throw BamlError.internalError("Failed to convert JSON data to string")
        }
        return string
    }

    /// Parse from JSON string
    public static func fromJSONString(_ json: String) throws -> BamlValue {
        guard let data = json.data(using: .utf8) else {
            throw BamlError.parseError("Invalid UTF-8 string")
        }
        let value = try JSONSerialization.jsonObject(with: data)
        return fromJSON(value)
    }
}

// MARK: - Codable

extension BamlValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .float(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([BamlValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: BamlValue].self) {
            self = .map(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode BamlValue")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .float(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .map(let value):
            try container.encode(value)
        }
    }
}

// MARK: - ExpressibleBy Protocols

extension BamlValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension BamlValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension BamlValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension BamlValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .float(value)
    }
}

extension BamlValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension BamlValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: BamlValue...) {
        self = .array(elements)
    }
}

extension BamlValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BamlValue)...) {
        self = .map(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - CustomStringConvertible

extension BamlValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null:
            return "null"
        case .bool(let value):
            return value ? "true" : "false"
        case .int(let value):
            return "\(value)"
        case .float(let value):
            return "\(value)"
        case .string(let value):
            return "\"\(value)\""
        case .array(let values):
            return "[\(values.map { $0.description }.joined(separator: ", "))]"
        case .map(let dict):
            let pairs = dict.map { "\"\($0.key)\": \($0.value.description)" }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}
