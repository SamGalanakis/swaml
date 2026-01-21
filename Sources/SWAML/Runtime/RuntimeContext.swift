import Foundation

/// Context for BAML function execution
public struct RuntimeContext: Sendable {
    /// Tags for this execution (for logging/tracing)
    public let tags: [String: String]

    /// Client name override (uses default if nil)
    public let clientName: String?

    /// Temperature override
    public let temperature: Double?

    /// Max tokens override
    public let maxTokens: Int?

    /// Response format override
    public let responseFormat: ResponseFormat?

    /// Custom headers to include in requests
    public let customHeaders: [String: String]

    /// Timeout for the request (in seconds)
    public let timeout: TimeInterval?

    public init(
        tags: [String: String] = [:],
        clientName: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        responseFormat: ResponseFormat? = nil,
        customHeaders: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) {
        self.tags = tags
        self.clientName = clientName
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.responseFormat = responseFormat
        self.customHeaders = customHeaders
        self.timeout = timeout
    }

    /// Create a child context with merged settings
    public func child(
        tags: [String: String] = [:],
        clientName: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        responseFormat: ResponseFormat? = nil,
        customHeaders: [String: String] = [:]
    ) -> RuntimeContext {
        RuntimeContext(
            tags: self.tags.merging(tags) { _, new in new },
            clientName: clientName ?? self.clientName,
            temperature: temperature ?? self.temperature,
            maxTokens: maxTokens ?? self.maxTokens,
            responseFormat: responseFormat ?? self.responseFormat,
            customHeaders: self.customHeaders.merging(customHeaders) { _, new in new },
            timeout: self.timeout
        )
    }

    /// Default context with no overrides
    public static let `default` = RuntimeContext()
}

// MARK: - Context Builder

/// Builder for creating RuntimeContext with fluent interface
public class RuntimeContextBuilder {
    private var tags: [String: String] = [:]
    private var clientName: String?
    private var temperature: Double?
    private var maxTokens: Int?
    private var responseFormat: ResponseFormat?
    private var customHeaders: [String: String] = [:]
    private var timeout: TimeInterval?

    public init() {}

    @discardableResult
    public func tag(_ key: String, _ value: String) -> RuntimeContextBuilder {
        tags[key] = value
        return self
    }

    @discardableResult
    public func tags(_ tags: [String: String]) -> RuntimeContextBuilder {
        self.tags.merge(tags) { _, new in new }
        return self
    }

    @discardableResult
    public func client(_ name: String) -> RuntimeContextBuilder {
        clientName = name
        return self
    }

    @discardableResult
    public func temperature(_ value: Double) -> RuntimeContextBuilder {
        temperature = value
        return self
    }

    @discardableResult
    public func maxTokens(_ value: Int) -> RuntimeContextBuilder {
        maxTokens = value
        return self
    }

    @discardableResult
    public func responseFormat(_ format: ResponseFormat) -> RuntimeContextBuilder {
        responseFormat = format
        return self
    }

    @discardableResult
    public func header(_ key: String, _ value: String) -> RuntimeContextBuilder {
        customHeaders[key] = value
        return self
    }

    @discardableResult
    public func timeout(_ seconds: TimeInterval) -> RuntimeContextBuilder {
        timeout = seconds
        return self
    }

    public func build() -> RuntimeContext {
        RuntimeContext(
            tags: tags,
            clientName: clientName,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: responseFormat,
            customHeaders: customHeaders,
            timeout: timeout
        )
    }
}

// MARK: - Convenience

extension RuntimeContext {
    /// Create a context with a specific client
    public static func withClient(_ name: String) -> RuntimeContext {
        RuntimeContext(clientName: name)
    }

    /// Create a context with tags
    public static func withTags(_ tags: [String: String]) -> RuntimeContext {
        RuntimeContext(tags: tags)
    }

    /// Create a context builder
    public static func builder() -> RuntimeContextBuilder {
        RuntimeContextBuilder()
    }
}
