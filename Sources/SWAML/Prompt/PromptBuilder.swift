import Foundation

/// A builder for constructing LLM prompts with type-safe variable substitution.
///
/// PromptBuilder replaces .swaml file templates with a Swift-native DSL for
/// building prompts. It supports:
/// - System and user prompt templates
/// - Variable substitution ({{ variable_name }} syntax)
/// - Automatic output format injection ({{ ctx.output_format }})
/// - Few-shot examples
///
/// Example usage:
/// ```swift
/// let prompt = PromptBuilder()
///     .system("""
///         You are a sentiment analyzer.
///         {{ ctx.output_format }}
///         """)
///     .user("Analyze this text: {{ text }}")
///     .variable("text", "I love this product!")
///     .build(returnType: SentimentResult.self)
/// ```
public struct PromptBuilder: Sendable {
    private var systemTemplate: String = ""
    private var userTemplate: String = ""
    private var variables: [String: String] = [:]
    private var examples: [String] = []

    public init() {}

    // MARK: - Template Setting

    /// Set the system prompt template
    ///
    /// Template variables use Jinja-like syntax:
    /// - `{{ variable_name }}` - substitutes a variable
    /// - `{{ ctx.output_format }}` - injects the output schema
    ///
    /// - Parameter template: The system prompt template
    /// - Returns: Updated builder for chaining
    public func system(_ template: String) -> PromptBuilder {
        var copy = self
        copy.systemTemplate = template
        return copy
    }

    /// Set the user prompt template
    ///
    /// - Parameter template: The user prompt template
    /// - Returns: Updated builder for chaining
    public func user(_ template: String) -> PromptBuilder {
        var copy = self
        copy.userTemplate = template
        return copy
    }

    // MARK: - Variable Substitution

    /// Add a string variable for substitution
    ///
    /// - Parameters:
    ///   - name: Variable name (used as {{ name }} in templates)
    ///   - value: Variable value
    /// - Returns: Updated builder for chaining
    public func variable(_ name: String, _ value: String) -> PromptBuilder {
        var copy = self
        copy.variables[name] = value
        return copy
    }

    /// Add an integer variable for substitution
    public func variable(_ name: String, _ value: Int) -> PromptBuilder {
        variable(name, String(value))
    }

    /// Add a double variable for substitution
    public func variable(_ name: String, _ value: Double) -> PromptBuilder {
        variable(name, String(value))
    }

    /// Add a boolean variable for substitution
    public func variable(_ name: String, _ value: Bool) -> PromptBuilder {
        variable(name, value ? "true" : "false")
    }

    /// Add an encodable value as a JSON variable
    ///
    /// The value will be serialized to JSON and substituted.
    public func variableJSON<T: Encodable>(_ name: String, _ value: T) -> PromptBuilder {
        var copy = self
        if let jsonString = try? jsonEncode(value) {
            copy.variables[name] = jsonString
        }
        return copy
    }

    /// Add multiple variables at once
    public func variables(_ dict: [String: String]) -> PromptBuilder {
        var copy = self
        for (key, value) in dict {
            copy.variables[key] = value
        }
        return copy
    }

    // MARK: - Examples

    /// Add a few-shot example
    ///
    /// Examples are automatically formatted and can be referenced in
    /// templates using {{ example }} or {{ examples }}.
    public func example<T: Encodable>(_ value: T) -> PromptBuilder {
        var copy = self
        if let json = try? jsonEncode(value, prettyPrinted: true) {
            copy.examples.append(json)
        }
        return copy
    }

    /// Add multiple examples
    public func examples<T: Encodable>(_ values: [T]) -> PromptBuilder {
        var copy = self
        for value in values {
            if let json = try? jsonEncode(value, prettyPrinted: true) {
                copy.examples.append(json)
            }
        }
        return copy
    }

    // MARK: - Building

    /// Build chat messages with output format automatically injected
    ///
    /// - Parameters:
    ///   - returnType: The expected return type (for schema generation)
    ///   - typeBuilder: Optional TypeBuilder for dynamic types
    ///   - includeDescriptions: Whether to include field descriptions in schema
    /// - Returns: Array of ChatMessage ready for LLM call
    public func build<T: SwamlTyped>(
        returnType: T.Type,
        typeBuilder: TypeBuilder? = nil,
        includeDescriptions: Bool = true
    ) -> [ChatMessage] {
        let outputFormat = SchemaPromptRenderer.render(
            for: T.self,
            typeBuilder: typeBuilder,
            includeDescriptions: includeDescriptions
        )

        return buildWithOutputFormat(outputFormat)
    }

    /// Build chat messages with a custom JSON schema
    ///
    /// - Parameters:
    ///   - schema: The JSON schema for output format
    ///   - typeBuilder: Optional TypeBuilder for dynamic types
    /// - Returns: Array of ChatMessage ready for LLM call
    public func build(
        schema: JSONSchema,
        typeBuilder: TypeBuilder? = nil
    ) -> [ChatMessage] {
        let outputFormat = SchemaPromptRenderer.render(
            schema: schema,
            typeBuilder: typeBuilder
        )

        return buildWithOutputFormat(outputFormat)
    }

    /// Build chat messages without type information (raw prompts)
    ///
    /// No output format will be injected. {{ ctx.output_format }} placeholders
    /// will be replaced with an empty string.
    public func buildRaw() -> [ChatMessage] {
        buildWithOutputFormat("")
    }

    // MARK: - Private Helpers

    private func buildWithOutputFormat(_ outputFormat: String) -> [ChatMessage] {
        var messages: [ChatMessage] = []

        // Build all variables including special ones
        var allVariables = variables
        allVariables["ctx.output_format"] = outputFormat

        // Add example variable if examples exist
        if !examples.isEmpty {
            if examples.count == 1 {
                allVariables["example"] = examples[0]
            }
            allVariables["examples"] = examples.joined(separator: "\n\n")
        }

        // Process system prompt
        if !systemTemplate.isEmpty {
            let systemContent = substituteVariables(systemTemplate, variables: allVariables)
            messages.append(.system(systemContent))
        }

        // Process user prompt
        if !userTemplate.isEmpty {
            let userContent = substituteVariables(userTemplate, variables: allVariables)
            messages.append(.user(userContent))
        }

        return messages
    }

    /// Substitute {{ variable }} placeholders in a template
    private func substituteVariables(_ template: String, variables: [String: String]) -> String {
        var result = template

        // Match {{ variable_name }} with optional whitespace
        let pattern = #"\{\{\s*([a-zA-Z_][a-zA-Z0-9_.]*)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return template
        }

        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, range: range)

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let varRange = Range(match.range(at: 1), in: result) else {
                continue
            }

            let varName = String(result[varRange])
            if let value = variables[varName] {
                result.replaceSubrange(fullRange, with: value)
            }
            // Leave unmatched variables as-is (or could throw)
        }

        return result
    }

    private func jsonEncode<T: Encodable>(_ value: T, prettyPrinted: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Convenience Extensions

extension PromptBuilder {
    /// Create a simple prompt with just user text
    public static func simple(_ userPrompt: String) -> PromptBuilder {
        PromptBuilder().user(userPrompt)
    }

    /// Create a prompt with system and user text
    public static func chat(system: String, user: String) -> PromptBuilder {
        PromptBuilder()
            .system(system)
            .user(user)
    }

    /// Create a prompt from a system template with output format placeholder
    ///
    /// This is the most common pattern - a system prompt that includes
    /// the output format instruction.
    public static func withOutputFormat(
        system: String = "{{ ctx.output_format }}",
        user: String
    ) -> PromptBuilder {
        PromptBuilder()
            .system(system)
            .user(user)
    }
}

// MARK: - ChatMessage Extensions for PromptBuilder

extension ChatMessage {
    /// Create a ChatMessage array from a PromptBuilder
    public static func from<T: SwamlTyped>(
        _ builder: PromptBuilder,
        returnType: T.Type,
        typeBuilder: TypeBuilder? = nil
    ) -> [ChatMessage] {
        builder.build(returnType: returnType, typeBuilder: typeBuilder)
    }
}
