//! Union to Swift enum conversion
//!
//! This module handles converting union types to Swift enums with associated values.

use crate::generated_types::{UnionSwift, UnionVariantSwift};
use crate::package::GenerationContext;
use crate::r#type::TypeSwift;
use crate::utils::to_swift_case_name;

use super::{field_type_to_swift, FieldType};

/// Simplified union definition for the generator
#[derive(Debug, Clone)]
pub struct UnionDef {
    /// The union name
    pub name: String,
    /// Optional documentation
    pub docstring: Option<String>,
    /// Union variants (the types that make up the union)
    pub variants: Vec<FieldType>,
}

/// Convert a union definition to a Swift enum with associated values
pub fn union_def_to_swift(union: &UnionDef, ctx: &GenerationContext) -> UnionSwift {
    let non_null_variants: Vec<_> = union
        .variants
        .iter()
        .filter(|v| !matches!(v, FieldType::Null))
        .collect();

    let swift_variants: Vec<UnionVariantSwift> = non_null_variants
        .iter()
        .map(|v| {
            let variant_type = field_type_to_swift(v, ctx);
            let variant_name = variant_case_name(&variant_type);

            UnionVariantSwift {
                name: variant_name,
                variant_type,
                docstring: None,
            }
        })
        .collect();

    UnionSwift {
        baml_name: union.name.clone(),
        name: union.name.clone(),
        docstring: union.docstring.clone(),
        variants: swift_variants,
    }
}

/// Generate a Swift case name from a type
fn variant_case_name(ty: &TypeSwift) -> String {
    let base_name = match ty {
        TypeSwift::String(_) => "string".to_string(),
        TypeSwift::Int(_) => "int".to_string(),
        TypeSwift::Float => "double".to_string(),
        TypeSwift::Bool(_) => "bool".to_string(),
        TypeSwift::Null => "null".to_string(),
        TypeSwift::Media(media) => match media {
            crate::r#type::MediaTypeSwift::Image => "image".to_string(),
            crate::r#type::MediaTypeSwift::Audio => "audio".to_string(),
            crate::r#type::MediaTypeSwift::File => "file".to_string(),
        },
        TypeSwift::Class { name, .. } => to_swift_case_name(name),
        TypeSwift::Enum { name, .. } => to_swift_case_name(name),
        TypeSwift::Union { name, .. } => to_swift_case_name(name),
        TypeSwift::TypeAlias { name, .. } => to_swift_case_name(name),
        TypeSwift::List(inner) => format!("{}Array", variant_case_name(inner)),
        TypeSwift::Map(_, value) => format!("{}Map", variant_case_name(value)),
        TypeSwift::Optional(inner) => format!("optional{}", capitalize(&variant_case_name(inner))),
        TypeSwift::Checked { inner, .. } => variant_case_name(inner),
        TypeSwift::StreamState(inner) => variant_case_name(inner),
        TypeSwift::Any { .. } => "value".to_string(),
    };

    to_swift_case_name(&base_name)
}

/// Capitalize the first character of a string
fn capitalize(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
    }
}

/// Collect all unions that need to be generated from a field type
pub fn collect_unions_from_field_type(
    field_type: &FieldType,
    ctx: &GenerationContext,
    unions: &mut Vec<UnionDef>,
) {
    match field_type {
        FieldType::Union(variants) => {
            let non_null_variants: Vec<_> = variants
                .iter()
                .filter(|v| !matches!(v, FieldType::Null))
                .collect();

            // Only generate union types for unions with multiple non-null variants
            if non_null_variants.len() > 1 {
                let types: Vec<TypeSwift> = non_null_variants
                    .iter()
                    .map(|v| field_type_to_swift(v, ctx))
                    .collect();
                let name = super::generate_union_name(&types);

                // Check if we already have this union
                if !unions.iter().any(|u| u.name == name) {
                    unions.push(UnionDef {
                        name,
                        docstring: None,
                        variants: non_null_variants.into_iter().cloned().collect(),
                    });
                }
            }

            // Recurse into variants
            for v in variants {
                collect_unions_from_field_type(v, ctx, unions);
            }
        }
        FieldType::List(inner) => {
            collect_unions_from_field_type(inner, ctx, unions);
        }
        FieldType::Map(key, value) => {
            collect_unions_from_field_type(key, ctx, unions);
            collect_unions_from_field_type(value, ctx, unions);
        }
        FieldType::Optional(inner) => {
            collect_unions_from_field_type(inner, ctx, unions);
        }
        // Other types don't contain unions
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::package::GeneratorConfig;

    fn test_ctx() -> GenerationContext {
        GenerationContext::new(GeneratorConfig::default())
    }

    #[test]
    fn test_variant_case_name() {
        assert_eq!(variant_case_name(&TypeSwift::string()), "string");
        assert_eq!(variant_case_name(&TypeSwift::int()), "int");
        assert_eq!(variant_case_name(&TypeSwift::class("User")), "user");
        assert_eq!(variant_case_name(&TypeSwift::enum_ref("Status")), "status");
    }

    #[test]
    fn test_variant_case_name_list() {
        let list_type = TypeSwift::list(TypeSwift::class("User"));
        assert_eq!(variant_case_name(&list_type), "userArray");
    }

    #[test]
    fn test_union_conversion() {
        let ctx = test_ctx();
        let union = UnionDef {
            name: "UserOrAdmin".to_string(),
            docstring: None,
            variants: vec![FieldType::Class("User".to_string()), FieldType::Class("Admin".to_string())],
        };

        let swift_union = union_def_to_swift(&union, &ctx);
        assert_eq!(swift_union.name, "UserOrAdmin");
        assert_eq!(swift_union.variants.len(), 2);
        assert_eq!(swift_union.variants[0].name, "user");
        assert_eq!(swift_union.variants[1].name, "admin");
    }

    #[test]
    fn test_collect_unions() {
        let ctx = test_ctx();
        let mut unions = Vec::new();

        let union_type = FieldType::union(vec![
            FieldType::Class("User".to_string()),
            FieldType::Class("Admin".to_string()),
        ]);

        collect_unions_from_field_type(&union_type, &ctx, &mut unions);
        assert_eq!(unions.len(), 1);
        assert_eq!(unions[0].name, "UserOrAdminUnion");
    }
}
