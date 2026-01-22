import Foundation

// MARK: - FFI Runtime Errors

/// Errors specific to FFI runtime operations
public enum BamlFFIError: Error, LocalizedError, Sendable {
    case libraryNotLoaded
    case runtimeCreationFailed(String)
    case functionCallFailed(String)
    case invalidResponse(String)
    case callbackError(String)
    case encodingError(String)
    case decodingError(String)
    case timeout
    /// Validation error with optional raw LLM output for repair
    case validationError(BamlValidationErrorInfo)

    public var errorDescription: String? {
        switch self {
        case .libraryNotLoaded:
            return "BAML FFI library not loaded. Ensure libbaml_ffi.so (Linux) or BamlFFI.framework (Apple) is available."
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
        case .validationError(let info):
            return "Validation error: \(info.message)"
        }
    }
}

/// Structured validation error info with raw output for repair
public struct BamlValidationErrorInfo: Sendable, Equatable {
    /// Maximum length for error message (for display purposes)
    private static let maxMessageLength = 200

    /// The validation error message (truncated for display, full version in fullMessage)
    public let message: String
    /// The raw LLM output that failed validation (if available)
    public let rawOutput: String?
    /// The prompt that was sent (if available)
    public let prompt: String?

    public init(message: String, rawOutput: String? = nil, prompt: String? = nil) {
        // Truncate message for cleaner error display
        if message.count > Self.maxMessageLength {
            self.message = String(message.prefix(Self.maxMessageLength)) + "... [truncated]"
        } else {
            self.message = message
        }
        self.rawOutput = rawOutput
        self.prompt = prompt
    }
}

/// Internal structure for parsing BAML FFI error responses
private struct BamlErrorResponse: Decodable {
    let message: String?
    let error: String?
    let rawOutput: String?
    let raw_output: String?
    let llmOutput: String?
    let llm_output: String?
    let prompt: String?

    /// Get the error message from various possible fields
    var errorMessage: String {
        message ?? error ?? "Unknown error"
    }

    /// Get raw output from various possible fields
    var extractedRawOutput: String? {
        rawOutput ?? raw_output ?? llmOutput ?? llm_output
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
        guard BamlFFI.isAvailable else { return }

        callbacksRegistered = true

        BamlFFI.registerCallbacks(
            resultCallback: { callId, isDone, contentPtr, length in
                CallbackManager.shared.handleResult(
                    callId: callId,
                    isDone: isDone != 0,
                    content: contentPtr,
                    length: length
                )
            },
            errorCallback: { callId, isDone, contentPtr, length in
                CallbackManager.shared.handleError(
                    callId: callId,
                    isDone: isDone != 0,
                    content: contentPtr,
                    length: length
                )
            },
            tickCallback: { callId in
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
        let error: BamlFFIError

        if let content = content, length > 0 {
            let data = Data(bytes: content, count: length)

            // Try to parse as structured JSON error first
            if let parsedError = Self.parseStructuredError(from: data) {
                error = parsedError
            } else {
                // Fall back to plain string error
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                error = Self.categorizeError(message: errorMessage)
            }
        } else {
            error = BamlFFIError.callbackError("Unknown error")
        }

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

    /// Try to parse error data as structured JSON
    private static func parseStructuredError(from data: Data) -> BamlFFIError? {
        guard let response = try? JSONDecoder().decode(BamlErrorResponse.self, from: data) else {
            return nil
        }

        let message = response.errorMessage
        let rawOutput = response.extractedRawOutput

        // If we have raw output, it's a validation error that can potentially be repaired
        if rawOutput != nil {
            return .validationError(BamlValidationErrorInfo(
                message: message,
                rawOutput: rawOutput,
                prompt: response.prompt
            ))
        }

        // Check if message indicates a validation error
        if Self.isValidationError(message: message) {
            return .validationError(BamlValidationErrorInfo(
                message: message,
                rawOutput: Self.extractRawOutputFromMessage(message),
                prompt: nil
            ))
        }

        return nil
    }

    /// Categorize a plain string error message
    private static func categorizeError(message: String) -> BamlFFIError {
        if isValidationError(message: message) {
            return .validationError(BamlValidationErrorInfo(
                message: message,
                rawOutput: extractRawOutputFromMessage(message),
                prompt: nil
            ))
        }
        return .callbackError(message)
    }

    /// Check if an error message indicates a validation/parsing error
    private static func isValidationError(message: String) -> Bool {
        let lowercased = message.lowercased()

        // Exclude HTTP/API errors
        let httpErrorIndicators = [
            "status code:", "status_code", "400", "401", "402", "403", "404",
            "429", "500", "502", "503", "request failed", "api error",
            "rate limit", "payment required", "unauthorized", "forbidden"
        ]

        if httpErrorIndicators.contains(where: { lowercased.contains($0) }) {
            return false
        }

        // These indicate LLM output parsing/validation errors
        let validationKeywords = [
            "failed to parse", "failed to coerce", "bamlvalidationerror",
            "parse error", "invalid json", "missing required", "type mismatch",
            "enum value", "unknown variant", "deserialize", "could not find"
        ]
        return validationKeywords.contains { lowercased.contains($0) }
    }

    /// Try to extract raw LLM output from an error message
    private static func extractRawOutputFromMessage(_ message: String) -> String? {
        let patterns = [
            "LLM response:", "Raw text:", "Output:", "Got:",
            "Failed to parse:", "failed to coerce:", "```", "received:"
        ]

        for pattern in patterns {
            if let range = message.range(of: pattern, options: .caseInsensitive) {
                let afterPattern = String(message[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !afterPattern.isEmpty {
                    return afterPattern
                }
            }
        }

        if message.count > 200 && (message.contains("{") || message.contains("[")) {
            return message
        }

        return nil
    }
}

// MARK: - BAML FFI Runtime

/// Swift wrapper around the BAML Rust FFI runtime
/// This class manages the lifecycle of the Rust runtime and provides
/// Swift-friendly APIs for calling BAML functions.
public final class BamlRuntimeFFI: @unchecked Sendable {
    /// Opaque pointer to the Rust runtime
    private let runtime: UnsafeMutableRawPointer

    /// Environment variables passed to the runtime
    public let envVars: [String: String]

    /// Create a runtime from embedded BAML source files
    /// - Parameters:
    ///   - rootPath: Root path for BAML files (used for relative imports)
    ///   - sourceFiles: Dictionary mapping file paths to file contents
    ///   - envVars: Environment variables to pass to the runtime
    /// - Throws: BamlFFIError if runtime creation fails
    public init(rootPath: String, sourceFiles: [String: String], envVars: [String: String] = [:]) throws {
        // Check if FFI is available
        guard BamlFFI.isAvailable else {
            throw BamlFFIError.libraryNotLoaded
        }

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
                    BamlFFI.createRuntime(rootPath: root, srcFilesJson: src, envVarsJson: env)
                }
            }
        }

        guard let runtimePtr = ptr else {
            throw BamlFFIError.runtimeCreationFailed("create_baml_runtime returned null")
        }

        self.runtime = runtimePtr
        self.envVars = envVars
    }

    deinit {
        BamlFFI.destroyRuntime(runtime)
    }

    #if BAML_FFI_ENABLED
    /// Call a BAML function with protobuf-encoded arguments
    /// - Parameters:
    ///   - name: Name of the function to call
    ///   - arguments: HostFunctionArguments containing the function parameters
    /// - Returns: JSON-encoded result data
    /// - Throws: BamlFFIError on failure
    public func callFunctionProto(_ name: String, arguments: HostFunctionArguments) async throws -> Data {
        let args: Data
        do {
            args = try arguments.serializedData()
        } catch {
            throw BamlFFIError.encodingError("Failed to serialize arguments: \(error)")
        }
        let responseData = try await callFunction(name, args: args)

        // Decode protobuf response to JSON
        do {
            return try decodeFFIResponse(responseData)
        } catch {
            throw BamlFFIError.decodingError("Failed to decode FFI response: \(error)")
        }
    }
    #endif

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
                    BamlFFI.callFunction(
                        runtime: runtime,
                        functionName: namePtr,
                        encodedArgs: argsPtr.baseAddress!.assumingMemoryBound(to: Int8.self),
                        length: args.count,
                        callId: callId
                    )
                }
            }

            // Check for immediate error in buffer
            if let data = buffer.toData() {
                if let response = try? JSONDecoder().decode(FFIResponse.self, from: data) {
                    if let error = response.error {
                        CallbackManager.shared.removeCall(callId)
                        continuation.resume(throwing: BamlFFIError.functionCallFailed(error))
                        BamlFFI.freeBuffer(buffer)
                        return
                    }
                }
            }

            BamlFFI.freeBuffer(buffer)
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
                    BamlFFI.callFunctionStream(
                        runtime: runtime,
                        functionName: namePtr,
                        encodedArgs: argsPtr.baseAddress!.assumingMemoryBound(to: Int8.self),
                        length: args.count,
                        callId: callId
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

            BamlFFI.freeBuffer(buffer)
        }
    }

    /// Call an object method (for TypeBuilder operations, etc.)
    /// - Parameter args: JSON-encoded method call arguments
    /// - Returns: JSON-encoded result data
    /// - Throws: BamlFFIError on failure
    public func callObjectMethod(_ args: Data) throws -> Data {
        let buffer = args.withUnsafeBytes { argsPtr in
            BamlFFI.callObjectMethod(
                runtime: runtime,
                encodedArgs: argsPtr.baseAddress!.assumingMemoryBound(to: Int8.self),
                length: args.count
            )
        }

        defer { BamlFFI.freeBuffer(buffer) }

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
}

// MARK: - FFI Response

/// Internal structure for parsing FFI responses
private struct FFIResponse: Decodable {
    let error: String?
    let result: AnyCodable?
}

/// Type-erased Codable for parsing unknown JSON structures
private struct AnyCodable: Decodable {
    init(from decoder: any Swift.Decoder) throws {
        _ = try decoder.singleValueContainer()
    }
}
