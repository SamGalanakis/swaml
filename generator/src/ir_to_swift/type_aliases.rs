//! Type alias to Swift typealias conversion
//!
//! This module handles converting type alias definitions to Swift typealiases.

use crate::generated_types::TypeAliasSwift;
use crate::package::GenerationContext;

use super::{field_type_to_swift, FieldType};

/// Simplified type alias definition for the generator
#[derive(Debug, Clone)]
pub struct TypeAliasDef {
    /// The alias name
    pub name: String,
    /// Optional documentation
    pub docstring: Option<String>,
    /// The target type being aliased
    pub target_type: FieldType,
}

/// Convert a type alias definition to a Swift typealias representation
pub fn type_alias_def_to_swift(alias: &TypeAliasDef, ctx: &GenerationContext) -> TypeAliasSwift {
    let target_type = field_type_to_swift(&alias.target_type, ctx);

    TypeAliasSwift {
        baml_name: alias.name.clone(),
        name: alias.name.clone(),
        target_type,
        docstring: alias.docstring.clone(),
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
    fn test_type_alias_conversion() {
        let ctx = test_ctx();
        let alias = TypeAliasDef {
            name: "UserId".to_string(),
            docstring: Some("A unique user identifier".to_string()),
            target_type: FieldType::String,
        };

        let swift_alias = type_alias_def_to_swift(&alias, &ctx);
        assert_eq!(swift_alias.name, "UserId");
        assert_eq!(swift_alias.target_type_string(), "String");
    }

    #[test]
    fn test_complex_type_alias() {
        let ctx = test_ctx();
        let alias = TypeAliasDef {
            name: "UserMap".to_string(),
            docstring: None,
            target_type: FieldType::map(
                FieldType::String,
                FieldType::Class("User".to_string()),
            ),
        };

        let swift_alias = type_alias_def_to_swift(&alias, &ctx);
        assert_eq!(swift_alias.target_type_string(), "[String: User]");
    }
}
