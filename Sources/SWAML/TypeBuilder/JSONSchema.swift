import Foundation

/// JSON Schema representation for validation and LLM structured output
public indirect enum JSONSchema: Sendable, Equatable {
    case string
    case integer
    case number
    case boolean
    case null
    case array(items: JSONSchema)
    case object(properties: [String: JSONSchema], required: [String], additionalProperties: JSONSchema? = nil)
    case `enum`(values: [String])
    case ref(String)
    case anyOf([JSONSchema])

    /// Convert to dictionary representation for JSON serialization
    public func toDictionary() -> [String: Any] {
        switch self {
        case .string:
            return ["type": "string"]
        case .integer:
            return ["type": "integer"]
        case .number:
            return ["type": "number"]
        case .boolean:
            return ["type": "boolean"]
        case .null:
            return ["type": "null"]
        case .array(let items):
            return [
                "type": "array",
                "items": items.toDictionary()
            ]
        case .object(let properties, let required, let additionalProperties):
            var dict: [String: Any] = [
                "type": "object",
                "properties": properties.mapValues { $0.toDictionary() }
            ]
            if !required.isEmpty {
                dict["required"] = required
            }
            if let additional = additionalProperties {
                dict["additionalProperties"] = additional.toDictionary()
            } else {
                dict["additionalProperties"] = false
            }
            return dict
        case .enum(let values):
            return [
                "type": "string",
                "enum": values
            ]
        case .ref(let name):
            return ["$ref": "#/$defs/\(name)"]
        case .anyOf(let schemas):
            return ["anyOf": schemas.map { $0.toDictionary() }]
        }
    }

    /// Create a complete JSON Schema document with definitions
    public static func document(
        root: JSONSchema,
        definitions: [String: JSONSchema] = [:]
    ) -> [String: Any] {
        var doc = root.toDictionary()
        if !definitions.isEmpty {
            doc["$defs"] = definitions.mapValues { $0.toDictionary() }
        }
        return doc
    }
}

// MARK: - Schema Builder Helpers

extension JSONSchema {
    /// Create an object schema with a fluent interface
    public static func object() -> ObjectSchemaBuilder {
        ObjectSchemaBuilder()
    }

    /// Create an array schema
    public static func array(of items: JSONSchema) -> JSONSchema {
        .array(items: items)
    }

    /// Create an optional (nullable) schema
    public static func optional(_ schema: JSONSchema) -> JSONSchema {
        .anyOf([schema, .null])
    }
}

/// Builder for object schemas
public class ObjectSchemaBuilder {
    private var properties: [String: JSONSchema] = [:]
    private var required: [String] = []
    private var additionalProperties: JSONSchema?

    @discardableResult
    public func property(_ name: String, _ schema: JSONSchema, required: Bool = true) -> ObjectSchemaBuilder {
        properties[name] = schema
        if required {
            self.required.append(name)
        }
        return self
    }

    @discardableResult
    public func additionalProperties(_ schema: JSONSchema) -> ObjectSchemaBuilder {
        additionalProperties = schema
        return self
    }

    public func build() -> JSONSchema {
        .object(properties: properties, required: required, additionalProperties: additionalProperties)
    }
}
