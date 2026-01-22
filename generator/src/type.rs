//! Swift type representation
//!
//! This module defines TypeSwift, which represents BAML types in their Swift form.

use std::fmt;

/// Represents the Swift module where a type is defined
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct SwiftModule {
    /// The module/package name (e.g., "BamlClient")
    pub name: String,
}

impl SwiftModule {
    pub fn new(name: impl Into<String>) -> Self {
        Self { name: name.into() }
    }

    /// The default module for generated types
    pub fn baml_client() -> Self {
        Self::new("BamlClient")
    }
}

impl Default for SwiftModule {
    fn default() -> Self {
        Self::baml_client()
    }
}

/// Media types supported in Swift
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MediaTypeSwift {
    Image,
    Audio,
    File,
}

impl fmt::Display for MediaTypeSwift {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MediaTypeSwift::Image => write!(f, "BamlImage"),
            MediaTypeSwift::Audio => write!(f, "BamlAudio"),
            MediaTypeSwift::File => write!(f, "BamlFile"),
        }
    }
}

/// Represents a BAML type in Swift form
///
/// This enum captures all the type information needed to generate Swift code,
/// including literals, primitives, collections, and user-defined types.
#[derive(Debug, Clone, PartialEq)]
pub enum TypeSwift {
    /// Null type (maps to Swift's nil/optional)
    Null,

    /// String type, optionally a literal value
    String(Option<String>),

    /// Integer type, optionally a literal value
    Int(Option<i64>),

    /// Float type (maps to Swift Double)
    Float,

    /// Boolean type, optionally a literal value
    Bool(Option<bool>),

    /// Media types (image, audio, file)
    Media(MediaTypeSwift),

    /// Reference to a class/struct type
    Class {
        name: String,
        module: SwiftModule,
        dynamic: bool,
    },

    /// Reference to an enum type
    Enum {
        name: String,
        module: SwiftModule,
        dynamic: bool,
    },

    /// Reference to a union type (Swift enum with associated values)
    Union {
        name: String,
        module: SwiftModule,
    },

    /// Reference to a type alias
    TypeAlias {
        name: String,
        module: SwiftModule,
    },

    /// Array type
    List(Box<TypeSwift>),

    /// Dictionary type (key must be Hashable - typically String)
    Map(Box<TypeSwift>, Box<TypeSwift>),

    /// Optional type
    Optional(Box<TypeSwift>),

    /// Checked type with validation checks
    Checked {
        inner: Box<TypeSwift>,
        checks: Vec<String>,
    },

    /// Streaming state wrapper
    StreamState(Box<TypeSwift>),

    /// Any type (escape hatch)
    Any {
        reason: String,
    },
}

impl TypeSwift {
    /// Create a string type
    pub fn string() -> Self {
        TypeSwift::String(None)
    }

    /// Create a string literal type
    pub fn string_literal(value: impl Into<String>) -> Self {
        TypeSwift::String(Some(value.into()))
    }

    /// Create an int type
    pub fn int() -> Self {
        TypeSwift::Int(None)
    }

    /// Create an int literal type
    pub fn int_literal(value: i64) -> Self {
        TypeSwift::Int(Some(value))
    }

    /// Create a bool type
    pub fn bool() -> Self {
        TypeSwift::Bool(None)
    }

    /// Create a bool literal type
    pub fn bool_literal(value: bool) -> Self {
        TypeSwift::Bool(Some(value))
    }

    /// Create a float/double type
    pub fn float() -> Self {
        TypeSwift::Float
    }

    /// Create a class reference
    pub fn class(name: impl Into<String>) -> Self {
        TypeSwift::Class {
            name: name.into(),
            module: SwiftModule::default(),
            dynamic: false,
        }
    }

    /// Create a dynamic class reference
    pub fn class_dynamic(name: impl Into<String>) -> Self {
        TypeSwift::Class {
            name: name.into(),
            module: SwiftModule::default(),
            dynamic: true,
        }
    }

    /// Create an enum reference
    pub fn enum_ref(name: impl Into<String>) -> Self {
        TypeSwift::Enum {
            name: name.into(),
            module: SwiftModule::default(),
            dynamic: false,
        }
    }

    /// Create a dynamic enum reference
    pub fn enum_dynamic(name: impl Into<String>) -> Self {
        TypeSwift::Enum {
            name: name.into(),
            module: SwiftModule::default(),
            dynamic: true,
        }
    }

    /// Create a union reference
    pub fn union(name: impl Into<String>) -> Self {
        TypeSwift::Union {
            name: name.into(),
            module: SwiftModule::default(),
        }
    }

    /// Create a type alias reference
    pub fn type_alias(name: impl Into<String>) -> Self {
        TypeSwift::TypeAlias {
            name: name.into(),
            module: SwiftModule::default(),
        }
    }

    /// Create a list/array type
    pub fn list(inner: TypeSwift) -> Self {
        TypeSwift::List(Box::new(inner))
    }

    /// Create a map/dictionary type
    pub fn map(key: TypeSwift, value: TypeSwift) -> Self {
        TypeSwift::Map(Box::new(key), Box::new(value))
    }

    /// Create an optional type
    pub fn optional(inner: TypeSwift) -> Self {
        // Avoid double-wrapping optionals
        match inner {
            TypeSwift::Optional(_) => inner,
            TypeSwift::Null => TypeSwift::Optional(Box::new(TypeSwift::Any {
                reason: "null optional".to_string(),
            })),
            _ => TypeSwift::Optional(Box::new(inner)),
        }
    }

    /// Create a checked type
    pub fn checked(inner: TypeSwift, checks: Vec<String>) -> Self {
        TypeSwift::Checked {
            inner: Box::new(inner),
            checks,
        }
    }

    /// Create a stream state type
    pub fn stream_state(inner: TypeSwift) -> Self {
        TypeSwift::StreamState(Box::new(inner))
    }

    /// Create an any type
    pub fn any(reason: impl Into<String>) -> Self {
        TypeSwift::Any {
            reason: reason.into(),
        }
    }

    /// Check if this type is optional
    pub fn is_optional(&self) -> bool {
        matches!(self, TypeSwift::Optional(_) | TypeSwift::Null)
    }

    /// Check if this type is a primitive
    pub fn is_primitive(&self) -> bool {
        matches!(
            self,
            TypeSwift::String(_)
                | TypeSwift::Int(_)
                | TypeSwift::Float
                | TypeSwift::Bool(_)
                | TypeSwift::Null
        )
    }

    /// Check if this type is complex (needs JSON encoding for string interpolation)
    pub fn is_complex(&self) -> bool {
        matches!(
            self,
            TypeSwift::Class { .. }
                | TypeSwift::List(_)
                | TypeSwift::Map(_, _)
                | TypeSwift::Union { .. }
                | TypeSwift::Any { .. }
        )
    }

    /// Get the inner type if this is a container (Optional, List, etc.)
    pub fn inner(&self) -> Option<&TypeSwift> {
        match self {
            TypeSwift::Optional(inner)
            | TypeSwift::List(inner)
            | TypeSwift::StreamState(inner)
            | TypeSwift::Checked { inner, .. } => Some(inner.as_ref()),
            _ => None,
        }
    }
}

/// Trait for serializing types to Swift syntax
pub trait SerializeType {
    /// Render the type as a Swift type string
    fn serialize(&self) -> String;

    /// Render as a parameter type (may differ for certain types)
    fn serialize_param(&self) -> String {
        self.serialize()
    }

    /// Render as a return type (may differ for certain types)
    fn serialize_return(&self) -> String {
        self.serialize()
    }
}

impl SerializeType for TypeSwift {
    fn serialize(&self) -> String {
        match self {
            TypeSwift::Null => "Void?".to_string(),
            TypeSwift::String(None) => "String".to_string(),
            TypeSwift::String(Some(literal)) => {
                // String literals in Swift don't have a distinct type representation
                // They're just String
                format!("String /* literal: {} */", escape_swift_string(literal))
            }
            TypeSwift::Int(None) => "Int".to_string(),
            TypeSwift::Int(Some(literal)) => {
                format!("Int /* literal: {} */", literal)
            }
            TypeSwift::Float => "Double".to_string(),
            TypeSwift::Bool(None) => "Bool".to_string(),
            TypeSwift::Bool(Some(literal)) => {
                format!("Bool /* literal: {} */", literal)
            }
            TypeSwift::Media(media) => media.to_string(),
            TypeSwift::Class { name, .. } => name.clone(),
            TypeSwift::Enum { name, .. } => name.clone(),
            TypeSwift::Union { name, .. } => name.clone(),
            TypeSwift::TypeAlias { name, .. } => name.clone(),
            TypeSwift::List(inner) => format!("[{}]", inner.serialize()),
            TypeSwift::Map(key, value) => {
                format!("[{}: {}]", key.serialize(), value.serialize())
            }
            TypeSwift::Optional(inner) => {
                let inner_str = inner.serialize();
                // Handle nested optionals - Swift doesn't allow T??
                if inner.is_optional() {
                    inner_str
                } else {
                    format!("{}?", inner_str)
                }
            }
            TypeSwift::Checked { inner, .. } => {
                // Checked types are represented as their inner type
                // The checks are validated at runtime
                format!("Checked<{}>", inner.serialize())
            }
            TypeSwift::StreamState(inner) => {
                format!("StreamState<{}>", inner.serialize())
            }
            TypeSwift::Any { .. } => "BamlValue".to_string(),
        }
    }
}

impl fmt::Display for TypeSwift {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.serialize())
    }
}

/// Escape a string for Swift string literals
fn escape_swift_string(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_primitive_types() {
        assert_eq!(TypeSwift::string().serialize(), "String");
        assert_eq!(TypeSwift::int().serialize(), "Int");
        assert_eq!(TypeSwift::float().serialize(), "Double");
        assert_eq!(TypeSwift::bool().serialize(), "Bool");
    }

    #[test]
    fn test_optional_types() {
        assert_eq!(
            TypeSwift::optional(TypeSwift::string()).serialize(),
            "String?"
        );
        assert_eq!(
            TypeSwift::optional(TypeSwift::int()).serialize(),
            "Int?"
        );
    }

    #[test]
    fn test_list_types() {
        assert_eq!(
            TypeSwift::list(TypeSwift::string()).serialize(),
            "[String]"
        );
        assert_eq!(
            TypeSwift::list(TypeSwift::int()).serialize(),
            "[Int]"
        );
    }

    #[test]
    fn test_map_types() {
        assert_eq!(
            TypeSwift::map(TypeSwift::string(), TypeSwift::int()).serialize(),
            "[String: Int]"
        );
    }

    #[test]
    fn test_nested_types() {
        assert_eq!(
            TypeSwift::optional(TypeSwift::list(TypeSwift::string())).serialize(),
            "[String]?"
        );
        assert_eq!(
            TypeSwift::list(TypeSwift::optional(TypeSwift::int())).serialize(),
            "[Int?]"
        );
    }

    #[test]
    fn test_class_types() {
        assert_eq!(TypeSwift::class("MyClass").serialize(), "MyClass");
        assert_eq!(TypeSwift::enum_ref("MyEnum").serialize(), "MyEnum");
    }

    #[test]
    fn test_double_optional_flattening() {
        let double_opt = TypeSwift::optional(TypeSwift::optional(TypeSwift::string()));
        assert_eq!(double_opt.serialize(), "String?");
    }
}
