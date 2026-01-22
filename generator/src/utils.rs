//! Swift-specific utility functions
//!
//! This module provides utility functions for converting BAML identifiers
//! and types to valid Swift code.

use heck::{ToLowerCamelCase, ToUpperCamelCase};

/// Swift reserved keywords that need escaping with backticks
const SWIFT_RESERVED_KEYWORDS: &[&str] = &[
    // Declaration keywords
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
    "func", "import", "init", "inout", "internal", "let", "open", "operator",
    "private", "precedencegroup", "protocol", "public", "rethrows", "static",
    "struct", "subscript", "typealias", "var",
    // Statement keywords
    "break", "case", "catch", "continue", "default", "defer", "do", "else",
    "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw",
    "switch", "where", "while",
    // Expression and type keywords
    "Any", "as", "await", "catch", "false", "is", "nil", "rethrows", "self",
    "Self", "super", "throw", "throws", "true", "try",
    // Pattern keywords
    "_",
    // Context-sensitive keywords (still good to escape)
    "Protocol", "Type",
];

/// Convert a BAML name to a valid Swift identifier
///
/// This handles:
/// - Converting snake_case to camelCase
/// - Escaping Swift reserved keywords with backticks
/// - Preserving already-valid identifiers
pub fn to_swift_identifier(name: &str) -> String {
    let camel = name.to_lower_camel_case();
    escape_if_reserved(&camel)
}

/// Convert a BAML name to a valid Swift type name (PascalCase)
pub fn to_swift_type_name(name: &str) -> String {
    let pascal = name.to_upper_camel_case();
    escape_if_reserved(&pascal)
}

/// Convert a BAML name to a Swift enum case name
///
/// Enum cases in Swift are typically lowerCamelCase
pub fn to_swift_case_name(name: &str) -> String {
    // Handle various input formats
    let normalized = name
        .replace('-', "_")
        .replace(' ', "_");

    let camel = normalized.to_lower_camel_case();
    escape_if_reserved(&camel)
}

/// Escape a name with backticks if it's a Swift reserved keyword
pub fn escape_if_reserved(name: &str) -> String {
    if SWIFT_RESERVED_KEYWORDS.contains(&name) {
        format!("`{}`", name)
    } else {
        name.to_string()
    }
}

/// Check if a name needs escaping in Swift
pub fn is_reserved_keyword(name: &str) -> bool {
    SWIFT_RESERVED_KEYWORDS.contains(&name)
}

/// Escape a string for use in a Swift string literal
pub fn escape_swift_string(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '\\' => result.push_str("\\\\"),
            '"' => result.push_str("\\\""),
            '\n' => result.push_str("\\n"),
            '\r' => result.push_str("\\r"),
            '\t' => result.push_str("\\t"),
            '\0' => result.push_str("\\0"),
            c => result.push(c),
        }
    }
    result
}

/// Format a docstring for Swift documentation comments
pub fn format_docstring(doc: &str) -> String {
    doc.lines()
        .map(|line| format!("/// {}", line.trim()))
        .collect::<Vec<_>>()
        .join("\n")
}

/// Format a multi-line string as a Swift multi-line string literal
pub fn format_multiline_string(s: &str) -> String {
    format!("\"\"\"\n{}\n\"\"\"", s)
}

/// Generate a Swift coding key enum for fields that need name mapping
pub fn generate_coding_keys(fields: &[(String, String)]) -> Option<String> {
    // Filter to only fields that need remapping
    let needs_mapping: Vec<_> = fields
        .iter()
        .filter(|(baml_name, swift_name)| baml_name != swift_name)
        .collect();

    if needs_mapping.is_empty() {
        return None;
    }

    let mut lines = vec![
        "    private enum CodingKeys: String, CodingKey {".to_string(),
    ];

    for (baml_name, swift_name) in fields {
        if baml_name != swift_name {
            lines.push(format!("        case {} = \"{}\"", swift_name, baml_name));
        } else {
            lines.push(format!("        case {}", swift_name));
        }
    }

    lines.push("    }".to_string());
    Some(lines.join("\n"))
}

/// Indent a block of code by a specified number of spaces
pub fn indent(code: &str, spaces: usize) -> String {
    let indent = " ".repeat(spaces);
    code.lines()
        .map(|line| {
            if line.trim().is_empty() {
                String::new()
            } else {
                format!("{}{}", indent, line)
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Join items with a separator, optionally with a trailing separator
pub fn join_with<T: AsRef<str>>(items: &[T], separator: &str, trailing: bool) -> String {
    let joined = items
        .iter()
        .map(|s| s.as_ref())
        .collect::<Vec<_>>()
        .join(separator);

    if trailing && !items.is_empty() {
        format!("{}{}", joined, separator)
    } else {
        joined
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_to_swift_identifier() {
        assert_eq!(to_swift_identifier("hello_world"), "helloWorld");
        assert_eq!(to_swift_identifier("user_name"), "userName");
        assert_eq!(to_swift_identifier("n_roasts"), "nRoasts");
        assert_eq!(to_swift_identifier("already"), "already");
        assert_eq!(to_swift_identifier("ABC"), "abc");
        assert_eq!(to_swift_identifier("userID"), "userId");
    }

    #[test]
    fn test_reserved_keyword_escaping() {
        assert_eq!(to_swift_identifier("class"), "`class`");
        assert_eq!(to_swift_identifier("return"), "`return`");
        assert_eq!(to_swift_identifier("self"), "`self`");
        assert_eq!(to_swift_identifier("var"), "`var`");
        assert_eq!(to_swift_identifier("let"), "`let`");
    }

    #[test]
    fn test_to_swift_type_name() {
        assert_eq!(to_swift_type_name("my_class"), "MyClass");
        assert_eq!(to_swift_type_name("user"), "User");
        assert_eq!(to_swift_type_name("user_profile"), "UserProfile");
    }

    #[test]
    fn test_to_swift_case_name() {
        assert_eq!(to_swift_case_name("HAPPY"), "happy");
        assert_eq!(to_swift_case_name("Very Happy"), "veryHappy");
        assert_eq!(to_swift_case_name("snake_case"), "snakeCase");
        assert_eq!(to_swift_case_name("kebab-case"), "kebabCase");
    }

    #[test]
    fn test_escape_swift_string() {
        assert_eq!(escape_swift_string("hello"), "hello");
        assert_eq!(escape_swift_string("hello\"world"), "hello\\\"world");
        assert_eq!(escape_swift_string("line1\nline2"), "line1\\nline2");
        assert_eq!(escape_swift_string("path\\to\\file"), "path\\\\to\\\\file");
    }

    #[test]
    fn test_format_docstring() {
        assert_eq!(format_docstring("Hello world"), "/// Hello world");
        assert_eq!(
            format_docstring("Line 1\nLine 2"),
            "/// Line 1\n/// Line 2"
        );
    }

    #[test]
    fn test_indent() {
        assert_eq!(indent("hello", 4), "    hello");
        assert_eq!(indent("line1\nline2", 2), "  line1\n  line2");
        assert_eq!(indent("hello\n\nworld", 4), "    hello\n\n    world");
    }

    #[test]
    fn test_generate_coding_keys() {
        let fields = vec![
            ("user_name".to_string(), "userName".to_string()),
            ("age".to_string(), "age".to_string()),
        ];

        let result = generate_coding_keys(&fields);
        assert!(result.is_some());
        let keys = result.unwrap();
        assert!(keys.contains("case userName = \"user_name\""));
        assert!(keys.contains("case age"));
    }

    #[test]
    fn test_generate_coding_keys_not_needed() {
        let fields = vec![
            ("name".to_string(), "name".to_string()),
            ("age".to_string(), "age".to_string()),
        ];

        let result = generate_coding_keys(&fields);
        assert!(result.is_none());
    }
}
