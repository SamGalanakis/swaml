# BAML Swift Generator

A Rust-based code generator that converts [BAML](https://docs.boundaryml.com/) schema files into Swift code compatible with the [SWAML](https://github.com/SamGalanakis/swaml) runtime.

## Overview

This generator takes BAML definitions (classes, enums, functions) and produces type-safe Swift code with:

- Structs with `Codable` conformance
- Enums with raw values and `CaseIterable`
- Async/await function signatures
- Automatic `CodingKeys` for snake_case → camelCase mapping
- Union types as Swift enums with associated values
- Streaming partial types for incremental parsing

## Installation

### As a Rust Binary

```bash
cd generator
cargo build --release
```

### As a Library Dependency

```toml
[dependencies]
baml-generator-swift = { git = "https://github.com/SamGalanakis/swaml", branch = "main" }
```

## Usage

### From BAML Files to Swift

1. **Define your schema in `.baml` files:**

```baml
// sentiment.baml

enum Sentiment {
    POSITIVE
    NEGATIVE
    NEUTRAL
}

class SentimentResult {
    sentiment Sentiment
    confidence float
    explanation string?
}

function ClassifySentiment(text: string) -> SentimentResult {
    client default
    prompt #"
        Analyze the sentiment of: {{ text }}
        Return JSON with sentiment, confidence (0-1), and explanation.
    "#
}
```

2. **Generate Swift code:**

```rust
use baml_generator_swift::{
    SwiftGenerator, GeneratorConfig, BamlIR,
    EnumDef, EnumValueDef, ClassDef, FieldDef, FunctionDef, ParamDef,
    FieldType,
};

// Build the IR from your BAML files (parser not included)
let ir = BamlIR {
    enums: vec![EnumDef {
        name: "Sentiment".to_string(),
        values: vec![
            EnumValueDef { name: "POSITIVE".to_string(), alias: None, docstring: None },
            EnumValueDef { name: "NEGATIVE".to_string(), alias: None, docstring: None },
            EnumValueDef { name: "NEUTRAL".to_string(), alias: None, docstring: None },
        ],
        docstring: None,
        dynamic: false,
    }],
    classes: vec![ClassDef {
        name: "SentimentResult".to_string(),
        fields: vec![
            FieldDef { name: "sentiment".to_string(), field_type: FieldType::Enum("Sentiment".to_string()), docstring: None },
            FieldDef { name: "confidence".to_string(), field_type: FieldType::Float, docstring: None },
            FieldDef { name: "explanation".to_string(), field_type: FieldType::Optional(Box::new(FieldType::String)), docstring: None },
        ],
        docstring: None,
        has_dynamic_fields: false,
    }],
    functions: vec![FunctionDef {
        name: "ClassifySentiment".to_string(),
        params: vec![ParamDef { name: "text".to_string(), param_type: FieldType::String, docstring: None }],
        return_type: FieldType::Class("SentimentResult".to_string()),
        docstring: None,
        default_client: Some("default".to_string()),
    }],
    type_aliases: vec![],
    clients: vec![],
};

// Generate Swift code
let generator = SwiftGenerator::with_defaults();
let files = generator.generate(&ir)?;

// Write files to disk
for (path, content) in files.iter() {
    std::fs::write(path, content)?;
}
```

3. **Generated Swift code:**

```swift
// Types.swift
public enum Sentiment: String, Codable, Sendable, CaseIterable {
    case positive = "POSITIVE"
    case negative = "NEGATIVE"
    case neutral = "NEUTRAL"
}

public struct SentimentResult: Codable, Sendable, Equatable {
    public let sentiment: Sentiment
    public let confidence: Double
    public let explanation: String?
}

// BamlClient.swift
public actor BamlClient {
    private let runtime: BamlRuntime

    public init(runtime: BamlRuntime) {
        self.runtime = runtime
    }

    public func classifySentiment(text: String) async throws -> SentimentResult {
        // Implementation using SWAML runtime
    }
}
```

## Swift Project Integration

### 1. Add SWAML Dependency

In your `Package.swift`:

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

### 2. Copy Generated Files

Copy the generated `baml_client/` directory into your Swift project:

```
YourApp/
├── Package.swift
├── Sources/
│   └── YourApp/
│       ├── main.swift
│       └── baml_client/          # Generated code
│           ├── Types.swift
│           ├── BamlClient.swift
│           ├── Globals.swift
│           └── Unions.swift      # If union types exist
```

### 3. Use the Generated Code

```swift
import SWAML

// Configure the runtime
let runtime = await BamlRuntime.openRouter(
    apiKey: ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]!,
    model: "anthropic/claude-sonnet-4-20250514"
)

// Create the client
let client = BamlClient(runtime: runtime)

// Call your BAML functions with full type safety
let result = try await client.classifySentiment(text: "I love this product!")
print(result.sentiment)      // .positive
print(result.confidence)     // 0.95
print(result.explanation)    // "The text expresses enthusiasm..."
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
| `class Foo` | `struct Foo: Codable, Sendable, Equatable` |
| `enum Bar` | `enum Bar: String, Codable, Sendable, CaseIterable` |
| `A \| B \| C` | `enum AOrBOrC { case a(A), case b(B), case c(C) }` |

## Generator Configuration

```rust
let config = GeneratorConfig::builder()
    .output_dir("Sources/Generated")
    .package_name("MyBamlClient")
    .generate_streaming(true)  // Generate partial types for streaming
    .build();

let generator = SwiftGenerator::new(config);
```

## Complex Example: E-commerce

BAML schema:

```baml
enum OrderStatus {
    PENDING
    PROCESSING
    SHIPPED
    DELIVERED
}

class Money {
    amount float
    currency string
}

class OrderItem {
    product_id string
    quantity int
    unit_price Money
}

class Order {
    order_id string
    items OrderItem[]
    status OrderStatus
    shipping_address string
    total Money
    notes string?
    metadata map<string, string>
}

function CreateOrder(
    customer_id: string,
    items: OrderItem[],
    shipping_address: string
) -> Order {
    client default
    prompt #"Create order for customer {{ customer_id }}"#
}
```

Generated Swift:

```swift
public enum OrderStatus: String, Codable, Sendable, CaseIterable {
    case pending = "PENDING"
    case processing = "PROCESSING"
    case shipped = "SHIPPED"
    case delivered = "DELIVERED"
}

public struct Money: Codable, Sendable, Equatable {
    public let amount: Double
    public let currency: String
}

public struct OrderItem: Codable, Sendable, Equatable {
    public let productId: String
    public let quantity: Int
    public let unitPrice: Money

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case quantity
        case unitPrice = "unit_price"
    }
}

public struct Order: Codable, Sendable, Equatable {
    public let orderId: String
    public let items: [OrderItem]
    public let status: OrderStatus
    public let shippingAddress: String
    public let total: Money
    public let notes: String?
    public let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case items, status
        case shippingAddress = "shipping_address"
        case total, notes, metadata
    }
}
```

## Union Types

BAML union types become Swift enums with associated values:

```baml
class TextContent {
    body string
}

class ImageContent {
    url string
    alt_text string?
}

class ContentItem {
    id string
    content TextContent | ImageContent
}
```

Generated:

```swift
public enum TextContentOrImageContent: Codable, Sendable, Equatable {
    case textContent(TextContent)
    case imageContent(ImageContent)

    public init(from decoder: Decoder) throws {
        if let value = try? TextContent(from: decoder) {
            self = .textContent(value)
            return
        }
        if let value = try? ImageContent(from: decoder) {
            self = .imageContent(value)
            return
        }
        throw DecodingError.typeMismatch(/* ... */)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .textContent(let value): try value.encode(to: encoder)
        case .imageContent(let value): try value.encode(to: encoder)
        }
    }
}
```

## Streaming Support

When `generate_streaming` is enabled, partial types are generated for incremental parsing:

```swift
// All fields become optional for partial parsing
public struct SentimentResultPartial: Codable, Sendable {
    public let sentiment: Sentiment?
    public let confidence: Double?
    public let explanation: String?
}
```

## Development

### Running Tests

```bash
cargo test
```

### Test Fixtures

Example BAML files are in `tests/fixtures/`:
- `sentiment.baml` - Basic enum and class
- `user_profile.baml` - Complex nested types with maps
- `content_types.baml` - Union types
- `ecommerce.baml` - Real-world e-commerce schema

## License

MIT
