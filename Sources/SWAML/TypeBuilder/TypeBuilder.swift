import Foundation

/// Build types dynamically at runtime for use with BAML functions
public class TypeBuilder: @unchecked Sendable {
    private var classes: [String: ClassBuilder] = [:]
    private var enums: [String: EnumBuilder] = [:]

    public init() {}

    /// Define a new class dynamically
    @discardableResult
    public func addClass(_ name: String) -> ClassBuilder {
        let builder = ClassBuilder(name: name)
        classes[name] = builder
        return builder
    }

    /// Define a new enum dynamically
    @discardableResult
    public func addEnum(_ name: String) -> EnumBuilder {
        let builder = EnumBuilder(name: name)
        enums[name] = builder
        return builder
    }

    /// Get a class builder by name
    public func getClass(_ name: String) -> ClassBuilder? {
        classes[name]
    }

    /// Get an enum builder by name
    public func getEnum(_ name: String) -> EnumBuilder? {
        enums[name]
    }

    /// Get all class names
    public var classNames: [String] {
        Array(classes.keys)
    }

    /// Get all enum names
    public var enumNames: [String] {
        Array(enums.keys)
    }

    /// Build a complete JSON Schema with all definitions
    public func buildSchema(root: String) throws -> [String: Any] {
        // Find the root type
        guard let rootClass = classes[root] else {
            if let rootEnum = enums[root] {
                return rootEnum.buildSchema().toDictionary()
            }
            throw BamlError.schemaValidationError("Root type '\(root)' not found")
        }

        // Build definitions for all types
        var definitions: [String: JSONSchema] = [:]

        for (name, classBuilder) in classes {
            definitions[name] = classBuilder.buildSchema()
        }

        for (name, enumBuilder) in enums {
            definitions[name] = enumBuilder.buildSchema()
        }

        // Build the document with root referencing definitions
        let rootSchema = rootClass.buildSchema()
        return JSONSchema.document(root: rootSchema, definitions: definitions)
    }

    /// Build JSON Schema for a specific type
    public func buildSchemaForType(_ name: String) -> JSONSchema? {
        if let classBuilder = classes[name] {
            return classBuilder.buildSchema()
        }
        if let enumBuilder = enums[name] {
            return enumBuilder.buildSchema()
        }
        return nil
    }

    /// Resolve a reference to its schema
    public func resolveReference(_ name: String) -> JSONSchema? {
        buildSchemaForType(name)
    }

    /// Generate Swift code for all types (for debugging/documentation)
    public func generateSwiftCode() -> String {
        var lines: [String] = []
        lines.append("// Generated Types")
        lines.append("")

        // Generate enums first (classes may reference them)
        for (_, enumBuilder) in enums.sorted(by: { $0.key < $1.key }) {
            lines.append(enumBuilder.generateSwiftEnum())
            lines.append("")
        }

        // Generate classes
        for (_, classBuilder) in classes.sorted(by: { $0.key < $1.key }) {
            lines.append(classBuilder.generateSwiftStruct())
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Convenience Extensions

extension TypeBuilder {
    /// Create a type builder with common patterns

    /// Add a simple DTO class with automatic property inference
    @discardableResult
    public func addSimpleClass(_ name: String, properties: [String: PropertyType]) -> ClassBuilder {
        let builder = addClass(name)
        for (propName, propType) in properties {
            builder.addProperty(propName, type: propType)
        }
        return builder
    }

    /// Add a simple enum with string values
    @discardableResult
    public func addSimpleEnum(_ name: String, values: [String]) -> EnumBuilder {
        let builder = addEnum(name)
        for value in values {
            builder.addValue(value)
        }
        return builder
    }
}
