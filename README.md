# SWAML - Swift BAML SDK

A Swift runtime library for [BAML](https://docs.boundaryml.com/) (Basically A Made-up Language) - a domain-specific language for building LLM applications with type-safe outputs.

## Installation

Add SWAML to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SamGalanakis/swaml", branch: "main"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["SWAML"]
    ),
]
```

## Quick Start

### 1. Configure a Client

```swift
import SWAML

// Using OpenRouter
let runtime = await BamlRuntime.openRouter(
    apiKey: "your-api-key",
    model: "anthropic/claude-sonnet-4-20250514"
)

// Or configure multiple clients
let registry = ClientRegistry()
await registry.register(
    name: "fast",
    provider: .openRouter(apiKey: "key"),
    model: "anthropic/claude-3-5-haiku-latest"
)
await registry.register(
    name: "smart",
    provider: .anthropic(apiKey: "key"),
    model: "claude-sonnet-4-20250514",
    isDefault: true
)
let runtime = BamlRuntime(clientRegistry: registry)
```

### 2. Define Your Types

```swift
struct SentimentResult: Codable {
    let sentiment: Sentiment
    let confidence: Double
    let explanation: String
}

enum Sentiment: String, Codable, CaseIterable {
    case positive, negative, neutral
}
```

### 3. Parse LLM Output

```swift
let llmOutput = """
```json
{"sentiment": "positive", "confidence": 0.95, "explanation": "The text expresses joy"}
```
"""

let result: SentimentResult = try OutputParser.parse(llmOutput, type: SentimentResult.self)
print(result.sentiment) // positive
```

## Features

### LLM Providers

```swift
// OpenRouter (access to many models)
.openRouter(apiKey: "key")

// OpenAI direct
.openAI(apiKey: "key")

// Anthropic direct
.anthropic(apiKey: "key")

// Custom endpoint
.custom(baseURL: URL(string: "https://api.example.com")!, apiKey: "key", headers: [:])
```

### Output Parsing

SWAML automatically extracts JSON from LLM responses, even when wrapped in markdown:

```swift
// Handles plain JSON
let json = #"{"name": "Alice", "age": 30}"#

// Handles markdown code blocks
let markdown = """
Here's the result:
```json
{"name": "Alice", "age": 30}
```
"""

// Both work the same way
let result: Person = try OutputParser.parse(markdown, type: Person.self)
```

### JSON Repair

Automatically fixes common LLM JSON errors:

```swift
// Trailing commas
let malformed = #"{"items": [1, 2, 3,]}"#
let repaired = JSONExtractor.repair(malformed)
// {"items": [1, 2, 3]}
```

### Dynamic Type Building

Build schemas at runtime for dynamic use cases:

```swift
let tb = TypeBuilder()

tb.addEnum("Priority")
    .addValue("LOW")
    .addValue("MEDIUM")
    .addValue("HIGH")

tb.addClass("Task")
    .addProperty("title", type: .string)
    .addProperty("priority", type: .reference("Priority"))
    .addProperty("tags", type: .array(.string))
    .addProperty("dueDate", type: .optional(.string))

let schema = try tb.buildSchema(root: "Task")
```

### BamlValue for Dynamic Access

Access parsed data without defining types:

```swift
let value = try BamlValue.fromJSONString(json)

// Type-safe accessors
let name = value["user"]?["name"]?.stringValue  // String?
let age = value["user"]?["age"]?.intValue       // Int?
let scores = value["scores"]?.arrayValue        // [BamlValue]?

// Check types
if value["count"]?.isInt == true { ... }
```

### Retry Policies

Built-in retry with exponential backoff:

```swift
// Preset policies
RetryPolicy.none        // No retries
RetryPolicy.standard    // 3 retries, 1s initial delay
RetryPolicy.aggressive  // 5 retries, 0.5s initial delay

// Custom policy
let policy = RetryPolicy(
    maxRetries: 5,
    initialDelay: 0.5,
    maxDelay: 30.0,
    multiplier: 2.0,
    jitter: true
)
```

### Runtime Context

Pass context to customize requests:

```swift
let ctx = RuntimeContext.builder()
    .client("fast")
    .temperature(0.7)
    .maxTokens(1000)
    .tag("user_id", "123")
    .build()

let response = try await runtime.complete(
    messages: [.user("Hello")],
    ctx: ctx
)
```

## Type Mapping

| BAML Type | Swift Type |
|-----------|------------|
| `string` | `String` |
| `int` | `Int` |
| `float` | `Double` |
| `bool` | `Bool` |
| `T[]` | `[T]` |
| `T?` | `T?` |
| `map<K,V>` | `[K: V]` |
| `class Foo` | `struct Foo: Codable` |
| `enum Bar` | `enum Bar: String, Codable` |

## Example: Chat Analysis

```swift
import SWAML

// Define response types
struct ChatAnalysis: Codable {
    let sentiment: String
    let topics: [String]
    let suggestedResponses: [String]

    enum CodingKeys: String, CodingKey {
        case sentiment, topics
        case suggestedResponses = "suggested_responses"
    }
}

// Configure runtime
let runtime = await BamlRuntime.openRouter(
    apiKey: ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]!,
    model: "anthropic/claude-sonnet-4-20250514"
)

// Make request
let response = try await runtime.complete(
    messages: [
        .system("Analyze the chat and return JSON with sentiment, topics, and suggested_responses."),
        .user("User: I love this product!\nAgent: ")
    ],
    responseFormat: .jsonObject
)

// Parse response
let analysis: ChatAnalysis = try OutputParser.parse(response.content, type: ChatAnalysis.self)
print(analysis.topics)
```

## Requirements

- Swift 5.9+
- macOS 13+ / iOS 16+ / Linux

## License

MIT
