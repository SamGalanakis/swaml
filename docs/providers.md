# LLM Providers

SWAML supports multiple LLM providers through the `LLMProvider` enum.

## OpenRouter

Access to many models through a single API:

```swift
let client = SwamlClient(provider: .openRouter(apiKey: "your-openrouter-key"))

// Use any model available on OpenRouter
let result = try await client.call(
    model: "openai/gpt-4o-mini",
    prompt: "...",
    returnType: MyType.self
)

// Or other providers
let result = try await client.call(
    model: "anthropic/claude-3-5-sonnet",
    prompt: "...",
    returnType: MyType.self
)
```

Get your API key at [openrouter.ai](https://openrouter.ai)

## OpenAI Direct

Direct connection to OpenAI:

```swift
let client = SwamlClient(provider: .openAI(apiKey: "your-openai-key"))

let result = try await client.call(
    model: "gpt-4o-mini",  // No prefix needed
    prompt: "...",
    returnType: MyType.self
)
```

## Anthropic Direct

Direct connection to Anthropic:

```swift
let client = SwamlClient(provider: .anthropic(apiKey: "your-anthropic-key"))

let result = try await client.call(
    model: "claude-3-5-sonnet-20241022",
    prompt: "...",
    returnType: MyType.self
)
```

## Custom Endpoint

For self-hosted models or OpenAI-compatible APIs:

```swift
let client = SwamlClient(provider: .custom(
    baseURL: URL(string: "https://your-api.example.com/v1")!,
    apiKey: "your-key",
    headers: ["X-Custom-Header": "value"]
))
```

The custom provider uses the OpenAI-compatible chat completions format.

## Model Selection

Different models have different capabilities and costs:

| Model | Best For |
|-------|----------|
| `gpt-4o-mini` | Fast, cheap, good for simple tasks |
| `gpt-4o` | Complex reasoning, high accuracy |
| `claude-3-5-sonnet` | Long context, nuanced responses |
| `claude-3-5-haiku` | Fast, cheap Claude alternative |

## Call Options

Fine-tune model behavior:

```swift
let result = try await client.call(
    model: "openai/gpt-4o-mini",
    prompt: "...",
    returnType: MyType.self,
    options: SwamlCallOptions(
        temperature: 0.7,      // Creativity (0-2)
        maxTokens: 1000,       // Max response length
        topP: 0.9,             // Nucleus sampling
        frequencyPenalty: 0.0, // Reduce repetition
        presencePenalty: 0.0   // Encourage new topics
    )
)
```

## Error Handling

```swift
do {
    let result = try await client.call(...)
} catch let error as SwamlError {
    switch error {
    case .networkError(let msg):
        print("Network issue: \(msg)")
    case .apiError(let code, let msg):
        print("API error \(code): \(msg)")
    case .parseError(let msg):
        print("Failed to parse response: \(msg)")
    default:
        print("Error: \(error)")
    }
}
```
