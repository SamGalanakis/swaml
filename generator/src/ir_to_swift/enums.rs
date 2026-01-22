//! Enum to Swift enum conversion
//!
//! This module handles converting enum definitions to Swift enums.

use crate::generated_types::{EnumSwift, EnumValueSwift};
use crate::package::GenerationContext;
use crate::utils::to_swift_case_name;

/// Simplified enum definition for the generator
#[derive(Debug, Clone)]
pub struct EnumDef {
    /// The enum name
    pub name: String,
    /// Optional documentation
    pub docstring: Option<String>,
    /// Enum values
    pub values: Vec<EnumValueDef>,
    /// Whether this is a dynamic enum
    pub dynamic: bool,
}

/// Simplified enum value definition
#[derive(Debug, Clone)]
pub struct EnumValueDef {
    /// The value name (BAML style)
    pub name: String,
    /// Optional alias for serialization
    pub alias: Option<String>,
    /// Optional documentation
    pub docstring: Option<String>,
}

/// Convert an enum definition to a Swift enum representation
pub fn enum_def_to_swift(enum_def: &EnumDef, _ctx: &GenerationContext) -> EnumSwift {
    let values = enum_def
        .values
        .iter()
        .map(|value| {
            let swift_name = to_swift_case_name(&value.name);

            EnumValueSwift {
                baml_name: value.name.clone(),
                name: swift_name,
                alias: value.alias.clone(),
                docstring: value.docstring.clone(),
            }
        })
        .collect();

    EnumSwift {
        baml_name: enum_def.name.clone(),
        name: enum_def.name.clone(),
        docstring: enum_def.docstring.clone(),
        values,
        dynamic: enum_def.dynamic,
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
    fn test_enum_conversion() {
        let ctx = test_ctx();
        let enum_def = EnumDef {
            name: "Sentiment".to_string(),
            docstring: Some("User sentiment".to_string()),
            values: vec![
                EnumValueDef {
                    name: "HAPPY".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "SAD".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "VERY_HAPPY".to_string(),
                    alias: Some("Very Happy".to_string()),
                    docstring: None,
                },
            ],
            dynamic: false,
        };

        let swift_enum = enum_def_to_swift(&enum_def, &ctx);
        assert_eq!(swift_enum.name, "Sentiment");
        assert_eq!(swift_enum.values.len(), 3);
        assert_eq!(swift_enum.values[0].name, "happy");
        assert_eq!(swift_enum.values[2].name, "veryHappy");
        assert_eq!(swift_enum.values[2].raw_value(), "Very Happy");
    }

    #[test]
    fn test_enum_needs_raw_values() {
        let ctx = test_ctx();
        let enum_def = EnumDef {
            name: "Status".to_string(),
            docstring: None,
            values: vec![
                EnumValueDef {
                    name: "ACTIVE".to_string(),
                    alias: None,
                    docstring: None,
                },
            ],
            dynamic: false,
        };

        let swift_enum = enum_def_to_swift(&enum_def, &ctx);
        // "active" != "ACTIVE", so needs raw value
        assert!(swift_enum.needs_raw_values());
    }
}
