# TypeBuilder

Build schemas dynamically at runtime for cases where types aren't known at compile time.

## Creating a TypeBuilder

```swift
let tb = TypeBuilder()
```

## Building Enums

```swift
let status = tb.enumBuilder("Status")
status.addValue("pending")
status.addValue("active")
status.addValue("completed")

// With descriptions
status.addValue("cancelled").description("Order was cancelled by user")
```

## Building Classes (Structs)

```swift
let order = tb.addClass("Order")
order.addProperty("id", .string).description("Unique identifier")
order.addProperty("total", .float).description("Total in dollars")
order.addProperty("items", .list(.string)).description("Item names")
order.addProperty("status", .reference("Status")).description("Current status")

// Optional properties
order.addProperty("notes", .optional(.string))
```

## Field Types

```swift
.string           // String
.int              // Int
.float            // Double
.bool             // Bool
.null             // Null
.literal("x")     // Literal string value
.list(.string)    // Array of strings
.optional(.int)   // Optional int
.reference("Foo") // Reference to another type
.union([.string, .int])  // String or Int
```

## Getting Schemas

```swift
// Get class schema
let orderSchema = tb.buildClassSchema("Order")

// Get enum schema
let statusSchema = tb.buildEnumSchema("Status")
```

## Using with SwamlClient

```swift
let tb = TypeBuilder()

// Build your types
let category = tb.enumBuilder("Category")
category.addValue("tech")
category.addValue("science")

let article = tb.addClass("Article")
article.addProperty("title", .string)
article.addProperty("category", .reference("Category"))
article.addProperty("summary", .string)

// Create client with TypeBuilder
let client = SwamlClient(provider: .openRouter(apiKey: key), typeBuilder: tb)

// Call with dynamic schema
let schema = tb.buildClassSchema("Article")!
let result = try await client.callDynamic(
    model: "openai/gpt-4o-mini",
    prompt: "Summarize this article about AI...",
    schema: schema
)

// Access result
print(result["title"]?.stringValue)     // Article title
print(result["category"]?.stringValue)  // "tech" or "science"
print(result["summary"]?.stringValue)   // Summary text
```

## Extending Static Types

For types marked with `@SwamlDynamic`:

```swift
@SwamlType
@SwamlDynamic
enum Priority: String {
    case low
    case medium
    case high
}

// Register with TypeBuilder
tb.registerDynamicType(Priority.self)

// Extend at runtime
let priorityBuilder = try tb.enumBuilder(for: Priority.self)
priorityBuilder.addValue("critical")
priorityBuilder.addValue("urgent")
```

## Complete Example

```swift
import SWAML

// Build a ticket system schema dynamically
let tb = TypeBuilder()

// Priority enum
let priority = tb.enumBuilder("Priority")
priority.addValue("low").description("Non-urgent issues")
priority.addValue("medium").description("Normal priority")
priority.addValue("high").description("Urgent issues")
priority.addValue("critical").description("System down")

// Status enum
let status = tb.enumBuilder("Status")
status.addValue("open")
status.addValue("in_progress")
status.addValue("resolved")
status.addValue("closed")

// Ticket class
let ticket = tb.addClass("Ticket")
ticket.addProperty("title", .string).description("Brief summary")
ticket.addProperty("description", .string).description("Detailed description")
ticket.addProperty("priority", .reference("Priority"))
ticket.addProperty("status", .reference("Status"))
ticket.addProperty("tags", .list(.string)).description("Categorization tags")
ticket.addProperty("assignee", .optional(.string)).description("Assigned engineer")

// Use it
let client = SwamlClient(provider: .openRouter(apiKey: key), typeBuilder: tb)
let schema = tb.buildClassSchema("Ticket")!

let result = try await client.callDynamic(
    model: "openai/gpt-4o-mini",
    prompt: "Create a ticket for: User can't log in after password reset",
    schema: schema
)
```
