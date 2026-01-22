//! Function generation utilities (legacy module)
//!
//! This module is kept for backwards compatibility.
//! New code should use the `ir_to_swift::functions` module instead.

use crate::ir_to_swift::functions::{FunctionDef, ParamDef};
use crate::ir_to_swift::FieldType;
use crate::swift_types::{baml_type_to_swift, snake_to_camel};
use crate::utils::to_swift_identifier;

/// Generate a Swift function signature
pub fn generate_function_signature(func: &FunctionDef) -> String {
    let func_name = snake_to_camel(&func.name);
    let return_type = baml_type_to_swift(&func.return_type);

    let params: Vec<String> = func
        .params
        .iter()
        .map(|p| generate_param_signature(p))
        .collect();

    format!(
        "public func {}(\n        {}\n    ) async throws -> {}",
        func_name,
        params.join(",\n        "),
        return_type
    )
}

/// Generate a parameter signature
fn generate_param_signature(param: &ParamDef) -> String {
    let swift_name = to_swift_identifier(&param.name);
    let swift_type = baml_type_to_swift(&param.param_type);
    format!("{}: {}", swift_name, swift_type)
}

/// Generate the args dictionary construction
pub fn generate_args_dict(func: &FunctionDef) -> String {
    let mut lines = Vec::new();
    lines.push("let args: [String: BamlValue] = [".to_string());

    for (i, param) in func.params.iter().enumerate() {
        let swift_name = to_swift_identifier(&param.name);
        let value_expr = param_to_baml_value(&swift_name, &param.param_type);
        let comma = if i < func.params.len() - 1 { "," } else { "" };
        lines.push(format!(
            "            \"{}\": {}{}",
            param.name, value_expr, comma
        ));
    }

    lines.push("        ]".to_string());
    lines.join("\n")
}

/// Convert a Swift variable to BamlValue expression
fn param_to_baml_value(var_name: &str, ty: &FieldType) -> String {
    match ty {
        FieldType::String | FieldType::LiteralString(_) => format!(".string({})", var_name),
        FieldType::Int | FieldType::LiteralInt(_) => format!(".int({})", var_name),
        FieldType::Float => format!(".float({})", var_name),
        FieldType::Bool | FieldType::LiteralBool(_) => format!(".bool({})", var_name),
        FieldType::Optional(inner) => {
            let inner_expr = param_to_baml_value("$0", inner);
            format!("{}.map {{ {} }} ?? .null", var_name, inner_expr)
        }
        FieldType::List(inner) => {
            let inner_expr = param_to_baml_value("$0", inner);
            format!(".array({}.map {{ {} }})", var_name, inner_expr)
        }
        FieldType::Map(_, value) => {
            let value_expr = param_to_baml_value("$0", value);
            format!(".map({}.mapValues {{ {} }})", var_name, value_expr)
        }
        FieldType::Class(_) | FieldType::Enum(_) => {
            format!("try BamlValue.from({})", var_name)
        }
        _ => format!("try BamlValue.from({})", var_name),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_param_signature() {
        let param = ParamDef {
            name: "user_name".to_string(),
            param_type: FieldType::String,
            docstring: None,
        };
        assert_eq!(generate_param_signature(&param), "userName: String");
    }

    #[test]
    fn test_param_to_baml_value() {
        assert_eq!(param_to_baml_value("name", &FieldType::String), ".string(name)");
        assert_eq!(param_to_baml_value("count", &FieldType::Int), ".int(count)");
        assert_eq!(param_to_baml_value("score", &FieldType::Float), ".float(score)");
        assert_eq!(param_to_baml_value("active", &FieldType::Bool), ".bool(active)");
    }
}
