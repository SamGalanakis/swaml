# BAML Swift Generator

Generate type-safe Swift code from [BAML](https://docs.boundaryml.com/) schema files for use with the [SWAML](https://github.com/SamGalanakis/swaml) runtime.

## Quick Start: Using BAML with Swift Today

BAML doesn't have native Swift support yet, but you can use it via the **OpenAPI approach**:

### 1. Install Prerequisites

```bash
# Install Node.js (for BAML CLI)
brew install node

# Install Java (for OpenAPI generator)
brew install openjdk

# Install BAML VSCode extension for syntax highlighting
# Search "BAML" in VSCode extensions
```

### 2. Initialize BAML Project

```bash
# Create a new BAML project with OpenAPI/Swift support
npx @boundaryml/baml init --client-type rest/openapi --openapi-client-type swift5

# This creates:
# - baml_src/ directory with your .baml files
# - generators.baml with OpenAPI configuration
```

### 3. Write Your BAML Schema

Create `baml_src/main.baml`:

```baml
// Define your types
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

// Define your LLM function
function ClassifySentiment(text: string) -> SentimentResult {
    client "openai/gpt-4o"
    prompt #"
        Analyze the sentiment of the following text and return JSON:

        Text: {{ text }}

        Return a JSON object with:
        - sentiment: "POSITIVE", "NEGATIVE", or "NEUTRAL"
        - confidence: a number between 0 and 1
        - explanation: brief explanation of the sentiment
    "#
}
```

### 4. Start BAML Dev Server

```bash
# Start the BAML server (runs on localhost:2024)
npx @boundaryml/baml dev --preview

# This will:
# - Parse your .baml files
# - Start REST API server
# - Generate baml_client/openapi.yaml
# - Generate Swift client in baml_client/
```

### 5. Use Generated Swift Client

```swift
import Foundation

// The OpenAPI generator creates these types for you
let client = BamlAPI()

// Call your BAML function
let result = try await client.classifySentiment(text: "I love this product!")
print(result.sentiment)     // .positive
print(result.confidence)    // 0.95
```

### 6. Production Deployment

For production, run the BAML server as a sidecar or separate service:

```bash
# Production mode
npx @boundaryml/baml serve --port 2024
```

---

## Alternative: Native Swift Generation (Recommended)

This generator produces native Swift code directly from BAML files, without requiring the REST server. This approach is useful for:

- Embedding generated code directly in your Swift package
- Avoiding network overhead of REST calls
- Full control over the generated code
- End-to-end BAML → Swift workflow

### How It Works

```
.baml files → [BAML Parser] → BamlIR → [Swift Generator] → Swift code
                    ↑                           ↑
           (internal-baml-core)          (this crate)
```

### CLI Usage (Recommended)

The easiest way to generate Swift code from BAML files:

```bash
# Install the CLI
cargo install --git https://github.com/SamGalanakis/swaml --features cli baml-swift

# Generate Swift from BAML files
baml-swift --input ./baml_src --output ./Sources/BamlClient

# With options
baml-swift \
    --input ./baml_src \
    --output ./Sources/Generated \
    --package MyBamlTypes \
    --streaming \
    --verbose
```

**CLI Options:**
- `-i, --input <DIR>` - Directory containing .baml files (default: `baml_src`)
- `-o, --output <DIR>` - Output directory for Swift code (default: `baml_client`)
- `-p, --package <NAME>` - Swift package name (default: `BamlClient`)
- `--streaming` - Generate streaming type variants
- `-v, --verbose` - Verbose output

### Usage as Rust Library

**With BAML file parsing (recommended):**

```rust
use baml_generator_swift::{parse_baml_dir, SwiftGenerator};
use std::path::Path;

// Parse BAML files from a directory
let ir = parse_baml_dir(Path::new("./baml_src"))?;

// Generate Swift code
let generator = SwiftGenerator::with_defaults();
let files = generator.generate(&ir)?;

// Write files
for (path, content) in files.files().iter() {
    std::fs::write(path, content)?;
}
```

**With manual IR construction:**

```rust
use baml_generator_swift::{
    SwiftGenerator, GeneratorConfig, BamlIR,
    EnumDef, EnumValueDef, ClassDef, FieldDef, FunctionDef, ParamDef,
    FieldType,
};

// Construct IR (normally this comes from BAML's parser)
let ir = BamlIR {
    enums: vec![EnumDef {
        name: "Sentiment".to_string(),
        values: vec![
            EnumValueDef { name: "POSITIVE".to_string(), alias: None, docstring: None },
            EnumValueDef { name: "NEGATIVE".to_string(), alias: None, docstring: None },
        ],
        docstring: None,
        dynamic: false,
    }],
    classes: vec![ClassDef {
        name: "SentimentResult".to_string(),
        fields: vec![
            FieldDef {
                name: "sentiment".to_string(),
                field_type: FieldType::Enum("Sentiment".to_string()),
                docstring: None
            },
            FieldDef {
                name: "confidence".to_string(),
                field_type: FieldType::Float,
                docstring: None
            },
        ],
        docstring: None,
        has_dynamic_fields: false,
    }],
    functions: vec![],
    type_aliases: vec![],
    clients: vec![],
};

// Generate Swift code
let generator = SwiftGenerator::with_defaults();
let files = generator.generate(&ir)?;

// Write files
for (path, content) in files.files().iter() {
    std::fs::write(path, content)?;
}
```

### Generated Output

The generator produces:

```
baml_client/
├── Types.swift       # Structs and enums
├── BamlClient.swift  # Function signatures
├── Globals.swift     # Client configuration
├── Unions.swift      # Union types (if any)
└── StreamTypes.swift # Streaming partials (if enabled)
```

**Types.swift:**
```swift
// Generated by BAML - do not edit

import Foundation
import SWAML

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
```

---

## Using Generated Code with SWAML Runtime

Whether you use the OpenAPI approach or native generation, you can use the [SWAML runtime](https://github.com/SamGalanakis/swaml) for direct LLM calls:

### Add SWAML to Your Project

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/SamGalanakis/swaml", branch: "main"),
],
targets: [
    .target(name: "YourApp", dependencies: ["SWAML"]),
]
```

### Direct LLM Calls with SWAML

```swift
import SWAML

// Configure runtime
let runtime = await BamlRuntime.openRouter(
    apiKey: ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]!,
    model: "anthropic/claude-sonnet-4-20250514"
)

// Make request and parse response
let response = try await runtime.complete(
    messages: [
        .system("Return JSON with sentiment, confidence, explanation"),
        .user("Analyze: I love this product!")
    ],
    responseFormat: .jsonObject
)

// Parse into your generated types
let result: SentimentResult = try OutputParser.parse(
    response.content,
    type: SentimentResult.self
)
```

---

## Type Mapping Reference

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

---

## Roadmap: Native BAML Integration

The goal is to add Swift as a first-class BAML target language:

1. **Done**: Native Swift generator with full type support
2. **Done**: Direct BAML file parsing via `internal-baml-core` integration
3. **Done**: CLI tool for end-to-end workflow (`baml-swift`)
4. **Future**: Contribute Swift generator upstream to BAML repository

### Contributing to BAML

To add native Swift support to BAML itself, you would:

1. Fork [BoundaryML/baml](https://github.com/BoundaryML/baml)
2. Add `language_client_swift/` following the pattern of `language_client_go/`
3. Integrate this generator's logic
4. Submit PR

---

## Development

### Building

```bash
cd generator

# Build library only
cargo build --release

# Build with BAML parsing support
cargo build --release --features baml-ir

# Build CLI
cargo build --release --features cli
```

### Running Tests

```bash
# Run all tests
cargo test

# Run tests with BAML parsing
cargo test --features baml-ir
```

### Test Fixtures

Example BAML schemas in `tests/fixtures/`:
- `sentiment.baml` - Basic enum and class
- `user_profile.baml` - Complex nested types with maps
- `content_types.baml` - Union types
- `ecommerce.baml` - Real-world e-commerce schema

---

## Resources

- [BAML Documentation](https://docs.boundaryml.com/)
- [BAML REST API Guide](https://docs.boundaryml.com/guide/installation-language/rest-api-other-languages)
- [SWAML Runtime](https://github.com/SamGalanakis/swaml)
- [OpenAPI Generator](https://openapi-generator.tech/)

## License

MIT
