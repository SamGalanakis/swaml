import Foundation

// MARK: - TypeBuilder Core

/// Build types dynamically at runtime for use with BAML functions.
/// This is the base class - generated code will create a subclass with
/// specific enum/class accessors.
open class TypeBuilder: @unchecked Sendable {
    private let lock = NSLock()

    /// Known class names from BAML schema
    public let knownClasses: Set<String>

    /// Known enum names from BAML schema
    public let knownEnums: Set<String>

    /// Dynamic enum builders (for @@dynamic enums)
    private var enumBuilders: [String: DynamicEnumBuilder] = [:]

    /// Dynamic class builders
    private var classBuilders: [String: DynamicClassBuilder] = [:]

    /// Registered dynamic types (types that can be extended at runtime)
    private var dynamicTypes: Set<String> = []

    /// Initialize with known types from the BAML schema
    public init(classes: Set<String> = [], enums: Set<String> = []) {
        self.knownClasses = classes
        self.knownEnums = enums
    }

    // MARK: - Dynamic Type Registration

    /// Register a type as dynamically extensible
    ///
    /// Only types registered as dynamic can be extended at runtime.
    /// Types marked with `@BamlDynamic` are automatically registered.
    public func registerDynamicType(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        dynamicTypes.insert(name)
    }

    /// Register a BamlTyped type as dynamic (if it declares isDynamic = true)
    public func registerDynamicType<T: BamlTyped>(_ type: T.Type) {
        if T.isDynamic {
            registerDynamicType(T.bamlTypeName)
        }
    }

    /// Check if a type is registered as dynamic
    public func isDynamicType(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return dynamicTypes.contains(name)
    }

    /// Get all registered dynamic type names
    public var registeredDynamicTypes: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return dynamicTypes
    }

    // MARK: - Primitive Type Factories

    /// Create a string type
    public func string() -> FieldType { .string }

    /// Create an integer type
    public func int() -> FieldType { .int }

    /// Create a float/double type
    public func float() -> FieldType { .float }

    /// Create a boolean type
    public func bool() -> FieldType { .bool }

    /// Create a null type
    public func null() -> FieldType { .null }

    // MARK: - Literal Type Factories

    /// Create a literal string type
    public func literalString(_ value: String) -> FieldType {
        .literalString(value)
    }

    /// Create a literal integer type
    public func literalInt(_ value: Int) -> FieldType {
        .literalInt(value)
    }

    /// Create a literal boolean type
    public func literalBool(_ value: Bool) -> FieldType {
        .literalBool(value)
    }

    // MARK: - Composite Type Factories

    /// Create a list type
    public func list(_ inner: FieldType) -> FieldType {
        .list(inner)
    }

    /// Create a map type
    public func map(key: FieldType, value: FieldType) -> FieldType {
        .map(key: key, value: value)
    }

    /// Create a union type
    public func union(_ types: FieldType...) -> FieldType {
        .union(types)
    }

    /// Create a union type from array
    public func union(_ types: [FieldType]) -> FieldType {
        .union(types)
    }

    // MARK: - Dynamic Type Creation

    /// Get or create a dynamic enum builder
    public func enumBuilder(_ name: String) -> DynamicEnumBuilder {
        lock.lock()
        defer { lock.unlock() }

        if let existing = enumBuilders[name] {
            return existing
        }

        let builder = DynamicEnumBuilder(name: name)
        enumBuilders[name] = builder
        return builder
    }

    /// Create or get a dynamic enum builder (alias for enumBuilder)
    public func addEnum(_ name: String) -> DynamicEnumBuilder {
        enumBuilder(name)
    }

    /// Create or get a dynamic class builder
    public func addClass(_ name: String) -> DynamicClassBuilder {
        lock.lock()
        defer { lock.unlock() }

        if let existing = classBuilders[name] {
            return existing
        }

        let builder = DynamicClassBuilder(name: name)
        classBuilders[name] = builder
        return builder
    }

    /// Get or create a dynamic class builder (alias for addClass)
    public func classBuilder(_ name: String) -> DynamicClassBuilder {
        addClass(name)
    }

    // MARK: - Strict Dynamic Type Extension

    /// Get or create a dynamic enum builder for a BamlTyped enum type
    ///
    /// This method validates that the type is marked as dynamic before allowing extension.
    /// - Parameter type: The BamlTyped enum type to extend
    /// - Returns: A builder for adding values to the enum
    /// - Throws: TypeBuilderError.typeNotDynamic if the type is not marked with @BamlDynamic
    public func enumBuilder<T: BamlTyped>(for type: T.Type) throws -> DynamicEnumBuilder {
        guard T.isDynamic else {
            throw TypeBuilderError.typeNotDynamic(T.bamlTypeName)
        }
        // Auto-register when using typed API
        registerDynamicType(T.bamlTypeName)
        return enumBuilder(T.bamlTypeName)
    }

    /// Get or create a dynamic class builder for a BamlTyped class type
    ///
    /// This method validates that the type is marked as dynamic before allowing extension.
    /// - Parameter type: The BamlTyped class type to extend
    /// - Returns: A builder for adding properties to the class
    /// - Throws: TypeBuilderError.typeNotDynamic if the type is not marked with @BamlDynamic
    public func classBuilder<T: BamlTyped>(for type: T.Type) throws -> DynamicClassBuilder {
        guard T.isDynamic else {
            throw TypeBuilderError.typeNotDynamic(T.bamlTypeName)
        }
        // Auto-register when using typed API
        registerDynamicType(T.bamlTypeName)
        return classBuilder(T.bamlTypeName)
    }

    /// Extend an enum with strict validation
    ///
    /// - Parameters:
    ///   - name: The enum type name
    ///   - values: Values to add
    /// - Throws: TypeBuilderError.typeNotDynamic if the type is not registered as dynamic
    public func extendEnumStrict(_ name: String, values: [String]) throws {
        lock.lock()
        let isDynamic = dynamicTypes.contains(name)
        lock.unlock()

        guard isDynamic else {
            throw TypeBuilderError.typeNotDynamic(name)
        }

        let builder = enumBuilder(name)
        for value in values {
            builder.addValue(value)
        }
    }

    /// Extend a class with strict validation
    ///
    /// - Parameters:
    ///   - name: The class type name
    ///   - properties: Properties to add (name -> type)
    /// - Throws: TypeBuilderError.typeNotDynamic if the type is not registered as dynamic
    public func extendClassStrict(_ name: String, properties: [(String, FieldType)]) throws {
        lock.lock()
        let isDynamic = dynamicTypes.contains(name)
        lock.unlock()

        guard isDynamic else {
            throw TypeBuilderError.typeNotDynamic(name)
        }

        let builder = classBuilder(name)
        for (propName, propType) in properties {
            builder.addProperty(propName, propType)
        }
    }

    /// Get all enum builders
    public var allEnumBuilders: [String: DynamicEnumBuilder] {
        lock.lock()
        defer { lock.unlock() }
        return enumBuilders
    }

    /// Get all class builders
    public var allClassBuilders: [String: DynamicClassBuilder] {
        lock.lock()
        defer { lock.unlock() }
        return classBuilders
    }

    /// Build JSON Schema for a dynamic enum (with added values)
    public func buildEnumSchema(_ name: String) -> JSONSchema? {
        lock.lock()
        defer { lock.unlock() }

        guard let builder = enumBuilders[name] else {
            return nil
        }

        let values = builder.allValues
        if values.isEmpty {
            return nil
        }

        return .enum(values: values)
    }

    /// Build JSON Schema for a dynamic class
    public func buildClassSchema(_ name: String) -> JSONSchema? {
        lock.lock()
        defer { lock.unlock() }

        guard let builder = classBuilders[name] else {
            return nil
        }

        return builder.buildSchema()
    }

    /// Get all dynamic enum values as a dictionary
    public func dynamicEnumValues() -> [String: [String]] {
        lock.lock()
        defer { lock.unlock() }

        var result: [String: [String]] = [:]
        for (name, builder) in enumBuilders {
            let values = builder.allValues
            if !values.isEmpty {
                result[name] = values
            }
        }
        return result
    }

    // MARK: - FFI Serialization

    /// Serialize the TypeBuilder state for FFI
    public func toSerializable() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        let enums = enumBuilders.values
            .filter { !$0.allValues.isEmpty }
            .map { $0.toSerializable() }

        let classes = classBuilders.values
            .filter { !$0.allPropertyNames.isEmpty }
            .map { $0.toSerializable() }

        return [
            "enums": enums,
            "classes": classes
        ]
    }

    /// Serialize the TypeBuilder state to JSON data
    public func toJSON() throws -> Data {
        try JSONSerialization.data(withJSONObject: toSerializable())
    }

    /// Serialize the TypeBuilder state to a JSON string
    public func toJSONString(prettyPrinted: Bool = false) throws -> String {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted, .sortedKeys] : []
        let data = try JSONSerialization.data(withJSONObject: toSerializable(), options: options)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TypeBuilderError.serializationFailed
        }
        return string
    }
}

/// Errors that can occur during TypeBuilder operations
public enum TypeBuilderError: Error, LocalizedError {
    case serializationFailed
    case typeNotDynamic(String)
    case typeNotRegistered(String)

    public var errorDescription: String? {
        switch self {
        case .serializationFailed:
            return "Failed to serialize TypeBuilder to JSON"
        case .typeNotDynamic(let name):
            return "Cannot extend non-dynamic type '\(name)'. Add @BamlDynamic to allow runtime extension."
        case .typeNotRegistered(let name):
            return "Type '\(name)' is not registered for dynamic extension"
        }
    }
}

// MARK: - Enum Value Builder

/// Builder for enum values with metadata (description, alias)
public final class EnumValueBuilder: @unchecked Sendable {
    private let lock = NSLock()

    /// Name of the enum value
    public let name: String

    private var _description: String?
    private var _alias: String?

    public init(name: String) {
        self.name = name
    }

    /// Set the description for this enum value
    @discardableResult
    public func description(_ desc: String) -> EnumValueBuilder {
        lock.lock()
        defer { lock.unlock() }
        _description = desc
        return self
    }

    /// Set the alias for this enum value
    @discardableResult
    public func alias(_ alias: String) -> EnumValueBuilder {
        lock.lock()
        defer { lock.unlock() }
        _alias = alias
        return self
    }

    /// Get the description
    public var descriptionValue: String? {
        lock.lock()
        defer { lock.unlock() }
        return _description
    }

    /// Get the alias
    public var aliasValue: String? {
        lock.lock()
        defer { lock.unlock() }
        return _alias
    }

    /// Convert to serializable dictionary
    public func toSerializable() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        var dict: [String: Any] = ["name": name]
        if let desc = _description {
            dict["description"] = desc
        }
        if let alias = _alias {
            dict["alias"] = alias
        }
        return dict
    }
}

// MARK: - Dynamic Enum Builder

/// Builder for adding values to a dynamic enum at runtime
public class DynamicEnumBuilder: @unchecked Sendable {
    private let lock = NSLock()

    /// Name of the enum
    public let name: String

    /// Values added to this enum (preserves order)
    private var valueOrder: [String] = []
    private var valueBuilders: [String: EnumValueBuilder] = [:]

    public init(name: String) {
        self.name = name
    }

    /// Add a value to this dynamic enum, returning a builder for metadata
    @discardableResult
    public func addValue(_ value: String) -> EnumValueBuilder {
        lock.lock()
        defer { lock.unlock() }

        if let existing = valueBuilders[value] {
            return existing
        }

        let builder = EnumValueBuilder(name: value)
        valueOrder.append(value)
        valueBuilders[value] = builder
        return builder
    }

    /// Get all values in order
    public var allValues: [String] {
        lock.lock()
        defer { lock.unlock() }
        return valueOrder
    }

    /// Get all value builders
    public var allValueBuilders: [EnumValueBuilder] {
        lock.lock()
        defer { lock.unlock() }
        return valueOrder.compactMap { valueBuilders[$0] }
    }

    /// Check if a value exists
    public func hasValue(_ value: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return valueBuilders[value] != nil
    }

    /// Get the count of values
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return valueOrder.count
    }

    /// Get a FieldType reference to this enum
    public func type() -> FieldType {
        .reference(name)
    }

    /// Convert to serializable dictionary
    public func toSerializable() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        return [
            "name": name,
            "values": valueOrder.compactMap { valueBuilders[$0]?.toSerializable() }
        ]
    }
}

// MARK: - Class Property Builder

/// Builder for class properties with metadata (description, alias)
public final class ClassPropertyBuilder: @unchecked Sendable {
    private let lock = NSLock()

    /// Name of the property
    public let name: String

    /// Type of the property
    private var _type: FieldType

    private var _description: String?
    private var _alias: String?

    public init(name: String, type: FieldType) {
        self.name = name
        self._type = type
    }

    /// Set the description for this property
    @discardableResult
    public func description(_ desc: String) -> ClassPropertyBuilder {
        lock.lock()
        defer { lock.unlock() }
        _description = desc
        return self
    }

    /// Set the alias for this property
    @discardableResult
    public func alias(_ alias: String) -> ClassPropertyBuilder {
        lock.lock()
        defer { lock.unlock() }
        _alias = alias
        return self
    }

    /// Get the type
    public var fieldType: FieldType {
        lock.lock()
        defer { lock.unlock() }
        return _type
    }

    /// Get the description
    public var descriptionValue: String? {
        lock.lock()
        defer { lock.unlock() }
        return _description
    }

    /// Get the alias
    public var aliasValue: String? {
        lock.lock()
        defer { lock.unlock() }
        return _alias
    }

    /// Convert to serializable dictionary
    public func toSerializable() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        var dict: [String: Any] = [
            "name": name,
            "type": _type.toSerializable()
        ]
        if let desc = _description {
            dict["description"] = desc
        }
        if let alias = _alias {
            dict["alias"] = alias
        }
        return dict
    }
}

// MARK: - Dynamic Class Builder

/// Builder for dynamic classes with properties
public final class DynamicClassBuilder: @unchecked Sendable {
    private let lock = NSLock()

    /// Name of the class
    public let name: String

    /// Properties in order
    private var propertyOrder: [String] = []
    private var propertyBuilders: [String: ClassPropertyBuilder] = [:]

    public init(name: String) {
        self.name = name
    }

    /// Add a property to this class
    @discardableResult
    public func addProperty(_ propertyName: String, _ type: FieldType) -> ClassPropertyBuilder {
        lock.lock()
        defer { lock.unlock() }

        if let existing = propertyBuilders[propertyName] {
            return existing
        }

        let builder = ClassPropertyBuilder(name: propertyName, type: type)
        propertyOrder.append(propertyName)
        propertyBuilders[propertyName] = builder
        return builder
    }

    /// Get all property builders in order
    public var allPropertyBuilders: [ClassPropertyBuilder] {
        lock.lock()
        defer { lock.unlock() }
        return propertyOrder.compactMap { propertyBuilders[$0] }
    }

    /// Get all property names in order
    public var allPropertyNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return propertyOrder
    }

    /// Check if a property exists
    public func hasProperty(_ propertyName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return propertyBuilders[propertyName] != nil
    }

    /// Get the count of properties
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return propertyOrder.count
    }

    /// Get a FieldType reference to this class
    public func type() -> FieldType {
        .reference(name)
    }

    /// Convert to serializable dictionary
    public func toSerializable() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        return [
            "name": name,
            "properties": propertyOrder.compactMap { propertyBuilders[$0]?.toSerializable() }
        ]
    }

    /// Build JSON Schema for this class
    public func buildSchema() -> JSONSchema {
        lock.lock()
        defer { lock.unlock() }

        var props: [String: JSONSchema] = [:]
        for name in propertyOrder {
            if let builder = propertyBuilders[name] {
                props[name] = builder.fieldType.toJSONSchema()
            }
        }

        // All properties are required by default (non-optional)
        let required = propertyOrder.filter { name in
            guard let builder = propertyBuilders[name] else { return true }
            if case .optional = builder.fieldType.kind {
                return false
            }
            return true
        }

        return .object(properties: props, required: required)
    }
}

// MARK: - Enum Value (for static enums)

/// Represents a value in an enum (for viewing existing values)
public struct EnumValue: Sendable, Equatable {
    public let name: String
    public let alias: String?

    public init(name: String, alias: String? = nil) {
        self.name = name
        self.alias = alias
    }

    /// The string value to use (alias if present, otherwise name)
    public var stringValue: String {
        alias ?? name
    }
}

// MARK: - Static Enum Viewer

/// Viewer for static enums (read-only access to existing values)
public class StaticEnumViewer: @unchecked Sendable {
    /// Name of the enum
    public let name: String

    /// Values defined in the BAML schema
    public let values: [EnumValue]

    private let valueSet: Set<String>

    public init(name: String, values: [EnumValue]) {
        self.name = name
        self.values = values
        self.valueSet = Set(values.map { $0.name })
    }

    /// List all values
    public func listValues() -> [EnumValue] {
        values
    }

    /// Check if a value exists
    public func hasValue(_ name: String) -> Bool {
        valueSet.contains(name)
    }

    /// Get value by name
    public func value(_ name: String) -> EnumValue? {
        values.first { $0.name == name }
    }
}

