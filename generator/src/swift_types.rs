//! Swift type conversion utilities (legacy module)
//!
//! This module is kept for backwards compatibility.
//! New code should use the `ir_to_swift` module instead.

use crate::ir_to_swift::FieldType;

/// Convert a BAML type to its Swift representation
pub fn baml_type_to_swift(ty: &FieldType) -> String {
    match ty {
        FieldType::String => "String".to_string(),
        FieldType::Int => "Int".to_string(),
        FieldType::Float => "Double".to_string(),
        FieldType::Bool => "Bool".to_string(),
        FieldType::Null => "Void?".to_string(),
        FieldType::Image => "BamlImage".to_string(),
        FieldType::Audio => "BamlAudio".to_string(),
        FieldType::File => "BamlFile".to_string(),
        FieldType::Optional(inner) => format!("{}?", baml_type_to_swift(inner)),
        FieldType::List(inner) => format!("[{}]", baml_type_to_swift(inner)),
        FieldType::Map(key, value) => {
            format!("[{}: {}]", baml_type_to_swift(key), baml_type_to_swift(value))
        }
        FieldType::Class(name) | FieldType::Enum(name) | FieldType::TypeAlias(name) => name.clone(),
        FieldType::Union(_) => "BamlValue".to_string(),
        FieldType::LiteralString(_) => "String".to_string(),
        FieldType::LiteralInt(_) => "Int".to_string(),
        FieldType::LiteralBool(_) => "Bool".to_string(),
    }
}

/// Convert a BAML type to its BamlValue representation
pub fn baml_type_to_value_type(ty: &FieldType) -> String {
    match ty {
        FieldType::String | FieldType::LiteralString(_) => ".string".to_string(),
        FieldType::Int | FieldType::LiteralInt(_) => ".int".to_string(),
        FieldType::Float => ".float".to_string(),
        FieldType::Bool | FieldType::LiteralBool(_) => ".bool".to_string(),
        FieldType::Optional(inner) => baml_type_to_value_type(inner),
        FieldType::List(_) => ".array".to_string(),
        FieldType::Map(_, _) => ".map".to_string(),
        FieldType::Class(_) | FieldType::Enum(_) => ".map".to_string(),
        _ => ".value".to_string(),
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
    crate::utils::to_swift_identifier(s)
}

/// Convert an enum value to a valid Swift case name
pub fn to_swift_case_name(value: &str) -> String {
    crate::utils::to_swift_case_name(value)
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
    fn test_baml_type_to_swift() {
        assert_eq!(baml_type_to_swift(&FieldType::String), "String");
        assert_eq!(baml_type_to_swift(&FieldType::Int), "Int");
        assert_eq!(baml_type_to_swift(&FieldType::Float), "Double");
        assert_eq!(
            baml_type_to_swift(&FieldType::Optional(Box::new(FieldType::String))),
            "String?"
        );
        assert_eq!(
            baml_type_to_swift(&FieldType::List(Box::new(FieldType::Int))),
            "[Int]"
        );
        assert_eq!(
            baml_type_to_swift(&FieldType::Map(
                Box::new(FieldType::String),
                Box::new(FieldType::Int)
            )),
            "[String: Int]"
        );
        assert_eq!(
            baml_type_to_swift(&FieldType::Class("MyClass".to_string())),
            "MyClass"
        );
    }
}
