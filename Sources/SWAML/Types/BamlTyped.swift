import Foundation

/// Protocol for types that can be used with BAML structured output.
/// Conforming types provide compile-time type information for schema generation
/// and LLM output parsing.
///
/// Types can conform manually or use the `@BamlType` macro for automatic conformance.
///
/// Example manual conformance:
/// ```swift
/// struct User: BamlTyped {
///     let name: String
///     let age: Int
///
///     static var bamlTypeName: String { "User" }
///     static var bamlSchema: JSONSchema {
///         .object()
///             .property("name", .string)
///             .property("age", .integer)
///             .build()
///     }
/// }
/// ```
public protocol BamlTyped: Codable, Sendable {
    /// The BAML type name (used in schema references)
    static var bamlTypeName: String { get }

    /// JSON Schema for this type
    static var bamlSchema: JSONSchema { get }

    /// Whether this type can be extended at runtime with TypeBuilder.
    /// Only types marked with `@BamlDynamic` return true.
    static var isDynamic: Bool { get }

    /// Field descriptions for documentation and schema generation.
    /// Maps property names to their descriptions.
    static var fieldDescriptions: [String: String] { get }

    /// Alias mappings for properties (property name -> alias).
    /// Aliases are alternative names that can be used in LLM output.
    static var fieldAliases: [String: String] { get }
}

// MARK: - Default Implementations

extension BamlTyped {
    /// By default, types are not dynamic (cannot be extended at runtime)
    public static var isDynamic: Bool { false }

    /// By default, no field descriptions
    public static var fieldDescriptions: [String: String] { [:] }

    /// By default, no field aliases
    public static var fieldAliases: [String: String] { [:] }
}

// MARK: - Primitive Type Conformance

extension String: BamlTyped {
    public static var bamlTypeName: String { "string" }
    public static var bamlSchema: JSONSchema { .string }
}

extension Int: BamlTyped {
    public static var bamlTypeName: String { "int" }
    public static var bamlSchema: JSONSchema { .integer }
}

extension Double: BamlTyped {
    public static var bamlTypeName: String { "float" }
    public static var bamlSchema: JSONSchema { .number }
}

extension Float: BamlTyped {
    public static var bamlTypeName: String { "float" }
    public static var bamlSchema: JSONSchema { .number }
}

extension Bool: BamlTyped {
    public static var bamlTypeName: String { "bool" }
    public static var bamlSchema: JSONSchema { .boolean }
}

// MARK: - Collection Type Conformance

extension Array: BamlTyped where Element: BamlTyped {
    public static var bamlTypeName: String { "[\(Element.bamlTypeName)]" }
    public static var bamlSchema: JSONSchema { .array(items: Element.bamlSchema) }
}

extension Optional: BamlTyped where Wrapped: BamlTyped {
    public static var bamlTypeName: String { "\(Wrapped.bamlTypeName)?" }
    public static var bamlSchema: JSONSchema { .anyOf([Wrapped.bamlSchema, .null]) }
}

extension Dictionary: BamlTyped where Key == String, Value: BamlTyped {
    public static var bamlTypeName: String { "map<string, \(Value.bamlTypeName)>" }
    public static var bamlSchema: JSONSchema {
        .object(properties: [:], required: [], additionalProperties: Value.bamlSchema)
    }
}

// MARK: - Type Information Helper

/// Provides runtime type information for BamlTyped types
public struct BamlTypeInfo: Sendable {
    /// The type name
    public let name: String

    /// The JSON schema
    public let schema: JSONSchema

    /// Whether the type is dynamic
    public let isDynamic: Bool

    /// Field descriptions
    public let fieldDescriptions: [String: String]

    /// Field aliases
    public let fieldAliases: [String: String]

    /// Create type info from a BamlTyped type
    public init<T: BamlTyped>(for type: T.Type) {
        self.name = T.bamlTypeName
        self.schema = T.bamlSchema
        self.isDynamic = T.isDynamic
        self.fieldDescriptions = T.fieldDescriptions
        self.fieldAliases = T.fieldAliases
    }

    /// Create type info manually
    public init(
        name: String,
        schema: JSONSchema,
        isDynamic: Bool = false,
        fieldDescriptions: [String: String] = [:],
        fieldAliases: [String: String] = [:]
    ) {
        self.name = name
        self.schema = schema
        self.isDynamic = isDynamic
        self.fieldDescriptions = fieldDescriptions
        self.fieldAliases = fieldAliases
    }
}

// MARK: - Dynamic Type Registration

/// Registry for dynamic type information that can be extended at runtime
public final class BamlTypeRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var dynamicTypes: [String: BamlTypeInfo] = [:]
    private var typeExtensions: [String: [String]] = [:]  // enum name -> additional values

    /// Shared instance
    public static let shared = BamlTypeRegistry()

    private init() {}

    /// Register a dynamic type
    public func register<T: BamlTyped>(_ type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        dynamicTypes[T.bamlTypeName] = BamlTypeInfo(for: type)
    }

    /// Get type info for a registered type
    public func typeInfo(for name: String) -> BamlTypeInfo? {
        lock.lock()
        defer { lock.unlock() }
        return dynamicTypes[name]
    }

    /// Check if a type is registered as dynamic
    public func isDynamic(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return dynamicTypes[name]?.isDynamic ?? false
    }

    /// Add values to a dynamic enum
    public func extendEnum(_ name: String, with values: [String]) throws {
        lock.lock()
        defer { lock.unlock() }

        guard let info = dynamicTypes[name] else {
            throw BamlError.configurationError("Type '\(name)' is not registered")
        }

        guard info.isDynamic else {
            throw BamlError.configurationError(
                "Cannot extend non-dynamic type '\(name)'. Add @BamlDynamic to allow runtime extension."
            )
        }

        var existing = typeExtensions[name] ?? []
        existing.append(contentsOf: values)
        typeExtensions[name] = existing
    }

    /// Get extended values for an enum
    public func enumExtensions(for name: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return typeExtensions[name] ?? []
    }

    /// Clear all registrations (useful for testing)
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        dynamicTypes.removeAll()
        typeExtensions.removeAll()
    }
}
