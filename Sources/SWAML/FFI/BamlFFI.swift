import Foundation

// MARK: - FFI Buffer Structure

/// Buffer structure for FFI data exchange
public struct BamlBuffer {
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

    public func toData() -> Data? {
        guard let ptr = ptr, len > 0 else { return nil }
        return Data(bytes: ptr, count: len)
    }

    public func toString() -> String? {
        guard let data = toData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Dynamic Library Loading

/// Manages dynamic loading of the BAML FFI library
public final class BamlFFILoader: @unchecked Sendable {
    public static let shared = BamlFFILoader()

    private var handle: UnsafeMutableRawPointer?
    private var _isLoaded = false
    private let lock = NSLock()

    public var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isLoaded
    }

    private init() {
        #if os(Linux)
        let libNames = ["libbaml_ffi.so", "baml_ffi.so"]
        #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let libNames = ["libbaml_ffi.dylib", "BamlFFI.framework/BamlFFI"]
        #else
        let libNames: [String] = []
        #endif

        for name in libNames {
            if let h = dlopen(name, RTLD_NOW | RTLD_LOCAL) {
                handle = h
                _isLoaded = true
                break
            }
        }
    }

    public func load(from path: String) throws {
        lock.lock()
        defer { lock.unlock() }

        if _isLoaded { return }

        guard let h = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            let error = String(cString: dlerror())
            throw BamlError.runtimeCreationFailed("Failed to load FFI library: \(error)")
        }

        handle = h
        _isLoaded = true
    }

    func rawSymbol(_ name: String) -> UnsafeMutableRawPointer? {
        guard let handle = handle else { return nil }
        return dlsym(handle, name)
    }

    deinit {
        if let handle = handle {
            dlclose(handle)
        }
    }
}

// MARK: - FFI Functions

/// FFI function wrappers using dynamic loading
public enum BamlFFI {

    public static var isAvailable: Bool {
        BamlFFILoader.shared.isLoaded
    }

    public static func createRuntime(
        rootPath: UnsafePointer<CChar>,
        srcFilesJson: UnsafePointer<CChar>,
        envVarsJson: UnsafePointer<CChar>
    ) -> UnsafeMutableRawPointer? {
        guard let sym = BamlFFILoader.shared.rawSymbol("create_baml_runtime") else {
            return nil
        }
        typealias Fn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
        return unsafeBitCast(sym, to: Fn.self)(rootPath, srcFilesJson, envVarsJson)
    }

    public static func destroyRuntime(_ runtime: UnsafeRawPointer) {
        guard let sym = BamlFFILoader.shared.rawSymbol("destroy_baml_runtime") else { return }
        typealias Fn = @convention(c) (UnsafeRawPointer) -> Void
        unsafeBitCast(sym, to: Fn.self)(runtime)
    }

    public static func callFunction(
        runtime: UnsafeRawPointer,
        functionName: UnsafePointer<CChar>,
        encodedArgs: UnsafePointer<Int8>,
        length: Int,
        callId: UInt32
    ) -> BamlBuffer {
        guard let sym = BamlFFILoader.shared.rawSymbol("call_function_from_c") else {
            return BamlBuffer()
        }
        // Returns raw pointer to buffer struct in memory
        typealias Fn = @convention(c) (UnsafeRawPointer, UnsafePointer<CChar>, UnsafePointer<Int8>, Int, UInt32) -> UnsafeRawPointer?
        guard let resultPtr = unsafeBitCast(sym, to: Fn.self)(runtime, functionName, encodedArgs, length, callId) else {
            return BamlBuffer()
        }
        // Interpret the returned pointer as (ptr, len) struct
        let ptr = resultPtr.assumingMemoryBound(to: UnsafePointer<Int8>?.self).pointee
        let len = resultPtr.advanced(by: MemoryLayout<UnsafePointer<Int8>?>.stride).assumingMemoryBound(to: Int.self).pointee
        return BamlBuffer(ptr: ptr, len: len)
    }

    public static func callFunctionStream(
        runtime: UnsafeRawPointer,
        functionName: UnsafePointer<CChar>,
        encodedArgs: UnsafePointer<Int8>,
        length: Int,
        callId: UInt32
    ) -> BamlBuffer {
        guard let sym = BamlFFILoader.shared.rawSymbol("call_function_stream_from_c") else {
            return BamlBuffer()
        }
        typealias Fn = @convention(c) (UnsafeRawPointer, UnsafePointer<CChar>, UnsafePointer<Int8>, Int, UInt32) -> UnsafeRawPointer?
        guard let resultPtr = unsafeBitCast(sym, to: Fn.self)(runtime, functionName, encodedArgs, length, callId) else {
            return BamlBuffer()
        }
        let ptr = resultPtr.assumingMemoryBound(to: UnsafePointer<Int8>?.self).pointee
        let len = resultPtr.advanced(by: MemoryLayout<UnsafePointer<Int8>?>.stride).assumingMemoryBound(to: Int.self).pointee
        return BamlBuffer(ptr: ptr, len: len)
    }

    public static func callObjectMethod(
        runtime: UnsafeRawPointer,
        encodedArgs: UnsafePointer<Int8>,
        length: Int
    ) -> BamlBuffer {
        guard let sym = BamlFFILoader.shared.rawSymbol("call_object_method") else {
            return BamlBuffer()
        }
        typealias Fn = @convention(c) (UnsafeRawPointer, UnsafePointer<Int8>, Int) -> UnsafeRawPointer?
        guard let resultPtr = unsafeBitCast(sym, to: Fn.self)(runtime, encodedArgs, length) else {
            return BamlBuffer()
        }
        let ptr = resultPtr.assumingMemoryBound(to: UnsafePointer<Int8>?.self).pointee
        let len = resultPtr.advanced(by: MemoryLayout<UnsafePointer<Int8>?>.stride).assumingMemoryBound(to: Int.self).pointee
        return BamlBuffer(ptr: ptr, len: len)
    }

    public static func freeBuffer(_ buffer: BamlBuffer) {
        guard let sym = BamlFFILoader.shared.rawSymbol("free_buffer"),
              buffer.ptr != nil else { return }
        typealias Fn = @convention(c) (UnsafePointer<Int8>?, Int) -> Void
        unsafeBitCast(sym, to: Fn.self)(buffer.ptr, buffer.len)
    }

    public static func registerCallbacks(
        resultCallback: @escaping @convention(c) (UInt32, Int32, UnsafePointer<Int8>?, Int) -> Void,
        errorCallback: @escaping @convention(c) (UInt32, Int32, UnsafePointer<Int8>?, Int) -> Void,
        tickCallback: @escaping @convention(c) (UInt32) -> Void
    ) {
        guard let sym = BamlFFILoader.shared.rawSymbol("register_callbacks") else { return }
        typealias Fn = @convention(c) (
            @convention(c) (UInt32, Int32, UnsafePointer<Int8>?, Int) -> Void,
            @convention(c) (UInt32, Int32, UnsafePointer<Int8>?, Int) -> Void,
            @convention(c) (UInt32) -> Void
        ) -> Void
        unsafeBitCast(sym, to: Fn.self)(resultCallback, errorCallback, tickCallback)
    }
}
