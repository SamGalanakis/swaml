//! Generated type structures for Swift templates
//!
//! This module contains the structs that are passed to Askama templates
//! for generating Swift code.

use crate::r#type::{SerializeType, TypeSwift};
use crate::utils::escape_swift_string;

/// Represents a Swift struct generated from a BAML class
#[derive(Debug, Clone)]
pub struct ClassSwift {
    /// The original BAML name
    pub baml_name: String,
    /// The Swift struct name (PascalCase)
    pub name: String,
    /// Optional documentation string
    pub docstring: Option<String>,
    /// Fields of the struct
    pub fields: Vec<FieldSwift>,
    /// Whether this is a dynamic type
    pub dynamic: bool,
}

impl ClassSwift {
    /// Check if CodingKeys are needed (when any field name differs from BAML name)
    pub fn needs_coding_keys(&self) -> bool {
        self.fields.iter().any(|f| f.baml_name != f.name)
    }

    /// Get fields that need CodingKey mapping
    pub fn coding_key_fields(&self) -> Vec<&FieldSwift> {
        self.fields.iter().collect()
    }
}

/// Represents a field in a Swift struct
#[derive(Debug, Clone)]
pub struct FieldSwift {
    /// The original BAML name
    pub baml_name: String,
    /// The Swift property name (camelCase)
    pub name: String,
    /// The Swift type
    pub field_type: TypeSwift,
    /// Optional documentation string
    pub docstring: Option<String>,
}

impl FieldSwift {
    /// Get the Swift type string
    pub fn type_string(&self) -> String {
        self.field_type.serialize()
    }

    /// Check if the field type is optional
    pub fn is_optional(&self) -> bool {
        self.field_type.is_optional()
    }
}

/// Represents a Swift enum generated from a BAML enum
#[derive(Debug, Clone)]
pub struct EnumSwift {
    /// The original BAML name
    pub baml_name: String,
    /// The Swift enum name (PascalCase)
    pub name: String,
    /// Optional documentation string
    pub docstring: Option<String>,
    /// Enum values/cases
    pub values: Vec<EnumValueSwift>,
    /// Whether this is a dynamic enum
    pub dynamic: bool,
}

impl EnumSwift {
    /// Check if any value needs a raw value assignment
    pub fn needs_raw_values(&self) -> bool {
        self.values.iter().any(|v| v.baml_name != v.name)
    }
}

/// Represents an enum case in Swift
#[derive(Debug, Clone)]
pub struct EnumValueSwift {
    /// The original BAML value name
    pub baml_name: String,
    /// The Swift case name (lowerCamelCase)
    pub name: String,
    /// Optional alias for serialization
    pub alias: Option<String>,
    /// Optional documentation string
    pub docstring: Option<String>,
}

impl EnumValueSwift {
    /// Get the raw value for serialization
    pub fn raw_value(&self) -> &str {
        self.alias.as_ref().unwrap_or(&self.baml_name)
    }

    /// Check if a raw value assignment is needed
    pub fn needs_raw_value(&self) -> bool {
        let raw = self.raw_value();
        raw != self.name
    }
}

/// Represents a Swift enum with associated values (from BAML union)
#[derive(Debug, Clone)]
pub struct UnionSwift {
    /// The original BAML name
    pub baml_name: String,
    /// The Swift enum name (PascalCase)
    pub name: String,
    /// Optional documentation string
    pub docstring: Option<String>,
    /// Union variants
    pub variants: Vec<UnionVariantSwift>,
}

impl UnionSwift {
    /// Get the list of types for the union discriminator
    pub fn variant_type_names(&self) -> Vec<String> {
        self.variants
            .iter()
            .map(|v| v.type_string())
            .collect()
    }
}

/// Represents a variant in a Swift union enum
#[derive(Debug, Clone)]
pub struct UnionVariantSwift {
    /// The Swift case name (lowerCamelCase)
    pub name: String,
    /// The associated type
    pub variant_type: TypeSwift,
    /// Optional documentation string
    pub docstring: Option<String>,
}

impl UnionVariantSwift {
    /// Get the Swift type string for this variant
    pub fn type_string(&self) -> String {
        self.variant_type.serialize()
    }
}

/// Represents a Swift function generated from a BAML function
#[derive(Debug, Clone)]
pub struct FunctionSwift {
    /// The original BAML name
    pub baml_name: String,
    /// The Swift function name (camelCase)
    pub name: String,
    /// Optional documentation string
    pub docstring: Option<String>,
    /// Function parameters
    pub params: Vec<ParamSwift>,
    /// Return type
    pub return_type: TypeSwift,
    /// Streaming return type (for streaming variant)
    pub stream_return_type: Option<TypeSwift>,
    /// The client to use for this function
    pub client: Option<String>,
    /// The prompt template
    pub prompt: Option<String>,
}

impl FunctionSwift {
    /// Get the return type string
    pub fn return_type_string(&self) -> String {
        self.return_type.serialize()
    }

    /// Get the stream return type string
    pub fn stream_return_type_string(&self) -> Option<String> {
        self.stream_return_type.as_ref().map(|t| t.serialize())
    }

    /// Check if this function has parameters
    pub fn has_params(&self) -> bool {
        !self.params.is_empty()
    }

    /// Get parameter list as a formatted string for function signature
    pub fn param_signature(&self) -> String {
        self.params
            .iter()
            .map(|p| p.signature())
            .collect::<Vec<_>>()
            .join(",\n        ")
    }

    /// Get the prompt as a Swift multiline string literal
    pub fn prompt_literal(&self) -> Option<String> {
        self.prompt.as_ref().map(|p| {
            // Escape for Swift multiline string
            let escaped = p
                .replace("\\", "\\\\")
                .replace("\"\"\"", "\\\"\\\"\\\"");
            format!("\"\"\"\n{}\n\"\"\"", escaped)
        })
    }
}

/// Represents a function parameter in Swift
#[derive(Debug, Clone)]
pub struct ParamSwift {
    /// The original BAML name
    pub baml_name: String,
    /// The Swift parameter name (camelCase)
    pub name: String,
    /// The Swift type
    pub param_type: TypeSwift,
    /// Optional default value
    pub default_value: Option<String>,
    /// Optional documentation string
    pub docstring: Option<String>,
}

impl ParamSwift {
    /// Get the Swift type string
    pub fn type_string(&self) -> String {
        self.param_type.serialize()
    }

    /// Get the full parameter signature
    pub fn signature(&self) -> String {
        let base = format!("{}: {}", self.name, self.type_string());
        match &self.default_value {
            Some(default) => format!("{} = {}", base, default),
            None => base,
        }
    }

    /// Check if the parameter has a default value
    pub fn has_default(&self) -> bool {
        self.default_value.is_some()
    }
}

/// Represents a type alias in Swift
#[derive(Debug, Clone)]
pub struct TypeAliasSwift {
    /// The original BAML name
    pub baml_name: String,
    /// The Swift typealias name (PascalCase)
    pub name: String,
    /// The aliased type
    pub target_type: TypeSwift,
    /// Optional documentation string
    pub docstring: Option<String>,
}

impl TypeAliasSwift {
    /// Get the target type string
    pub fn target_type_string(&self) -> String {
        self.target_type.serialize()
    }
}

/// Represents a client configuration
#[derive(Debug, Clone)]
pub struct ClientConfigSwift {
    /// The client name
    pub name: String,
    /// The provider type (e.g., "openai", "anthropic")
    pub provider: String,
    /// The model name
    pub model: String,
    /// Additional options as key-value pairs
    pub options: indexmap::IndexMap<String, String>,
}

impl ClientConfigSwift {
    /// Get the Swift provider initializer
    pub fn provider_init(&self) -> String {
        match self.provider.to_lowercase().as_str() {
            "openai" => ".openAI".to_string(),
            "anthropic" => ".anthropic".to_string(),
            "google" | "google-ai" => ".googleAI".to_string(),
            "azure" | "azure-openai" => ".azureOpenAI".to_string(),
            "ollama" => ".ollama".to_string(),
            other => format!(".custom(\"{}\")", escape_swift_string(other)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_class_needs_coding_keys() {
        let class = ClassSwift {
            baml_name: "User".to_string(),
            name: "User".to_string(),
            docstring: None,
            dynamic: false,
            fields: vec![
                FieldSwift {
                    baml_name: "user_name".to_string(),
                    name: "userName".to_string(),
                    field_type: TypeSwift::string(),
                    docstring: None,
                },
                FieldSwift {
                    baml_name: "age".to_string(),
                    name: "age".to_string(),
                    field_type: TypeSwift::int(),
                    docstring: None,
                },
            ],
        };

        assert!(class.needs_coding_keys());
    }

    #[test]
    fn test_class_no_coding_keys() {
        let class = ClassSwift {
            baml_name: "User".to_string(),
            name: "User".to_string(),
            docstring: None,
            dynamic: false,
            fields: vec![
                FieldSwift {
                    baml_name: "name".to_string(),
                    name: "name".to_string(),
                    field_type: TypeSwift::string(),
                    docstring: None,
                },
            ],
        };

        assert!(!class.needs_coding_keys());
    }

    #[test]
    fn test_enum_value_raw_value() {
        let value = EnumValueSwift {
            baml_name: "HAPPY".to_string(),
            name: "happy".to_string(),
            alias: None,
            docstring: None,
        };

        assert_eq!(value.raw_value(), "HAPPY");
        assert!(value.needs_raw_value());

        let value_with_alias = EnumValueSwift {
            baml_name: "HAPPY".to_string(),
            name: "happy".to_string(),
            alias: Some("Happy".to_string()),
            docstring: None,
        };

        assert_eq!(value_with_alias.raw_value(), "Happy");
    }

    #[test]
    fn test_param_signature() {
        let param = ParamSwift {
            baml_name: "user_name".to_string(),
            name: "userName".to_string(),
            param_type: TypeSwift::string(),
            default_value: None,
            docstring: None,
        };

        assert_eq!(param.signature(), "userName: String");

        let param_with_default = ParamSwift {
            baml_name: "count".to_string(),
            name: "count".to_string(),
            param_type: TypeSwift::int(),
            default_value: Some("5".to_string()),
            docstring: None,
        };

        assert_eq!(param_with_default.signature(), "count: Int = 5");
    }

    #[test]
    fn test_client_provider_init() {
        let client = ClientConfigSwift {
            name: "default".to_string(),
            provider: "openai".to_string(),
            model: "gpt-4".to_string(),
            options: indexmap::IndexMap::new(),
        };

        assert_eq!(client.provider_init(), ".openAI");

        let anthropic = ClientConfigSwift {
            name: "claude".to_string(),
            provider: "anthropic".to_string(),
            model: "claude-3".to_string(),
            options: indexmap::IndexMap::new(),
        };

        assert_eq!(anthropic.provider_init(), ".anthropic");
    }
}
