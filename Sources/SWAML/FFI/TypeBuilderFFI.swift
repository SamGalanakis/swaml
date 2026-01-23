// TypeBuilder FFI - manages TypeBuilder objects on the Rust side

import Foundation

#if BAML_FFI_ENABLED

// MARK: - TypeBuilder FFI Handle

/// A handle to a TypeBuilder created on the Rust side via FFI.
/// This allows passing TypeBuilder to BAML function calls for dynamic enum constraints.
public final class TypeBuilderFFI: @unchecked Sendable {
    /// The raw pointer to the Rust TypeBuilder object
    public let handle: BamlObjectHandleV2

    /// Reference to the runtime (needed for method calls)
    private let runtime: BamlRuntimeFFI

    /// Enum builders that have been created (cached for reuse)
    private var enumBuilders: [String: EnumBuilderFFI] = [:]
    private let lock = NSLock()

    /// Create a new TypeBuilder on the Rust side
    /// - Parameter runtime: The BAML runtime (needed for method calls on the TypeBuilder)
    public init(runtime: BamlRuntimeFFI) throws {
        self.runtime = runtime
        // Create the constructor invocation
        let invocation = BamlObjectConstructorInvocation(type: .typeBuilder)

        // Serialize to protobuf
        let data: Data
        do {
            data = try invocation.serializedData()
        } catch {
            throw TypeBuilderFFIError.serializationFailed("Failed to serialize constructor: \(error)")
        }

        // Call the FFI constructor
        let buffer = data.withUnsafeBytes { ptr in
            BamlFFI.callObjectConstructor(
                encodedArgs: ptr.baseAddress!.assumingMemoryBound(to: Int8.self),
                length: data.count
            )
        }
        defer { BamlFFI.freeBuffer(buffer) }

        // Parse the response
        guard let responseData = buffer.toData() else {
            throw TypeBuilderFFIError.constructorFailed("Empty response from FFI")
        }

        let response: ObjectInvocationResponse
        do {
            response = try ObjectInvocationResponse(serializedBytes: responseData)
        } catch {
            // Try to parse as raw error string
            if let errorStr = String(data: responseData, encoding: .utf8) {
                throw TypeBuilderFFIError.constructorFailed(errorStr)
            }
            throw TypeBuilderFFIError.deserializationFailed("Failed to parse response: \(error)")
        }

        // Extract the handle
        switch response.response {
        case .success(let obj):
            self.handle = obj
        case .error(let msg):
            throw TypeBuilderFFIError.constructorFailed(msg)
        case .none:
            throw TypeBuilderFFIError.constructorFailed("Empty response")
        }
    }

    /// Get or create an enum builder for the given enum name
    public func enumBuilder(_ name: String) throws -> EnumBuilderFFI {
        lock.lock()
        defer { lock.unlock() }

        // Return cached builder if available
        if let existing = enumBuilders[name] {
            return existing
        }

        // Try add_enum first (for dynamic enums not yet created)
        // If it already exists, fall back to enum_ to get the existing one
        var methodName = "add_enum"
        var invocation = BamlObjectMethodInvocation(
            object: handle,
            methodName: methodName,
            kwargs: [HostMapEntry(stringKey: "name", value: .string(name))]
        )

        var data = try invocation.serializedData()
        var responseData = try runtime.callObjectMethod(data)
        var response = try ObjectInvocationResponse(serializedBytes: responseData)

        // If add_enum fails with "already exists", try enum_ to get existing
        if case .error(let msg) = response.response, msg.contains("already exists") {
            methodName = "enum_"
            invocation = BamlObjectMethodInvocation(
                object: handle,
                methodName: methodName,
                kwargs: [HostMapEntry(stringKey: "name", value: .string(name))]
            )
            data = try invocation.serializedData()
            responseData = try runtime.callObjectMethod(data)
            response = try ObjectInvocationResponse(serializedBytes: responseData)
        }

        switch response.response {
        case .success(let obj):
            let builder = EnumBuilderFFI(handle: obj, name: name, runtime: runtime)
            enumBuilders[name] = builder
            return builder
        case .error(let msg):
            throw TypeBuilderFFIError.methodCallFailed("enum() failed: \(msg)")
        case .none:
            throw TypeBuilderFFIError.methodCallFailed("Empty response from enum()")
        }
    }

    /// Get the handle for passing to function calls
    public func getHandle() -> BamlObjectHandleV2 {
        handle
    }
}

// MARK: - EnumBuilder FFI Handle

/// A handle to an EnumBuilder created on the Rust side
public final class EnumBuilderFFI: @unchecked Sendable {
    public let handle: BamlObjectHandleV2
    public let name: String
    private let runtime: BamlRuntimeFFI
    private var addedValues: Set<String> = []
    private let lock = NSLock()

    init(handle: BamlObjectHandleV2, name: String, runtime: BamlRuntimeFFI) {
        self.handle = handle
        self.name = name
        self.runtime = runtime
    }

    /// Add a value to this enum
    @discardableResult
    public func addValue(_ value: String) throws -> EnumBuilderFFI {
        lock.lock()
        defer { lock.unlock() }

        // Skip if already added
        if addedValues.contains(value) {
            return self
        }

        // Call add_value() to add a value to the dynamic enum
        // Parameter is "value" not "name"
        let invocation = BamlObjectMethodInvocation(
            object: handle,
            methodName: "add_value",
            kwargs: [HostMapEntry(stringKey: "value", value: .string(value))]
        )

        let data = try invocation.serializedData()

        // Use runtime.callObjectMethod for method calls
        let responseData = try runtime.callObjectMethod(data)

        // The response might be the EnumValueBuilder, but we don't need it
        // Just check for errors
        if let response = try? ObjectInvocationResponse(serializedBytes: responseData) {
            if case .error(let msg) = response.response {
                throw TypeBuilderFFIError.methodCallFailed("value() failed: \(msg)")
            }
        }

        addedValues.insert(value)
        return self
    }

    /// Add multiple values to this enum
    @discardableResult
    public func addValues(_ values: [String]) throws -> EnumBuilderFFI {
        for value in values {
            try addValue(value)
        }
        return self
    }

    /// Add multiple values from a sequence of keys
    @discardableResult
    public func addValues<S: Sequence>(from keys: S) throws -> EnumBuilderFFI where S.Element == String {
        for key in keys {
            try addValue(key)
        }
        return self
    }
}

// MARK: - Errors

public enum TypeBuilderFFIError: Error, LocalizedError {
    case ffiNotAvailable
    case serializationFailed(String)
    case deserializationFailed(String)
    case constructorFailed(String)
    case methodCallFailed(String)

    public var errorDescription: String? {
        switch self {
        case .ffiNotAvailable:
            return "BAML FFI is not available"
        case .serializationFailed(let msg):
            return "Serialization failed: \(msg)"
        case .deserializationFailed(let msg):
            return "Deserialization failed: \(msg)"
        case .constructorFailed(let msg):
            return "TypeBuilder constructor failed: \(msg)"
        case .methodCallFailed(let msg):
            return "TypeBuilder method call failed: \(msg)"
        }
    }
}

// MARK: - BamlArgumentsBuilder Extension

extension BamlArgumentsBuilder {
    /// Set the TypeBuilder for this call (constrains dynamic enum values)
    /// - Parameter typeBuilder: The TypeBuilder FFI handle to use
    public mutating func setTypeBuilder(_ typeBuilder: TypeBuilderFFI) {
        setTypeBuilderHandle(typeBuilder.getHandle())
    }
}

#endif // BAML_FFI_ENABLED
