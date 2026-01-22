//! Package and module context for Swift code generation
//!
//! This module manages the context needed during code generation,
//! including module tracking and IR lookups.

use std::sync::{Arc, Mutex};

use crate::r#type::SwiftModule;

/// Represents the current rendering context for Swift code generation
///
/// This struct is passed to templates and conversion functions to provide
/// access to type information and track the current module being generated.
#[derive(Clone)]
pub struct GenerationContext {
    /// The current module being rendered
    current_module: Arc<Mutex<SwiftModule>>,
    /// Known class names
    classes: Arc<Vec<String>>,
    /// Known enum names
    enums: Arc<Vec<String>>,
    /// Known type alias names
    type_aliases: Arc<Vec<String>>,
    /// Configuration for the generator
    config: GeneratorConfig,
}

impl GenerationContext {
    /// Create a new generation context
    pub fn new(config: GeneratorConfig) -> Self {
        Self {
            current_module: Arc::new(Mutex::new(SwiftModule::baml_client())),
            classes: Arc::new(Vec::new()),
            enums: Arc::new(Vec::new()),
            type_aliases: Arc::new(Vec::new()),
            config,
        }
    }

    /// Create a context with known types
    pub fn with_types(
        config: GeneratorConfig,
        classes: Vec<String>,
        enums: Vec<String>,
        type_aliases: Vec<String>,
    ) -> Self {
        Self {
            current_module: Arc::new(Mutex::new(SwiftModule::baml_client())),
            classes: Arc::new(classes),
            enums: Arc::new(enums),
            type_aliases: Arc::new(type_aliases),
            config,
        }
    }

    /// Get the current module
    pub fn current_module(&self) -> SwiftModule {
        self.current_module.lock().unwrap().clone()
    }

    /// Set the current module
    pub fn set_module(&self, module: SwiftModule) {
        *self.current_module.lock().unwrap() = module;
    }

    /// Get the generator configuration
    pub fn config(&self) -> &GeneratorConfig {
        &self.config
    }

    /// Check if a type name is a class
    pub fn is_class(&self, name: &str) -> bool {
        self.classes.iter().any(|c| c == name)
    }

    /// Check if a type name is an enum
    pub fn is_enum(&self, name: &str) -> bool {
        self.enums.iter().any(|e| e == name)
    }

    /// Check if a type name is a type alias
    pub fn is_type_alias(&self, name: &str) -> bool {
        self.type_aliases.iter().any(|t| t == name)
    }
}

/// Configuration for the Swift generator
#[derive(Debug, Clone)]
pub struct GeneratorConfig {
    /// Output directory for generated files
    pub output_dir: String,
    /// Package/module name for the generated code
    pub package_name: String,
    /// Whether to generate streaming support
    pub generate_streaming: bool,
    /// Whether to generate sync wrappers
    pub generate_sync: bool,
}

impl Default for GeneratorConfig {
    fn default() -> Self {
        Self {
            output_dir: "baml_client".to_string(),
            package_name: "BamlClient".to_string(),
            generate_streaming: true,
            generate_sync: true,
        }
    }
}

impl GeneratorConfig {
    /// Create a new configuration with a custom output directory
    pub fn with_output_dir(mut self, dir: impl Into<String>) -> Self {
        self.output_dir = dir.into();
        self
    }

    /// Create a new configuration with a custom package name
    pub fn with_package_name(mut self, name: impl Into<String>) -> Self {
        self.package_name = name.into();
        self
    }

    /// Enable or disable streaming support generation
    pub fn with_streaming(mut self, enabled: bool) -> Self {
        self.generate_streaming = enabled;
        self
    }

    /// Enable or disable sync wrapper generation
    pub fn with_sync(mut self, enabled: bool) -> Self {
        self.generate_sync = enabled;
        self
    }
}

/// File collector for generated files
///
/// This collects all generated files during code generation
/// for writing to disk or further processing.
#[derive(Debug, Default)]
pub struct FileCollector {
    files: indexmap::IndexMap<String, String>,
}

impl FileCollector {
    /// Create a new file collector
    pub fn new() -> Self {
        Self::default()
    }

    /// Add a file to the collector
    pub fn add_file(&mut self, path: impl Into<String>, content: impl Into<String>) {
        self.files.insert(path.into(), content.into());
    }

    /// Get all collected files
    pub fn files(&self) -> &indexmap::IndexMap<String, String> {
        &self.files
    }

    /// Take ownership of collected files
    pub fn into_files(self) -> indexmap::IndexMap<String, String> {
        self.files
    }

    /// Get the number of files collected
    pub fn len(&self) -> usize {
        self.files.len()
    }

    /// Check if no files have been collected
    pub fn is_empty(&self) -> bool {
        self.files.is_empty()
    }

    /// Get content of a specific file
    pub fn get(&self, path: &str) -> Option<&String> {
        self.files.get(path)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generator_config_defaults() {
        let config = GeneratorConfig::default();
        assert_eq!(config.output_dir, "baml_client");
        assert_eq!(config.package_name, "BamlClient");
        assert!(config.generate_streaming);
        assert!(config.generate_sync);
    }

    #[test]
    fn test_generator_config_builder() {
        let config = GeneratorConfig::default()
            .with_output_dir("custom_output")
            .with_package_name("CustomClient")
            .with_streaming(false)
            .with_sync(false);

        assert_eq!(config.output_dir, "custom_output");
        assert_eq!(config.package_name, "CustomClient");
        assert!(!config.generate_streaming);
        assert!(!config.generate_sync);
    }

    #[test]
    fn test_file_collector() {
        let mut collector = FileCollector::new();
        assert!(collector.is_empty());

        collector.add_file("Types.swift", "// types");
        collector.add_file("Client.swift", "// client");

        assert_eq!(collector.len(), 2);
        assert_eq!(collector.get("Types.swift"), Some(&"// types".to_string()));
    }

    #[test]
    fn test_generation_context_types() {
        let ctx = GenerationContext::with_types(
            GeneratorConfig::default(),
            vec!["User".to_string(), "Post".to_string()],
            vec!["Status".to_string()],
            vec!["UserId".to_string()],
        );

        assert!(ctx.is_class("User"));
        assert!(ctx.is_class("Post"));
        assert!(!ctx.is_class("Status"));

        assert!(ctx.is_enum("Status"));
        assert!(!ctx.is_enum("User"));

        assert!(ctx.is_type_alias("UserId"));
        assert!(!ctx.is_type_alias("User"));
    }
}
