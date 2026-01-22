import Foundation

// FFI code is only available when the BamlFFI xcframework is linked.
// To enable FFI support:
// 1. Run ./scripts/build-xcframework.sh to build BamlFFI.xcframework
// 2. Add the xcframework to your Xcode project
// 3. Define BAML_FFI_ENABLED in your build settings

#if BAML_FFI_ENABLED

// MARK: - FFI Runtime Errors

/// Errors specific to FFI runtime operations
public enum BamlFFIError: Error, LocalizedError, Sendable {
    case runtimeCreationFailed(String)
    case functionCallFailed(String)
    case invalidResponse(String)
    case callbackError(String)
    case encodingError(String)
    case decodingError(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .runtimeCreationFailed(let msg):
            return "Failed to create BAML runtime: \(msg)"
        case .functionCallFailed(let msg):
            return "Function call failed: \(msg)"
        case .invalidResponse(let msg):
            return "Invalid response from FFI: \(msg)"
        case .callbackError(let msg):
            return "Callback error: \(msg)"
        case .encodingError(let msg):
            return "Encoding error: \(msg)"
        case .decodingError(let msg):
            return "Decoding error: \(msg)"
        case .timeout:
            return "Operation timed out"
        }
    }
}

// MARK: - Callback Manager

/// Manages async callbacks from the FFI layer
final class CallbackManager: @unchecked Sendable {
    static let shared = CallbackManager()

    private let lock = NSLock()
    private var pendingCalls: [UInt32: CheckedContinuation<Data, Error>] = [:]
    private var streamingCalls: [UInt32: AsyncThrowingStream<Data, Error>.Continuation] = [:]
    private var nextCallId: UInt32 = 0
    private var callbacksRegistered = false

    private init() {}

    /// Register FFI callbacks (called once at initialization)
    func registerCallbacksIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard !callbacksRegistered else { return }
        callbacksRegistered = true

        baml_register_callbacks(
            // Result callback
            { callId, isDone, contentPtr, length in
                CallbackManager.shared.handleResult(
                    callId: callId,
                    isDone: isDone != 0,
                    content: contentPtr,
                    length: length
                )
            },
            // Error callback
            { callId, isDone, contentPtr, length in
                CallbackManager.shared.handleError(
                    callId: callId,
                    isDone: isDone != 0,
                    content: contentPtr,
                    length: length
                )
            },
            // Tick callback (for progress/keepalive)
            { callId in
                // Currently unused, but available for progress reporting
            }
        )
    }

    /// Get a unique call ID for a new function call
    func getNextCallId() -> UInt32 {
        lock.lock()
        defer { lock.unlock() }
        let id = nextCallId
        nextCallId += 1
        return id
    }

    /// Register a continuation for a pending call
    func registerCall(_ callId: UInt32, continuation: CheckedContinuation<Data, Error>) {
        lock.lock()
        defer { lock.unlock() }
        pendingCalls[callId] = continuation
    }

    /// Register a stream continuation for a streaming call
    func registerStreamCall(_ callId: UInt32, continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        lock.lock()
        defer { lock.unlock() }
        streamingCalls[callId] = continuation
    }

    /// Remove a pending call
    func removeCall(_ callId: UInt32) {
        lock.lock()
        defer { lock.unlock() }
        pendingCalls.removeValue(forKey: callId)
    }

    /// Remove a streaming call
    func removeStreamCall(_ callId: UInt32) {
        lock.lock()
        defer { lock.unlock() }
        streamingCalls.removeValue(forKey: callId)
    }

    /// Handle a result callback from FFI
    private func handleResult(callId: UInt32, isDone: Bool, content: UnsafePointer<Int8>?, length: Int) {
        let data: Data
        if let content = content, length > 0 {
            data = Data(bytes: content, count: length)
        } else {
            data = Data()
        }

        lock.lock()
        let continuation = pendingCalls[callId]
        let streamContinuation = streamingCalls[callId]

        if isDone {
            pendingCalls.removeValue(forKey: callId)
            streamingCalls.removeValue(forKey: callId)
        }
        lock.unlock()

        if let continuation = continuation {
            continuation.resume(returning: data)
        } else if let streamContinuation = streamContinuation {
            streamContinuation.yield(data)
            if isDone {
                streamContinuation.finish()
            }
        }
    }

    /// Handle an error callback from FFI
    private func handleError(callId: UInt32, isDone: Bool, content: UnsafePointer<Int8>?, length: Int) {
        let errorMessage: String
        if let content = content, length > 0 {
            let data = Data(bytes: content, count: length)
            errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        } else {
            errorMessage = "Unknown error"
        }

        let error = BamlFFIError.callbackError(errorMessage)

        lock.lock()
        let continuation = pendingCalls.removeValue(forKey: callId)
        let streamContinuation = streamingCalls.removeValue(forKey: callId)
        lock.unlock()

        if let continuation = continuation {
            continuation.resume(throwing: error)
        } else if let streamContinuation = streamContinuation {
            streamContinuation.finish(throwing: error)
        }
    }
}

// MARK: - BAML FFI Runtime

/// Swift wrapper around the BAML Rust FFI runtime
/// This class manages the lifecycle of the Rust runtime and provides
/// Swift-friendly APIs for calling BAML functions.
public final class BamlRuntimeFFI: @unchecked Sendable {
    /// Opaque pointer to the Rust runtime
    private let runtime: UnsafeMutableRawPointer

    /// Create a runtime from embedded BAML source files
    /// - Parameters:
    ///   - rootPath: Root path for BAML files (used for relative imports)
    ///   - sourceFiles: Dictionary mapping file paths to file contents
    ///   - envVars: Environment variables to pass to the runtime
    /// - Throws: BamlFFIError if runtime creation fails
    public init(rootPath: String, sourceFiles: [String: String], envVars: [String: String] = [:]) throws {
        // Ensure callbacks are registered
        CallbackManager.shared.registerCallbacksIfNeeded()

        // Encode source files as JSON
        let srcJson: Data
        do {
            srcJson = try JSONEncoder().encode(sourceFiles)
        } catch {
            throw BamlFFIError.encodingError("Failed to encode source files: \(error)")
        }

        // Encode env vars as JSON
        let envJson: Data
        do {
            envJson = try JSONEncoder().encode(envVars)
        } catch {
            throw BamlFFIError.encodingError("Failed to encode environment variables: \(error)")
        }

        // Convert to C strings and create runtime
        guard let srcString = String(data: srcJson, encoding: .utf8),
              let envString = String(data: envJson, encoding: .utf8) else {
            throw BamlFFIError.encodingError("Failed to convert JSON to string")
        }

        let ptr = rootPath.withCString { root in
            srcString.withCString { src in
                envString.withCString { env in
                    baml_create_runtime(root, src, env)
                }
            }
        }

        guard let runtimePtr = ptr else {
            throw BamlFFIError.runtimeCreationFailed("baml_create_runtime returned null")
        }

        self.runtime = runtimePtr
    }

    deinit {
        baml_destroy_runtime(runtime)
    }

    /// Call a BAML function asynchronously
    /// - Parameters:
    ///   - name: Name of the function to call
    ///   - args: JSON-encoded arguments
    /// - Returns: JSON-encoded result data
    /// - Throws: BamlFFIError on failure
    public func callFunction(_ name: String, args: Data) async throws -> Data {
        let callId = CallbackManager.shared.getNextCallId()

        return try await withCheckedThrowingContinuation { continuation in
            CallbackManager.shared.registerCall(callId, continuation: continuation)

            let buffer = name.withCString { namePtr in
                args.withUnsafeBytes { argsPtr in
                    baml_call_function(
                        runtime,
                        namePtr,
                        argsPtr.baseAddress!.assumingMemoryBound(to: Int8.self),
                        args.count,
                        callId
                    )
                }
            }

            // Check for immediate error in buffer
            if let data = buffer.toData() {
                // Try to parse as error response
                if let response = try? JSONDecoder().decode(FFIResponse.self, from: data) {
                    if let error = response.error {
                        CallbackManager.shared.removeCall(callId)
                        continuation.resume(throwing: BamlFFIError.functionCallFailed(error))
                        baml_free_buffer(buffer)
                        return
                    }
                }
            }

            baml_free_buffer(buffer)
        }
    }

    /// Call a BAML function with streaming
    /// - Parameters:
    ///   - name: Name of the function to call
    ///   - args: JSON-encoded arguments
    /// - Returns: AsyncThrowingStream of partial results
    public func callFunctionStream(_ name: String, args: Data) -> AsyncThrowingStream<Data, Error> {
        let callId = CallbackManager.shared.getNextCallId()

        return AsyncThrowingStream { continuation in
            CallbackManager.shared.registerStreamCall(callId, continuation: continuation)

            continuation.onTermination = { _ in
                CallbackManager.shared.removeStreamCall(callId)
            }

            let buffer = name.withCString { namePtr in
                args.withUnsafeBytes { argsPtr in
                    baml_call_function_stream(
                        runtime,
                        namePtr,
                        argsPtr.baseAddress!.assumingMemoryBound(to: Int8.self),
                        args.count,
                        callId
                    )
                }
            }

            // Check for immediate error
            if let data = buffer.toData() {
                if let response = try? JSONDecoder().decode(FFIResponse.self, from: data) {
                    if let error = response.error {
                        CallbackManager.shared.removeStreamCall(callId)
                        continuation.finish(throwing: BamlFFIError.functionCallFailed(error))
                    }
                }
            }

            baml_free_buffer(buffer)
        }
    }

    /// Call an object method (for TypeBuilder operations, etc.)
    /// - Parameter args: JSON-encoded method call arguments
    /// - Returns: JSON-encoded result data
    /// - Throws: BamlFFIError on failure
    public func callObjectMethod(_ args: Data) throws -> Data {
        let buffer = args.withUnsafeBytes { argsPtr in
            baml_call_object_method(
                runtime,
                argsPtr.baseAddress!.assumingMemoryBound(to: Int8.self),
                args.count
            )
        }

        defer { baml_free_buffer(buffer) }

        guard let data = buffer.toData() else {
            throw BamlFFIError.invalidResponse("Empty response from call_object_method")
        }

        // Check for error in response
        if let response = try? JSONDecoder().decode(FFIResponse.self, from: data) {
            if let error = response.error {
                throw BamlFFIError.functionCallFailed(error)
            }
        }

        return data
    }

    /// Get the output format JSON schema for a function
    /// - Parameter functionName: Name of the function
    /// - Returns: JSON schema string
    /// - Throws: BamlFFIError on failure
    public func getOutputFormat(_ functionName: String) throws -> String {
        let buffer = functionName.withCString { namePtr in
            baml_get_output_format(runtime, namePtr)
        }

        defer { baml_free_buffer(buffer) }

        guard let schema = buffer.toString() else {
            throw BamlFFIError.invalidResponse("Empty response from get_output_format")
        }

        return schema
    }

    /// Render a prompt template with arguments
    /// - Parameters:
    ///   - functionName: Name of the function
    ///   - args: JSON-encoded arguments
    /// - Returns: Rendered prompt string
    /// - Throws: BamlFFIError on failure
    public func renderPrompt(_ functionName: String, args: Data) throws -> String {
        let buffer = functionName.withCString { namePtr in
            args.withUnsafeBytes { argsPtr in
                baml_render_prompt(
                    runtime,
                    namePtr,
                    argsPtr.baseAddress!.assumingMemoryBound(to: Int8.self),
                    args.count
                )
            }
        }

        defer { baml_free_buffer(buffer) }

        guard let prompt = buffer.toString() else {
            throw BamlFFIError.invalidResponse("Empty response from render_prompt")
        }

        return prompt
    }
}

// MARK: - FFI Response

/// Internal structure for parsing FFI responses
private struct FFIResponse: Decodable {
    let error: String?
    let result: AnyCodable?
}

/// Type-erased Codable for parsing unknown JSON structures
private struct AnyCodable: Decodable {
    init(from decoder: Decoder) throws {
        // Just consume the value, we don't need to store it
        _ = try decoder.singleValueContainer()
    }
}

#endif // BAML_FFI_ENABLED
