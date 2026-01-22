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

    /// Initialize with known types from the BAML schema
    public init(classes: Set<String> = [], enums: Set<String> = []) {
        self.knownClasses = classes
        self.knownEnums = enums
    }

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

    /// Get all enum builders
    public var allEnumBuilders: [String: DynamicEnumBuilder] {
        lock.lock()
        defer { lock.unlock() }
        return enumBuilders
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
}

// MARK: - Dynamic Enum Builder

/// Builder for adding values to a dynamic enum at runtime
public class DynamicEnumBuilder: @unchecked Sendable {
    private let lock = NSLock()

    /// Name of the enum
    public let name: String

    /// Values added to this enum
    private var values: [String] = []
    private var valueSet: Set<String> = []

    public init(name: String) {
        self.name = name
    }

    /// Add a value to this dynamic enum
    @discardableResult
    public func addValue(_ value: String) -> DynamicEnumBuilder {
        lock.lock()
        defer { lock.unlock() }

        if !valueSet.contains(value) {
            values.append(value)
            valueSet.insert(value)
        }
        return self
    }

    /// Get all values in order
    public var allValues: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    /// Check if a value exists
    public func hasValue(_ value: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return valueSet.contains(value)
    }

    /// Get the count of values
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return values.count
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

// MARK: - Class Builder (for future use)

/// Builder for dynamic class properties
public class ClassBuilder: @unchecked Sendable {
    public let name: String
    private var properties: [String: PropertyType] = [:]
    private var required: Set<String> = []

    public init(name: String) {
        self.name = name
    }

    @discardableResult
    public func addProperty(_ name: String, type: PropertyType, required: Bool = true) -> ClassBuilder {
        properties[name] = type
        if required {
            self.required.insert(name)
        }
        return self
    }

    public var allProperties: [String: PropertyType] {
        properties
    }

    public func buildSchema() -> JSONSchema {
        var props: [String: JSONSchema] = [:]
        for (name, type) in properties {
            props[name] = type.toJSONSchema()
        }
        return .object(
            properties: props,
            required: Array(required).sorted()
        )
    }

    public func generateSwiftStruct() -> String {
        var lines: [String] = []
        lines.append("public struct \(name): Codable, Sendable {")
        for (propName, propType) in properties.sorted(by: { $0.key < $1.key }) {
            let swiftType = propType.toSwiftType()
            lines.append("    public let \(propName): \(swiftType)")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Enum Builder (legacy - for backwards compat)

/// Legacy enum builder for building schemas
public class EnumBuilder: @unchecked Sendable {
    public let name: String
    private var values: [EnumValue] = []

    public init(name: String) {
        self.name = name
    }

    @discardableResult
    public func addValue(_ name: String, alias: String? = nil) -> EnumBuilder {
        values.append(EnumValue(name: name, alias: alias))
        return self
    }

    public var allValues: [EnumValue] {
        values
    }

    public var valueStrings: [String] {
        values.map { $0.stringValue }
    }

    public func buildSchema() -> JSONSchema {
        .enum(values: valueStrings)
    }

    public func generateSwiftEnum() -> String {
        var lines: [String] = []
        lines.append("public enum \(name): String, Codable, Sendable {")
        for value in values {
            let caseName = value.name.lowercased()
            lines.append("    case \(caseName) = \"\(value.stringValue)\"")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}

// MARK: - PropertyType Extensions

extension PropertyType {
    func toSwiftType() -> String {
        switch self {
        case .string: return "String"
        case .int: return "Int"
        case .float: return "Double"
        case .bool: return "Bool"
        case .optional(let inner): return "\(inner.toSwiftType())?"
        case .array(let element): return "[\(element.toSwiftType())]"
        case .map(_, let value): return "[String: \(value.toSwiftType())]"
        case .reference(let name): return name
        }
    }
}
