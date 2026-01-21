//! Swift type conversion utilities
//!
//! This module handles the conversion of BAML types to Swift types.

use crate::{BamlType, BamlEnum, BamlClass, BamlField, BamlEnumValue};

/// Convert a BAML type to its Swift representation
pub fn baml_type_to_swift(ty: &BamlType) -> String {
    match ty {
        BamlType::String => "String".to_string(),
        BamlType::Int => "Int".to_string(),
        BamlType::Float => "Double".to_string(),
        BamlType::Bool => "Bool".to_string(),
        BamlType::Optional(inner) => format!("{}?", baml_type_to_swift(inner)),
        BamlType::List(inner) => format!("[{}]", baml_type_to_swift(inner)),
        BamlType::Map(key, value) => {
            format!("[{}: {}]", baml_type_to_swift(key), baml_type_to_swift(value))
        }
        BamlType::Named(name) => name.clone(),
    }
}

/// Convert a BAML type to its BamlValue representation
pub fn baml_type_to_value_type(ty: &BamlType) -> String {
    match ty {
        BamlType::String => ".string".to_string(),
        BamlType::Int => ".int".to_string(),
        BamlType::Float => ".float".to_string(),
        BamlType::Bool => ".bool".to_string(),
        BamlType::Optional(inner) => baml_type_to_value_type(inner),
        BamlType::List(_) => ".array".to_string(),
        BamlType::Map(_, _) => ".map".to_string(),
        BamlType::Named(_) => ".map".to_string(), // Classes/enums are represented as maps/strings
    }
}

/// Convert snake_case to camelCase
pub fn snake_to_camel(s: &str) -> String {
    let mut result = String::new();
    let mut capitalize_next = false;

    for (i, c) in s.chars().enumerate() {
        if c == '_' {
            capitalize_next = true;
        } else if capitalize_next {
            result.push(c.to_ascii_uppercase());
            capitalize_next = false;
        } else if i == 0 {
            result.push(c.to_ascii_lowercase());
        } else {
            result.push(c);
        }
    }

    result
}

/// Convert PascalCase to camelCase
pub fn pascal_to_camel(s: &str) -> String {
    if s.is_empty() {
        return s.to_string();
    }
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(first) => first.to_lowercase().collect::<String>() + chars.as_str(),
    }
}

/// Convert a string to a valid Swift identifier
pub fn to_swift_identifier(s: &str) -> String {
    let result = snake_to_camel(s);

    // Handle Swift reserved words
    let reserved = [
        "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
        "if", "else", "for", "while", "do", "switch", "case", "default", "break",
        "continue", "return", "throw", "try", "catch", "import", "public", "private",
        "internal", "fileprivate", "open", "static", "final", "override", "init",
        "deinit", "subscript", "typealias", "associatedtype", "where", "guard",
        "defer", "repeat", "in", "is", "as", "self", "Self", "super", "nil",
        "true", "false", "Any", "Type", "Protocol",
    ];

    if reserved.contains(&result.as_str()) {
        format!("`{}`", result)
    } else {
        result
    }
}

/// Convert an enum value to a valid Swift case name
pub fn to_swift_case_name(value: &str) -> String {
    // If it's already lowercase and valid, use as-is
    if value.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_') {
        return to_swift_identifier(value);
    }

    // Convert to camelCase
    let result = snake_to_camel(&value.to_lowercase().replace('-', "_").replace(' ', "_"));
    to_swift_identifier(&result)
}

/// Generate Swift struct code for a BAML class
pub fn generate_swift_struct(class: &BamlClass) -> String {
    let mut lines = Vec::new();

    // Doc comment
    if let Some(doc) = &class.doc {
        lines.push(format!("/// {}", doc));
    }

    // Struct declaration
    lines.push(format!(
        "public struct {}: Codable, Sendable, Equatable {{",
        class.name
    ));

    // Fields
    for field in &class.fields {
        if let Some(doc) = &field.doc {
            lines.push(format!("    /// {}", doc));
        }
        let swift_name = to_swift_identifier(&field.name);
        let swift_type = baml_type_to_swift(&field.field_type);
        lines.push(format!("    public let {}: {}", swift_name, swift_type));
    }

    // CodingKeys if needed (for snake_case conversion)
    let needs_coding_keys = class.fields.iter().any(|f| f.name.contains('_'));
    if needs_coding_keys {
        lines.push("");
        lines.push("    private enum CodingKeys: String, CodingKey {".to_string());
        for field in &class.fields {
            let swift_name = to_swift_identifier(&field.name);
            if field.name.contains('_') {
                lines.push(format!(
                    "        case {} = \"{}\"",
                    swift_name, field.name
                ));
            } else {
                lines.push(format!("        case {}", swift_name));
            }
        }
        lines.push("    }".to_string());
    }

    lines.push("}".to_string());

    lines.join("\n")
}

/// Generate Swift enum code for a BAML enum
pub fn generate_swift_enum(e: &BamlEnum) -> String {
    let mut lines = Vec::new();

    // Doc comment
    if let Some(doc) = &e.doc {
        lines.push(format!("/// {}", doc));
    }

    // Enum declaration
    lines.push(format!(
        "public enum {}: String, Codable, Sendable, CaseIterable {{",
        e.name
    ));

    // Cases
    for value in &e.values {
        if let Some(doc) = &value.doc {
            lines.push(format!("    /// {}", doc));
        }

        let case_name = to_swift_case_name(&value.name);
        let raw_value = value.alias.as_ref().unwrap_or(&value.name);

        if case_name == raw_value.to_lowercase() || case_name == raw_value {
            lines.push(format!("    case {}", case_name));
        } else {
            lines.push(format!("    case {} = \"{}\"", case_name, raw_value));
        }
    }

    lines.push("}".to_string());

    lines.join("\n")
}

/// Generate JSON Schema type string for a BAML type
pub fn baml_type_to_json_schema(ty: &BamlType) -> String {
    match ty {
        BamlType::String => r#"["type": "string"]"#.to_string(),
        BamlType::Int => r#"["type": "integer"]"#.to_string(),
        BamlType::Float => r#"["type": "number"]"#.to_string(),
        BamlType::Bool => r#"["type": "boolean"]"#.to_string(),
        BamlType::Optional(inner) => {
            format!(
                r#"["anyOf": [{}, ["type": "null"]]]"#,
                baml_type_to_json_schema(inner)
            )
        }
        BamlType::List(inner) => {
            format!(
                r#"["type": "array", "items": {}]"#,
                baml_type_to_json_schema(inner)
            )
        }
        BamlType::Map(_, value) => {
            format!(
                r#"["type": "object", "additionalProperties": {}]"#,
                baml_type_to_json_schema(value)
            )
        }
        BamlType::Named(name) => {
            format!(r#"["$ref": "#/$defs/{}"]"#, name)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_snake_to_camel() {
        assert_eq!(snake_to_camel("hello_world"), "helloWorld");
        assert_eq!(snake_to_camel("user_name"), "userName");
        assert_eq!(snake_to_camel("n_roasts"), "nRoasts");
        assert_eq!(snake_to_camel("already"), "already");
        assert_eq!(snake_to_camel("ABC"), "aBC");
    }

    #[test]
    fn test_to_swift_identifier() {
        assert_eq!(to_swift_identifier("hello_world"), "helloWorld");
        assert_eq!(to_swift_identifier("class"), "`class`");
        assert_eq!(to_swift_identifier("return"), "`return`");
    }

    #[test]
    fn test_to_swift_case_name() {
        assert_eq!(to_swift_case_name("HAPPY"), "happy");
        assert_eq!(to_swift_case_name("Very Happy"), "veryHappy");
        assert_eq!(to_swift_case_name("snake_case"), "snakeCase");
    }

    #[test]
    fn test_baml_type_to_swift() {
        assert_eq!(baml_type_to_swift(&BamlType::String), "String");
        assert_eq!(baml_type_to_swift(&BamlType::Int), "Int");
        assert_eq!(baml_type_to_swift(&BamlType::Float), "Double");
        assert_eq!(
            baml_type_to_swift(&BamlType::Optional(Box::new(BamlType::String))),
            "String?"
        );
        assert_eq!(
            baml_type_to_swift(&BamlType::List(Box::new(BamlType::Int))),
            "[Int]"
        );
        assert_eq!(
            baml_type_to_swift(&BamlType::Map(
                Box::new(BamlType::String),
                Box::new(BamlType::Int)
            )),
            "[String: Int]"
        );
        assert_eq!(
            baml_type_to_swift(&BamlType::Named("MyClass".to_string())),
            "MyClass"
        );
    }
}
