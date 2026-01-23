import Foundation

/// Protocol for types that can be used with SWAML structured output.
/// Conforming types provide compile-time type information for schema generation
/// and LLM output parsing.
///
/// Types can conform manually or use the `@SwamlType` macro for automatic conformance.
///
/// Example manual conformance:
/// ```swift
/// struct User: SwamlTyped {
///     let name: String
///     let age: Int
///
///     static var swamlTypeName: String { "User" }
///     static var swamlSchema: JSONSchema {
///         .object()
///             .property("name", .string)
///             .property("age", .integer)
///             .build()
///     }
/// }
/// ```
public protocol SwamlTyped: Codable, Sendable {
    /// The SWAML type name (used in schema references)
    static var swamlTypeName: String { get }

    /// JSON Schema for this type
    static var swamlSchema: JSONSchema { get }

    /// Whether this type can be extended at runtime with TypeBuilder.
    /// Only types marked with `@SwamlDynamic` return true.
    static var isDynamic: Bool { get }

    /// Field descriptions for documentation and schema generation.
    /// Maps property names to their descriptions.
    static var fieldDescriptions: [String: String] { get }

    /// Alias mappings for properties (property name -> alias).
    /// Aliases are alternative names that can be used in LLM output.
    static var fieldAliases: [String: String] { get }
}

// MARK: - Default Implementations

extension SwamlTyped {
    /// By default, types are not dynamic (cannot be extended at runtime)
    public static var isDynamic: Bool { false }

    /// By default, no field descriptions
    public static var fieldDescriptions: [String: String] { [:] }

    /// By default, no field aliases
    public static var fieldAliases: [String: String] { [:] }
}

// MARK: - Primitive Type Conformance

extension String: SwamlTyped {
    public static var swamlTypeName: String { "string" }
    public static var swamlSchema: JSONSchema { .string }
}

extension Int: SwamlTyped {
    public static var swamlTypeName: String { "int" }
    public static var swamlSchema: JSONSchema { .integer }
}

extension Double: SwamlTyped {
    public static var swamlTypeName: String { "float" }
    public static var swamlSchema: JSONSchema { .number }
}

extension Float: SwamlTyped {
    public static var swamlTypeName: String { "float" }
    public static var swamlSchema: JSONSchema { .number }
}

extension Bool: SwamlTyped {
    public static var swamlTypeName: String { "bool" }
    public static var swamlSchema: JSONSchema { .boolean }
}

// MARK: - Collection Type Conformance

extension Array: SwamlTyped where Element: SwamlTyped {
    public static var swamlTypeName: String { "[\(Element.swamlTypeName)]" }
    public static var swamlSchema: JSONSchema { .array(items: Element.swamlSchema) }
}

extension Optional: SwamlTyped where Wrapped: SwamlTyped {
    public static var swamlTypeName: String { "\(Wrapped.swamlTypeName)?" }
    public static var swamlSchema: JSONSchema { .anyOf([Wrapped.swamlSchema, .null]) }
}

extension Dictionary: SwamlTyped where Key == String, Value: SwamlTyped {
    public static var swamlTypeName: String { "map<string, \(Value.swamlTypeName)>" }
    public static var swamlSchema: JSONSchema {
        .object(properties: [:], required: [], additionalProperties: Value.swamlSchema)
    }
}

// MARK: - Type Information Helper

/// Provides runtime type information for SwamlTyped types
public struct SwamlTypeInfo: Sendable {
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

    /// Create type info from a SwamlTyped type
    public init<T: SwamlTyped>(for type: T.Type) {
        self.name = T.swamlTypeName
        self.schema = T.swamlSchema
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
public final class SwamlTypeRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var dynamicTypes: [String: SwamlTypeInfo] = [:]
    private var typeExtensions: [String: [String]] = [:]  // enum name -> additional values

    /// Shared instance
    public static let shared = SwamlTypeRegistry()

    private init() {}

    /// Register a dynamic type
    public func register<T: SwamlTyped>(_ type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        dynamicTypes[T.swamlTypeName] = SwamlTypeInfo(for: type)
    }

    /// Get type info for a registered type
    public func typeInfo(for name: String) -> SwamlTypeInfo? {
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
            throw SwamlError.configurationError("Type '\(name)' is not registered")
        }

        guard info.isDynamic else {
            throw SwamlError.configurationError(
                "Cannot extend non-dynamic type '\(name)'. Add @SwamlDynamic to allow runtime extension."
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

