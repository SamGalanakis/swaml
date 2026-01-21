import Foundation

/// Response from an LLM API call
public struct LLMResponse: Sendable {
    /// The generated text content
    public let content: String

    /// The model that generated the response
    public let model: String

    /// Token usage information
    public let usage: Usage?

    /// The reason the model stopped generating
    public let finishReason: FinishReason?

    /// The unique ID of this response
    public let id: String?

    public init(
        content: String,
        model: String,
        usage: Usage? = nil,
        finishReason: FinishReason? = nil,
        id: String? = nil
    ) {
        self.content = content
        self.model = model
        self.usage = usage
        self.finishReason = finishReason
        self.id = id
    }
}

extension LLMResponse {
    /// Token usage statistics
    public struct Usage: Codable, Sendable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int

        public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
        }

        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    /// Reason the model stopped generating
    public enum FinishReason: String, Codable, Sendable {
        case stop
        case length
        case contentFilter = "content_filter"
        case toolCalls = "tool_calls"
        case endTurn = "end_turn"
        case maxTokens = "max_tokens"

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = FinishReason(rawValue: rawValue) ?? .stop
        }
    }
}

/// Response format specification for structured outputs
public enum ResponseFormat: Sendable {
    case text
    case jsonObject
    case jsonSchema(name: String, schema: [String: Any], strict: Bool)

    func toRequestFormat() -> [String: Any] {
        switch self {
        case .text:
            return ["type": "text"]
        case .jsonObject:
            return ["type": "json_object"]
        case .jsonSchema(let name, let schema, let strict):
            return [
                "type": "json_schema",
                "json_schema": [
                    "name": name,
                    "schema": schema,
                    "strict": strict
                ]
            ]
        }
    }
}

// MARK: - OpenAI API Response Structures

struct OpenAICompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: LLMResponse.Usage?

    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: LLMResponse.FinishReason?

        private enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Codable {
        let role: String
        let content: String?
    }
}

// MARK: - Anthropic API Response Structures

struct AnthropicCompletionResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    let usage: AnthropicUsage

    private enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }

    struct AnthropicUsage: Codable {
        let inputTokens: Int
        let outputTokens: Int

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }

        var toLLMUsage: LLMResponse.Usage {
            LLMResponse.Usage(
                promptTokens: inputTokens,
                completionTokens: outputTokens,
                totalTokens: inputTokens + outputTokens
            )
        }
    }
}
