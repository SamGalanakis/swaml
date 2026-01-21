import Foundation

/// Extracts JSON from LLM output that may contain markdown or other formatting
public struct JSONExtractor {

    /// Extract JSON from raw LLM output
    /// Handles common cases like markdown code blocks, extra text before/after JSON
    public static func extract(from output: String) throws -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to parse as-is first
        if isValidJSON(trimmed) {
            return trimmed
        }

        // Try extracting from markdown code block
        if let extracted = extractFromMarkdownCodeBlock(trimmed) {
            return extracted
        }

        // Try finding JSON object or array
        if let extracted = extractJSONStructure(from: trimmed) {
            return extracted
        }

        throw BamlError.jsonExtractionError("Could not find valid JSON in output")
    }

    /// Extract from markdown code block (```json ... ``` or ``` ... ```)
    private static func extractFromMarkdownCodeBlock(_ text: String) -> String? {
        // Pattern for ```json ... ``` or ``` ... ```
        let patterns = [
            #"```json\s*([\s\S]*?)\s*```"#,
            #"```\s*([\s\S]*?)\s*```"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let extracted = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidJSON(extracted) {
                    return extracted
                }
            }
        }

        return nil
    }

    /// Find JSON object {...} or array [...] in text
    private static func extractJSONStructure(from text: String) -> String? {
        // Try to find JSON object
        if let objectRange = findBalancedBraces(in: text, open: "{", close: "}") {
            let extracted = String(text[objectRange])
            if isValidJSON(extracted) {
                return extracted
            }
        }

        // Try to find JSON array
        if let arrayRange = findBalancedBraces(in: text, open: "[", close: "]") {
            let extracted = String(text[arrayRange])
            if isValidJSON(extracted) {
                return extracted
            }
        }

        return nil
    }

    /// Find range of balanced braces/brackets
    private static func findBalancedBraces(in text: String, open: Character, close: Character) -> Range<String.Index>? {
        guard let startIndex = text.firstIndex(of: open) else { return nil }

        var depth = 0
        var inString = false
        var escapeNext = false
        var index = startIndex

        while index < text.endIndex {
            let char = text[index]

            if escapeNext {
                escapeNext = false
                index = text.index(after: index)
                continue
            }

            if char == "\\" && inString {
                escapeNext = true
                index = text.index(after: index)
                continue
            }

            if char == "\"" {
                inString.toggle()
            } else if !inString {
                if char == open {
                    depth += 1
                } else if char == close {
                    depth -= 1
                    if depth == 0 {
                        return startIndex..<text.index(after: index)
                    }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    /// Check if string is valid JSON
    private static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Attempt to repair common JSON issues
    public static func repair(_ json: String) -> String? {
        var repaired = json

        // Fix trailing commas in objects and arrays
        repaired = removeTrailingCommas(repaired)

        // Fix unquoted keys
        repaired = quoteUnquotedKeys(repaired)

        // Fix single quotes to double quotes
        repaired = fixSingleQuotes(repaired)

        // Validate the repaired JSON
        if isValidJSON(repaired) {
            return repaired
        }

        return nil
    }

    private static func removeTrailingCommas(_ json: String) -> String {
        var result = json

        // Remove trailing commas before } (with optional whitespace)
        while let range = result.range(of: ",\\s*\\}", options: .regularExpression) {
            let whitespaceCount = result.distance(from: range.lowerBound, to: range.upperBound) - 2
            result.replaceSubrange(range, with: "}")
        }

        // Remove trailing commas before ] (with optional whitespace)
        while let range = result.range(of: ",\\s*\\]", options: .regularExpression) {
            result.replaceSubrange(range, with: "]")
        }

        return result
    }

    private static func quoteUnquotedKeys(_ json: String) -> String {
        // Match unquoted keys followed by colon
        let pattern = #"(\{|\,)\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return json
        }

        var result = json
        var offset = 0

        let matches = regex.matches(in: json, options: [], range: NSRange(json.startIndex..., in: json))

        for match in matches {
            guard let keyRange = Range(match.range(at: 2), in: json) else { continue }
            let key = String(json[keyRange])

            let nsRange = NSRange(location: match.range(at: 2).location + offset, length: match.range(at: 2).length)
            guard let swiftRange = Range(nsRange, in: result) else { continue }

            let quotedKey = "\"\(key)\""
            result.replaceSubrange(swiftRange, with: quotedKey)
            offset += 2 // Added two quote characters
        }

        return result
    }

    private static func fixSingleQuotes(_ json: String) -> String {
        // This is a simplified fix - in production, need to handle escaped quotes
        var result = json
        var inDoubleQuoteString = false
        var newString = ""
        var prevChar: Character?

        for char in result {
            if char == "\"" && prevChar != "\\" {
                inDoubleQuoteString.toggle()
                newString.append(char)
            } else if char == "'" && !inDoubleQuoteString && prevChar != "\\" {
                newString.append("\"")
            } else {
                newString.append(char)
            }
            prevChar = char
        }

        return newString
    }
}
