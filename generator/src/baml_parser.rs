//! BAML parser integration module
//!
//! This module provides functions to parse BAML source files and convert
//! them to the simplified BamlIR format used by the Swift code generator.
//!
//! # Feature
//!
//! This module is only available when the `baml-ir` feature is enabled.

use std::path::Path;

use anyhow::{Context, Result};
use baml_types::{LiteralValue, TypeValue};
use internal_baml_core::ir::repr::{
    make_test_ir, make_test_ir_from_dir, Class, Enum, Field, Function, IntermediateRepr, Node,
    TypeAlias,
};

use crate::ir_to_swift::classes::{ClassDef, FieldDef};
use crate::ir_to_swift::enums::{EnumDef, EnumValueDef};
use crate::ir_to_swift::functions::{FunctionDef, ParamDef};
use crate::ir_to_swift::type_aliases::TypeAliasDef;
use crate::ir_to_swift::FieldType;
use crate::ClientConfigSwift;
use crate::BamlIR;

/// Parse a directory of .baml files into BamlIR
///
/// This function reads all .baml files in the specified directory,
/// parses them using the internal BAML parser, and converts the
/// intermediate representation to the simplified BamlIR format.
///
/// # Arguments
///
/// * `dir` - Path to the directory containing .baml files
///
/// # Returns
///
/// Returns a `BamlIR` struct containing all parsed definitions.
///
/// # Errors
///
/// Returns an error if:
/// - The directory cannot be read
/// - Any .baml file contains syntax errors
/// - Type conversion fails
pub fn parse_baml_dir(dir: &Path) -> Result<BamlIR> {
    let ir = make_test_ir_from_dir(&dir.to_path_buf())
        .with_context(|| format!("Failed to parse BAML files in directory: {}", dir.display()))?;
    convert_ir(&ir)
}

/// Parse BAML source code string into BamlIR
///
/// This function parses a single BAML source code string and converts
/// the intermediate representation to the simplified BamlIR format.
///
/// # Arguments
///
/// * `source` - BAML source code as a string
///
/// # Returns
///
/// Returns a `BamlIR` struct containing all parsed definitions.
///
/// # Errors
///
/// Returns an error if:
/// - The source code contains syntax errors
/// - Type conversion fails
pub fn parse_baml_string(source: &str) -> Result<BamlIR> {
    let ir = make_test_ir(source).with_context(|| "Failed to parse BAML source string")?;
    convert_ir(&ir)
}

/// Convert BAML's IntermediateRepr to our simplified BamlIR
fn convert_ir(ir: &IntermediateRepr) -> Result<BamlIR> {
    Ok(BamlIR {
        enums: ir
            .enums
            .iter()
            .map(convert_enum)
            .collect::<Result<Vec<_>>>()?,
        classes: ir
            .classes
            .iter()
            .map(convert_class)
            .collect::<Result<Vec<_>>>()?,
        functions: ir
            .functions
            .iter()
            .map(convert_function)
            .collect::<Result<Vec<_>>>()?,
        type_aliases: ir
            .type_aliases
            .iter()
            .map(convert_type_alias)
            .collect::<Result<Vec<_>>>()?,
        clients: ir
            .clients
            .iter()
            .map(convert_client)
            .collect::<Result<Vec<_>>>()?,
    })
}

/// Convert a BAML Enum to our EnumDef
fn convert_enum(node: &Node<Enum>) -> Result<EnumDef> {
    let baml_enum = &node.elem;

    let values = baml_enum
        .values
        .iter()
        .map(|(value_node, docstring)| {
            // Try to get alias from attributes - convert to string representation
            let alias = value_node.attributes.alias().map(|s| format!("{:?}", s));
            EnumValueDef {
                name: value_node.elem.0.clone(),
                alias,
                docstring: docstring.as_ref().map(|d| d.0.clone()),
            }
        })
        .collect();

    Ok(EnumDef {
        name: baml_enum.name.clone(),
        docstring: baml_enum.docstring.as_ref().map(|d| d.0.clone()),
        values,
        dynamic: node.attributes.dynamic(),
    })
}

/// Convert a BAML Class to our ClassDef
fn convert_class(node: &Node<Class>) -> Result<ClassDef> {
    let baml_class = &node.elem;

    let fields = baml_class
        .static_fields
        .iter()
        .map(convert_field)
        .collect::<Result<Vec<_>>>()?;

    Ok(ClassDef {
        name: baml_class.name.clone(),
        docstring: baml_class.docstring.as_ref().map(|d| d.0.clone()),
        fields,
        has_dynamic_fields: node.attributes.dynamic(),
    })
}

/// Convert a BAML Field to our FieldDef
fn convert_field(node: &Node<Field>) -> Result<FieldDef> {
    let field = &node.elem;

    Ok(FieldDef {
        name: field.name.clone(),
        field_type: convert_type(&field.r#type.elem)?,
        docstring: field.docstring.as_ref().map(|d| d.0.clone()),
    })
}

/// Convert a BAML Function to our FunctionDef
fn convert_function(node: &Node<Function>) -> Result<FunctionDef> {
    let func = &node.elem;

    let params = func
        .inputs
        .iter()
        .map(|(name, ty)| {
            Ok(ParamDef {
                name: name.clone(),
                param_type: convert_type(ty)?,
                docstring: None,
            })
        })
        .collect::<Result<Vec<_>>>()?;

    // Get the default client name from configs
    let default_client = func.default_config().map(|config| {
        // ClientSpec to string
        format!("{:?}", config.client)
    });

    Ok(FunctionDef {
        name: func.name.clone(),
        docstring: None, // Functions don't have direct docstrings in the IR
        params,
        return_type: convert_type(&func.output)?,
        default_client,
    })
}

/// Convert a BAML TypeAlias to our TypeAliasDef
fn convert_type_alias(node: &Node<TypeAlias>) -> Result<TypeAliasDef> {
    let alias = &node.elem;

    Ok(TypeAliasDef {
        name: alias.name.clone(),
        target_type: convert_type(&alias.r#type.elem)?,
        docstring: alias.docstring.as_ref().map(|d| d.0.clone()),
    })
}

/// Convert a BAML Client to our ClientConfigSwift
fn convert_client(
    node: &Node<internal_baml_core::ir::repr::Client>,
) -> Result<ClientConfigSwift> {
    let client = &node.elem;

    Ok(ClientConfigSwift {
        name: client.name.clone(),
        provider: format!("{:?}", client.provider),
        model: String::new(), // Model is configured elsewhere in BAML
        options: indexmap::IndexMap::new(),
    })
}

/// Convert BAML TypeIR to our simplified FieldType
fn convert_type(ty: &baml_types::TypeIR) -> Result<FieldType> {
    use baml_types::ir_type::TypeGeneric;

    match ty {
        TypeGeneric::Primitive(type_value, _) => convert_primitive(type_value),
        TypeGeneric::Enum { name, .. } => Ok(FieldType::Enum(name.clone())),
        TypeGeneric::Class { name, .. } => Ok(FieldType::Class(name.clone())),
        TypeGeneric::List(inner, _) => Ok(FieldType::List(Box::new(convert_type(inner)?))),
        TypeGeneric::Map(key, value, _) => Ok(FieldType::Map(
            Box::new(convert_type(key)?),
            Box::new(convert_type(value)?),
        )),
        TypeGeneric::Union(union_type, _) => {
            // Get all non-null variants using iter_skip_null
            let non_null_variants = union_type.iter_skip_null();

            // Check if optional by checking for null in the union
            let is_optional = union_type.is_optional();

            let variants: Vec<FieldType> = non_null_variants
                .iter()
                .map(|t| convert_type(t))
                .collect::<Result<Vec<_>>>()?;

            if variants.len() == 1 && is_optional {
                // Single type + null = Optional
                Ok(FieldType::Optional(Box::new(
                    variants.into_iter().next().unwrap(),
                )))
            } else if variants.is_empty() && is_optional {
                // Just null
                Ok(FieldType::Null)
            } else if is_optional {
                // Multiple types + null = Optional(Union)
                Ok(FieldType::Optional(Box::new(FieldType::Union(variants))))
            } else {
                // Multiple types, no null = Union
                Ok(FieldType::Union(variants))
            }
        }
        TypeGeneric::RecursiveTypeAlias { name, .. } => Ok(FieldType::TypeAlias(name.clone())),
        TypeGeneric::Literal(lit_value, _) => convert_literal(lit_value),
        TypeGeneric::Tuple(types, _) => {
            // Tuples are treated as lists for now
            // TODO: Add proper tuple support if needed
            let inner_types: Vec<FieldType> = types
                .iter()
                .map(|t| convert_type(t))
                .collect::<Result<Vec<_>>>()?;
            if inner_types.len() == 1 {
                Ok(inner_types.into_iter().next().unwrap())
            } else {
                Ok(FieldType::Union(inner_types))
            }
        }
        TypeGeneric::Arrow(_, _) => {
            // Arrow types (functions) are not supported in Swift codegen
            anyhow::bail!("Arrow types are not supported in Swift code generation")
        }
        TypeGeneric::Top(_) => {
            // Top type represents "any" - map to a union of common types or String
            Ok(FieldType::String)
        }
    }
}

/// Convert BAML primitive TypeValue to FieldType
fn convert_primitive(type_value: &TypeValue) -> Result<FieldType> {
    match type_value {
        TypeValue::String => Ok(FieldType::String),
        TypeValue::Int => Ok(FieldType::Int),
        TypeValue::Float => Ok(FieldType::Float),
        TypeValue::Bool => Ok(FieldType::Bool),
        TypeValue::Null => Ok(FieldType::Null),
        TypeValue::Media(media_type) => {
            // Media types map to our supported media FieldTypes
            // The MediaType enum has Image, Audio, File variants
            let type_str = format!("{:?}", media_type);
            match type_str.as_str() {
                s if s.contains("Image") => Ok(FieldType::Image),
                s if s.contains("Audio") => Ok(FieldType::Audio),
                _ => Ok(FieldType::File),
            }
        }
    }
}

/// Convert BAML LiteralValue to FieldType
fn convert_literal(lit_value: &LiteralValue) -> Result<FieldType> {
    match lit_value {
        LiteralValue::String(s) => Ok(FieldType::LiteralString(s.clone())),
        LiteralValue::Int(i) => Ok(FieldType::LiteralInt(*i)),
        LiteralValue::Bool(b) => Ok(FieldType::LiteralBool(*b)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_enum() {
        let source = r#"
enum Sentiment {
    HAPPY
    SAD
    NEUTRAL
}
"#;

        let ir = parse_baml_string(source).unwrap();
        assert_eq!(ir.enums.len(), 1);
        assert_eq!(ir.enums[0].name, "Sentiment");
        assert_eq!(ir.enums[0].values.len(), 3);
        assert_eq!(ir.enums[0].values[0].name, "HAPPY");
    }

    #[test]
    fn test_parse_simple_class() {
        let source = r#"
class User {
    name string
    age int
    email string?
}
"#;

        let ir = parse_baml_string(source).unwrap();
        assert_eq!(ir.classes.len(), 1);
        assert_eq!(ir.classes[0].name, "User");
        assert_eq!(ir.classes[0].fields.len(), 3);
        assert_eq!(ir.classes[0].fields[0].name, "name");
        assert!(matches!(
            ir.classes[0].fields[0].field_type,
            FieldType::String
        ));
        assert!(matches!(
            ir.classes[0].fields[2].field_type,
            FieldType::Optional(_)
        ));
    }

    #[test]
    fn test_parse_function() {
        let source = r##"
enum Sentiment {
    HAPPY
    SAD
}

function ClassifySentiment(text: string) -> Sentiment {
    client GPT4
    prompt #"
        Classify the sentiment of: {{ text }}
    "#
}

client<llm> GPT4 {
    provider openai
    options {
        model gpt-4
    }
}
"##;

        let ir = parse_baml_string(source).unwrap();
        assert_eq!(ir.functions.len(), 1);
        assert_eq!(ir.functions[0].name, "ClassifySentiment");
        assert_eq!(ir.functions[0].params.len(), 1);
        assert_eq!(ir.functions[0].params[0].name, "text");
        assert!(matches!(
            ir.functions[0].return_type,
            FieldType::Enum(ref name) if name == "Sentiment"
        ));
    }

    #[test]
    fn test_parse_complex_types() {
        let source = r#"
class Container {
    items string[]
    metadata map<string, int>
    tags string[] | null
}
"#;

        let ir = parse_baml_string(source).unwrap();
        assert_eq!(ir.classes.len(), 1);

        // Check list type
        assert!(matches!(
            ir.classes[0].fields[0].field_type,
            FieldType::List(_)
        ));

        // Check map type
        assert!(matches!(
            ir.classes[0].fields[1].field_type,
            FieldType::Map(_, _)
        ));

        // Check optional type
        assert!(matches!(
            ir.classes[0].fields[2].field_type,
            FieldType::Optional(_)
        ));
    }
}
