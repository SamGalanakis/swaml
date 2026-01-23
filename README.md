# SWAML - Swift LLM SDK

A pure Swift library for building LLM applications with type-safe structured outputs. Inspired by [BAML](https://docs.boundaryml.com/), but implemented entirely in Swift with no external dependencies.

## Features

- **Pure Swift** - No Rust, no FFI, no external binaries
- **Type-safe LLM calls** - Define Swift types, get typed responses
- **Proven output format** - Uses a proven prompt format for structured outputs
- **Robust JSON parsing** - Handles trailing commas, comments, unquoted keys, markdown code blocks
- **Dynamic types** - Build schemas at runtime with TypeBuilder
- **Multiple providers** - OpenRouter, OpenAI, Anthropic, or custom endpoints

## Installation

Add SWAML to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SamGalanakis/swaml", branch: "main"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["SWAML", "SwamlMacros"]
    ),
]
```

## Quick Start

```swift
import SWAML
import SwamlMacros

// Define your response type
@SwamlType
struct Sentiment {
    @Description("The detected sentiment")
    let sentiment: String

    @Description("Confidence score from 0 to 1")
    let confidence: Double

    @Description("Reasons for the sentiment")
    let reasons: [String]
}

// Create a client
let client = SwamlClient(provider: .openRouter(apiKey: apiKey))

// Get typed responses from LLMs
let result = try await client.call(
    model: "openai/gpt-4o-mini",
    prompt: "Analyze the sentiment of: 'I love this product!'",
    returnType: Sentiment.self
)

print(result.sentiment)    // "positive"
print(result.confidence)   // 0.95
print(result.reasons)      // ["Expresses love", "Enthusiastic tone"]
```

## How It Works

SWAML automatically generates schema prompts that instruct the LLM how to format its response:

```
Answer in JSON using this schema:
{
  // Confidence score from 0 to 1
  confidence: float,
  // Reasons for the sentiment
  reasons: string[],
  // The detected sentiment
  sentiment: "positive" | "negative" | "neutral",
}
```

The response is then parsed with a robust JSON parser that handles common LLM output quirks.

## PromptBuilder for Complex Prompts

Use `{{ ctx.output_format }}` to inject the schema into custom prompts:

```swift
let prompt = PromptBuilder()
    .system("""
        You are a sentiment analysis expert.

        {{ ctx.output_format }}
        """)
    .user("Analyze: {{ text }}")
    .variable("text", "I absolutely love this product!")

let result = try await client.call(
    model: "openai/gpt-4o-mini",
    prompt: prompt,
    returnType: Sentiment.self
)
```

## Dynamic Types with TypeBuilder

Build schemas at runtime for dynamic use cases:

```swift
let tb = TypeBuilder()

// Create a dynamic enum
let category = tb.enumBuilder("Category")
category.addValue("bug")
category.addValue("feature")
category.addValue("docs")

// Create a dynamic class
let issue = tb.addClass("Issue")
issue.addProperty("title", .string).description("Brief summary")
issue.addProperty("category", .reference("Category")).description("Issue type")
issue.addProperty("priority", .int).description("Priority 1-5")

// Use with SwamlClient
let schema = tb.buildClassSchema("Issue")!
let result = try await client.callDynamic(
    model: "openai/gpt-4o-mini",
    prompt: "Classify this bug report: ...",
    schema: schema
)
```

## Robust JSON Parsing

The built-in parser handles common LLM output issues:

```swift
// Trailing commas
let json1 = #"{"items": [1, 2, 3,]}"#

// Unquoted keys
let json2 = #"{name: "Alice", age: 30}"#

// Single quotes
let json3 = #"{'status': 'active'}"#

// Comments
let json4 = #"{"value": 42 /* important */}"#

// Markdown code blocks
let json5 = """
Here's the result:
```json
{"answer": 42}
```
"""

// All of these parse correctly
let parsed = try JsonishParser.parse(json5)
```

## Swift Macros

### @SwamlType

Generates schema conformance:

```swift
@SwamlType
struct User {
    let name: String
    let age: Int
    let email: String?  // Optional fields handled automatically
}
```

### @Description

Add descriptions (included in LLM prompts):

```swift
@SwamlType
struct Order {
    @Description("Unique order identifier")
    let orderId: String

    @Description("Total price in cents")
    let totalCents: Int
}
```

### @SwamlDynamic

Mark types as extensible at runtime:

```swift
@SwamlType
@SwamlDynamic
enum Category: String {
    case electronics
    case clothing
}

// Extend at runtime
try client.extendEnum(Category.self, with: ["furniture", "books"])
```

## LLM Providers

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

## Output Format by Type

| Return Type | Prompt Format |
|-------------|---------------|
| Object/Struct | `Answer in JSON using this schema:\n{...}` |
| Enum | `Answer with any of the categories:\n----\n- value1\n- value2` |
| Integer | `Answer as an int` |
| Float/Double | `Answer as a float` |
| Boolean | `Answer as a bool` |
| String | (no format instruction) |
| Array | `Answer with a JSON Array using this schema:\n{...}[]` |

## Type Mapping

| Swift Type | Schema Type |
|------------|-------------|
| `String` | `string` |
| `Int` | `int` |
| `Double`, `Float` | `float` |
| `Bool` | `bool` |
| `[T]` | `T[]` |
| `T?` | `T \| null` |
| `[String: T]` | `map<string, T>` |

## Documentation

See the [docs/](docs/) folder for comprehensive documentation:

- [Getting Started](docs/getting-started.md)
- [Core Concepts](docs/core-concepts.md)
- [API Reference](docs/api-reference.md)
- [TypeBuilder](docs/type-builder.md)
- [Providers](docs/providers.md)
- [Advanced Usage](docs/advanced-usage.md)

## Requirements

- Swift 5.9+
- macOS 13+ / iOS 16+ / Linux

## License

MIT
