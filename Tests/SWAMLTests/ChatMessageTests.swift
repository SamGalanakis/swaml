import XCTest
@testable import SWAML

final class ChatMessageTests: XCTestCase {

    // MARK: - Basic Message Creation

    func testSystemMessage() {
        let msg = ChatMessage.system("You are a helpful assistant.")

        XCTAssertEqual(msg.role, .system)
        XCTAssertEqual(msg.content.textValue, "You are a helpful assistant.")
    }

    func testUserMessage() {
        let msg = ChatMessage.user("Hello!")

        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content.textValue, "Hello!")
    }

    func testAssistantMessage() {
        let msg = ChatMessage.assistant("Hi there!")

        XCTAssertEqual(msg.role, .assistant)
        XCTAssertEqual(msg.content.textValue, "Hi there!")
    }

    // MARK: - Direct Initialization

    func testDirectInitWithString() {
        let msg = ChatMessage(role: .user, content: "Test message")

        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content.textValue, "Test message")
    }

    func testDirectInitWithContent() {
        let content = ChatMessage.Content.text("Direct content")
        let msg = ChatMessage(role: .assistant, content: content)

        XCTAssertEqual(msg.role, .assistant)
        XCTAssertEqual(msg.content.textValue, "Direct content")
    }

    // MARK: - Content Types

    func testTextContent() {
        let content = ChatMessage.Content.text("Hello world")

        XCTAssertEqual(content.textValue, "Hello world")
    }

    func testMultipartContentTextValue() {
        let content = ChatMessage.Content.multipart([
            .text("Hello "),
            .text("world!")
        ])

        XCTAssertEqual(content.textValue, "Hello world!")
    }

    func testMultipartContentWithImageIgnoresImage() {
        let content = ChatMessage.Content.multipart([
            .text("Here's an image: "),
            .imageURL(URL(string: "https://example.com/image.png")!),
            .text(" What do you see?")
        ])

        XCTAssertEqual(content.textValue, "Here's an image:  What do you see?")
    }

    // MARK: - Content Parts

    func testTextPart() {
        let part = ChatMessage.ContentPart.text("Hello")

        if case .text(let text) = part {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected text part")
        }
    }

    func testImageURLPart() {
        let url = URL(string: "https://example.com/image.png")!
        let part = ChatMessage.ContentPart.imageURL(url)

        if case .imageURL(let partURL) = part {
            XCTAssertEqual(partURL, url)
        } else {
            XCTFail("Expected imageURL part")
        }
    }

    func testImageBase64Part() {
        let part = ChatMessage.ContentPart.imageBase64(data: "base64data==", mediaType: "image/png")

        if case .imageBase64(let data, let mediaType) = part {
            XCTAssertEqual(data, "base64data==")
            XCTAssertEqual(mediaType, "image/png")
        } else {
            XCTFail("Expected imageBase64 part")
        }
    }

    // MARK: - Role Encoding

    func testRoleRawValues() {
        XCTAssertEqual(ChatMessage.Role.system.rawValue, "system")
        XCTAssertEqual(ChatMessage.Role.user.rawValue, "user")
        XCTAssertEqual(ChatMessage.Role.assistant.rawValue, "assistant")
    }

    // MARK: - Equatable

    func testMessageEquality() {
        let msg1 = ChatMessage.user("Hello")
        let msg2 = ChatMessage.user("Hello")
        let msg3 = ChatMessage.user("Goodbye")
        let msg4 = ChatMessage.assistant("Hello")

        XCTAssertEqual(msg1, msg2)
        XCTAssertNotEqual(msg1, msg3)
        XCTAssertNotEqual(msg1, msg4)
    }

    func testContentEquality() {
        let c1 = ChatMessage.Content.text("Hello")
        let c2 = ChatMessage.Content.text("Hello")
        let c3 = ChatMessage.Content.text("World")

        XCTAssertEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
    }

    func testContentPartEquality() {
        let p1 = ChatMessage.ContentPart.text("Hello")
        let p2 = ChatMessage.ContentPart.text("Hello")
        let p3 = ChatMessage.ContentPart.text("World")

        XCTAssertEqual(p1, p2)
        XCTAssertNotEqual(p1, p3)
    }

    // MARK: - Codable - Text Content

    func testEncodeDecodeTextMessage() throws {
        let original = ChatMessage.user("Hello, world!")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content.textValue, "Hello, world!")
    }

    func testDecodeTextContentFromString() throws {
        let json = #"{"role": "user", "content": "Simple text"}"#
        let data = json.data(using: .utf8)!

        let decoder = JSONDecoder()
        let msg = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content.textValue, "Simple text")
    }

    // MARK: - Codable - Multipart Content

    func testEncodeDecodeMultipartTextMessage() throws {
        let original = ChatMessage(
            role: .user,
            content: .multipart([
                .text("Part 1"),
                .text("Part 2")
            ])
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.content.textValue, "Part 1Part 2")
    }

    func testDecodeMultipartFromJSON() throws {
        let json = #"""
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "What is in this image?"},
                {"type": "image_url", "image_url": {"url": "https://example.com/image.png"}}
            ]
        }
        """#

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let msg = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(msg.role, .user)

        if case .multipart(let parts) = msg.content {
            XCTAssertEqual(parts.count, 2)

            if case .text(let text) = parts[0] {
                XCTAssertEqual(text, "What is in this image?")
            } else {
                XCTFail("Expected text part")
            }

            if case .imageURL(let url) = parts[1] {
                XCTAssertEqual(url.absoluteString, "https://example.com/image.png")
            } else {
                XCTFail("Expected imageURL part")
            }
        } else {
            XCTFail("Expected multipart content")
        }
    }

    func testDecodeBase64ImageFromJSON() throws {
        let json = #"""
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "Describe this:"},
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": "iVBORw0KGgo="
                    }
                }
            ]
        }
        """#

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let msg = try decoder.decode(ChatMessage.self, from: data)

        if case .multipart(let parts) = msg.content {
            XCTAssertEqual(parts.count, 2)

            if case .imageBase64(let imageData, let mediaType) = parts[1] {
                XCTAssertEqual(imageData, "iVBORw0KGgo=")
                XCTAssertEqual(mediaType, "image/jpeg")
            } else {
                XCTFail("Expected imageBase64 part")
            }
        } else {
            XCTFail("Expected multipart content")
        }
    }

    // MARK: - Codable Round Trip

    func testRoundTripTextContent() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ChatMessage.system("You are helpful.")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testRoundTripImageURL() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ChatMessage(
            role: .user,
            content: .multipart([
                .text("Check this:"),
                .imageURL(URL(string: "https://example.com/test.jpg")!)
            ])
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testRoundTripImageBase64() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = ChatMessage(
            role: .user,
            content: .multipart([
                .text("Analyze:"),
                .imageBase64(data: "ABC123==", mediaType: "image/png")
            ])
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatMessage.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Error Cases

    func testDecodeInvalidContentTypeFails() {
        let json = #"""
        {
            "role": "user",
            "content": [
                {"type": "video", "video_url": {"url": "https://example.com/video.mp4"}}
            ]
        }
        """#

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(ChatMessage.self, from: data))
    }

    func testDecodeInvalidImageURLFails() {
        // Use empty string which Swift's URL(string:) returns nil for
        let json = #"""
        {
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": ""}}
            ]
        }
        """#

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(ChatMessage.self, from: data))
    }
}
