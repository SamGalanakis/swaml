//! Function generation utilities
//!
//! This module handles the generation of Swift function signatures and implementations.

use crate::{BamlFunction, BamlParam, BamlType};
use crate::swift_types::{baml_type_to_swift, snake_to_camel, to_swift_identifier};

/// Generate a Swift function signature
pub fn generate_function_signature(func: &BamlFunction) -> String {
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
fn generate_param_signature(param: &BamlParam) -> String {
    let swift_name = to_swift_identifier(&param.name);
    let swift_type = baml_type_to_swift(&param.param_type);

    if let Some(default) = &param.default_value {
        format!("{}: {} = {}", swift_name, swift_type, default)
    } else {
        format!("{}: {}", swift_name, swift_type)
    }
}

/// Generate the args dictionary construction
pub fn generate_args_dict(func: &BamlFunction) -> String {
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
fn param_to_baml_value(var_name: &str, ty: &BamlType) -> String {
    match ty {
        BamlType::String => format!(".string({})", var_name),
        BamlType::Int => format!(".int({})", var_name),
        BamlType::Float => format!(".float({})", var_name),
        BamlType::Bool => format!(".bool({})", var_name),
        BamlType::Optional(inner) => {
            let inner_expr = param_to_baml_value("$0", inner);
            format!(
                "{}.map {{ {} }} ?? .null",
                var_name, inner_expr
            )
        }
        BamlType::List(inner) => {
            let inner_expr = param_to_baml_value("$0", inner);
            format!(".array({}.map {{ {} }})", var_name, inner_expr)
        }
        BamlType::Map(_, value) => {
            let value_expr = param_to_baml_value("$0", value);
            format!(
                ".map({}.mapValues {{ {} }})",
                var_name, value_expr
            )
        }
        BamlType::Named(_) => {
            // For custom types, encode to JSON then to BamlValue
            format!(
                "try BamlValue.fromJSON(JSONEncoder().encode({}))",
                var_name
            )
        }
    }
}

/// Generate prompt template rendering code
pub fn generate_prompt_rendering(func: &BamlFunction) -> String {
    // This is a simplified version - real implementation would use
    // BAML's prompt template syntax
    let mut template = func.prompt_template.clone();

    for param in &func.params {
        let placeholder = format!("{{{{ {} }}}}", param.name);
        let swift_var = to_swift_identifier(&param.name);
        template = template.replace(
            &placeholder,
            &format!("\\({})", swift_var),
        );
    }

    format!("let prompt = \"\"\"\\n{}\\n\"\"\"", template)
}

/// Generate the full function implementation
pub fn generate_function_impl(func: &BamlFunction) -> String {
    let signature = generate_function_signature(func);
    let return_type = baml_type_to_swift(&func.return_type);

    let mut lines = Vec::new();

    // Doc comment
    if let Some(doc) = &func.doc {
        lines.push(format!("    /// {}", doc));
    }

    lines.push(format!("    {}", signature));
    lines.push("    {".to_string());

    // Generate args dictionary
    lines.push(format!("        {}", generate_args_dict(func)));
    lines.push("".to_string());

    // Generate prompt (simplified - real impl would use template engine)
    lines.push("        // Render prompt template".to_string());
    lines.push(format!("        {}", generate_prompt_rendering(func)));
    lines.push("".to_string());

    // Call runtime
    lines.push("        let result = try await runtime.callFunction(".to_string());
    lines.push(format!("            \"{}\",", func.name));
    lines.push("            args: args,".to_string());
    lines.push("            prompt: prompt,".to_string());
    lines.push(format!("            outputType: {}.self,", return_type));
    lines.push("            ctx: RuntimeContext()".to_string());
    lines.push("        )".to_string());
    lines.push("".to_string());
    lines.push("        return result".to_string());
    lines.push("    }".to_string());

    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_param_signature() {
        let param = BamlParam {
            name: "user_name".to_string(),
            param_type: BamlType::String,
            default_value: None,
        };
        assert_eq!(generate_param_signature(&param), "userName: String");

        let param_with_default = BamlParam {
            name: "n_roasts".to_string(),
            param_type: BamlType::Int,
            default_value: Some("5".to_string()),
        };
        assert_eq!(
            generate_param_signature(&param_with_default),
            "nRoasts: Int = 5"
        );
    }

    #[test]
    fn test_param_to_baml_value() {
        assert_eq!(param_to_baml_value("name", &BamlType::String), ".string(name)");
        assert_eq!(param_to_baml_value("count", &BamlType::Int), ".int(count)");
        assert_eq!(param_to_baml_value("score", &BamlType::Float), ".float(score)");
        assert_eq!(param_to_baml_value("active", &BamlType::Bool), ".bool(active)");
    }
}
