import Foundation

/// Represents a message in a chat conversation
public struct ChatMessage: Codable, Sendable, Equatable {
    public let role: Role
    public let content: Content

    public init(role: Role, content: String) {
        self.role = role
        self.content = .text(content)
    }

    public init(role: Role, content: Content) {
        self.role = role
        self.content = content
    }

    /// Creates a system message
    public static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }

    /// Creates a user message
    public static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }

    /// Creates an assistant message
    public static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: content)
    }
}

extension ChatMessage {
    /// The role of a message sender
    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    /// The content of a message
    public enum Content: Codable, Sendable, Equatable {
        case text(String)
        case multipart([ContentPart])

        public var textValue: String? {
            switch self {
            case .text(let text):
                return text
            case .multipart(let parts):
                return parts.compactMap { part in
                    if case .text(let text) = part {
                        return text
                    }
                    return nil
                }.joined()
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else {
                let parts = try container.decode([ContentPart].self)
                self = .multipart(parts)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .multipart(let parts):
                try container.encode(parts)
            }
        }
    }

    /// A part of multipart content
    public enum ContentPart: Codable, Sendable, Equatable {
        case text(String)
        case imageURL(URL)
        case imageBase64(data: String, mediaType: String)

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
            case source
        }

        private enum ImageURLKeys: String, CodingKey {
            case url
        }

        private enum ImageBase64Keys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "text":
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case "image_url":
                let imageContainer = try container.nestedContainer(keyedBy: ImageURLKeys.self, forKey: .imageURL)
                let urlString = try imageContainer.decode(String.self, forKey: .url)
                guard let url = URL(string: urlString) else {
                    throw DecodingError.dataCorruptedError(forKey: .imageURL, in: container, debugDescription: "Invalid URL")
                }
                self = .imageURL(url)
            case "image":
                let sourceContainer = try container.nestedContainer(keyedBy: ImageBase64Keys.self, forKey: .source)
                let data = try sourceContainer.decode(String.self, forKey: .data)
                let mediaType = try sourceContainer.decode(String.self, forKey: .mediaType)
                self = .imageBase64(data: data, mediaType: mediaType)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .imageURL(let url):
                try container.encode("image_url", forKey: .type)
                var imageContainer = container.nestedContainer(keyedBy: ImageURLKeys.self, forKey: .imageURL)
                try imageContainer.encode(url.absoluteString, forKey: .url)
            case .imageBase64(let data, let mediaType):
                try container.encode("image", forKey: .type)
                var sourceContainer = container.nestedContainer(keyedBy: ImageBase64Keys.self, forKey: .source)
                try sourceContainer.encode("base64", forKey: .type)
                try sourceContainer.encode(mediaType, forKey: .mediaType)
                try sourceContainer.encode(data, forKey: .data)
            }
        }
    }
}
