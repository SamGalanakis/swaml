import Foundation
import BamlFFIC

// MARK: - BAML FFI Version Compatibility
// Compatible with BAML 0.218.0+
// The BAML FFI library can be built from: https://github.com/BoundaryML/baml
// Build the C FFI library from engine/language_client_cffi

// MARK: - Swift Buffer Wrapper

/// Swift-friendly buffer wrapper for FFI data exchange
/// @unchecked because UnsafePointer is used safely within FFI boundaries
public struct BamlBuffer: @unchecked Sendable {
    public let ptr: UnsafePointer<Int8>?
    public let len: Int

    public init() {
        self.ptr = nil
        self.len = 0
    }

    public init(ptr: UnsafePointer<Int8>?, len: Int) {
        self.ptr = ptr
        self.len = len
    }

    public var isEmpty: Bool {
        ptr == nil || len == 0
    }

    public func toData() -> Data? {
        guard let ptr = ptr, len > 0 else { return nil }
        return Data(bytes: ptr, count: len)
    }

    public func toString() -> String? {
        guard let data = toData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - FFI Library Loader

/// Manages dynamic loading of the BAML FFI library using C wrapper
public final class BamlFFILoader: @unchecked Sendable {
    public static let shared = BamlFFILoader()

    private var library: OpaquePointer?
    private let lock = NSLock()

    public var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return library != nil
    }

    var libraryHandle: OpaquePointer? {
        lock.lock()
        defer { lock.unlock() }
        return library
    }

    private init() {
        // Try to load from default locations
        library = baml_library_load_default()
    }

    public func load(from path: String) throws {
        lock.lock()
        defer { lock.unlock() }

        if library != nil { return }

        guard let lib = baml_library_load(path) else {
            throw BamlError.runtimeCreationFailed("Failed to load FFI library from: \(path)")
        }

        library = lib
    }

    deinit {
        if let lib = library {
            baml_library_unload(lib)
        }
    }
}

// MARK: - FFI Functions

/// FFI function wrappers using C library for ABI-safe struct returns.
/// Compatible with BAML 0.218.0+ C FFI interface.
public enum BamlFFI {

    public static var isAvailable: Bool {
        BamlFFILoader.shared.isLoaded
    }

    /// Create a BAML runtime instance
    public static func createRuntime(
        rootPath: UnsafePointer<CChar>,
        srcFilesJson: UnsafePointer<CChar>,
        envVarsJson: UnsafePointer<CChar>
    ) -> UnsafeMutableRawPointer? {
        guard let lib = BamlFFILoader.shared.libraryHandle else {
            return nil
        }
        return baml_create_runtime(lib, rootPath, srcFilesJson, envVarsJson)
    }

    /// Destroy a BAML runtime instance
    public static func destroyRuntime(_ runtime: UnsafeRawPointer) {
        guard let lib = BamlFFILoader.shared.libraryHandle else { return }
        baml_destroy_runtime(lib, UnsafeMutableRawPointer(mutating: runtime))
    }

    /// Call a BAML function synchronously
    /// Returns a Buffer containing protobuf-encoded InvocationResponse
    public static func callFunction(
        runtime: UnsafeRawPointer,
        functionName: UnsafePointer<CChar>,
        encodedArgs: UnsafePointer<Int8>,
        length: Int,
        callId: UInt32
    ) -> BamlBuffer {
        guard let lib = BamlFFILoader.shared.libraryHandle else {
            return BamlBuffer()
        }

        var outPtr: UnsafePointer<Int8>?
        var outLen: Int = 0

        baml_call_function(
            lib,
            UnsafeMutableRawPointer(mutating: runtime),
            functionName,
            encodedArgs,
            length,
            callId,
            &outPtr,
            &outLen
        )

        return BamlBuffer(ptr: outPtr, len: outLen)
    }

    /// Call a BAML function with streaming
    /// Returns a Buffer containing protobuf-encoded response
    public static func callFunctionStream(
        runtime: UnsafeRawPointer,
        functionName: UnsafePointer<CChar>,
        encodedArgs: UnsafePointer<Int8>,
        length: Int,
        callId: UInt32
    ) -> BamlBuffer {
        guard let lib = BamlFFILoader.shared.libraryHandle else {
            return BamlBuffer()
        }

        var outPtr: UnsafePointer<Int8>?
        var outLen: Int = 0

        baml_call_function_stream(
            lib,
            UnsafeMutableRawPointer(mutating: runtime),
            functionName,
            encodedArgs,
            length,
            callId,
            &outPtr,
            &outLen
        )

        return BamlBuffer(ptr: outPtr, len: outLen)
    }

    /// Call an object constructor (creates TypeBuilder, Collector, etc.)
    public static func callObjectConstructor(
        encodedArgs: UnsafePointer<Int8>,
        length: Int
    ) -> BamlBuffer {
        guard let lib = BamlFFILoader.shared.libraryHandle else {
            return BamlBuffer()
        }

        var outPtr: UnsafePointer<Int8>?
        var outLen: Int = 0

        baml_call_object_constructor(
            lib,
            encodedArgs,
            length,
            &outPtr,
            &outLen
        )

        return BamlBuffer(ptr: outPtr, len: outLen)
    }

    /// Call an object method
    public static func callObjectMethod(
        runtime: UnsafeRawPointer,
        encodedArgs: UnsafePointer<Int8>,
        length: Int
    ) -> BamlBuffer {
        guard let lib = BamlFFILoader.shared.libraryHandle else {
            return BamlBuffer()
        }

        var outPtr: UnsafePointer<Int8>?
        var outLen: Int = 0

        baml_call_object_method(
            lib,
            UnsafeMutableRawPointer(mutating: runtime),
            encodedArgs,
            length,
            &outPtr,
            &outLen
        )

        return BamlBuffer(ptr: outPtr, len: outLen)
    }

    /// Free a buffer allocated by the FFI
    public static func freeBuffer(_ buffer: BamlBuffer) {
        guard let lib = BamlFFILoader.shared.libraryHandle,
              let ptr = buffer.ptr else { return }
        baml_free_buffer(lib, ptr, buffer.len)
    }

    /// Register callbacks for async operations
    public static func registerCallbacks(
        resultCallback: @escaping @convention(c) (UInt32, Int32, UnsafePointer<Int8>?, Int) -> Void,
        errorCallback: @escaping @convention(c) (UInt32, Int32, UnsafePointer<Int8>?, Int) -> Void,
        tickCallback: @escaping @convention(c) (UInt32) -> Void
    ) {
        guard let lib = BamlFFILoader.shared.libraryHandle else { return }
        baml_register_callbacks(lib, resultCallback, errorCallback, tickCallback)
    }

    /// Get the BAML FFI library version
    public static func version() -> String? {
        guard let lib = BamlFFILoader.shared.libraryHandle else {
            return nil
        }

        var outPtr: UnsafePointer<Int8>?
        var outLen: Int = 0

        baml_version(lib, &outPtr, &outLen)

        let buffer = BamlBuffer(ptr: outPtr, len: outLen)
        defer { freeBuffer(buffer) }
        return buffer.toString()
    }
}
