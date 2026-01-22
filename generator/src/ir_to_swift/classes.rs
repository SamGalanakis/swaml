//! Class to Swift struct conversion
//!
//! This module handles converting class definitions to Swift structs.

use crate::generated_types::{ClassSwift, FieldSwift};
use crate::package::GenerationContext;
use crate::r#type::TypeSwift;
use crate::utils::to_swift_identifier;

use super::{field_type_to_swift, FieldType};

/// Simplified class definition for the generator
#[derive(Debug, Clone)]
pub struct ClassDef {
    /// The class name
    pub name: String,
    /// Optional documentation
    pub docstring: Option<String>,
    /// Static fields
    pub fields: Vec<FieldDef>,
    /// Whether the class has dynamic fields
    pub has_dynamic_fields: bool,
}

/// Simplified field definition
#[derive(Debug, Clone)]
pub struct FieldDef {
    /// The field name (BAML style)
    pub name: String,
    /// The field type
    pub field_type: FieldType,
    /// Optional documentation
    pub docstring: Option<String>,
}

/// Convert a class definition to a Swift struct representation
pub fn class_def_to_swift(class: &ClassDef, ctx: &GenerationContext) -> ClassSwift {
    let fields = class
        .fields
        .iter()
        .map(|field| {
            let swift_name = to_swift_identifier(&field.name);
            let swift_type = field_type_to_swift(&field.field_type, ctx);

            FieldSwift {
                baml_name: field.name.clone(),
                name: swift_name,
                field_type: swift_type,
                docstring: field.docstring.clone(),
            }
        })
        .collect();

    ClassSwift {
        baml_name: class.name.clone(),
        name: class.name.clone(),
        docstring: class.docstring.clone(),
        fields,
        dynamic: class.has_dynamic_fields,
    }
}

/// Convert a class definition to a streaming (partial) Swift struct
///
/// In streaming mode, all fields become optional to allow partial updates.
pub fn class_def_to_swift_stream(class: &ClassDef, ctx: &GenerationContext) -> ClassSwift {
    let stream_name = format!("{}Partial", class.name);
    let docstring = class.docstring.as_ref().map(|d| {
        format!("Partial streaming version of {}. {}", class.name, d)
    });

    let fields = class
        .fields
        .iter()
        .map(|field| {
            let swift_name = to_swift_identifier(&field.name);
            let base_type = field_type_to_swift(&field.field_type, ctx);
            // Make all fields optional for streaming
            let field_type = TypeSwift::optional(streaming_type(&base_type));

            FieldSwift {
                baml_name: field.name.clone(),
                name: swift_name,
                field_type,
                docstring: field.docstring.clone(),
            }
        })
        .collect();

    ClassSwift {
        baml_name: class.name.clone(),
        name: stream_name,
        docstring,
        fields,
        dynamic: class.has_dynamic_fields,
    }
}

/// Convert a type to its streaming variant
fn streaming_type(ty: &TypeSwift) -> TypeSwift {
    match ty {
        TypeSwift::Class { name, module, dynamic } => TypeSwift::Class {
            name: format!("{}Partial", name),
            module: module.clone(),
            dynamic: *dynamic,
        },
        TypeSwift::List(inner) => TypeSwift::List(Box::new(streaming_type(inner))),
        TypeSwift::Map(key, value) => {
            TypeSwift::Map(key.clone(), Box::new(streaming_type(value)))
        }
        // For other types, just make them optional if not already
        other => TypeSwift::optional(other.clone()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::package::GeneratorConfig;
    use crate::r#type::SerializeType;

    fn test_ctx() -> GenerationContext {
        GenerationContext::new(GeneratorConfig::default())
    }

    #[test]
    fn test_class_conversion() {
        let ctx = test_ctx();
        let class = ClassDef {
            name: "User".to_string(),
            docstring: Some("A user".to_string()),
            fields: vec![
                FieldDef {
                    name: "user_name".to_string(),
                    field_type: FieldType::String,
                    docstring: None,
                },
                FieldDef {
                    name: "age".to_string(),
                    field_type: FieldType::Int,
                    docstring: None,
                },
            ],
            has_dynamic_fields: false,
        };

        let swift_class = class_def_to_swift(&class, &ctx);
        assert_eq!(swift_class.name, "User");
        assert_eq!(swift_class.fields.len(), 2);
        assert_eq!(swift_class.fields[0].name, "userName");
        assert_eq!(swift_class.fields[0].baml_name, "user_name");
        assert!(swift_class.needs_coding_keys());
    }

    #[test]
    fn test_streaming_type_class() {
        let ty = TypeSwift::class("User");
        let stream_ty = streaming_type(&ty);
        // streaming_type wraps class in Partial version (without optional)
        // The optional wrapping happens in class_def_to_swift_stream
        assert_eq!(stream_ty.serialize(), "UserPartial");
    }

    #[test]
    fn test_stream_class_conversion() {
        let ctx = test_ctx();
        let class = ClassDef {
            name: "User".to_string(),
            docstring: None,
            fields: vec![FieldDef {
                name: "name".to_string(),
                field_type: FieldType::String,
                docstring: None,
            }],
            has_dynamic_fields: false,
        };

        let stream_class = class_def_to_swift_stream(&class, &ctx);
        assert_eq!(stream_class.name, "UserPartial");
        assert!(stream_class.fields[0].is_optional());
    }
}
