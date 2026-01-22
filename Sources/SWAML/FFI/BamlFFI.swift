import Foundation

// FFI code is only available when the BamlFFI xcframework is linked.
// To enable FFI support:
// 1. Run ./scripts/build-xcframework.sh to build BamlFFI.xcframework
// 2. Add the xcframework to your Xcode project
// 3. Define BAML_FFI_ENABLED in your build settings

#if BAML_FFI_ENABLED

// MARK: - FFI Buffer Structure

/// Buffer structure matching the C definition from baml_cffi_generated.h
/// Used to pass data between Rust and Swift
public struct BamlBuffer {
    /// Pointer to the buffer data
    public let ptr: UnsafePointer<Int8>?
    /// Length of the buffer data
    public let len: Int

    /// Initialize an empty buffer
    public init() {
        self.ptr = nil
        self.len = 0
    }

    /// Initialize with pointer and length
    public init(ptr: UnsafePointer<Int8>?, len: Int) {
        self.ptr = ptr
        self.len = len
    }

    /// Convert buffer contents to Data
    public func toData() -> Data? {
        guard let ptr = ptr, len > 0 else { return nil }
        return Data(bytes: ptr, count: len)
    }

    /// Convert buffer contents to String
    public func toString() -> String? {
        guard let data = toData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - C Function Declarations

/// Create a new BAML runtime instance
/// - Parameters:
///   - rootPath: Root path for BAML files
///   - srcFilesJson: JSON-encoded dictionary of source file paths to contents
///   - envVarsJson: JSON-encoded dictionary of environment variables
/// - Returns: Opaque pointer to the runtime, or nil on failure
@_silgen_name("create_baml_runtime")
public func baml_create_runtime(
    _ rootPath: UnsafePointer<CChar>,
    _ srcFilesJson: UnsafePointer<CChar>,
    _ envVarsJson: UnsafePointer<CChar>
) -> UnsafeMutableRawPointer?

/// Destroy a BAML runtime instance
/// - Parameter runtime: Pointer to the runtime to destroy
@_silgen_name("destroy_baml_runtime")
public func baml_destroy_runtime(_ runtime: UnsafeRawPointer)

/// Call a BAML function synchronously (starts async execution)
/// - Parameters:
///   - runtime: Pointer to the BAML runtime
///   - functionName: Name of the function to call
///   - encodedArgs: MessagePack-encoded arguments
///   - length: Length of the encoded arguments
///   - callId: Unique identifier for this call (used for callback routing)
/// - Returns: Buffer containing invocation handle or error
@_silgen_name("call_function_from_c")
public func baml_call_function(
    _ runtime: UnsafeRawPointer,
    _ functionName: UnsafePointer<CChar>,
    _ encodedArgs: UnsafePointer<Int8>,
    _ length: Int,
    _ callId: UInt32
) -> BamlBuffer

/// Call a BAML function with streaming
/// - Parameters:
///   - runtime: Pointer to the BAML runtime
///   - functionName: Name of the function to call
///   - encodedArgs: MessagePack-encoded arguments
///   - length: Length of the encoded arguments
///   - callId: Unique identifier for this call (used for callback routing)
/// - Returns: Buffer containing stream handle or error
@_silgen_name("call_function_stream_from_c")
public func baml_call_function_stream(
    _ runtime: UnsafeRawPointer,
    _ functionName: UnsafePointer<CChar>,
    _ encodedArgs: UnsafePointer<Int8>,
    _ length: Int,
    _ callId: UInt32
) -> BamlBuffer

/// Call an object method (used for TypeBuilder, etc.)
/// - Parameters:
///   - runtime: Pointer to the BAML runtime
///   - encodedArgs: MessagePack-encoded method call arguments
///   - length: Length of the encoded arguments
/// - Returns: Buffer containing result or error
@_silgen_name("call_object_method")
public func baml_call_object_method(
    _ runtime: UnsafeRawPointer,
    _ encodedArgs: UnsafePointer<Int8>,
    _ length: Int
) -> BamlBuffer

/// Free a buffer allocated by the Rust runtime
/// - Parameter buffer: Buffer to free
@_silgen_name("free_buffer")
public func baml_free_buffer(_ buffer: BamlBuffer)

/// Register callbacks for async function execution
/// - Parameters:
///   - resultCallback: Called when a function produces a result
///   - errorCallback: Called when a function produces an error
///   - tickCallback: Called periodically during execution
@_silgen_name("register_callbacks")
public func baml_register_callbacks(
    _ resultCallback: @escaping @convention(c) (UInt32, Int32, UnsafePointer<Int8>?, Int) -> Void,
    _ errorCallback: @escaping @convention(c) (UInt32, Int32, UnsafePointer<Int8>?, Int) -> Void,
    _ tickCallback: @escaping @convention(c) (UInt32) -> Void
)

/// Get the output format JSON schema for a function
/// - Parameters:
///   - runtime: Pointer to the BAML runtime
///   - functionName: Name of the function
/// - Returns: Buffer containing JSON schema string
@_silgen_name("get_output_format")
public func baml_get_output_format(
    _ runtime: UnsafeRawPointer,
    _ functionName: UnsafePointer<CChar>
) -> BamlBuffer

/// Render a prompt template with arguments
/// - Parameters:
///   - runtime: Pointer to the BAML runtime
///   - functionName: Name of the function
///   - encodedArgs: MessagePack-encoded arguments
///   - length: Length of the encoded arguments
/// - Returns: Buffer containing rendered prompt
@_silgen_name("render_prompt")
public func baml_render_prompt(
    _ runtime: UnsafeRawPointer,
    _ functionName: UnsafePointer<CChar>,
    _ encodedArgs: UnsafePointer<Int8>,
    _ length: Int
) -> BamlBuffer

#endif // BAML_FFI_ENABLED
