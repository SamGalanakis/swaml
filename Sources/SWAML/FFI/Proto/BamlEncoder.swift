// BAML FFI Encoder - converts Swift values to protobuf HostValue

import Foundation
import CoreFoundation

#if BAML_FFI_ENABLED

/// Protocol for types that can be encoded to BAML HostValue
public protocol BamlEncodable {
    func toBamlHostValue() throws -> HostValue
}

// MARK: - Primitive Type Extensions

extension String: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        return .string(self)
    }
}

extension Int: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        return .int(self)
    }
}

extension Int64: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        return .int(self)
    }
}

extension Double: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        return .float(self)
    }
}

extension Float: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        return .float(Double(self))
    }
}

extension Bool: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        return .bool(self)
    }
}

extension Optional: BamlEncodable where Wrapped: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        switch self {
        case .none:
            return .null
        case .some(let value):
            return try value.toBamlHostValue()
        }
    }
}

extension Array: BamlEncodable where Element: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        let values = try self.map { try $0.toBamlHostValue() }
        return .list(values)
    }
}

extension Dictionary: BamlEncodable where Key == String, Value: BamlEncodable {
    public func toBamlHostValue() throws -> HostValue {
        var entries: [HostMapEntry] = []
        for (key, value) in self {
            let hostValue = try value.toBamlHostValue()
            entries.append(HostMapEntry(stringKey: key, value: hostValue))
        }
        return .map(entries)
    }
}

// MARK: - BAML Function Arguments Builder

/// Builder for creating BAML function arguments
public struct BamlArgumentsBuilder {
    private var kwargs: [HostMapEntry] = []
    private var envVars: [HostEnvVar] = []
    private var clientRegistry: HostClientRegistry?
    private var typeBuilderHandle: BamlObjectHandleV2?

    public init() {}

    /// Add a named argument
    public mutating func add(_ name: String, value: any BamlEncodable) throws {
        let hostValue = try value.toBamlHostValue()
        kwargs.append(HostMapEntry(stringKey: name, value: hostValue))
    }

    /// Add a named argument that might be nil
    public mutating func add(_ name: String, optionalValue: (any BamlEncodable)?) throws {
        if let value = optionalValue {
            try add(name, value: value)
        }
        // If nil, we skip adding it (protobuf handles missing fields as null)
    }

    /// Add environment variables to the function call
    public mutating func addEnvVars(_ envVars: [String: String]) {
        for (key, value) in envVars {
            self.envVars.append(HostEnvVar(key: key, value: value))
        }
    }

    /// Set the client registry for this call (overrides default clients)
    public mutating func setClientRegistry(_ registry: HostClientRegistry) {
        self.clientRegistry = registry
    }

    /// Set a single client override for this call
    /// - Parameters:
    ///   - name: Client name to override (e.g., "TextClient")
    ///   - provider: Provider string (e.g., "openai-generic")
    ///   - options: Client options (api_key, model, base_url, temperature, etc.)
    public mutating func setClient(name: String, provider: String, options: [String: String]) {
        var clientProperty = HostClientProperty()
        clientProperty.name = name
        clientProperty.provider = provider
        for (key, value) in options {
            clientProperty.options.append(HostMapEntry(stringKey: key, value: .string(value)))
        }

        var registry = clientRegistry ?? HostClientRegistry()
        registry.clients.append(clientProperty)
        registry.primary = name
        self.clientRegistry = registry
    }

    /// Set the TypeBuilder handle directly
    /// - Parameter handle: The BamlObjectHandleV2 for the TypeBuilder
    public mutating func setTypeBuilderHandle(_ handle: BamlObjectHandleV2) {
        self.typeBuilderHandle = handle
    }

    /// Build the HostFunctionArguments
    public func build() -> HostFunctionArguments {
        var args = HostFunctionArguments(kwargs: kwargs)
        args.env = envVars
        args.clientRegistry = clientRegistry
        args.typeBuilder = typeBuilderHandle
        return args
    }

    /// Serialize to protobuf bytes
    public func serialize() throws -> Data {
        let args = build()
        return try args.serializedData()
    }
}

// MARK: - Encodable to BamlEncodable Bridge

/// Error for encoding failures
public enum BamlEncodingError: Error, LocalizedError {
    case unsupportedType(String)
    case encodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let type):
            return "Unsupported type for BAML encoding: \(type)"
        case .encodingFailed(let reason):
            return "BAML encoding failed: \(reason)"
        }
    }
}

/// Convert any Encodable to HostValue by going through JSON
public func encodeToHostValue<T: Encodable>(_ value: T) throws -> HostValue {
    // First encode to JSON
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)

    // Parse JSON to get the structure
    let json = try JSONSerialization.jsonObject(with: data)

    // Convert JSON to HostValue
    return try jsonToHostValue(json)
}

/// Convert a JSON object to HostValue
private func jsonToHostValue(_ json: Any) throws -> HostValue {
    switch json {
    case is NSNull:
        return .null

    case let string as String:
        return .string(string)

    case let number as NSNumber:
        // Check if it's a boolean
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return .bool(number.boolValue)
        }
        // Check if it's an integer or float
        if number.doubleValue == Double(number.int64Value) {
            return .int(number.int64Value)
        }
        return .float(number.doubleValue)

    case let array as [Any]:
        let values = try array.map { try jsonToHostValue($0) }
        return .list(values)

    case let dict as [String: Any]:
        var entries: [HostMapEntry] = []
        for (key, value) in dict {
            let hostValue = try jsonToHostValue(value)
            entries.append(HostMapEntry(stringKey: key, value: hostValue))
        }
        return .map(entries)

    default:
        throw BamlEncodingError.unsupportedType(String(describing: type(of: json)))
    }
}

/// Extension to make encoding Encodable types easier
extension BamlArgumentsBuilder {
    /// Add an Encodable value as a named argument
    public mutating func addEncodable<T: Encodable>(_ name: String, value: T) throws {
        let hostValue = try encodeToHostValue(value)
        kwargs.append(HostMapEntry(stringKey: name, value: hostValue))
    }
}

/// Extension for converting Encodable types to HostValue
extension HostValue {
    /// Create a HostValue from any Encodable type
    public static func from<T: Encodable>(_ value: T) throws -> HostValue {
        return try encodeToHostValue(value)
    }
}

#endif // BAML_FFI_ENABLED
