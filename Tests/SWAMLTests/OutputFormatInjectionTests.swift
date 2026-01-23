import XCTest
@testable import SWAML

/// Tests that verify the dynamic output format injection works correctly.
///
/// This tests the `{{ ctx.output_format }}` replacement in prompts, ensuring
/// that different return types produce different schema instructions.
final class OutputFormatInjectionTests: XCTestCase {

    // MARK: - Test Types

    struct SimpleSentiment: SwamlTyped, Codable {
        let sentiment: String
        let confidence: Double

        static var swamlTypeName: String { "SimpleSentiment" }
        static var swamlSchema: JSONSchema {
            .object(
                properties: [
                    "sentiment": .string,
                    "confidence": .number
                ],
                required: ["sentiment", "confidence"]
            )
        }
        static var fieldDescriptions: [String: String] {
            ["sentiment": "The detected sentiment", "confidence": "Confidence score 0-1"]
        }
    }

    struct IssueClassification: SwamlTyped, Codable {
        let category: String
        let priority: String
        let tags: [String]

        static var swamlTypeName: String { "IssueClassification" }
        static var swamlSchema: JSONSchema {
            .object(
                properties: [
                    "category": .enum(values: ["bug", "feature", "docs"]),
                    "priority": .enum(values: ["low", "medium", "high"]),
                    "tags": .array(items: .string)
                ],
                required: ["category", "priority", "tags"]
            )
        }
    }

    struct NestedAnalysis: SwamlTyped, Codable {
        let summary: String
        let details: Details

        struct Details: Codable {
            let score: Int
            let notes: [String]
        }

        static var swamlTypeName: String { "NestedAnalysis" }
        static var swamlSchema: JSONSchema {
            .object(
                properties: [
                    "summary": .string,
                    "details": .object(
                        properties: [
                            "score": .integer,
                            "notes": .array(items: .string)
                        ],
                        required: ["score", "notes"]
                    )
                ],
                required: ["summary", "details"]
            )
        }
    }

    // MARK: - Basic Output Format Injection Tests

    func testOutputFormatInjectedInSystemPrompt() {
        let prompt = PromptBuilder()
            .system("""
                You are a sentiment analyzer.

                {{ ctx.output_format }}
                """)
            .user("Analyze: I love this!")

        let messages = prompt.build(returnType: SimpleSentiment.self)

        XCTAssertEqual(messages.count, 2)

        let systemContent = messages[0].content.textValue ?? ""

        // Verify the output format was injected
        XCTAssertTrue(systemContent.contains("Answer in JSON using this schema:"), "Should contain schema header")
        XCTAssertTrue(systemContent.contains("sentiment:"), "Should contain sentiment field")
        XCTAssertTrue(systemContent.contains("confidence: float"), "Should contain confidence field")
        XCTAssertTrue(systemContent.contains("// The detected sentiment"), "Should contain field description")
    }

    func testOutputFormatChangesWithType() {
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Test")

        // Build with SimpleSentiment
        let sentimentMessages = prompt.build(returnType: SimpleSentiment.self)
        let sentimentSystem = sentimentMessages[0].content.textValue ?? ""

        // Build with IssueClassification
        let issueMessages = prompt.build(returnType: IssueClassification.self)
        let issueSystem = issueMessages[0].content.textValue ?? ""

        // They should be different
        XCTAssertNotEqual(sentimentSystem, issueSystem, "Different types should produce different output formats")

        // Verify specific content for each
        XCTAssertTrue(sentimentSystem.contains("confidence: float"), "Sentiment should have confidence")
        XCTAssertFalse(sentimentSystem.contains("category:"), "Sentiment should not have category")

        XCTAssertTrue(issueSystem.contains("category:"), "Issue should have category")
        XCTAssertTrue(issueSystem.contains("\"bug\" | \"feature\" | \"docs\""), "Issue should have enum values")
        XCTAssertFalse(issueSystem.contains("confidence:"), "Issue should not have confidence")
    }

    func testOutputFormatWithEnumValues() {
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Classify this issue")

        let messages = prompt.build(returnType: IssueClassification.self)
        let systemContent = messages[0].content.textValue ?? ""

        // Verify enum values are rendered BAML-style
        XCTAssertTrue(systemContent.contains("\"bug\" | \"feature\" | \"docs\""), "Should render enum values with |")
        XCTAssertTrue(systemContent.contains("\"low\" | \"medium\" | \"high\""), "Should render priority enum")
        XCTAssertTrue(systemContent.contains("tags: string[]"), "Should render array type BAML-style")
    }

    func testOutputFormatWithNestedTypes() {
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Analyze this")

        let messages = prompt.build(returnType: NestedAnalysis.self)
        let systemContent = messages[0].content.textValue ?? ""

        // Verify nested structure is rendered
        XCTAssertTrue(systemContent.contains("summary: string"), "Should have summary field")
        XCTAssertTrue(systemContent.contains("details: {"), "Should have nested details object")
        XCTAssertTrue(systemContent.contains("score: int"), "Should have score in nested object")
        XCTAssertTrue(systemContent.contains("notes: string[]"), "Should have notes array in nested object")
    }

    // MARK: - Dynamic Type Tests

    func testOutputFormatWithDynamicEnum() {
        let tb = TypeBuilder()
        let statusEnum = tb.enumBuilder("DynamicStatus")
        statusEnum.addValue("pending")
        statusEnum.addValue("approved")
        statusEnum.addValue("rejected")

        let dynamicClass = tb.addClass("DynamicResult")
        dynamicClass.addProperty("status", .reference("DynamicStatus")).description("Current status")
        dynamicClass.addProperty("message", .string)

        let schema = tb.buildClassSchema("DynamicResult")!

        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Get status")

        let messages = prompt.build(schema: schema, typeBuilder: tb)
        let systemContent = messages[0].content.textValue ?? ""

        // Verify dynamic enum values are rendered
        XCTAssertTrue(systemContent.contains("\"pending\" | \"approved\" | \"rejected\""), "Should render dynamic enum values")
        XCTAssertTrue(systemContent.contains("message: string"), "Should have message field")
        XCTAssertTrue(systemContent.contains("// Current status"), "Should have field description")
    }

    func testOutputFormatWithDynamicClass() {
        let tb = TypeBuilder()

        let resultClass = tb.addClass("CustomResult")
        resultClass.addProperty("score", .float).description("Score from 0 to 100")
        resultClass.addProperty("tags", .list(.string)).description("Relevant tags")
        resultClass.addProperty("metadata", .map(key: .string, value: .int)).description("Key-value counts")

        let schema = tb.buildClassSchema("CustomResult")!

        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Analyze")

        let messages = prompt.build(schema: schema, typeBuilder: tb)
        let systemContent = messages[0].content.textValue ?? ""

        XCTAssertTrue(systemContent.contains("score: float"), "Should have score field")
        XCTAssertTrue(systemContent.contains("tags: string[]"), "Should have tags array")
        XCTAssertTrue(systemContent.contains("// Score from 0 to 100"), "Should have score description")
        XCTAssertTrue(systemContent.contains("// Relevant tags"), "Should have tags description")
    }

    // MARK: - Multiple Placeholder Tests

    func testMultipleOutputFormatPlaceholders() {
        let prompt = PromptBuilder()
            .system("""
                You must respond with valid JSON.
                {{ ctx.output_format }}

                Remember the schema:
                {{ ctx.output_format }}
                """)
            .user("Do it")

        let messages = prompt.build(returnType: SimpleSentiment.self)
        let systemContent = messages[0].content.textValue ?? ""

        // Count occurrences of the schema header
        let occurrences = systemContent.components(separatedBy: "Answer in JSON using this schema:").count - 1
        XCTAssertEqual(occurrences, 2, "Should inject output format in both placeholders")
    }

    func testOutputFormatInUserPrompt() {
        let prompt = PromptBuilder()
            .system("You are a helpful assistant.")
            .user("""
                Analyze this text and respond with:
                {{ ctx.output_format }}

                Text: Hello world
                """)

        let messages = prompt.build(returnType: SimpleSentiment.self)
        let userContent = messages[1].content.textValue ?? ""

        XCTAssertTrue(userContent.contains("Answer in JSON using this schema:"), "Should inject in user prompt")
        XCTAssertTrue(userContent.contains("sentiment:"), "Should contain schema in user prompt")
    }

    // MARK: - Primitive Type Output Formats

    func testOutputFormatForInteger() {
        let schema = JSONSchema.integer
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Count items")

        let messages = prompt.build(schema: schema)
        let systemContent = messages[0].content.textValue ?? ""

        XCTAssertEqual(systemContent, "Answer as an int")
    }

    func testOutputFormatForFloat() {
        let schema = JSONSchema.number
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Get score")

        let messages = prompt.build(schema: schema)
        let systemContent = messages[0].content.textValue ?? ""

        XCTAssertEqual(systemContent, "Answer as a float")
    }

    func testOutputFormatForBoolean() {
        let schema = JSONSchema.boolean
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Is valid?")

        let messages = prompt.build(schema: schema)
        let systemContent = messages[0].content.textValue ?? ""

        XCTAssertEqual(systemContent, "Answer as a bool")
    }

    func testOutputFormatForString() {
        let schema = JSONSchema.string
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("What is the name?")

        let messages = prompt.build(schema: schema)
        let systemContent = messages[0].content.textValue ?? ""

        // String has no special format instruction
        XCTAssertEqual(systemContent, "")
    }

    func testOutputFormatForEnum() {
        let schema = JSONSchema.enum(values: ["red", "green", "blue"])
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Pick a color")

        let messages = prompt.build(schema: schema)
        let systemContent = messages[0].content.textValue ?? ""

        // BAML enum format
        XCTAssertTrue(systemContent.contains("Answer with any of the categories:"))
        XCTAssertTrue(systemContent.contains("----"))
        XCTAssertTrue(systemContent.contains("- red"))
        XCTAssertTrue(systemContent.contains("- green"))
        XCTAssertTrue(systemContent.contains("- blue"))
    }

    func testOutputFormatForArray() {
        let schema = JSONSchema.array(items: .object(
            properties: ["name": .string, "age": .integer],
            required: ["name", "age"]
        ))
        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("List people")

        let messages = prompt.build(schema: schema)
        let systemContent = messages[0].content.textValue ?? ""

        XCTAssertTrue(systemContent.contains("Answer with a JSON Array using this schema:"))
        XCTAssertTrue(systemContent.contains("name: string"))
        XCTAssertTrue(systemContent.contains("age: int"))
    }

    // MARK: - SwamlClient Integration Tests

    func testSwamlClientIncludesOutputFormat() {
        // This tests that SwamlClient.call() properly includes the output format
        // We can't make actual LLM calls, but we can verify the schema is generated correctly

        let schemaPrompt = SchemaPromptRenderer.render(
            for: SimpleSentiment.self,
            typeBuilder: nil,
            includeDescriptions: true
        )

        // Verify the full prompt format
        XCTAssertTrue(schemaPrompt.hasPrefix("Answer in JSON using this schema:"))
        XCTAssertTrue(schemaPrompt.contains("sentiment:"))
        XCTAssertTrue(schemaPrompt.contains("confidence: float"))
        XCTAssertTrue(schemaPrompt.contains("// The detected sentiment"))
        XCTAssertTrue(schemaPrompt.contains("// Confidence score 0-1"))
    }

    func testSwamlClientDynamicSchemaIncludesOutputFormat() {
        let tb = TypeBuilder()

        let category = tb.enumBuilder("Category")
        category.addValue("tech")
        category.addValue("sports")
        category.addValue("politics")

        let articleClass = tb.addClass("ArticleAnalysis")
        articleClass.addProperty("title", .string).description("Article title")
        articleClass.addProperty("category", .reference("Category")).description("Main category")
        articleClass.addProperty("keywords", .list(.string)).description("Key terms")
        articleClass.addProperty("readTime", .int).description("Estimated read time in minutes")

        let schema = tb.buildClassSchema("ArticleAnalysis")!
        let prompt = SchemaPromptRenderer.render(schema: schema, typeBuilder: tb)

        // Verify complete output format
        XCTAssertTrue(prompt.hasPrefix("Answer in JSON using this schema:"))
        XCTAssertTrue(prompt.contains("title: string"))
        XCTAssertTrue(prompt.contains("// Article title"))
        XCTAssertTrue(prompt.contains("\"tech\" | \"sports\" | \"politics\""))
        XCTAssertTrue(prompt.contains("// Main category"))
        XCTAssertTrue(prompt.contains("keywords: string[]"))
        XCTAssertTrue(prompt.contains("readTime: int"))
    }

    // MARK: - Variable + Output Format Combined Tests

    func testVariablesAndOutputFormatTogether() {
        let prompt = PromptBuilder()
            .system("""
                You are analyzing text for {{ user_name }}.

                {{ ctx.output_format }}
                """)
            .user("Analyze: {{ text }}")
            .variable("user_name", "Alice")
            .variable("text", "I love this product!")

        let messages = prompt.build(returnType: SimpleSentiment.self)

        let systemContent = messages[0].content.textValue ?? ""
        let userContent = messages[1].content.textValue ?? ""

        // Verify variable substitution
        XCTAssertTrue(systemContent.contains("You are analyzing text for Alice."))
        XCTAssertTrue(userContent.contains("Analyze: I love this product!"))

        // Verify output format injection
        XCTAssertTrue(systemContent.contains("Answer in JSON using this schema:"))
        XCTAssertTrue(systemContent.contains("sentiment:"))
    }

    func testExamplesAndOutputFormatTogether() {
        struct ExampleResult: SwamlTyped, Codable {
            let label: String
            let score: Double

            static var swamlTypeName: String { "ExampleResult" }
            static var swamlSchema: JSONSchema {
                .object(
                    properties: ["label": .string, "score": .number],
                    required: ["label", "score"]
                )
            }
        }

        let example1 = ExampleResult(label: "positive", score: 0.95)
        let example2 = ExampleResult(label: "negative", score: 0.85)

        let prompt = PromptBuilder()
            .system("""
                {{ ctx.output_format }}

                Examples:
                {{ examples }}
                """)
            .user("Classify this")
            .example(example1)
            .example(example2)

        let messages = prompt.build(returnType: ExampleResult.self)
        let systemContent = messages[0].content.textValue ?? ""

        // Verify output format
        XCTAssertTrue(systemContent.contains("Answer in JSON using this schema:"))
        XCTAssertTrue(systemContent.contains("label: string"))

        // Verify examples
        XCTAssertTrue(systemContent.contains("\"label\" : \"positive\"") || systemContent.contains("\"label\": \"positive\""))
        XCTAssertTrue(systemContent.contains("0.95"))
        XCTAssertTrue(systemContent.contains("\"label\" : \"negative\"") || systemContent.contains("\"label\": \"negative\""))
    }

    // MARK: - Edge Cases

    func testOutputFormatWithEmptyTypeBuilder() {
        let tb = TypeBuilder()

        let prompt = PromptBuilder()
            .system("{{ ctx.output_format }}")
            .user("Test")

        let messages = prompt.build(returnType: SimpleSentiment.self, typeBuilder: tb)
        let systemContent = messages[0].content.textValue ?? ""

        // Should still work without dynamic types
        XCTAssertTrue(systemContent.contains("Answer in JSON using this schema:"))
    }

    func testOutputFormatWithoutPlaceholder() {
        let prompt = PromptBuilder()
            .system("You are a helpful assistant.")
            .user("What is 2+2?")

        let messages = prompt.build(returnType: SimpleSentiment.self)

        let systemContent = messages[0].content.textValue ?? ""

        // Without {{ ctx.output_format }}, no schema should be injected
        XCTAssertFalse(systemContent.contains("Answer in JSON"))
        XCTAssertEqual(systemContent, "You are a helpful assistant.")
    }

    func testConvenienceWithOutputFormat() {
        let prompt = PromptBuilder.withOutputFormat(user: "Analyze this text")
        let messages = prompt.build(returnType: SimpleSentiment.self)

        XCTAssertEqual(messages.count, 2)

        let systemContent = messages[0].content.textValue ?? ""
        XCTAssertTrue(systemContent.contains("Answer in JSON using this schema:"))
    }
}
