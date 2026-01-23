# API Reference

## SwamlClient

The main client for making LLM calls.

### Initialization

```swift
// With provider
let client = SwamlClient(provider: .openRouter(apiKey: "key"))

// With custom TypeBuilder
let client = SwamlClient(provider: .openAI(apiKey: "key"), typeBuilder: myTypeBuilder)
```

### Methods

#### call(model:prompt:returnType:options:)

Make a typed LLM call:

```swift
let result = try await client.call(
    model: "openai/gpt-4o-mini",
    prompt: "Your prompt here",
    returnType: MyType.self,
    options: SwamlCallOptions(temperature: 0.7, maxTokens: 1000)
)
```

#### call(model:prompt:returnType:options:) with PromptBuilder

```swift
let prompt = PromptBuilder()
    .system("You are a helpful assistant.\n\n{{ ctx.output_format }}")
    .user("{{ question }}")
    .variable("question", "What is 2+2?")

let result = try await client.call(
    model: "openai/gpt-4o-mini",
    prompt: prompt,
    returnType: Answer.self
)
```

#### callDynamic(model:prompt:schema:options:)

Call with a dynamically-built schema:

```swift
let schema = typeBuilder.buildClassSchema("DynamicType")!
let result = try await client.callDynamic(
    model: "openai/gpt-4o-mini",
    prompt: "Your prompt",
    schema: schema
)
// result is SwamlValue
```

#### rawComplete(model:messages:options:)

Raw completion without parsing:

```swift
let response = try await client.rawComplete(
    model: "openai/gpt-4o-mini",
    messages: [
        ChatMessage(role: .system, content: "You are helpful."),
        ChatMessage(role: .user, content: "Hello!")
    ]
)
print(response) // Raw string response
```

#### extendEnum(_:with:)

Extend a dynamic enum at runtime:

```swift
@SwamlType
@SwamlDynamic
enum Category: String {
    case a, b
}

try client.extendEnum(Category.self, with: ["c", "d"])
```

---

## SwamlCallOptions

Options for LLM calls.

```swift
struct SwamlCallOptions {
    var temperature: Double?
    var maxTokens: Int?
    var topP: Double?
    var frequencyPenalty: Double?
    var presencePenalty: Double?
    var stop: [String]?
}
```

---

## PromptBuilder

Build complex prompts with variable substitution.

### Methods

```swift
let prompt = PromptBuilder()
    .system("System message with {{ variable }}")
    .user("User message with {{ other_var }}")
    .assistant("Previous assistant response")
    .variable("variable", "value")
    .variable("other_var", "other value")
```

### Special Variables

- `{{ ctx.output_format }}` - Injects the schema prompt for the return type

### Building

```swift
// Build with a specific return type
let messages = prompt.build(for: MyType.self)

// Build without type (no output format injection)
let messages = prompt.buildRaw()
```

---

## LLMProvider

Supported LLM providers.

```swift
// OpenRouter (access to many models)
.openRouter(apiKey: "key")

// OpenAI direct
.openAI(apiKey: "key")

// Anthropic direct
.anthropic(apiKey: "key")

// Custom endpoint (OpenAI-compatible)
.custom(baseURL: URL(string: "https://api.example.com")!, apiKey: "key", headers: [:])
```

---

## SwamlTyped Protocol

Protocol for types that can be used with SWAML.

```swift
public protocol SwamlTyped: Codable, Sendable {
    static var swamlTypeName: String { get }
    static var swamlSchema: JSONSchema { get }
    static var isDynamic: Bool { get }
    static var fieldDescriptions: [String: String] { get }
    static var fieldAliases: [String: String] { get }
}
```

Use `@SwamlType` macro for automatic conformance.

---

## SwamlValue

Dynamic value type for untyped responses.

```swift
enum SwamlValue {
    case null
    case bool(Bool)
    case int(Int)
    case float(Double)
    case string(String)
    case array([SwamlValue])
    case map([String: SwamlValue])
}
```

### Access

```swift
let value: SwamlValue = ...

value.stringValue    // String?
value.intValue       // Int?
value.boolValue      // Bool?
value.doubleValue    // Double?
value.arrayValue     // [SwamlValue]?
value.mapValue       // [String: SwamlValue]?

value["key"]         // Subscript for maps
value[0]             // Subscript for arrays
```

---

## SwamlError

Error types thrown by SWAML.

```swift
enum SwamlError: Error {
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case parseError(String)
    case jsonExtractionError(String)
    case typeCoercionError(expected: String, actual: String)
    case schemaValidationError(String)
    case configurationError(String)
    case internalError(String)
}
```

---

## JsonishParser

Parse LLM output with relaxed JSON rules.

```swift
let cleanJSON = try JsonishParser.parse(rawOutput)
```

Handles:
- Trailing commas
- Unquoted keys
- Single quotes
- Comments (`//` and `/* */`)
- Markdown code blocks
- Extra text before/after JSON
