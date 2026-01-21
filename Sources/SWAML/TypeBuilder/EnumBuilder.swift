import Foundation

/// Builder for defining enum schemas dynamically
public class EnumBuilder: @unchecked Sendable {
    public let name: String
    private var values: [(value: String, alias: String?, description: String?)] = []

    public init(name: String) {
        self.name = name
    }

    /// Add a value to the enum
    @discardableResult
    public func addValue(_ value: String) -> Self {
        values.append((value: value, alias: nil, description: nil))
        return self
    }

    /// Add a value with an alias
    @discardableResult
    public func addValue(_ value: String, alias: String?) -> Self {
        values.append((value: value, alias: alias, description: nil))
        return self
    }

    /// Add a value with alias and description
    @discardableResult
    public func addValue(_ value: String, alias: String?, description: String?) -> Self {
        values.append((value: value, alias: alias, description: description))
        return self
    }

    /// Get all values
    public var allValues: [(value: String, alias: String?, description: String?)] {
        values
    }

    /// Get just the value strings (for JSON Schema enum)
    public var valueStrings: [String] {
        values.map { $0.value }
    }

    /// Build JSON Schema for this enum
    public func buildSchema() -> JSONSchema {
        .enum(values: valueStrings)
    }

    /// Generate a Swift enum definition for documentation/debugging
    public func generateSwiftEnum() -> String {
        var lines: [String] = []
        lines.append("public enum \(name): String, Codable, Sendable, CaseIterable {")

        for val in values {
            let caseName = swiftCaseName(from: val.value)
            if let desc = val.description {
                lines.append("    /// \(desc)")
            }
            if caseName != val.value {
                lines.append("    case \(caseName) = \"\(val.value)\"")
            } else {
                lines.append("    case \(caseName)")
            }
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// Convert a string value to a valid Swift case name
    private func swiftCaseName(from value: String) -> String {
        // Convert to camelCase and handle special characters
        var result = ""
        var capitalizeNext = false

        for (index, char) in value.enumerated() {
            if char == "_" || char == "-" || char == " " {
                capitalizeNext = true
            } else if char.isLetter || char.isNumber {
                if index == 0 {
                    result.append(char.lowercased())
                } else if capitalizeNext {
                    result.append(char.uppercased())
                    capitalizeNext = false
                } else {
                    result.append(char.lowercased())
                }
            }
        }

        // Handle reserved words
        let reserved = ["class", "struct", "enum", "case", "default", "for", "in", "while", "if", "else", "return", "true", "false", "nil"]
        if reserved.contains(result.lowercased()) {
            result = "`\(result)`"
        }

        return result.isEmpty ? "unknown" : result
    }
}
