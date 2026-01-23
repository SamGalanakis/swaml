import Foundation

/// Renders schema prompts that instruct LLMs how to format structured output.
///
/// The renderer generates human-readable schema descriptions in BAML's format
/// that LLMs understand well.
///
/// Example output:
/// ```
/// Answer in JSON using this schema:
/// {
///   // The person's name
///   name: string,
///   // Current status
///   status: "active" | "inactive",
/// }
/// ```
public struct SchemaPromptRenderer {

    // MARK: - Public API

    /// Render a schema prompt for a BamlTyped type
    ///
    /// Uses BAML's exact output format:
    /// - Objects: "Answer in JSON using this schema:\n{...}"
    /// - Enums: "Answer with any of the categories:\n..."
    /// - Primitives: "Answer as an int", "Answer as a float", etc.
    /// - Arrays: "Answer with a JSON Array using this schema:\n..."
    public static func render<T: BamlTyped>(
        for type: T.Type,
        typeBuilder: TypeBuilder? = nil,
        includeDescriptions: Bool = true
    ) -> String {
        renderFullPrompt(
            schema: T.bamlSchema,
            descriptions: includeDescriptions ? T.fieldDescriptions : [:],
            typeBuilder: typeBuilder
        )
    }

    /// Render a schema prompt from JSONSchema directly
    public static func render(
        schema: JSONSchema,
        descriptions: [String: String] = [:],
        typeBuilder: TypeBuilder? = nil
    ) -> String {
        // If no descriptions provided but we have a TypeBuilder, try to extract them
        var finalDescriptions = descriptions
        if descriptions.isEmpty, let tb = typeBuilder {
            finalDescriptions = extractDescriptions(from: schema, typeBuilder: tb)
        }
        return renderFullPrompt(schema: schema, descriptions: finalDescriptions, typeBuilder: typeBuilder)
    }

    /// Extract field descriptions from TypeBuilder for a given schema
    private static func extractDescriptions(from schema: JSONSchema, typeBuilder: TypeBuilder) -> [String: String] {
        // For object schemas, look up the class in TypeBuilder
        if case .object(let properties, _, _) = schema {
            // Try to find a matching class in TypeBuilder
            for (_, classBuilder) in typeBuilder.allClassBuilders {
                var matches = true
                for propName in properties.keys {
                    if classBuilder.allPropertyBuilders.first(where: { $0.name == propName }) == nil {
                        matches = false
                        break
                    }
                }
                if matches {
                    var descriptions: [String: String] = [:]
                    for prop in classBuilder.allPropertyBuilders {
                        if let desc = prop.descriptionValue {
                            descriptions[prop.name] = desc
                        }
                    }
                    return descriptions
                }
            }
        }
        return [:]
    }

    /// Render a schema prompt from FieldType
    public static func render(
        fieldType: FieldType,
        descriptions: [String: String] = [:],
        typeBuilder: TypeBuilder? = nil
    ) -> String {
        render(schema: fieldType.toJSONSchema(), descriptions: descriptions, typeBuilder: typeBuilder)
    }

    /// Render schema prompt from TypeBuilder's dynamic class
    public static func render(
        className: String,
        from typeBuilder: TypeBuilder
    ) -> String {
        guard let schema = typeBuilder.buildClassSchema(className) else {
            return "Answer in JSON."
        }

        // Get descriptions from class builder
        var descriptions: [String: String] = [:]
        if let classBuilder = typeBuilder.allClassBuilders[className] {
            for prop in classBuilder.allPropertyBuilders {
                if let desc = prop.descriptionValue {
                    descriptions[prop.name] = desc
                }
            }
        }

        return render(schema: schema, descriptions: descriptions, typeBuilder: typeBuilder)
    }

    // MARK: - Full Prompt Rendering (BAML Format)

    /// Render a complete prompt with the appropriate format for the schema type
    private static func renderFullPrompt(
        schema: JSONSchema,
        descriptions: [String: String] = [:],
        typeBuilder: TypeBuilder? = nil
    ) -> String {
        switch schema {
        case .string:
            return ""  // No special instruction for string

        case .integer:
            return "Answer as an int"

        case .number:
            return "Answer as a float"

        case .boolean:
            return "Answer as a bool"

        case .null:
            return "Answer with null"

        case .array(let items):
            let itemSchema = renderSchema(items, descriptions: descriptions, typeBuilder: typeBuilder)
            return "Answer with a JSON Array using this schema:\n\(itemSchema)[]"

        case .enum(let values):
            // BAML enum format
            var lines = ["Answer with any of the categories:"]
            lines.append("----")
            for value in values {
                lines.append("- \(value)")
            }
            return lines.joined(separator: "\n")

        case .object(_, _, _):
            let schemaText = renderSchema(schema, descriptions: descriptions, typeBuilder: typeBuilder)
            return "Answer in JSON using this schema:\n\(schemaText)"

        case .ref(let name):
            // Check if it's a dynamic enum
            if let builder = typeBuilder, let enumSchema = builder.buildEnumSchema(name) {
                return renderFullPrompt(schema: enumSchema, descriptions: descriptions, typeBuilder: typeBuilder)
            }
            // Otherwise treat as object
            let schemaText = renderSchema(schema, descriptions: descriptions, typeBuilder: typeBuilder)
            return "Answer in JSON using this schema:\n\(schemaText)"

        case .anyOf(let schemas):
            // For unions, render the types
            let types = schemas.map { renderSchema($0, descriptions: descriptions, typeBuilder: typeBuilder) }
            return "Answer with one of: \(types.joined(separator: " | "))"
        }
    }

    // MARK: - Schema Rendering

    /// Render a JSONSchema to BAML-style schema text
    public static func renderSchema(
        _ schema: JSONSchema,
        descriptions: [String: String] = [:],
        typeBuilder: TypeBuilder? = nil,
        indent: Int = 0
    ) -> String {
        let indentStr = String(repeating: "  ", count: indent)

        switch schema {
        case .string:
            return "string"

        case .integer:
            return "int"

        case .number:
            return "float"

        case .boolean:
            return "bool"

        case .null:
            return "null"

        case .array(let items):
            let itemSchema = renderSchema(items, descriptions: descriptions, typeBuilder: typeBuilder, indent: indent)
            // BAML style: string[] not [string]
            return "\(itemSchema)[]"

        case .object(let properties, let required, _):
            if properties.isEmpty {
                return "{}"
            }

            var lines: [String] = ["{"]

            // Sort properties for consistent output
            let sortedKeys = properties.keys.sorted()
            for key in sortedKeys {
                guard let propSchema = properties[key] else { continue }

                // Add description as comment above field (BAML style)
                if let desc = descriptions[key] {
                    for line in desc.split(separator: "\n") {
                        lines.append("\(indentStr)  // \(line)")
                    }
                }

                let propType = renderSchema(propSchema, descriptions: descriptions, typeBuilder: typeBuilder, indent: indent + 1)
                let isOptional = !required.contains(key)
                let optionalSuffix = isOptional ? "?" : ""

                // BAML style: unquoted field names
                lines.append("\(indentStr)  \(key)\(optionalSuffix): \(propType),")
            }

            lines.append("\(indentStr)}")
            return lines.joined(separator: "\n")

        case .enum(let values):
            // BAML style: "value1" | "value2"
            if values.count == 1 {
                return "\"\(values[0])\""
            }
            return values.map { "\"\($0)\"" }.joined(separator: " | ")

        case .ref(let name):
            // Check if TypeBuilder has this as a dynamic enum
            if let builder = typeBuilder, let enumSchema = builder.buildEnumSchema(name) {
                return renderSchema(enumSchema, descriptions: descriptions, typeBuilder: typeBuilder, indent: indent)
            }
            // Otherwise return as reference
            return name

        case .anyOf(let schemas):
            // Check for optional pattern (T | null)
            if schemas.count == 2 {
                if case .null = schemas[1] {
                    let inner = renderSchema(schemas[0], descriptions: descriptions, typeBuilder: typeBuilder, indent: indent)
                    return "\(inner) | null"
                }
                if case .null = schemas[0] {
                    let inner = renderSchema(schemas[1], descriptions: descriptions, typeBuilder: typeBuilder, indent: indent)
                    return "\(inner) | null"
                }
            }
            // General union
            return schemas.map {
                renderSchema($0, descriptions: descriptions, typeBuilder: typeBuilder, indent: indent)
            }.joined(separator: " | ")
        }
    }

    // MARK: - Advanced Rendering

    /// Render a complete schema document with type definitions
    public static func renderDocument(
        root: JSONSchema,
        definitions: [String: JSONSchema] = [:],
        typeBuilder: TypeBuilder? = nil
    ) -> String {
        var sections: [String] = []

        // Render type definitions first
        if !definitions.isEmpty {
            sections.append("Type definitions:")
            for (name, schema) in definitions.sorted(by: { $0.key < $1.key }) {
                let rendered = renderSchema(schema, typeBuilder: typeBuilder, indent: 1)
                sections.append("  \(name) = \(rendered)")
            }
            sections.append("")
        }

        // Render dynamic enums from TypeBuilder
        if let builder = typeBuilder {
            let dynamicEnums = builder.dynamicEnumValues()
            if !dynamicEnums.isEmpty {
                if definitions.isEmpty {
                    sections.append("Type definitions:")
                }
                for (name, values) in dynamicEnums.sorted(by: { $0.key < $1.key }) {
                    let enumStr = values.map { "\"\($0)\"" }.joined(separator: " | ")
                    sections.append("  \(name) = \(enumStr)")
                }
                sections.append("")
            }
        }

        // Render main schema
        let rootSchema = renderSchema(root, typeBuilder: typeBuilder)
        sections.append("Answer in JSON using this schema:")
        sections.append(rootSchema)

        return sections.joined(separator: "\n")
    }

    /// Render a prompt with examples
    public static func renderWithExamples<T: BamlTyped>(
        for type: T.Type,
        examples: [T],
        typeBuilder: TypeBuilder? = nil
    ) -> String {
        var parts: [String] = []

        // Schema section
        parts.append(render(for: type, typeBuilder: typeBuilder))

        // Examples section
        if !examples.isEmpty {
            parts.append("\nExamples:")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            for (index, example) in examples.enumerated() {
                if let data = try? encoder.encode(example),
                   let json = String(data: data, encoding: .utf8) {
                    parts.append("\nExample \(index + 1):")
                    parts.append(json)
                }
            }
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - FieldType Schema Rendering Extension

extension FieldType {
    /// Render this type to BAML-style schema text
    public func toSchemaText(typeBuilder: TypeBuilder? = nil) -> String {
        SchemaPromptRenderer.renderSchema(self.toJSONSchema(), typeBuilder: typeBuilder)
    }
}

// MARK: - JSONSchema Extensions for Rendering

extension JSONSchema {
    /// Render this schema to BAML-style schema text
    public func toSchemaText(typeBuilder: TypeBuilder? = nil) -> String {
        SchemaPromptRenderer.renderSchema(self, typeBuilder: typeBuilder)
    }
}
