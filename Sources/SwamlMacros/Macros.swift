import SWAML

/// Swift macros for SWAML type generation.
///
/// These macros generate `SwamlTyped` protocol conformance at compile time,
/// providing schema information for structured LLM output.
///
/// Usage:
/// ```swift
/// @SwamlType
/// struct User {
///     @Description("The user's full name")
///     let name: String
///
///     let age: Int
///
///     @Description("Current account status")
///     let status: UserStatus
/// }
///
/// @SwamlType
/// @SwamlDynamic  // Allows runtime extension via TypeBuilder
/// enum UserStatus: String {
///     case active
///     case inactive
/// }
/// ```

// MARK: - SwamlType Macro

/// Generates `SwamlTyped` protocol conformance for a struct or enum.
///
/// The macro generates:
/// - `swamlTypeName`: The type name as a string
/// - `swamlSchema`: JSON Schema representation
/// - `fieldDescriptions`: Property descriptions from `@Description`
/// - `isDynamic`: Whether the type can be extended at runtime
///
/// Example:
/// ```swift
/// @SwamlType
/// struct Person {
///     let name: String
///     let age: Int
/// }
/// ```
///
/// Generates:
/// ```swift
/// extension Person: SwamlTyped {
///     static var swamlTypeName: String { "Person" }
///     static var swamlSchema: JSONSchema {
///         .object()
///             .property("name", .string)
///             .property("age", .integer)
///             .build()
///     }
///     static var isDynamic: Bool { false }
/// }
/// ```
@attached(extension, conformances: SwamlTyped, names: named(swamlTypeName), named(swamlSchema), named(isDynamic), named(fieldDescriptions), named(fieldAliases))
public macro SwamlType() = #externalMacro(module: "SwamlMacrosPlugin", type: "SwamlTypeMacro")

// MARK: - SwamlDynamic Macro

/// Marks a type as dynamically extensible at runtime.
///
/// When applied to an enum, the enum's values can be extended using `TypeBuilder`
/// at runtime. This is useful when the possible values aren't known until runtime.
///
/// Example:
/// ```swift
/// @SwamlType
/// @SwamlDynamic
/// enum Category: String {
///     case electronics
///     case clothing
/// }
///
/// // Later, at runtime:
/// let client = SwamlClient(provider: .openAI(apiKey: key))
/// try client.extendEnum(Category.self, with: ["furniture", "books"])
/// ```
///
/// Without `@SwamlDynamic`, attempting to extend a type at runtime will throw an error.
@attached(peer)
public macro SwamlDynamic() = #externalMacro(module: "SwamlMacrosPlugin", type: "SwamlDynamicMacro")

// MARK: - Description Macro

/// Attaches a description to a property or enum case.
///
/// Descriptions are included in the schema prompt to help the LLM understand
/// what each field represents.
///
/// Example:
/// ```swift
/// @SwamlType
/// struct Order {
///     @Description("Unique order identifier")
///     let orderId: String
///
///     @Description("Total price in cents")
///     let totalCents: Int
///
///     @Description("Current order status")
///     let status: OrderStatus
/// }
/// ```
///
/// The descriptions appear as comments in the schema prompt:
/// ```
/// {
///   "orderId": string,  // Unique order identifier
///   "totalCents": int,  // Total price in cents
///   "status": OrderStatus  // Current order status
/// }
/// ```
@attached(peer)
public macro Description(_ description: String) = #externalMacro(module: "SwamlMacrosPlugin", type: "DescriptionMacro")

// MARK: - Alias Macro

/// Provides an alternative name for a property in LLM output.
///
/// The alias is used when parsing LLM responses - if the LLM outputs the alias
/// instead of the property name, it will still be parsed correctly.
///
/// Example:
/// ```swift
/// @SwamlType
/// struct User {
///     @Alias("user_name")
///     let userName: String
///
///     @Alias("email_address")
///     let email: String
/// }
/// ```
@attached(peer)
public macro Alias(_ alias: String) = #externalMacro(module: "SwamlMacrosPlugin", type: "AliasMacro")
