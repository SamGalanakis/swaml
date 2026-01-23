import Foundation

/// Handles coercion of values to expected types
public struct TypeCoercion {

    /// Coerce a SwamlValue to match expected type in schema
    public static func coerce(_ value: SwamlValue, to type: FieldType) throws -> SwamlValue {
        switch type {
        case .string, .literalString:
            return try coerceToString(value)
        case .int, .literalInt:
            return try coerceToInt(value)
        case .float:
            return try coerceToFloat(value)
        case .bool, .literalBool:
            return try coerceToBool(value)
        case .null:
            if value.isNull {
                return .null
            }
            throw SwamlError.typeCoercionError(expected: "null", actual: value.typeName)
        case .optional(let inner):
            if value.isNull {
                return .null
            }
            return try coerce(value, to: inner)
        case .list(let element):
            return try coerceToArray(value, elementType: element)
        case .map(let keyType, let valueType):
            return try coerceToMap(value, keyType: keyType, valueType: valueType)
        case .union(let types):
            // Try each type in the union until one succeeds
            for unionType in types {
                if let result = try? coerce(value, to: unionType) {
                    return result
                }
            }
            throw SwamlError.typeCoercionError(expected: "union type", actual: value.typeName)
        case .reference:
            // References are validated at a higher level
            return value
        }
    }

    // MARK: - String Coercion

    private static func coerceToString(_ value: SwamlValue) throws -> SwamlValue {
        switch value {
        case .string:
            return value
        case .int(let v):
            return .string(String(v))
        case .float(let v):
            return .string(String(v))
        case .bool(let v):
            return .string(v ? "true" : "false")
        case .null:
            throw SwamlError.typeCoercionError(expected: "string", actual: "null")
        case .array, .map:
            throw SwamlError.typeCoercionError(expected: "string", actual: value.typeName)
        }
    }

    // MARK: - Int Coercion

    private static func coerceToInt(_ value: SwamlValue) throws -> SwamlValue {
        switch value {
        case .int:
            return value
        case .float(let v):
            // Only coerce if it's a whole number
            if v.truncatingRemainder(dividingBy: 1) == 0 {
                return .int(Int(v))
            }
            throw SwamlError.typeCoercionError(expected: "int", actual: "float with decimal")
        case .string(let s):
            if let intValue = Int(s) {
                return .int(intValue)
            }
            // Try parsing as float then converting
            if let floatValue = Double(s), floatValue.truncatingRemainder(dividingBy: 1) == 0 {
                return .int(Int(floatValue))
            }
            throw SwamlError.typeCoercionError(expected: "int", actual: "string '\(s)'")
        case .bool(let v):
            return .int(v ? 1 : 0)
        default:
            throw SwamlError.typeCoercionError(expected: "int", actual: value.typeName)
        }
    }

    // MARK: - Float Coercion

    private static func coerceToFloat(_ value: SwamlValue) throws -> SwamlValue {
        switch value {
        case .float:
            return value
        case .int(let v):
            return .float(Double(v))
        case .string(let s):
            if let floatValue = Double(s) {
                return .float(floatValue)
            }
            throw SwamlError.typeCoercionError(expected: "float", actual: "string '\(s)'")
        default:
            throw SwamlError.typeCoercionError(expected: "float", actual: value.typeName)
        }
    }

    // MARK: - Bool Coercion

    private static func coerceToBool(_ value: SwamlValue) throws -> SwamlValue {
        switch value {
        case .bool:
            return value
        case .int(let v):
            return .bool(v != 0)
        case .string(let s):
            let lower = s.lowercased()
            if lower == "true" || lower == "1" || lower == "yes" {
                return .bool(true)
            }
            if lower == "false" || lower == "0" || lower == "no" {
                return .bool(false)
            }
            throw SwamlError.typeCoercionError(expected: "bool", actual: "string '\(s)'")
        default:
            throw SwamlError.typeCoercionError(expected: "bool", actual: value.typeName)
        }
    }

    // MARK: - Array Coercion

    private static func coerceToArray(_ value: SwamlValue, elementType: FieldType) throws -> SwamlValue {
        guard case .array(let elements) = value else {
            throw SwamlError.typeCoercionError(expected: "array", actual: value.typeName)
        }

        let coercedElements = try elements.map { try coerce($0, to: elementType) }
        return .array(coercedElements)
    }

    // MARK: - Map Coercion

    private static func coerceToMap(_ value: SwamlValue, keyType: FieldType, valueType: FieldType) throws -> SwamlValue {
        guard case .map(let dict) = value else {
            throw SwamlError.typeCoercionError(expected: "map", actual: value.typeName)
        }

        // Keys must be strings in JSON, so we just validate values
        var coercedDict: [String: SwamlValue] = [:]
        for (key, val) in dict {
            coercedDict[key] = try coerce(val, to: valueType)
        }
        return .map(coercedDict)
    }
}

// MARK: - SwamlValue Type Name Extension

extension SwamlValue {
    var typeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "bool"
        case .int: return "int"
        case .float: return "float"
        case .string: return "string"
        case .array: return "array"
        case .map: return "map"
        }
    }
}
