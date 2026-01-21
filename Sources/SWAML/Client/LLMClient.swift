import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP client for making requests to LLM APIs
public actor LLMClient {
    public let provider: LLMProvider
    private let session: URLSession

    public init(provider: LLMProvider, session: URLSession? = nil) {
        self.provider = provider
        self.session = session ?? URLSession.shared
    }

    /// Send a chat completion request to the LLM
    public func complete(
        model: String,
        messages: [ChatMessage],
        responseFormat: ResponseFormat? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        stop: [String]? = nil
    ) async throws -> LLMResponse {
        if provider.isOpenAICompatible {
            return try await completeOpenAI(
                model: model,
                messages: messages,
                responseFormat: responseFormat,
                temperature: temperature,
                maxTokens: maxTokens,
                topP: topP,
                stop: stop
            )
        } else {
            return try await completeAnthropic(
                model: model,
                messages: messages,
                temperature: temperature,
                maxTokens: maxTokens ?? 4096,
                topP: topP,
                stop: stop
            )
        }
    }

    // MARK: - OpenAI-Compatible API

    private func completeOpenAI(
        model: String,
        messages: [ChatMessage],
        responseFormat: ResponseFormat?,
        temperature: Double?,
        maxTokens: Int?,
        topP: Double?,
        stop: [String]?
    ) async throws -> LLMResponse {
        let url = provider.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let auth = provider.authHeader
        request.setValue(auth.value, forHTTPHeaderField: auth.name)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in provider.additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { encodeOpenAIMessage($0) }
        ]

        if let responseFormat = responseFormat {
            body["response_format"] = responseFormat.toRequestFormat()
        }
        if let temperature = temperature {
            body["temperature"] = temperature
        }
        if let maxTokens = maxTokens {
            body["max_tokens"] = maxTokens
        }
        if let topP = topP {
            body["top_p"] = topP
        }
        if let stop = stop, !stop.isEmpty {
            body["stop"] = stop
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BamlError.networkError("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BamlError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(OpenAICompletionResponse.self, from: data)

        guard let choice = apiResponse.choices.first,
              let content = choice.message.content else {
            throw BamlError.parseError("No content in response")
        }

        return LLMResponse(
            content: content,
            model: apiResponse.model,
            usage: apiResponse.usage,
            finishReason: choice.finishReason,
            id: apiResponse.id
        )
    }

    private func encodeOpenAIMessage(_ message: ChatMessage) -> [String: Any] {
        var dict: [String: Any] = ["role": message.role.rawValue]

        switch message.content {
        case .text(let text):
            dict["content"] = text
        case .multipart(let parts):
            dict["content"] = parts.map { encodeContentPart($0) }
        }

        return dict
    }

    private func encodeContentPart(_ part: ChatMessage.ContentPart) -> [String: Any] {
        switch part {
        case .text(let text):
            return ["type": "text", "text": text]
        case .imageURL(let url):
            return ["type": "image_url", "image_url": ["url": url.absoluteString]]
        case .imageBase64(let data, let mediaType):
            return ["type": "image_url", "image_url": ["url": "data:\(mediaType);base64,\(data)"]]
        }
    }

    // MARK: - Anthropic API

    private func completeAnthropic(
        model: String,
        messages: [ChatMessage],
        temperature: Double?,
        maxTokens: Int,
        topP: Double?,
        stop: [String]?
    ) async throws -> LLMResponse {
        let url = provider.baseURL.appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let auth = provider.authHeader
        request.setValue(auth.value, forHTTPHeaderField: auth.name)

        for (key, value) in provider.additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Anthropic requires system message to be separate
        var systemMessage: String? = nil
        var anthropicMessages: [[String: Any]] = []

        for message in messages {
            if message.role == .system {
                systemMessage = message.content.textValue
            } else {
                anthropicMessages.append(encodeAnthropicMessage(message))
            }
        }

        var body: [String: Any] = [
            "model": model,
            "messages": anthropicMessages,
            "max_tokens": maxTokens
        ]

        if let systemMessage = systemMessage {
            body["system"] = systemMessage
        }
        if let temperature = temperature {
            body["temperature"] = temperature
        }
        if let topP = topP {
            body["top_p"] = topP
        }
        if let stop = stop, !stop.isEmpty {
            body["stop_sequences"] = stop
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BamlError.networkError("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BamlError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(AnthropicCompletionResponse.self, from: data)

        let content = apiResponse.content
            .compactMap { $0.text }
            .joined()

        let finishReason: LLMResponse.FinishReason? = {
            guard let reason = apiResponse.stopReason else { return nil }
            return LLMResponse.FinishReason(rawValue: reason)
        }()

        return LLMResponse(
            content: content,
            model: apiResponse.model,
            usage: apiResponse.usage.toLLMUsage,
            finishReason: finishReason,
            id: apiResponse.id
        )
    }

    private func encodeAnthropicMessage(_ message: ChatMessage) -> [String: Any] {
        var dict: [String: Any] = ["role": message.role.rawValue]

        switch message.content {
        case .text(let text):
            dict["content"] = text
        case .multipart(let parts):
            dict["content"] = parts.map { encodeAnthropicContentPart($0) }
        }

        return dict
    }

    private func encodeAnthropicContentPart(_ part: ChatMessage.ContentPart) -> [String: Any] {
        switch part {
        case .text(let text):
            return ["type": "text", "text": text]
        case .imageURL(let url):
            // Anthropic doesn't support URL directly, would need to fetch and convert
            return ["type": "text", "text": "[Image URL: \(url.absoluteString)]"]
        case .imageBase64(let data, let mediaType):
            return [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": mediaType,
                    "data": data
                ]
            ]
        }
    }
}
