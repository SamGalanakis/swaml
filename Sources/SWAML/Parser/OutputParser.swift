import Foundation

/// Parses LLM output into typed values
public struct OutputParser {

    /// Parse raw LLM output string into a typed value
    public static func parse<T: Codable>(
        _ output: String,
        schema: JSONSchema? = nil,
        type: T.Type
    ) throws -> T {
        // Extract JSON from potentially wrapped output
        let jsonString = try JSONExtractor.extract(from: output)

        // Get JSON data for decoding
        let data: Data
        if let schema = schema {
            // Parse to SwamlValue for coercion
            var swamlValue = try SwamlValue.fromJSONString(jsonString)
            swamlValue = try applySchemaCoercion(swamlValue, schema: schema)
            let coercedJSON = try swamlValue.toJSONString()
            guard let d = coercedJSON.data(using: .utf8) else {
                throw SwamlError.parseError("Failed to convert to UTF-8")
            }
            data = d
        } else {
            // Decode directly without going through SwamlValue
            guard let d = jsonString.data(using: .utf8) else {
                throw SwamlError.parseError("Failed to convert to UTF-8")
            }
            data = d
        }

        // Try decoding with snake_case conversion first, then without
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            // Retry without key conversion for already-camelCase JSON
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch let error2 {
                throw SwamlError.parseError("Failed to decode \(T.self): \(error2.localizedDescription)")
            }
        }
    }

    /// Parse raw output to SwamlValue with schema validation
    public static func parseToValue(_ output: String, schema: JSONSchema? = nil) throws -> SwamlValue {
        let jsonString = try JSONExtractor.extract(from: output)
        var swamlValue = try SwamlValue.fromJSONString(jsonString)

        if let schema = schema {
            swamlValue = try applySchemaCoercion(swamlValue, schema: schema)
            try validateAgainstSchema(swamlValue, schema: schema)
        }

        return swamlValue
    }

    /// Parse with repair attempts for malformed JSON
    public static func parseWithRepair<T: Codable>(
        _ output: String,
        schema: JSONSchema? = nil,
        type: T.Type
    ) throws -> T {
        // First try normal parsing
        do {
            return try parse(output, schema: schema, type: type)
        } catch {
            // Try to repair the JSON
            if let repaired = JSONExtractor.repair(output) {
                return try parse(repaired, schema: schema, type: type)
            }
            throw error
        }
    }

    // MARK: - Schema Coercion

    private static func applySchemaCoercion(_ value: SwamlValue, schema: JSONSchema) throws -> SwamlValue {
        switch schema {
        case .string:
            return try TypeCoercion.coerce(value, to: FieldType.string)
        case .integer:
            return try TypeCoercion.coerce(value, to: FieldType.int)
        case .number:
            return try TypeCoercion.coerce(value, to: FieldType.float)
        case .boolean:
            return try TypeCoercion.coerce(value, to: FieldType.bool)
        case .null:
            if value.isNull {
                return value
            }
            throw SwamlError.typeCoercionError(expected: "null", actual: value.typeName)
        case .array(let items):
            guard case .array(let elements) = value else {
                throw SwamlError.typeCoercionError(expected: "array", actual: value.typeName)
            }
            let coercedElements = try elements.map { try applySchemaCoercion($0, schema: items) }
            return .array(coercedElements)
        case .object(let properties, _, _):
            guard case .map(var dict) = value else {
                throw SwamlError.typeCoercionError(expected: "object", actual: value.typeName)
            }
            for (key, propSchema) in properties {
                if let propValue = dict[key] {
                    dict[key] = try applySchemaCoercion(propValue, schema: propSchema)
                }
            }
            return .map(dict)
        case .enum:
            // Enum values should be strings
            return try TypeCoercion.coerce(value, to: FieldType.string)
        case .ref:
            // References are resolved at a higher level
            return value
        case .anyOf(let schemas):
            // Try each schema until one works
            for subSchema in schemas {
                if let coerced = try? applySchemaCoercion(value, schema: subSchema) {
                    return coerced
                }
            }
            throw SwamlError.schemaValidationError("Value doesn't match any schema in anyOf")
        }
    }

    // MARK: - Schema Validation

    private static func validateAgainstSchema(_ value: SwamlValue, schema: JSONSchema) throws {
        switch schema {
        case .string:
            guard value.isString else {
                throw SwamlError.schemaValidationError("Expected string, got \(value.typeName)")
            }
        case .integer:
            guard value.isInt else {
                throw SwamlError.schemaValidationError("Expected integer, got \(value.typeName)")
            }
        case .number:
            guard value.isNumber else {
                throw SwamlError.schemaValidationError("Expected number, got \(value.typeName)")
            }
        case .boolean:
            guard value.isBool else {
                throw SwamlError.schemaValidationError("Expected boolean, got \(value.typeName)")
            }
        case .null:
            guard value.isNull else {
                throw SwamlError.schemaValidationError("Expected null, got \(value.typeName)")
            }
        case .array(let items):
            guard let elements = value.arrayValue else {
                throw SwamlError.schemaValidationError("Expected array, got \(value.typeName)")
            }
            for element in elements {
                try validateAgainstSchema(element, schema: items)
            }
        case .object(let properties, let required, _):
            guard let dict = value.mapValue else {
                throw SwamlError.schemaValidationError("Expected object, got \(value.typeName)")
            }
            // Check required properties
            for reqKey in required {
                guard dict[reqKey] != nil else {
                    throw SwamlError.schemaValidationError("Missing required property: \(reqKey)")
                }
            }
            // Validate property types
            for (key, propSchema) in properties {
                if let propValue = dict[key] {
                    try validateAgainstSchema(propValue, schema: propSchema)
                }
            }
        case .enum(let values):
            guard let stringValue = value.stringValue else {
                throw SwamlError.schemaValidationError("Enum value must be a string")
            }
            guard values.contains(stringValue) else {
                throw SwamlError.schemaValidationError("Invalid enum value: \(stringValue). Expected one of: \(values.joined(separator: ", "))")
            }
        case .ref:
            // Reference validation happens at schema resolution time
            break
        case .anyOf(let schemas):
            var valid = false
            for subSchema in schemas {
                if (try? validateAgainstSchema(value, schema: subSchema)) != nil {
                    valid = true
                    break
                }
            }
            if !valid {
                throw SwamlError.schemaValidationError("Value doesn't match any schema in anyOf")
            }
        }
    }
}

// MARK: - Convenience Extensions

extension OutputParser {
    /// Parse a string value directly (for simple string returns)
    public static func parseString(_ output: String) -> String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse a boolean value
    public static func parseBool(_ output: String) throws -> Bool {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "true" || trimmed == "yes" || trimmed == "1" {
            return true
        }
        if trimmed == "false" || trimmed == "no" || trimmed == "0" {
            return false
        }
        throw SwamlError.parseError("Cannot parse '\(output)' as boolean")
    }

    /// Parse an integer value
    public static func parseInt(_ output: String) throws -> Int {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else {
            throw SwamlError.parseError("Cannot parse '\(output)' as integer")
        }
        return value
    }

    /// Parse a float value
    public static func parseFloat(_ output: String) throws -> Double {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed) else {
            throw SwamlError.parseError("Cannot parse '\(output)' as float")
        }
        return value
    }
}
