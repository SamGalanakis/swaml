//! Swift code generator for BAML
//!
//! This crate generates Swift code from BAML intermediate representation (IR).
//! The generated code depends on the SWAML runtime package.

mod swift_types;
mod functions;

use anyhow::Result;
use askama::Template;
use indexmap::IndexMap;
use std::collections::HashSet;

pub use swift_types::*;
pub use functions::*;

/// Configuration for the Swift generator
#[derive(Debug, Clone)]
pub struct SwiftGeneratorConfig {
    /// Output directory for generated files
    pub output_dir: String,
    /// Package name for the generated code
    pub package_name: String,
    /// Whether to generate async/await code (always true for Swift)
    pub async_mode: bool,
}

impl Default for SwiftGeneratorConfig {
    fn default() -> Self {
        Self {
            output_dir: "baml_client".to_string(),
            package_name: "BamlClient".to_string(),
            async_mode: true,
        }
    }
}

/// Represents a generated file
#[derive(Debug, Clone)]
pub struct GeneratedFile {
    pub path: String,
    pub content: String,
}

/// Main entry point for Swift code generation
pub struct SwiftGenerator {
    config: SwiftGeneratorConfig,
}

impl SwiftGenerator {
    pub fn new(config: SwiftGeneratorConfig) -> Self {
        Self { config }
    }

    /// Generate all Swift files from IR
    ///
    /// In the actual BAML integration, this would take IntermediateRepr
    /// For now, we define our own simplified IR types
    pub fn generate(&self, ir: &BamlIR) -> Result<Vec<GeneratedFile>> {
        let mut files = Vec::new();

        // Generate Types.swift
        let types_content = self.generate_types(ir)?;
        files.push(GeneratedFile {
            path: format!("{}/Types.swift", self.config.output_dir),
            content: types_content,
        });

        // Generate BamlClient.swift
        let client_content = self.generate_client(ir)?;
        files.push(GeneratedFile {
            path: format!("{}/BamlClient.swift", self.config.output_dir),
            content: client_content,
        });

        // Generate Globals.swift
        let globals_content = self.generate_globals(ir)?;
        files.push(GeneratedFile {
            path: format!("{}/Globals.swift", self.config.output_dir),
            content: globals_content,
        });

        Ok(files)
    }

    fn generate_types(&self, ir: &BamlIR) -> Result<String> {
        let template = TypesTemplate {
            enums: &ir.enums,
            classes: &ir.classes,
        };
        Ok(template.render()?)
    }

    fn generate_client(&self, ir: &BamlIR) -> Result<String> {
        let template = ClientTemplate {
            functions: &ir.functions,
        };
        Ok(template.render()?)
    }

    fn generate_globals(&self, ir: &BamlIR) -> Result<String> {
        let template = GlobalsTemplate {
            client_configs: &ir.clients,
        };
        Ok(template.render()?)
    }
}

/// Simplified BAML IR for the generator
/// In actual BAML integration, this would use internal-baml-core types
#[derive(Debug, Clone, Default)]
pub struct BamlIR {
    pub enums: Vec<BamlEnum>,
    pub classes: Vec<BamlClass>,
    pub functions: Vec<BamlFunction>,
    pub clients: Vec<BamlClientConfig>,
}

#[derive(Debug, Clone)]
pub struct BamlEnum {
    pub name: String,
    pub values: Vec<BamlEnumValue>,
    pub doc: Option<String>,
}

#[derive(Debug, Clone)]
pub struct BamlEnumValue {
    pub name: String,
    pub alias: Option<String>,
    pub doc: Option<String>,
}

#[derive(Debug, Clone)]
pub struct BamlClass {
    pub name: String,
    pub fields: Vec<BamlField>,
    pub doc: Option<String>,
}

#[derive(Debug, Clone)]
pub struct BamlField {
    pub name: String,
    pub field_type: BamlType,
    pub doc: Option<String>,
}

#[derive(Debug, Clone)]
pub enum BamlType {
    String,
    Int,
    Float,
    Bool,
    Optional(Box<BamlType>),
    List(Box<BamlType>),
    Map(Box<BamlType>, Box<BamlType>),
    Named(String), // Reference to enum or class
}

#[derive(Debug, Clone)]
pub struct BamlFunction {
    pub name: String,
    pub params: Vec<BamlParam>,
    pub return_type: BamlType,
    pub doc: Option<String>,
    pub client: String,
    pub prompt_template: String,
}

#[derive(Debug, Clone)]
pub struct BamlParam {
    pub name: String,
    pub param_type: BamlType,
    pub default_value: Option<String>,
}

#[derive(Debug, Clone)]
pub struct BamlClientConfig {
    pub name: String,
    pub provider: String,
    pub model: String,
    pub options: IndexMap<String, String>,
}

// Askama templates

#[derive(Template)]
#[template(path = "types.swift.j2", escape = "none")]
struct TypesTemplate<'a> {
    enums: &'a [BamlEnum],
    classes: &'a [BamlClass],
}

#[derive(Template)]
#[template(path = "client.swift.j2", escape = "none")]
struct ClientTemplate<'a> {
    functions: &'a [BamlFunction],
}

#[derive(Template)]
#[template(path = "globals.swift.j2", escape = "none")]
struct GlobalsTemplate<'a> {
    client_configs: &'a [BamlClientConfig],
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_type_conversion() {
        assert_eq!(baml_type_to_swift(&BamlType::String), "String");
        assert_eq!(baml_type_to_swift(&BamlType::Int), "Int");
        assert_eq!(baml_type_to_swift(&BamlType::Float), "Double");
        assert_eq!(baml_type_to_swift(&BamlType::Bool), "Bool");
        assert_eq!(
            baml_type_to_swift(&BamlType::Optional(Box::new(BamlType::String))),
            "String?"
        );
        assert_eq!(
            baml_type_to_swift(&BamlType::List(Box::new(BamlType::Int))),
            "[Int]"
        );
    }

    #[test]
    fn test_snake_to_camel() {
        assert_eq!(snake_to_camel("hello_world"), "helloWorld");
        assert_eq!(snake_to_camel("user_name"), "userName");
        assert_eq!(snake_to_camel("already"), "already");
    }
}
