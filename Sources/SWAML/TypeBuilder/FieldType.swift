import Foundation

/// Represents a field type for dynamic type building.
/// Supports chainable modifiers like `.list()` and `.optional()`.
public indirect enum FieldType: Sendable, Equatable {
    case string
    case int
    case float
    case bool
    case null
    case literalString(String)
    case literalInt(Int)
    case literalBool(Bool)
    case list(FieldType)
    case map(key: FieldType, value: FieldType)
    case optional(FieldType)
    case union([FieldType])
    case reference(String)

    // MARK: - Convenience Properties

    /// The kind of this type (for pattern matching compatibility)
    public var kind: FieldType { self }

    // MARK: - Chainable Modifiers

    /// Wrap this type in a list (returns a new FieldType)
    public func list() -> FieldType {
        .list(self)
    }

    /// Make this type optional (returns a new FieldType)
    public func optional() -> FieldType {
        .optional(self)
    }

    // MARK: - Serialization

    /// Convert to a serializable dictionary for FFI
    public func toSerializable() -> [String: Any] {
        switch self {
        case .string:
            return ["type": "string"]
        case .int:
            return ["type": "int"]
        case .float:
            return ["type": "float"]
        case .bool:
            return ["type": "bool"]
        case .null:
            return ["type": "null"]
        case .literalString(let value):
            return ["type": "literal_string", "value": value]
        case .literalInt(let value):
            return ["type": "literal_int", "value": value]
        case .literalBool(let value):
            return ["type": "literal_bool", "value": value]
        case .list(let inner):
            return ["type": "list", "inner": inner.toSerializable()]
        case .map(let key, let value):
            return ["type": "map", "key": key.toSerializable(), "value": value.toSerializable()]
        case .optional(let inner):
            return ["type": "optional", "inner": inner.toSerializable()]
        case .union(let types):
            return ["type": "union", "types": types.map { $0.toSerializable() }]
        case .reference(let name):
            return ["type": "ref", "name": name]
        }
    }

    /// Convert to JSON Schema representation
    public func toJSONSchema() -> JSONSchema {
        switch self {
        case .string:
            return .string
        case .int:
            return .integer
        case .float:
            return .number
        case .bool:
            return .boolean
        case .null:
            return .null
        case .literalString(let value):
            return .enum(values: [value])
        case .literalInt:
            // JSON Schema doesn't have literal int, use integer
            return .integer
        case .literalBool:
            // JSON Schema doesn't have literal bool, use boolean
            return .boolean
        case .list(let inner):
            return .array(items: inner.toJSONSchema())
        case .map(_, let value):
            return .object(properties: [:], required: [], additionalProperties: value.toJSONSchema())
        case .optional(let inner):
            return .anyOf([inner.toJSONSchema(), .null])
        case .union(let types):
            return .anyOf(types.map { $0.toJSONSchema() })
        case .reference(let name):
            return .ref(name)
        }
    }

    /// Convert to Swift type string
    public func toSwiftType() -> String {
        switch self {
        case .string, .literalString:
            return "String"
        case .int, .literalInt:
            return "Int"
        case .float:
            return "Double"
        case .bool, .literalBool:
            return "Bool"
        case .null:
            return "Never?" // Represents null type
        case .list(let inner):
            return "[\(inner.toSwiftType())]"
        case .map(_, let value):
            return "[String: \(value.toSwiftType())]"
        case .optional(let inner):
            return "\(inner.toSwiftType())?"
        case .union(let types):
            // For unions, check if it's an optional pattern (T | null)
            if types.count == 2 {
                if case .null = types[1] {
                    return "\(types[0].toSwiftType())?"
                }
                if case .null = types[0] {
                    return "\(types[1].toSwiftType())?"
                }
            }
            return "Any"
        case .reference(let name):
            return name
        }
    }
}
