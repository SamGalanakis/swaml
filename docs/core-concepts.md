# Core Concepts

## Schema Generation

SWAML generates JSON schema prompts from Swift types. The `@SwamlType` macro creates conformance to `SwamlTyped`, which provides:

- `swamlTypeName` - The type name as a string
- `swamlSchema` - JSON Schema representation
- `fieldDescriptions` - Property descriptions for prompts
- `isDynamic` - Whether the type can be extended at runtime

## Output Formats

Different types get different prompt formats:

| Type | Prompt Format |
|------|---------------|
| Struct | `Answer in JSON using this schema:\n{...}` |
| Enum | `Answer with any of the categories:\n- value1\n- value2` |
| Int | `Answer as an int` |
| Double | `Answer as a float` |
| Bool | `Answer as a bool` |
| String | (no format instruction) |
| Array | `Answer with a JSON Array using this schema:\n[...]` |

## The @SwamlType Macro

```swift
@SwamlType
struct User {
    let name: String
    let age: Int
    let email: String?
}
```

Generates:

```swift
extension User: SwamlTyped {
    static var swamlTypeName: String { "User" }
    static var swamlSchema: JSONSchema {
        .object(properties: [
            "name": .string,
            "age": .integer,
            "email": .anyOf([.string, .null])
        ], required: ["name", "age"])
    }
    static var isDynamic: Bool { false }
    static var fieldDescriptions: [String: String] { [:] }
    static var fieldAliases: [String: String] { [:] }
}
```

## The @Description Macro

Add descriptions to fields (included in LLM prompts):

```swift
@SwamlType
struct Order {
    @Description("Unique order identifier")
    let orderId: String

    @Description("Total price in cents")
    let totalCents: Int
}
```

The prompt includes:

```
{
  // Unique order identifier
  orderId: string,
  // Total price in cents
  totalCents: int,
}
```

## The @SwamlDynamic Macro

Mark types as extensible at runtime:

```swift
@SwamlType
@SwamlDynamic
enum Category: String {
    case electronics
    case clothing
}
```

Then extend at runtime:

```swift
try client.extendEnum(Category.self, with: ["furniture", "books"])
```

## Robust JSON Parsing

SWAML's parser handles common LLM output issues:

- **Trailing commas**: `{"items": [1, 2, 3,]}`
- **Unquoted keys**: `{name: "Alice"}`
- **Single quotes**: `{'status': 'active'}`
- **Comments**: `{"value": 42 /* note */}`
- **Markdown blocks**: ` ```json {"x": 1} ``` `
- **Newlines in strings**: Multi-line string values

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
| Custom struct | Object schema |
| Enum | Enum of literal values |
