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

## Runtime Options

SWAML provides two runtime options:

### Pure Swift Runtime (Default)

The pure Swift runtime works out of the box with no additional setup:

```swift
import SWAML

let runtime = await BamlRuntime.openRouter(
    apiKey: "your-api-key",
    model: "anthropic/claude-sonnet-4-20250514"
)
```

### FFI Runtime (BAML Rust Backend)

For full BAML compatibility including `ctx.output_format`, streaming, and all BAML Rust runtime features, use the FFI runtime:

```swift
import SWAML

// Initialize with embedded BAML sources
let runtime = try BamlRuntimeFFI(
    rootPath: "baml_src",
    sourceFiles: bamlSources,  // Generated from your .baml files
    envVars: ["OPENAI_API_KEY": ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!]
)

// Use generated client
let client = BamlAsyncClientFFI(runtime: runtime)
let result = try await client.extractResume(text: resumeText)
```

The FFI runtime communicates with the Rust backend using Protocol Buffers for efficient serialization.

#### Building for iOS/macOS (XCFramework)

```bash
# Build XCFramework for iOS/macOS
./scripts/build-xcframework.sh
```

This creates `BamlFFI.xcframework` containing:
- iOS Device (arm64)
- iOS Simulator (arm64)
- macOS (arm64 + x86_64 universal)

Then in your Xcode project:
1. Add `BamlFFI.xcframework` to your target
2. Define `BAML_FFI_ENABLED` in your build settings

#### Building for Linux

```bash
# Build shared library for Linux
./scripts/build-linux.sh
```

This creates `lib/libbaml_ffi.so`. Configure your `Package.swift`:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: ["SWAML"],
        swiftSettings: [
            .define("BAML_FFI_ENABLED")
        ],
        linkerSettings: [
            .linkedLibrary("baml_ffi", .when(platforms: [.linux])),
            .unsafeFlags(["-Llib"], .when(platforms: [.linux]))
        ]
    ),
]
```

Run with the library path:

```bash
LD_LIBRARY_PATH=./lib:$LD_LIBRARY_PATH swift run YourApp
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

Build schemas at runtime for dynamic use cases. The TypeBuilder API matches Python BAML's capabilities.

#### Fluent Type Creation

```swift
let tb = TypeBuilder()

// Primitive types
let stringType = tb.string()
let intType = tb.int()
let floatType = tb.float()
let boolType = tb.bool()

// Literal types
let literalStr = tb.literalString("active")
let literalInt = tb.literalInt(42)

// Composite types
let listOfStrings = tb.list(tb.string())
let mapType = tb.map(key: tb.string(), value: tb.int())
let unionType = tb.union(tb.string(), tb.int())
```

#### Chainable Modifiers

```swift
// Chain .list() and .optional() modifiers
let optionalInt = tb.int().optional()
let listOfStrings = tb.string().list()
let optionalListOfInts = tb.int().list().optional()
```

#### Dynamic Enums with Metadata

```swift
// Add values with description and alias
let categoryEnum = tb.addEnum("Category")
categoryEnum.addValue("TECH").description("Technology topics").alias("tech")
categoryEnum.addValue("SPORTS").description("Sports related")
categoryEnum.addValue("NEWS")

// Get a type reference to use in classes
let categoryType = categoryEnum.type()

// Access all values
let values = tb.dynamicEnumValues()
// ["Category": ["TECH", "SPORTS", "NEWS"]]
```

#### Dynamic Classes

```swift
// Create a class with typed properties
let person = tb.addClass("Person")
person.addProperty("name", tb.string()).description("Full name")
person.addProperty("age", tb.int().optional())
person.addProperty("email", tb.string()).alias("emailAddress")
person.addProperty("tags", tb.string().list())

// Reference other types
person.addProperty("category", categoryEnum.type())

// Build JSON Schema
let schema = person.buildSchema()
```

#### FFI Serialization

```swift
// Serialize for passing to Rust FFI runtime
let serializable = tb.toSerializable()
let jsonData = try tb.toJSON()
let jsonString = try tb.toJSONString(prettyPrinted: true)
```

#### Generated TypeBuilder

When using the code generator with `@@dynamic` enums, a `BamlTypeBuilder` subclass is generated with typed accessors:

```swift
let tb = BamlTypeBuilder()

// Access dynamic enums by name
tb.MomentId.addValue("moment_123")
tb.PatternId.addValue("pattern_456")

// Access static enum viewers
let statusValues = tb.Status.listValues()

// Access class type references
let personType = tb.Person.type()

// Use with function calls
let result = try await client.extract(
    text: input,
    options: .with(typeBuilder: tb)
)
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

## Code Generation

SWAML includes a code generator that produces Swift types from BAML definitions:

```bash
# Generate Swift code from BAML files
baml-swift generate --input ./baml_src --output ./Sources/BamlClient
```

Generated files:
- `Types.swift` - Structs and enums from your BAML schema
- `BamlClient.swift` - Type-safe client with all your BAML functions
- `Globals.swift` - Client configurations
- `TypeBuilder.swift` - Dynamic type support for `@@dynamic` enums

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

### FFI Runtime Additional Requirements

**Apple Platforms:**
- Rust toolchain with iOS targets: `rustup target add aarch64-apple-ios aarch64-apple-ios-sim`
- Xcode 15+

**Linux:**
- Rust toolchain: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Build dependencies: `apt install build-essential pkg-config libssl-dev`

## License

MIT
