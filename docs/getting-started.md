# Getting Started

## Installation

Add SWAML to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Ascending-AI/swaml", branch: "main"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["SWAML", "SwamlMacros"]
    ),
]
```

## First Call

```swift
import SWAML
import SwamlMacros

// 1. Define your response type
@SwamlType
struct Sentiment {
    let sentiment: String
    let confidence: Double
}

// 2. Create a client
let client = SwamlClient(provider: .openRouter(apiKey: "your-api-key"))

// 3. Make a typed call
let result = try await client.call(
    model: "openai/gpt-4o-mini",
    prompt: "Analyze the sentiment of: 'I love this!'",
    returnType: Sentiment.self
)

print(result.sentiment)   // "positive"
print(result.confidence)  // 0.95
```

## How It Works

1. **Define types** - Use `@SwamlType` to mark structs/enums
2. **SWAML generates prompts** - Schema instructions are automatically added
3. **LLM responds** - The model outputs JSON matching your schema
4. **SWAML parses** - Response is decoded into your Swift type

The LLM sees a prompt like:

```
Analyze the sentiment of: 'I love this!'

Answer in JSON using this schema:
{
  confidence: float,
  sentiment: string,
}
```

## Next Steps

- [Core Concepts](core-concepts.md) - Understand how SWAML works
- [API Reference](api-reference.md) - Full API documentation
- [TypeBuilder](type-builder.md) - Build schemas at runtime
