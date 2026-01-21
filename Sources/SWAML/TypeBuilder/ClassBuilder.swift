import Foundation

/// Builder for defining class/struct schemas dynamically
public class ClassBuilder: @unchecked Sendable {
    public let name: String
    private var properties: [(name: String, type: PropertyType, description: String?)] = []

    public init(name: String) {
        self.name = name
    }

    /// Add a property to the class
    @discardableResult
    public func addProperty(_ name: String, type: PropertyType) -> Self {
        properties.append((name: name, type: type, description: nil))
        return self
    }

    /// Add a property with description
    @discardableResult
    public func addProperty(_ name: String, type: PropertyType, description: String?) -> Self {
        properties.append((name: name, type: type, description: description))
        return self
    }

    /// Get all properties
    public var allProperties: [(name: String, type: PropertyType, description: String?)] {
        properties
    }

    /// Build JSON Schema for this class
    public func buildSchema() -> JSONSchema {
        var schemaProperties: [String: JSONSchema] = [:]
        var required: [String] = []

        for prop in properties {
            let propSchema = prop.type.toJSONSchema()
            schemaProperties[prop.name] = propSchema

            // Non-optional properties are required
            if case .optional = prop.type {
                // Optional, not required
            } else {
                required.append(prop.name)
            }
        }

        return .object(properties: schemaProperties, required: required)
    }

    /// Generate a struct definition for documentation/debugging
    public func generateSwiftStruct() -> String {
        var lines: [String] = []
        lines.append("public struct \(name): Codable, Sendable {")

        for prop in properties {
            let swiftType = propertyTypeToSwift(prop.type)
            if let desc = prop.description {
                lines.append("    /// \(desc)")
            }
            lines.append("    public let \(prop.name): \(swiftType)")
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private func propertyTypeToSwift(_ type: PropertyType) -> String {
        switch type {
        case .string:
            return "String"
        case .int:
            return "Int"
        case .float:
            return "Double"
        case .bool:
            return "Bool"
        case .optional(let inner):
            return "\(propertyTypeToSwift(inner))?"
        case .array(let element):
            return "[\(propertyTypeToSwift(element))]"
        case .map(let key, let value):
            return "[\(propertyTypeToSwift(key)): \(propertyTypeToSwift(value))]"
        case .reference(let name):
            return name
        }
    }
}
