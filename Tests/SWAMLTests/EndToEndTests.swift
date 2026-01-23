import XCTest
@testable import SWAML

/// Comprehensive end-to-end tests for the pure Swift implementation
final class EndToEndTests: XCTestCase {

    // MARK: - Nested Types with Dynamic Enums

    func testNestedTypesWithDynamicEnum() throws {
        // Build dynamic types
        let tb = TypeBuilder()

        // Dynamic enum for sentiment categories
        let sentiment = tb.enumBuilder("Sentiment")
        sentiment.addValue("positive")
        sentiment.addValue("negative")
        sentiment.addValue("neutral")
        sentiment.addValue("mixed")

        // Dynamic class with nested structure
        let analysis = tb.addClass("Analysis")
        analysis.addProperty("sentiment", .reference("Sentiment")).description("The detected sentiment")
        analysis.addProperty("confidence", .float).description("Confidence score 0-1")
        analysis.addProperty("keywords", .list(.string)).description("Key words found")

        // Build schema
        let schema = tb.buildClassSchema("Analysis")!

        // Render prompt
        let prompt = SchemaPromptRenderer.render(schema: schema, typeBuilder: tb)

        // Verify BAML format
        XCTAssertTrue(prompt.contains("Answer in JSON using this schema:"), "Missing schema header")
        XCTAssertTrue(prompt.contains("sentiment:"), "Missing sentiment field")
        // Check that enum values are rendered (order may vary due to sorting)
        XCTAssertTrue(prompt.contains("\"positive\""), "Missing positive value")
        XCTAssertTrue(prompt.contains("\"negative\""), "Missing negative value")
        XCTAssertTrue(prompt.contains("\"neutral\""), "Missing neutral value")
        XCTAssertTrue(prompt.contains("\"mixed\""), "Missing mixed value")
        XCTAssertTrue(prompt.contains("confidence: float"), "Missing confidence field")
        XCTAssertTrue(prompt.contains("keywords: string[]"), "Missing keywords field")
        XCTAssertTrue(prompt.contains("// The detected sentiment"), "Missing description")
    }

    func testDeeplyNestedDynamicTypes() throws {
        let tb = TypeBuilder()

        // Nested level 3
        let score = tb.addClass("Score")
        score.addProperty("value", .float)
        score.addProperty("category", .string)

        // Nested level 2
        let pattern = tb.addClass("Pattern")
        pattern.addProperty("name", .string)
        pattern.addProperty("frequency", .int)
        pattern.addProperty("scores", .list(.reference("Score")))

        // Nested level 1
        let result = tb.addClass("AnalysisResult")
        result.addProperty("patterns", .list(.reference("Pattern")))
        result.addProperty("summary", .string)

        // Build and render
        let schema = tb.buildClassSchema("AnalysisResult")!
        let prompt = SchemaPromptRenderer.render(schema: schema, typeBuilder: tb)

        XCTAssertTrue(prompt.contains("patterns:"))
        XCTAssertTrue(prompt.contains("summary: string"))
    }

    // MARK: - Parsing BAML-Style LLM Output

    func testParseTypicalLLMResponse() throws {
        // Simulate typical LLM output with explanatory text
        let llmOutput = """
            I've analyzed the text and here are my findings:

            ```json
            {
              "sentiment": "positive",
              "confidence": 0.92,
              "keywords": ["excellent", "amazing", "love"],
              "reasons": [
                "Strong positive adjectives used",
                "Enthusiastic tone throughout"
              ]
            }
            ```

            The overall sentiment is clearly positive based on the language used.
            """

        let result = try JsonishParser.parse(llmOutput)

        // Verify parsed JSON
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["sentiment"] as? String, "positive")
        XCTAssertEqual(json["confidence"] as? Double, 0.92)
        XCTAssertEqual((json["keywords"] as? [String])?.count, 3)
        XCTAssertEqual((json["reasons"] as? [String])?.count, 2)
    }

    func testParseUnquotedKeysAndTrailingCommas() throws {
        // BAML-style output with unquoted keys and trailing commas
        let llmOutput = """
            {
              sentiment: "positive",
              confidence: 0.85,
              tags: ["happy", "excited",],
            }
            """

        let result = try JsonishParser.parse(llmOutput)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["sentiment"] as? String, "positive")
        XCTAssertEqual(json["confidence"] as? Double, 0.85)
        XCTAssertEqual((json["tags"] as? [String])?.count, 2)
    }

    func testParseWithComments() throws {
        let llmOutput = """
            {
              // The main sentiment
              "sentiment": "negative",
              /* Confidence level */
              "confidence": 0.75,
              "issues": [
                "Poor customer service", // Main complaint
                "Long wait times"
              ]
            }
            """

        let result = try JsonishParser.parse(llmOutput)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["sentiment"] as? String, "negative")
        XCTAssertEqual((json["issues"] as? [String])?.count, 2)
    }

    func testParseSingleQuotes() throws {
        let llmOutput = """
            {
              'name': 'Alice',
              'status': 'active',
              'roles': ['admin', 'user']
            }
            """

        let result = try JsonishParser.parse(llmOutput)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["name"] as? String, "Alice")
        XCTAssertEqual(json["status"] as? String, "active")
        XCTAssertEqual((json["roles"] as? [String])?.count, 2)
    }

    func testParseNestedObjectsWithIssues() throws {
        // Nested objects with various issues
        let llmOutput = """
            ```json
            {
              user: {
                name: 'John Doe',
                profile: {
                  age: 30,
                  verified: true,
                },
              },
              scores: [
                { category: "technical", value: 85, },
                { category: "communication", value: 92, },
              ],
            }
            ```
            """

        let result = try JsonishParser.parse(llmOutput)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let user = json["user"] as! [String: Any]
        XCTAssertEqual(user["name"] as? String, "John Doe")

        let profile = user["profile"] as! [String: Any]
        XCTAssertEqual(profile["age"] as? Int, 30)
        XCTAssertEqual(profile["verified"] as? Bool, true)

        let scores = json["scores"] as! [[String: Any]]
        XCTAssertEqual(scores.count, 2)
        XCTAssertEqual(scores[0]["category"] as? String, "technical")
        XCTAssertEqual(scores[1]["value"] as? Int, 92)
    }

    // MARK: - Full Rendering Flow

    func testFullRenderingForComplexType() throws {
        let tb = TypeBuilder()

        // Create a complex analysis type
        let category = tb.enumBuilder("Category")
        category.addValue("bug")
        category.addValue("feature")
        category.addValue("enhancement")
        category.addValue("documentation")

        let priority = tb.enumBuilder("Priority")
        priority.addValue("low")
        priority.addValue("medium")
        priority.addValue("high")
        priority.addValue("critical")

        let issue = tb.addClass("Issue")
        issue.addProperty("title", .string).description("Brief title of the issue")
        issue.addProperty("description", .string).description("Detailed description")
        issue.addProperty("category", .reference("Category")).description("Issue category")
        issue.addProperty("priority", .reference("Priority")).description("Priority level")
        issue.addProperty("tags", .list(.string)).description("Related tags")
        issue.addProperty("assignee", .optional(.string)).description("Assigned developer")

        let schema = tb.buildClassSchema("Issue")!
        let prompt = SchemaPromptRenderer.render(schema: schema, typeBuilder: tb)

        // Verify the full prompt format
        XCTAssertTrue(prompt.hasPrefix("Answer in JSON using this schema:"))
        XCTAssertTrue(prompt.contains("// Brief title of the issue"))
        XCTAssertTrue(prompt.contains("title: string"))
        XCTAssertTrue(prompt.contains("// Issue category"))
        XCTAssertTrue(prompt.contains("\"bug\" | \"feature\" | \"enhancement\" | \"documentation\""))
        XCTAssertTrue(prompt.contains("\"low\" | \"medium\" | \"high\" | \"critical\""))
        XCTAssertTrue(prompt.contains("tags: string[]"))
        XCTAssertTrue(prompt.contains("assignee?:"))  // Optional marker
    }

    func testEnumOnlyPrompt() throws {
        let tb = TypeBuilder()

        let status = tb.enumBuilder("Status")
        status.addValue("pending")
        status.addValue("approved")
        status.addValue("rejected")

        let schema = tb.buildEnumSchema("Status")!
        let prompt = SchemaPromptRenderer.render(schema: schema, typeBuilder: tb)

        // BAML enum format
        XCTAssertTrue(prompt.contains("Answer with any of the categories:"))
        XCTAssertTrue(prompt.contains("- pending"))
        XCTAssertTrue(prompt.contains("- approved"))
        XCTAssertTrue(prompt.contains("- rejected"))
    }

    func testArrayPrompt() throws {
        let schema = JSONSchema.array(items: .object(
            properties: [
                "name": .string,
                "score": .number
            ],
            required: ["name", "score"]
        ))

        let prompt = SchemaPromptRenderer.render(schema: schema)

        XCTAssertTrue(prompt.contains("Answer with a JSON Array using this schema:"))
        XCTAssertTrue(prompt.contains("name: string"))
        XCTAssertTrue(prompt.contains("score: float"))
    }

    func testPrimitivePrompts() throws {
        XCTAssertEqual(
            SchemaPromptRenderer.render(schema: .integer),
            "Answer as an int"
        )

        XCTAssertEqual(
            SchemaPromptRenderer.render(schema: .number),
            "Answer as a float"
        )

        XCTAssertEqual(
            SchemaPromptRenderer.render(schema: .boolean),
            "Answer as a bool"
        )

        XCTAssertEqual(
            SchemaPromptRenderer.render(schema: .null),
            "Answer with null"
        )
    }

    // MARK: - Parse and Decode Flow

    func testParseAndDecodeComplexType() throws {
        struct ChatAnalysis: Codable {
            let sentiment: String
            let confidence: Double
            let keywords: [String]
            let issues: [Issue]

            struct Issue: Codable {
                let description: String
                let severity: String
            }
        }

        let llmOutput = """
            Based on my analysis:

            ```json
            {
              "sentiment": "mixed",
              "confidence": 0.78,
              "keywords": ["frustration", "appreciation", "confusion"],
              "issues": [
                {"description": "User had trouble with login", "severity": "high"},
                {"description": "UI was confusing at first", "severity": "medium"}
              ]
            }
            ```
            """

        let parsed = try JsonishParser.parse(llmOutput)
        let data = parsed.data(using: .utf8)!
        let analysis = try JSONDecoder().decode(ChatAnalysis.self, from: data)

        XCTAssertEqual(analysis.sentiment, "mixed")
        XCTAssertEqual(analysis.confidence, 0.78)
        XCTAssertEqual(analysis.keywords.count, 3)
        XCTAssertEqual(analysis.issues.count, 2)
        XCTAssertEqual(analysis.issues[0].severity, "high")
    }

    // MARK: - Edge Cases

    func testParseEmptyObject() throws {
        let result = try JsonishParser.parse("{}")
        XCTAssertEqual(result, "{}")
    }

    func testParseEmptyArray() throws {
        let result = try JsonishParser.parse("[]")
        XCTAssertEqual(result, "[]")
    }

    func testParseArrayOfObjects() throws {
        let llmOutput = """
            [
              {name: "Alice", age: 30,},
              {name: "Bob", age: 25,},
            ]
            """

        let result = try JsonishParser.parse(llmOutput)
        let data = result.data(using: .utf8)!
        let array = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]

        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(array[0]["name"] as? String, "Alice")
        XCTAssertEqual(array[1]["age"] as? Int, 25)
    }

    func testParseMixedNestedTrailingCommas() throws {
        let llmOutput = """
            {
              "data": {
                "items": [
                  {"id": 1, "value": "a",},
                  {"id": 2, "value": "b",},
                ],
                "metadata": {
                  "count": 2,
                  "valid": true,
                },
              },
            }
            """

        let result = try JsonishParser.parse(llmOutput)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let dataObj = json["data"] as! [String: Any]
        let items = dataObj["items"] as! [[String: Any]]
        XCTAssertEqual(items.count, 2)

        let metadata = dataObj["metadata"] as! [String: Any]
        XCTAssertEqual(metadata["count"] as? Int, 2)
    }

    // MARK: - Real-World Scenario: Chat Analysis

    func testRealWorldChatAnalysisScenario() throws {
        // Set up TypeBuilder like ellie-wrapped-embedded would
        let tb = TypeBuilder()

        // Dynamic enum for attachment types
        let attachType = tb.enumBuilder("AttachmentType")
        attachType.addValue("photo")
        attachType.addValue("video")
        attachType.addValue("audio")
        attachType.addValue("sticker")
        attachType.addValue("gif")

        // Dynamic enum for communication patterns
        let patternType = tb.enumBuilder("PatternType")
        patternType.addValue("questioning")
        patternType.addValue("storytelling")
        patternType.addValue("emotional_sharing")
        patternType.addValue("practical_planning")

        // Build the analysis result class
        let result = tb.addClass("ChatAnalysisResult")
        result.addProperty("overallSentiment", .string).description("Overall sentiment of the conversation")
        result.addProperty("dominantTopics", .list(.string)).description("Main topics discussed")
        result.addProperty("communicationPatterns", .list(.reference("PatternType"))).description("Identified patterns")
        result.addProperty("attachmentBreakdown", .map(key: .string, value: .int)).description("Count by attachment type")
        result.addProperty("confidenceScore", .float).description("Analysis confidence 0-1")

        // Generate prompt
        let schema = tb.buildClassSchema("ChatAnalysisResult")!
        let prompt = SchemaPromptRenderer.render(schema: schema, typeBuilder: tb)

        // Verify prompt structure
        XCTAssertTrue(prompt.contains("Answer in JSON using this schema:"))
        XCTAssertTrue(prompt.contains("overallSentiment: string"))
        XCTAssertTrue(prompt.contains("dominantTopics: string[]"))
        XCTAssertTrue(prompt.contains("\"questioning\" | \"storytelling\" | \"emotional_sharing\" | \"practical_planning\""))

        // Simulate LLM response
        let llmResponse = """
            Here's my analysis of the chat:

            ```json
            {
              overallSentiment: "positive",
              dominantTopics: ["vacation planning", "family updates", "work stress"],
              communicationPatterns: ["storytelling", "emotional_sharing"],
              attachmentBreakdown: {
                "photo": 15,
                "video": 3,
                "sticker": 42,
              },
              confidenceScore: 0.87,
            }
            ```
            """

        // Parse the response
        let parsed = try JsonishParser.parse(llmResponse)
        let data = parsed.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Validate parsed content
        XCTAssertEqual(json["overallSentiment"] as? String, "positive")
        XCTAssertEqual((json["dominantTopics"] as? [String])?.count, 3)
        XCTAssertEqual((json["communicationPatterns"] as? [String])?.count, 2)

        let breakdown = json["attachmentBreakdown"] as! [String: Int]
        XCTAssertEqual(breakdown["photo"], 15)
        XCTAssertEqual(breakdown["sticker"], 42)

        XCTAssertEqual(json["confidenceScore"] as? Double, 0.87)
    }

    // MARK: - Streaming Parse

    func testStreamingParsePartialJSON() throws {
        // Partial JSON during streaming
        let partial1 = #"{"name": "test""#
        let result1 = try JsonishParser.parse(partial1, isDone: false)
        // Should complete the partial JSON
        XCTAssertTrue(result1.hasSuffix("}"))

        // More complete but still partial
        let partial2 = #"{"items": [1, 2, 3"#
        let result2 = try JsonishParser.parse(partial2, isDone: false)
        XCTAssertTrue(result2.contains("]"))
        XCTAssertTrue(result2.hasSuffix("}"))
    }

    func testStreamingParseComplete() throws {
        let complete = #"{"status": "done", "count": 42}"#
        let result = try JsonishParser.parse(complete, isDone: true)
        XCTAssertEqual(result, complete)
    }
}
