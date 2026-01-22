//! IR to Swift conversion module
//!
//! This module provides functions to convert intermediate representation types
//! to Swift-specific types for code generation.
//!
//! The module is designed to work with a simple IR defined in this crate,
//! with optional support for BAML's IntermediateRepr when the `baml-ir` feature
//! is enabled.

pub mod classes;
pub mod enums;
pub mod functions;
pub mod type_aliases;
pub mod unions;

use crate::package::GenerationContext;
use crate::r#type::{MediaTypeSwift, TypeSwift};

/// Simplified type representation for the generator
///
/// This enum represents BAML types in a form that's easy to work with
/// for code generation. When the `baml-ir` feature is enabled, these
/// can be created from BAML's actual FieldType.
#[derive(Debug, Clone, PartialEq)]
pub enum FieldType {
    /// Primitive string type
    String,
    /// Primitive int type
    Int,
    /// Primitive float type (maps to Double in Swift)
    Float,
    /// Primitive bool type
    Bool,
    /// Null type
    Null,
    /// Image media type
    Image,
    /// Audio media type
    Audio,
    /// File media type
    File,
    /// Reference to a class by name
    Class(String),
    /// Reference to an enum by name
    Enum(String),
    /// Array/list of a type
    List(Box<FieldType>),
    /// Map/dictionary from key type to value type
    Map(Box<FieldType>, Box<FieldType>),
    /// Optional (nullable) type
    Optional(Box<FieldType>),
    /// Union of multiple types
    Union(Vec<FieldType>),
    /// String literal type
    LiteralString(String),
    /// Int literal type
    LiteralInt(i64),
    /// Bool literal type
    LiteralBool(bool),
    /// Reference to a type alias
    TypeAlias(String),
}

impl FieldType {
    /// Create a string type
    pub fn string() -> Self {
        FieldType::String
    }

    /// Create an int type
    pub fn int() -> Self {
        FieldType::Int
    }

    /// Create a float type
    pub fn float() -> Self {
        FieldType::Float
    }

    /// Create a bool type
    pub fn bool() -> Self {
        FieldType::Bool
    }

    /// Create a null type
    pub fn null() -> Self {
        FieldType::Null
    }

    /// Create a class reference
    pub fn class(name: impl Into<String>) -> Self {
        FieldType::Class(name.into())
    }

    /// Create an enum reference
    pub fn enum_ref(name: impl Into<String>) -> Self {
        FieldType::Enum(name.into())
    }

    /// Create a list type
    pub fn list(inner: FieldType) -> Self {
        FieldType::List(Box::new(inner))
    }

    /// Create a map type
    pub fn map(key: FieldType, value: FieldType) -> Self {
        FieldType::Map(Box::new(key), Box::new(value))
    }

    /// Create an optional type
    pub fn optional(inner: FieldType) -> Self {
        FieldType::Optional(Box::new(inner))
    }

    /// Create a union type
    pub fn union(variants: Vec<FieldType>) -> Self {
        FieldType::Union(variants)
    }
}

/// Convert a FieldType to TypeSwift
pub fn field_type_to_swift(field_type: &FieldType, ctx: &GenerationContext) -> TypeSwift {
    match field_type {
        FieldType::String => TypeSwift::String(None),
        FieldType::Int => TypeSwift::Int(None),
        FieldType::Float => TypeSwift::Float,
        FieldType::Bool => TypeSwift::Bool(None),
        FieldType::Null => TypeSwift::Null,
        FieldType::Image => TypeSwift::Media(MediaTypeSwift::Image),
        FieldType::Audio => TypeSwift::Media(MediaTypeSwift::Audio),
        FieldType::File => TypeSwift::Media(MediaTypeSwift::File),
        FieldType::Class(name) => TypeSwift::Class {
            name: name.clone(),
            module: ctx.current_module(),
            dynamic: false,
        },
        FieldType::Enum(name) => TypeSwift::Enum {
            name: name.clone(),
            module: ctx.current_module(),
            dynamic: false,
        },
        FieldType::List(inner) => TypeSwift::List(Box::new(field_type_to_swift(inner, ctx))),
        FieldType::Map(key, value) => TypeSwift::Map(
            Box::new(field_type_to_swift(key, ctx)),
            Box::new(field_type_to_swift(value, ctx)),
        ),
        FieldType::Optional(inner) => {
            TypeSwift::Optional(Box::new(field_type_to_swift(inner, ctx)))
        }
        FieldType::Union(variants) => union_field_type_to_swift(variants, ctx),
        FieldType::LiteralString(s) => TypeSwift::String(Some(s.clone())),
        FieldType::LiteralInt(i) => TypeSwift::Int(Some(*i)),
        FieldType::LiteralBool(b) => TypeSwift::Bool(Some(*b)),
        FieldType::TypeAlias(name) => TypeSwift::TypeAlias {
            name: name.clone(),
            module: ctx.current_module(),
        },
    }
}

/// Convert a union field type to TypeSwift
fn union_field_type_to_swift(variants: &[FieldType], ctx: &GenerationContext) -> TypeSwift {
    // Check if this is a nullable union (type | null)
    let non_null_variants: Vec<_> = variants
        .iter()
        .filter(|v| !matches!(v, FieldType::Null))
        .collect();
    let has_null = non_null_variants.len() < variants.len();

    // If only one non-null variant, it's just an optional
    if non_null_variants.len() == 1 {
        let inner = field_type_to_swift(non_null_variants[0], ctx);
        if has_null {
            return TypeSwift::Optional(Box::new(inner));
        }
        return inner;
    }

    // For multiple variants, create a union type
    let variant_types: Vec<TypeSwift> = non_null_variants
        .iter()
        .map(|v| field_type_to_swift(v, ctx))
        .collect();

    let union_name = generate_union_name(&variant_types);

    let union_type = TypeSwift::Union {
        name: union_name,
        module: ctx.current_module(),
    };

    if has_null {
        TypeSwift::Optional(Box::new(union_type))
    } else {
        union_type
    }
}

/// Generate a name for an anonymous union type
pub fn generate_union_name(types: &[TypeSwift]) -> String {
    let names: Vec<String> = types
        .iter()
        .map(|t| match t {
            TypeSwift::String(_) => "String".to_string(),
            TypeSwift::Int(_) => "Int".to_string(),
            TypeSwift::Float => "Double".to_string(),
            TypeSwift::Bool(_) => "Bool".to_string(),
            TypeSwift::Class { name, .. } => name.clone(),
            TypeSwift::Enum { name, .. } => name.clone(),
            TypeSwift::List(inner) => {
                format!("{}Array", generate_union_name(&[(**inner).clone()]))
            }
            _ => "Value".to_string(),
        })
        .collect();

    format!("{}Union", names.join("Or"))
}

/// Convert a streaming field type to TypeSwift
pub fn streaming_field_type_to_swift(field_type: &FieldType, ctx: &GenerationContext) -> TypeSwift {
    let inner = field_type_to_swift(field_type, ctx);
    TypeSwift::StreamState(Box::new(inner))
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
    fn test_primitive_conversion() {
        let ctx = test_ctx();
        assert_eq!(
            field_type_to_swift(&FieldType::String, &ctx).serialize(),
            "String"
        );
        assert_eq!(
            field_type_to_swift(&FieldType::Int, &ctx).serialize(),
            "Int"
        );
        assert_eq!(
            field_type_to_swift(&FieldType::Float, &ctx).serialize(),
            "Double"
        );
        assert_eq!(
            field_type_to_swift(&FieldType::Bool, &ctx).serialize(),
            "Bool"
        );
    }

    #[test]
    fn test_optional_conversion() {
        let ctx = test_ctx();
        let optional_string = FieldType::optional(FieldType::String);
        assert_eq!(
            field_type_to_swift(&optional_string, &ctx).serialize(),
            "String?"
        );
    }

    #[test]
    fn test_list_conversion() {
        let ctx = test_ctx();
        let list_int = FieldType::list(FieldType::Int);
        assert_eq!(
            field_type_to_swift(&list_int, &ctx).serialize(),
            "[Int]"
        );
    }

    #[test]
    fn test_map_conversion() {
        let ctx = test_ctx();
        let map_type = FieldType::map(FieldType::String, FieldType::Int);
        assert_eq!(
            field_type_to_swift(&map_type, &ctx).serialize(),
            "[String: Int]"
        );
    }

    #[test]
    fn test_nullable_union_becomes_optional() {
        let ctx = test_ctx();
        let nullable_string = FieldType::union(vec![FieldType::String, FieldType::Null]);
        assert_eq!(
            field_type_to_swift(&nullable_string, &ctx).serialize(),
            "String?"
        );
    }

    #[test]
    fn test_generate_union_name() {
        let types = vec![TypeSwift::string(), TypeSwift::int()];
        assert_eq!(generate_union_name(&types), "StringOrIntUnion");
    }
}
