import XCTest
@testable import SWAML

/// Integration tests modeled on ellie-wrapped BAML schema
final class IntegrationTests: XCTestCase {

    // MARK: - Ellie-Wrapped Style Types

    // Animal archetype enum (subset of the 40+ values)
    enum FriendAnimalArchetype: String, Codable, CaseIterable {
        case ant = "Ant"
        case bear = "Bear"
        case dog = "Dog"
        case dolphin = "Dolphin"
        case fox = "Fox"
        case owl = "Owl"
        case wolf = "Wolf"
    }

    enum MomentCategory: String, Codable {
        case highlight = "Highlight"
        case lowlight = "Lowlight"
        case achievement = "Achievement"
    }

    struct Moment: Codable, Equatable {
        let messageIndex: Int
        let title: String
        let text: String
        let quote: String
        let emoji: String
        let category: MomentCategory

        enum CodingKeys: String, CodingKey {
            case messageIndex = "message_index"
            case title, text, quote, emoji, category
        }
    }

    struct CommunicationStyleItem: Codable, Equatable {
        let score: Double
        let note: String
    }

    struct CommunicationStyle: Codable, Equatable {
        let assertiveness: CommunicationStyleItem
        let emotionality: CommunicationStyleItem
        let positivity: CommunicationStyleItem
        let summary: String
    }

    struct RelationshipHealthScore: Codable, Equatable {
        let score: Double
        let note: String
    }

    struct RecurringTopic: Codable, Equatable {
        let topic: String
        let initiatorScore: Double
        let note: String

        enum CodingKeys: String, CodingKey {
            case topic
            case initiatorScore = "initiator_score"
            case note
        }
    }

    struct ChatAnalysisResult: Codable, Equatable {
        let contactTitles: [String]
        let contactAnimal: FriendAnimalArchetype
        let relationshipHealth: RelationshipHealthScore
        let isFamily: Bool
        let isAlreadyRomanticConnection: Bool
        let recurringTopics: [RecurringTopic]
        let moments: [Moment]
        let communicationStyle: CommunicationStyle
        let roasts: [String]
        let improvementTips: [String]
        let userAvgResponseTimeSeconds: Int
        let contactAvgResponseTimeSeconds: Int
        let userCommunicationIq: Int
        let contactCommunicationIq: Int

        enum CodingKeys: String, CodingKey {
            case contactTitles = "contact_titles"
            case contactAnimal = "contact_animal"
            case relationshipHealth = "relationship_health"
            case isFamily = "is_family"
            case isAlreadyRomanticConnection = "is_already_romantic_connection"
            case recurringTopics = "recurring_topics"
            case moments
            case communicationStyle = "communication_style"
            case roasts
            case improvementTips = "improvement_tips"
            case userAvgResponseTimeSeconds = "user_avg_response_time_seconds"
            case contactAvgResponseTimeSeconds = "contact_avg_response_time_seconds"
            case userCommunicationIq = "user_communication_iq"
            case contactCommunicationIq = "contact_communication_iq"
        }
    }

    // MARK: - Parse Complex Nested Response

    func testParseComplexChatAnalysisResult() throws {
        let json = #"""
        {
            "contact_titles": ["Your anchor", "The one who gets it", "Your chaos partner"],
            "contact_animal": "Dog",
            "relationship_health": {"score": 0.85, "note": "You two have a strong connection"},
            "is_family": false,
            "is_already_romantic_connection": false,
            "recurring_topics": [
                {"topic": "Work stress", "initiator_score": 0.7, "note": "You vent, she listens"},
                {"topic": "Weekend plans", "initiator_score": 0.5, "note": "Both of you bring it up equally"}
            ],
            "moments": [
                {
                    "message_index": 42,
                    "title": "Got the promotion",
                    "text": "The moment you shared the big news",
                    "quote": "I GOT IT!!!",
                    "emoji": "🎉",
                    "category": "Achievement"
                },
                {
                    "message_index": 128,
                    "title": "Late night support",
                    "text": "When she was there at 2am",
                    "quote": "I'm always here for you",
                    "emoji": "💙",
                    "category": "Highlight"
                }
            ],
            "communication_style": {
                "assertiveness": {"score": 0.6, "note": "You speak your mind when it matters"},
                "emotionality": {"score": 0.75, "note": "You wear your heart on your sleeve"},
                "positivity": {"score": 0.8, "note": "You bring the good vibes"},
                "summary": "You communicate with warmth and authenticity"
            },
            "roasts": [
                "You text like you're being charged per character",
                "Your response time could qualify as ghosting in some countries"
            ],
            "improvement_tips": [
                "Try asking more follow-up questions",
                "Don't disappear for weeks without warning"
            ],
            "user_avg_response_time_seconds": 3600,
            "contact_avg_response_time_seconds": 1800,
            "user_communication_iq": 112,
            "contact_communication_iq": 108
        }
        """#

        let result: ChatAnalysisResult = try OutputParser.parse(json, type: ChatAnalysisResult.self)

        // Verify top-level fields
        XCTAssertEqual(result.contactTitles.count, 3)
        XCTAssertEqual(result.contactTitles[0], "Your anchor")
        XCTAssertEqual(result.contactAnimal, .dog)
        XCTAssertFalse(result.isFamily)
        XCTAssertFalse(result.isAlreadyRomanticConnection)

        // Verify nested objects
        XCTAssertEqual(result.relationshipHealth.score, 0.85)
        XCTAssertEqual(result.relationshipHealth.note, "You two have a strong connection")

        // Verify arrays of objects
        XCTAssertEqual(result.recurringTopics.count, 2)
        XCTAssertEqual(result.recurringTopics[0].topic, "Work stress")
        XCTAssertEqual(result.recurringTopics[0].initiatorScore, 0.7)

        XCTAssertEqual(result.moments.count, 2)
        XCTAssertEqual(result.moments[0].title, "Got the promotion")
        XCTAssertEqual(result.moments[0].category, .achievement)
        XCTAssertEqual(result.moments[1].category, .highlight)

        // Verify deeply nested objects
        XCTAssertEqual(result.communicationStyle.assertiveness.score, 0.6)
        XCTAssertEqual(result.communicationStyle.emotionality.score, 0.75)

        // Verify string arrays
        XCTAssertEqual(result.roasts.count, 2)
        XCTAssertEqual(result.improvementTips.count, 2)

        // Verify integer fields
        XCTAssertEqual(result.userAvgResponseTimeSeconds, 3600)
        XCTAssertEqual(result.userCommunicationIq, 112)
    }

    // MARK: - Parse from Markdown Code Block

    func testParseFromMarkdownCodeBlock() throws {
        let llmOutput = """
        Here's the analysis of your chat:

        ```json
        {
            "contact_titles": ["Best friend"],
            "contact_animal": "Bear",
            "relationship_health": {"score": 0.9, "note": "Very healthy"},
            "is_family": true,
            "is_already_romantic_connection": false,
            "recurring_topics": [],
            "moments": [],
            "communication_style": {
                "assertiveness": {"score": 0.5, "note": "Balanced"},
                "emotionality": {"score": 0.5, "note": "Balanced"},
                "positivity": {"score": 0.5, "note": "Balanced"},
                "summary": "Well-rounded communicator"
            },
            "roasts": [],
            "improvement_tips": [],
            "user_avg_response_time_seconds": 0,
            "contact_avg_response_time_seconds": 0,
            "user_communication_iq": 100,
            "contact_communication_iq": 100
        }
        ```

        Let me know if you need anything else!
        """

        let result: ChatAnalysisResult = try OutputParser.parse(llmOutput, type: ChatAnalysisResult.self)

        XCTAssertEqual(result.contactAnimal, .bear)
        XCTAssertTrue(result.isFamily)
        XCTAssertEqual(result.relationshipHealth.score, 0.9)
    }

    // MARK: - TypeBuilder for Dynamic Enums

    func testTypeBuilderForDynamicEnums() throws {
        let tb = TypeBuilder()

        // Add values to dynamic enums (like MomentId, PatternId in BAML)
        let momentEnum = tb.enumBuilder("MomentId")
        momentEnum.addValue("moment_emma_1")
        momentEnum.addValue("moment_emma_2")
        momentEnum.addValue("moment_jake_1")

        let patternEnum = tb.enumBuilder("PatternId")
        patternEnum.addValue("pattern_1")
        patternEnum.addValue("pattern_2")

        // Verify enum values are stored
        let momentValues = tb.dynamicEnumValues()["MomentId"]
        XCTAssertEqual(momentValues, ["moment_emma_1", "moment_emma_2", "moment_jake_1"])

        let patternValues = tb.dynamicEnumValues()["PatternId"]
        XCTAssertEqual(patternValues, ["pattern_1", "pattern_2"])

        // Verify schema generation for dynamic enum
        let schema = tb.buildEnumSchema("MomentId")
        XCTAssertNotNil(schema)

        if case .enum(let values) = schema {
            XCTAssertEqual(values.count, 3)
            XCTAssertTrue(values.contains("moment_emma_1"))
        } else {
            XCTFail("Expected enum schema")
        }
    }

    // MARK: - BamlValue Dynamic Access

    func testBamlValueDynamicAccess() throws {
        let json = #"""
        {
            "contact_animal": "Wolf",
            "relationship_health": {"score": 0.75, "note": "Good connection"},
            "moments": [
                {"title": "First moment", "emoji": "🎉"},
                {"title": "Second moment", "emoji": "😊"}
            ],
            "roasts": ["Roast 1", "Roast 2", "Roast 3"]
        }
        """#

        let value = try BamlValue.fromJSONString(json)

        // Access string
        XCTAssertEqual(value["contact_animal"]?.stringValue, "Wolf")

        // Access nested object
        XCTAssertEqual(value["relationship_health"]?["score"]?.doubleValue, 0.75)
        XCTAssertEqual(value["relationship_health"]?["note"]?.stringValue, "Good connection")

        // Access array
        XCTAssertEqual(value["moments"]?.arrayValue?.count, 2)
        XCTAssertEqual(value["moments"]?[0]?["title"]?.stringValue, "First moment")
        XCTAssertEqual(value["moments"]?[1]?["emoji"]?.stringValue, "😊")

        // Access string array
        XCTAssertEqual(value["roasts"]?[0]?.stringValue, "Roast 1")
        XCTAssertEqual(value["roasts"]?[2]?.stringValue, "Roast 3")
    }

    // MARK: - Large Enum Generation

    func testLargeEnumGeneration() {
        let animals = [
            "Ant", "Badger", "Bear", "Bee", "Bison", "BlackPanther", "Camel",
            "Chameleon", "Cheetah", "Chimpanzee", "Crow", "Deer", "Dog",
            "Dolphin", "Fox", "Frog", "Giraffe", "Hawk", "Hedgehog", "Hyena",
            "Koala", "Lemur", "Lion", "Lizard", "Moose", "Octopus", "Orangutan",
            "Owl", "Parrot", "Pelican", "PolarBear", "Rabbit", "Seahorse",
            "Shark", "Tiger", "Turtle", "Wolf"
        ]

        let tb = TypeBuilder()
        let builder = tb.addEnum("FriendAnimalArchetype")
        for animal in animals {
            builder.addValue(animal)
        }

        let schema = tb.buildEnumSchema("FriendAnimalArchetype")
        XCTAssertNotNil(schema)

        if case .enum(let values) = schema {
            XCTAssertEqual(values.count, animals.count)
            XCTAssertTrue(values.contains("Dog"))
            XCTAssertTrue(values.contains("Wolf"))
        } else {
            XCTFail("Expected enum schema")
        }
    }

    // MARK: - Schema Coercion

    func testSchemaCoercionForScores() throws {
        // LLMs sometimes return integers instead of floats for scores
        let json = #"{"score": 1, "note": "Perfect score"}"#

        let schema = JSONSchema.object(
            properties: [
                "score": .number,
                "note": .string
            ],
            required: ["score", "note"]
        )

        let value = try OutputParser.parseToValue(json, schema: schema)

        // Integer 1 should be accessible as double 1.0
        XCTAssertEqual(value["score"]?.doubleValue, 1.0)
    }

    // MARK: - Client Registry

    func testClientRegistrySetup() async {
        let registry = ClientRegistry()

        await registry.register(
            name: "TextClient",
            provider: .openRouter(apiKey: "test-key"),
            model: "anthropic/claude-sonnet-4-20250514",
            isDefault: true
        )

        await registry.register(
            name: "FastClient",
            provider: .openRouter(apiKey: "test-key"),
            model: "anthropic/claude-3-5-haiku-latest"
        )

        let names = await registry.clientNames
        XCTAssertEqual(names.count, 2)
        XCTAssertTrue(names.contains("TextClient"))
        XCTAssertTrue(names.contains("FastClient"))

        let defaultConfig = await registry.getDefaultConfig()
        XCTAssertEqual(defaultConfig?.name, "TextClient")
        XCTAssertEqual(defaultConfig?.model, "anthropic/claude-sonnet-4-20250514")
    }
}
