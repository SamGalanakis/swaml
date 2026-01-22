//! Function to Swift function conversion
//!
//! This module handles converting function definitions to Swift function representations.

use crate::generated_types::{FunctionSwift, ParamSwift};
use crate::package::GenerationContext;
use crate::r#type::TypeSwift;
use crate::utils::to_swift_identifier;

use super::{field_type_to_swift, FieldType};

/// Simplified function definition for the generator
#[derive(Debug, Clone)]
pub struct FunctionDef {
    /// The function name
    pub name: String,
    /// Optional documentation
    pub docstring: Option<String>,
    /// Function parameters
    pub params: Vec<ParamDef>,
    /// Return type
    pub return_type: FieldType,
    /// Default client to use
    pub default_client: Option<String>,
    /// The prompt template
    pub prompt: Option<String>,
}

/// Simplified parameter definition
#[derive(Debug, Clone)]
pub struct ParamDef {
    /// The parameter name (BAML style)
    pub name: String,
    /// The parameter type
    pub param_type: FieldType,
    /// Optional documentation
    pub docstring: Option<String>,
}

/// Convert a function definition to a Swift function representation
pub fn function_def_to_swift(func: &FunctionDef, ctx: &GenerationContext) -> FunctionSwift {
    let swift_name = to_swift_identifier(&func.name);

    let params = func
        .params
        .iter()
        .map(|param| {
            let swift_param_name = to_swift_identifier(&param.name);
            let param_type = field_type_to_swift(&param.param_type, ctx);

            ParamSwift {
                baml_name: param.name.clone(),
                name: swift_param_name,
                param_type,
                default_value: None,
                docstring: param.docstring.clone(),
            }
        })
        .collect();

    let return_type = field_type_to_swift(&func.return_type, ctx);
    let stream_return_type = Some(streaming_return_type(&return_type));

    FunctionSwift {
        baml_name: func.name.clone(),
        name: swift_name,
        docstring: func.docstring.clone(),
        params,
        return_type,
        stream_return_type,
        client: func.default_client.clone(),
        prompt: func.prompt.clone(),
    }
}

/// Convert a return type to its streaming variant
fn streaming_return_type(ty: &TypeSwift) -> TypeSwift {
    match ty {
        TypeSwift::Class { name, module, dynamic } => TypeSwift::StreamState(Box::new(
            TypeSwift::Class {
                name: format!("{}Partial", name),
                module: module.clone(),
                dynamic: *dynamic,
            },
        )),
        TypeSwift::Enum { name, module, dynamic } => TypeSwift::StreamState(Box::new(
            TypeSwift::Enum {
                name: name.clone(),
                module: module.clone(),
                dynamic: *dynamic,
            },
        )),
        TypeSwift::List(inner) => TypeSwift::StreamState(Box::new(TypeSwift::List(Box::new(
            partial_type(inner),
        )))),
        // For primitives and other types, just wrap in StreamState
        other => TypeSwift::StreamState(Box::new(other.clone())),
    }
}

/// Convert a type to its partial variant (for streaming)
fn partial_type(ty: &TypeSwift) -> TypeSwift {
    match ty {
        TypeSwift::Class { name, module, dynamic } => TypeSwift::Class {
            name: format!("{}Partial", name),
            module: module.clone(),
            dynamic: *dynamic,
        },
        TypeSwift::List(inner) => TypeSwift::List(Box::new(partial_type(inner))),
        TypeSwift::Map(key, value) => {
            TypeSwift::Map(key.clone(), Box::new(partial_type(value)))
        }
        // Other types remain the same
        other => other.clone(),
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
    fn test_function_conversion() {
        let ctx = test_ctx();
        let func = FunctionDef {
            name: "classify_sentiment".to_string(),
            docstring: Some("Classify text sentiment".to_string()),
            params: vec![ParamDef {
                name: "user_input".to_string(),
                param_type: FieldType::String,
                docstring: None,
            }],
            return_type: FieldType::Enum("Sentiment".to_string()),
            default_client: Some("default".to_string()),
            prompt: Some("Classify the sentiment of: {{ user_input }}".to_string()),
        };

        let swift_func = function_def_to_swift(&func, &ctx);
        assert_eq!(swift_func.name, "classifySentiment");
        assert_eq!(swift_func.baml_name, "classify_sentiment");
        assert_eq!(swift_func.params.len(), 1);
        assert_eq!(swift_func.params[0].name, "userInput");
        assert_eq!(swift_func.return_type_string(), "Sentiment");
    }

    #[test]
    fn test_streaming_return_type_class() {
        let ty = TypeSwift::class("User");
        let stream_ty = streaming_return_type(&ty);
        assert_eq!(stream_ty.serialize(), "StreamState<UserPartial>");
    }

    #[test]
    fn test_streaming_return_type_enum() {
        let ty = TypeSwift::enum_ref("Sentiment");
        let stream_ty = streaming_return_type(&ty);
        assert_eq!(stream_ty.serialize(), "StreamState<Sentiment>");
    }

    #[test]
    fn test_streaming_return_type_list() {
        let ty = TypeSwift::list(TypeSwift::class("User"));
        let stream_ty = streaming_return_type(&ty);
        assert_eq!(stream_ty.serialize(), "StreamState<[UserPartial]>");
    }
}
