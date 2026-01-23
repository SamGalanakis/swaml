# Advanced Usage

## Complex Prompts with PromptBuilder

For multi-turn conversations or complex prompts:

```swift
let prompt = PromptBuilder()
    .system("""
        You are a code review assistant.

        Review code for:
        - Security vulnerabilities
        - Performance issues
        - Best practices

        {{ ctx.output_format }}
        """)
    .user("Review this code:\n\n{{ code }}")
    .variable("code", userProvidedCode)

@SwamlType
struct CodeReview {
    @Description("List of issues found")
    let issues: [Issue]

    @Description("Overall quality score 1-10")
    let score: Int

    @Description("Summary of the review")
    let summary: String
}

@SwamlType
struct Issue {
    let severity: String  // "low", "medium", "high", "critical"
    let line: Int?
    let description: String
    let suggestion: String
}

let review = try await client.call(
    model: "openai/gpt-4o",
    prompt: prompt,
    returnType: CodeReview.self
)
```

## Nested Types

SWAML handles nested types automatically:

```swift
@SwamlType
struct Company {
    let name: String
    let employees: [Employee]
    let headquarters: Address
}

@SwamlType
struct Employee {
    let name: String
    let role: String
    let startDate: String
}

@SwamlType
struct Address {
    let street: String
    let city: String
    let country: String
}

// Works automatically
let result = try await client.call(
    model: "openai/gpt-4o-mini",
    prompt: "Extract company info from: ...",
    returnType: Company.self
)
```

## Enums with Descriptions

```swift
@SwamlType
enum Sentiment: String {
    @Description("Positive sentiment - happy, excited, satisfied")
    case positive

    @Description("Neutral sentiment - factual, objective")
    case neutral

    @Description("Negative sentiment - angry, sad, frustrated")
    case negative
}
```

## Optional Fields

Handle missing data gracefully:

```swift
@SwamlType
struct ExtractedData {
    let title: String           // Required
    let author: String?         // Optional
    let publishDate: String?    // Optional
    let pageCount: Int?         // Optional
}
```

## Arrays and Maps

```swift
@SwamlType
struct Analysis {
    let keywords: [String]
    let sentimentBySection: [String: String]  // Section name -> sentiment
    let scores: [Double]
}
```

## Raw Completions

When you don't need structured output:

```swift
let response = try await client.rawComplete(
    model: "openai/gpt-4o-mini",
    messages: [
        ChatMessage(role: .system, content: "You are a poet."),
        ChatMessage(role: .user, content: "Write a haiku about Swift.")
    ],
    options: SwamlCallOptions(temperature: 1.0)
)

print(response)  // Free-form text
```

## Error Recovery

Handle parse errors gracefully:

```swift
do {
    let result = try await client.call(
        model: "openai/gpt-4o-mini",
        prompt: prompt,
        returnType: MyType.self
    )
    // Use result
} catch SwamlError.parseError(let message) {
    // Try with a more capable model
    let result = try await client.call(
        model: "openai/gpt-4o",
        prompt: prompt,
        returnType: MyType.self
    )
}
```

## Combining Static and Dynamic Types

```swift
// Static type
@SwamlType
struct Order {
    let id: String
    let items: [String]
    let status: OrderStatus
}

@SwamlType
@SwamlDynamic
enum OrderStatus: String {
    case pending
    case processing
    case shipped
}

// Add runtime values
let client = SwamlClient(provider: .openRouter(apiKey: key))
try client.extendEnum(OrderStatus.self, with: ["delivered", "returned"])

// Now OrderStatus accepts: pending, processing, shipped, delivered, returned
```

## Custom Schema Rendering

Access the generated prompt format:

```swift
import SWAML

let prompt = SchemaPromptRenderer.render(for: MyType.self)
print(prompt)
// Output:
// Answer in JSON using this schema:
// {
//   field1: string,
//   field2: int,
// }
```

## Performance Tips

1. **Use appropriate models** - `gpt-4o-mini` is fast and cheap for simple extractions
2. **Keep schemas simple** - Fewer fields = faster, more reliable responses
3. **Use descriptions** - Help the model understand what you want
4. **Set maxTokens** - Prevent runaway responses
5. **Lower temperature** - For more deterministic outputs (0.0-0.3)
