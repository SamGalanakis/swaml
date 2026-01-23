import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Macro that generates SwamlTyped conformance for structs and enums
public struct SwamlTypeMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Determine if this is a struct or enum
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return try expandStruct(structDecl, type: type, context: context)
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return try expandEnum(enumDecl, type: type, context: context)
        } else {
            throw MacroError.message("@SwamlType can only be applied to structs and enums")
        }
    }

    // MARK: - Struct Expansion

    private static func expandStruct(
        _ structDecl: StructDeclSyntax,
        type: some TypeSyntaxProtocol,
        context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let typeName = structDecl.name.text

        // Extract properties
        var properties: [(name: String, type: String, isOptional: Bool)] = []
        var descriptions: [String: String] = [:]
        var aliases: [String: String] = [:]

        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

            // Check for @Description and @Alias attributes
            for attr in varDecl.attributes {
                if let attrSyntax = attr.as(AttributeSyntax.self) {
                    let attrName = attrSyntax.attributeName.description.trimmingCharacters(in: .whitespaces)

                    if attrName == "Description",
                       let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self),
                       let firstArg = args.first,
                       let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        // Get property name
                        if let binding = varDecl.bindings.first,
                           let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                            descriptions[pattern.identifier.text] = segment.content.text
                        }
                    }

                    if attrName == "Alias",
                       let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self),
                       let firstArg = args.first,
                       let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        if let binding = varDecl.bindings.first,
                           let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                            aliases[pattern.identifier.text] = segment.content.text
                        }
                    }
                }
            }

            // Extract property info
            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                      let typeAnnotation = binding.typeAnnotation else { continue }

                let propName = pattern.identifier.text
                let propType = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)
                let isOptional = propType.hasSuffix("?") || propType.hasPrefix("Optional<")

                properties.append((name: propName, type: propType, isOptional: isOptional))
            }
        }

        // Check for @SwamlDynamic attribute
        let isDynamic = structDecl.attributes.contains { attr in
            guard let attrSyntax = attr.as(AttributeSyntax.self) else { return false }
            return attrSyntax.attributeName.description.trimmingCharacters(in: .whitespaces) == "SwamlDynamic"
        }

        // Build schema code
        let schemaCode = buildObjectSchema(properties: properties)

        // Build descriptions dictionary
        let descriptionsCode = buildDictionaryLiteral(descriptions)

        // Build aliases dictionary
        let aliasesCode = buildDictionaryLiteral(aliases)

        let extensionDecl: DeclSyntax = """
        extension \(raw: typeName): SwamlTyped {
            public static var swamlTypeName: String { "\(raw: typeName)" }
            public static var swamlSchema: JSONSchema {
                \(raw: schemaCode)
            }
            public static var isDynamic: Bool { \(raw: isDynamic ? "true" : "false") }
            public static var fieldDescriptions: [String: String] { \(raw: descriptionsCode) }
            public static var fieldAliases: [String: String] { \(raw: aliasesCode) }
        }
        """

        return [extensionDecl.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: - Enum Expansion

    private static func expandEnum(
        _ enumDecl: EnumDeclSyntax,
        type: some TypeSyntaxProtocol,
        context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let typeName = enumDecl.name.text

        // Extract enum cases
        var cases: [String] = []
        var descriptions: [String: String] = [:]

        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }

            // Check for @Description attribute on the case
            for attr in caseDecl.attributes {
                if let attrSyntax = attr.as(AttributeSyntax.self) {
                    let attrName = attrSyntax.attributeName.description.trimmingCharacters(in: .whitespaces)

                    if attrName == "Description",
                       let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self),
                       let firstArg = args.first,
                       let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        for element in caseDecl.elements {
                            descriptions[element.name.text] = segment.content.text
                        }
                    }
                }
            }

            for element in caseDecl.elements {
                cases.append(element.name.text)
            }
        }

        // Check for @SwamlDynamic attribute
        let isDynamic = enumDecl.attributes.contains { attr in
            guard let attrSyntax = attr.as(AttributeSyntax.self) else { return false }
            return attrSyntax.attributeName.description.trimmingCharacters(in: .whitespaces) == "SwamlDynamic"
        }

        // Build schema code
        let enumValues = cases.map { "\"\($0)\"" }.joined(separator: ", ")

        let descriptionsCode = buildDictionaryLiteral(descriptions)

        let extensionDecl: DeclSyntax = """
        extension \(raw: typeName): SwamlTyped {
            public static var swamlTypeName: String { "\(raw: typeName)" }
            public static var swamlSchema: JSONSchema { .enum(values: [\(raw: enumValues)]) }
            public static var isDynamic: Bool { \(raw: isDynamic ? "true" : "false") }
            public static var fieldDescriptions: [String: String] { \(raw: descriptionsCode) }
            public static var fieldAliases: [String: String] { [:] }
        }
        """

        return [extensionDecl.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: - Helpers

    private static func buildObjectSchema(properties: [(name: String, type: String, isOptional: Bool)]) -> String {
        if properties.isEmpty {
            return ".object(properties: [:], required: [])"
        }

        var propLines: [String] = []
        var requiredProps: [String] = []

        for prop in properties {
            let jsonSchema = swiftTypeToJSONSchema(prop.type)
            propLines.append("\"\(prop.name)\": \(jsonSchema)")

            if !prop.isOptional {
                requiredProps.append("\"\(prop.name)\"")
            }
        }

        let propsDict = "[\(propLines.joined(separator: ", "))]"
        let requiredArray = "[\(requiredProps.joined(separator: ", "))]"

        return ".object(properties: \(propsDict), required: \(requiredArray))"
    }

    private static func swiftTypeToJSONSchema(_ swiftType: String) -> String {
        let trimmed = swiftType.trimmingCharacters(in: .whitespaces)

        // Handle optionals
        if trimmed.hasSuffix("?") {
            let inner = String(trimmed.dropLast())
            return ".anyOf([\(swiftTypeToJSONSchema(inner)), .null])"
        }

        if trimmed.hasPrefix("Optional<") && trimmed.hasSuffix(">") {
            let inner = String(trimmed.dropFirst(9).dropLast())
            return ".anyOf([\(swiftTypeToJSONSchema(inner)), .null])"
        }

        // Handle arrays
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let inner = String(trimmed.dropFirst().dropLast())
            return ".array(items: \(swiftTypeToJSONSchema(inner)))"
        }

        if trimmed.hasPrefix("Array<") && trimmed.hasSuffix(">") {
            let inner = String(trimmed.dropFirst(6).dropLast())
            return ".array(items: \(swiftTypeToJSONSchema(inner)))"
        }

        // Handle dictionaries
        if trimmed.hasPrefix("[String:") && trimmed.hasSuffix("]") {
            let valueType = String(trimmed.dropFirst(8).dropLast()).trimmingCharacters(in: .whitespaces)
            return ".object(properties: [:], required: [], additionalProperties: \(swiftTypeToJSONSchema(valueType)))"
        }

        if trimmed.hasPrefix("Dictionary<String,") && trimmed.hasSuffix(">") {
            let rest = String(trimmed.dropFirst(18).dropLast()).trimmingCharacters(in: .whitespaces)
            return ".object(properties: [:], required: [], additionalProperties: \(swiftTypeToJSONSchema(rest)))"
        }

        // Primitive types
        switch trimmed {
        case "String":
            return ".string"
        case "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return ".integer"
        case "Double", "Float", "Float32", "Float64", "CGFloat":
            return ".number"
        case "Bool":
            return ".boolean"
        default:
            // Assume it's a reference to another type
            return ".ref(\"\(trimmed)\")"
        }
    }

    private static func buildDictionaryLiteral(_ dict: [String: String]) -> String {
        if dict.isEmpty {
            return "[:]"
        }

        let pairs = dict.map { "\"\($0.key)\": \"\($0.value)\"" }
        return "[\(pairs.joined(separator: ", "))]"
    }
}

/// Error type for macro expansion failures
enum MacroError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let msg):
            return msg
        }
    }
}
