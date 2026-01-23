import Foundation

/// Pure Swift implementation of SWAML's jsonish parser.
///
/// Handles robust parsing of LLM output that may contain:
/// - Trailing commas
/// - Comments (// and /* */)
/// - Unquoted keys
/// - Single quotes instead of double quotes
/// - Markdown code blocks
/// - Extra text before/after JSON
/// - Newlines in strings
/// - Multiple JSON candidates (picks the best one)
public struct JsonishParser {

    // MARK: - Public API

    /// Parse LLM output to clean JSON string
    ///
    /// - Parameter input: Raw LLM output
    /// - Parameter isDone: Whether the stream is complete (for streaming support)
    /// - Returns: Clean JSON string
    /// - Throws: SwamlError if no valid JSON can be extracted
    public static func parse(_ input: String, isDone: Bool = true) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try direct parse first (most common case)
        if let json = parseDirectJSON(trimmed) {
            return json
        }

        // Extract from markdown code blocks
        if let json = extractFromCodeBlock(trimmed) {
            return json
        }

        // Find and fix JSON structures in text
        if let json = extractAndFixJSON(from: trimmed, isDone: isDone) {
            return json
        }

        // For streaming, be more lenient with partial content
        if !isDone {
            // Return empty object for incomplete stream
            return "{}"
        }

        throw SwamlError.parseError("Could not extract valid JSON from output: \(trimmed.prefix(200))")
    }

    /// Parse LLM output with streaming support
    public static func parseStreaming(_ input: String, isDone: Bool) throws -> String {
        try parse(input, isDone: isDone)
    }

    // MARK: - Direct JSON Parsing

    private static func parseDirectJSON(_ text: String) -> String? {
        // If it looks like JSON, try to fix and normalize it
        if text.hasPrefix("{") || text.hasPrefix("[") {
            if let fixed = fixAndValidate(text) {
                return fixed
            }

            // If fixing didn't work, try as-is
            if isValidJSON(text) {
                return text
            }
        }

        return nil
    }

    // MARK: - Markdown Code Block Extraction

    private static func extractFromCodeBlock(_ text: String) -> String? {
        // Try various code block patterns
        let patterns = [
            #"```json\s*\n?([\s\S]*?)\n?\s*```"#,
            #"```JSON\s*\n?([\s\S]*?)\n?\s*```"#,
            #"```\s*\n?([\s\S]*?)\n?\s*```"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let content = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let json = fixAndValidate(content) {
                    return json
                }
            }
        }

        return nil
    }

    // MARK: - JSON Structure Extraction

    private static func extractAndFixJSON(from text: String, isDone: Bool) -> String? {
        // Find all potential JSON objects and arrays
        var candidates: [(String, Int)] = []  // (json, startIndex)

        // Find JSON objects
        var searchStart = text.startIndex
        while let objectRange = findBalancedBraces(in: text, from: searchStart, open: "{", close: "}") {
            let candidate = String(text[objectRange])
            let startPos = text.distance(from: text.startIndex, to: objectRange.lowerBound)
            candidates.append((candidate, startPos))
            searchStart = text.index(after: objectRange.lowerBound)
        }

        // Find JSON arrays
        searchStart = text.startIndex
        while let arrayRange = findBalancedBraces(in: text, from: searchStart, open: "[", close: "]") {
            let candidate = String(text[arrayRange])
            let startPos = text.distance(from: text.startIndex, to: arrayRange.lowerBound)
            candidates.append((candidate, startPos))
            searchStart = text.index(after: arrayRange.lowerBound)
        }

        // Sort by position (earlier is usually better for LLM output)
        candidates.sort { $0.1 < $1.1 }

        // Try each candidate, fix it, and validate
        for (candidate, _) in candidates {
            if let json = fixAndValidate(candidate) {
                return json
            }
        }

        // For incomplete streams, try to fix partial JSON
        if !isDone, let partial = fixPartialJSON(text) {
            return partial
        }

        return nil
    }

    // MARK: - JSON Fixing

    /// Apply all fixes and validate
    private static func fixAndValidate(_ json: String) -> String? {
        var fixed = json

        // Order matters - apply fixes in sequence
        fixed = removeComments(fixed)
        fixed = fixSingleQuotes(fixed)
        fixed = quoteUnquotedKeys(fixed)
        fixed = removeTrailingCommas(fixed)
        fixed = fixUnescapedNewlines(fixed)
        fixed = fixMultilineStrings(fixed)

        if isValidJSON(fixed) {
            return fixed
        }

        return nil
    }

    /// Remove C-style comments (// and /* */)
    private static func removeComments(_ json: String) -> String {
        var result = ""
        var i = json.startIndex
        var inString = false
        var escapeNext = false

        while i < json.endIndex {
            let c = json[i]

            if escapeNext {
                result.append(c)
                escapeNext = false
                i = json.index(after: i)
                continue
            }

            if c == "\\" && inString {
                result.append(c)
                escapeNext = true
                i = json.index(after: i)
                continue
            }

            if c == "\"" {
                inString.toggle()
                result.append(c)
                i = json.index(after: i)
                continue
            }

            if !inString {
                // Check for // comment
                if c == "/" {
                    let next = json.index(after: i)
                    if next < json.endIndex {
                        let nextChar = json[next]
                        if nextChar == "/" {
                            // Skip to end of line
                            while i < json.endIndex && json[i] != "\n" {
                                i = json.index(after: i)
                            }
                            continue
                        } else if nextChar == "*" {
                            // Skip to */
                            i = json.index(after: next)
                            while i < json.endIndex {
                                if json[i] == "*" {
                                    let afterStar = json.index(after: i)
                                    if afterStar < json.endIndex && json[afterStar] == "/" {
                                        i = json.index(after: afterStar)
                                        break
                                    }
                                }
                                i = json.index(after: i)
                            }
                            continue
                        }
                    }
                }
            }

            result.append(c)
            i = json.index(after: i)
        }

        return result
    }

    /// Fix single quotes to double quotes (outside of double-quoted strings)
    private static func fixSingleQuotes(_ json: String) -> String {
        var result = ""
        var inDoubleString = false
        var inSingleString = false
        var escapeNext = false

        for c in json {
            if escapeNext {
                result.append(c)
                escapeNext = false
                continue
            }

            if c == "\\" {
                result.append(c)
                escapeNext = true
                continue
            }

            if c == "\"" && !inSingleString {
                inDoubleString.toggle()
                result.append(c)
            } else if c == "'" && !inDoubleString {
                inSingleString.toggle()
                result.append("\"")
            } else {
                result.append(c)
            }
        }

        return result
    }

    /// Quote unquoted object keys
    private static func quoteUnquotedKeys(_ json: String) -> String {
        // Match { or , followed by optional whitespace, then unquoted key, then optional whitespace and :
        let pattern = #"([\{\,])\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*:"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return json
        }

        var result = json
        var offset = 0

        let matches = regex.matches(in: json, options: [], range: NSRange(json.startIndex..., in: json))

        for match in matches {
            guard let keyRange = Range(match.range(at: 2), in: json) else { continue }

            let key = String(json[keyRange])

            // Calculate the adjusted range in the result string
            let adjustedKeyStart = json.distance(from: json.startIndex, to: keyRange.lowerBound) + offset
            let adjustedKeyEnd = json.distance(from: json.startIndex, to: keyRange.upperBound) + offset

            let startIdx = result.index(result.startIndex, offsetBy: adjustedKeyStart)
            let endIdx = result.index(result.startIndex, offsetBy: adjustedKeyEnd)

            let quotedKey = "\"\(key)\""
            result.replaceSubrange(startIdx..<endIdx, with: quotedKey)
            offset += 2 // Added two quote characters
        }

        return result
    }

    /// Remove trailing commas before } or ]
    private static func removeTrailingCommas(_ json: String) -> String {
        var result = ""
        var inString = false
        var escapeNext = false
        var i = json.startIndex

        while i < json.endIndex {
            let c = json[i]

            if escapeNext {
                result.append(c)
                escapeNext = false
                i = json.index(after: i)
                continue
            }

            if c == "\\" && inString {
                result.append(c)
                escapeNext = true
                i = json.index(after: i)
                continue
            }

            if c == "\"" {
                inString.toggle()
                result.append(c)
                i = json.index(after: i)
                continue
            }

            if !inString && c == "," {
                // Look ahead past whitespace to see if next non-whitespace is } or ]
                var j = json.index(after: i)
                while j < json.endIndex && (json[j] == " " || json[j] == "\n" || json[j] == "\r" || json[j] == "\t") {
                    j = json.index(after: j)
                }

                if j < json.endIndex && (json[j] == "}" || json[j] == "]") {
                    // Skip the comma - it's trailing
                    i = json.index(after: i)
                    continue
                }
            }

            result.append(c)
            i = json.index(after: i)
        }

        return result
    }

    /// Fix unescaped newlines inside strings
    private static func fixUnescapedNewlines(_ json: String) -> String {
        var result = ""
        var inString = false
        var escapeNext = false

        for c in json {
            if escapeNext {
                result.append(c)
                escapeNext = false
                continue
            }

            if c == "\\" {
                result.append(c)
                escapeNext = true
                continue
            }

            if c == "\"" {
                inString.toggle()
                result.append(c)
            } else if c == "\n" && inString {
                // Replace unescaped newline in string with \n
                result.append("\\n")
            } else if c == "\r" && inString {
                // Skip carriage returns
                continue
            } else if c == "\t" && inString {
                // Replace unescaped tab with \t
                result.append("\\t")
            } else {
                result.append(c)
            }
        }

        return result
    }

    /// Fix multiline strings (Python-style triple quotes)
    private static func fixMultilineStrings(_ json: String) -> String {
        // Handle """...""" multiline strings
        var result = json

        // Replace triple double quotes with single double quotes and escape contents
        let tripleQuotePattern = #"\"\"\""#
        while let range = result.range(of: tripleQuotePattern, options: .regularExpression) {
            result.replaceSubrange(range, with: "\"")
        }

        return result
    }

    /// Fix partial JSON for streaming
    private static func fixPartialJSON(_ text: String) -> String? {
        // Find the start of a JSON object or array
        guard let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }) else {
            return nil
        }

        var partial = String(text[start...])

        // Remove comments
        partial = removeComments(partial)
        partial = fixSingleQuotes(partial)
        partial = quoteUnquotedKeys(partial)
        partial = removeTrailingCommas(partial)
        partial = fixUnescapedNewlines(partial)

        // Count braces/brackets to see what's missing
        var braceCount = 0
        var bracketCount = 0
        var inString = false
        var escapeNext = false

        for c in partial {
            if escapeNext {
                escapeNext = false
                continue
            }
            if c == "\\" {
                escapeNext = true
                continue
            }
            if c == "\"" {
                inString.toggle()
                continue
            }
            if !inString {
                switch c {
                case "{": braceCount += 1
                case "}": braceCount -= 1
                case "[": bracketCount += 1
                case "]": bracketCount -= 1
                default: break
                }
            }
        }

        // Close any unclosed strings
        if inString {
            partial += "\""
        }

        // Close unclosed structures
        for _ in 0..<bracketCount {
            partial += "]"
        }
        for _ in 0..<braceCount {
            partial += "}"
        }

        if isValidJSON(partial) {
            return partial
        }

        return nil
    }

    // MARK: - Helpers

    /// Find balanced braces/brackets starting from a given position
    private static func findBalancedBraces(
        in text: String,
        from start: String.Index,
        open: Character,
        close: Character
    ) -> Range<String.Index>? {
        guard let openIndex = text[start...].firstIndex(of: open) else { return nil }

        var depth = 0
        var inString = false
        var escapeNext = false
        var index = openIndex

        while index < text.endIndex {
            let c = text[index]

            if escapeNext {
                escapeNext = false
                index = text.index(after: index)
                continue
            }

            if c == "\\" && inString {
                escapeNext = true
                index = text.index(after: index)
                continue
            }

            if c == "\"" {
                inString.toggle()
            } else if !inString {
                if c == open {
                    depth += 1
                } else if c == close {
                    depth -= 1
                    if depth == 0 {
                        return openIndex..<text.index(after: index)
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
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }
}
