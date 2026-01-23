import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwamlMacrosPlugin)
@testable import SwamlMacrosPlugin

final class SwamlTypeMacroTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "BamlType": SwamlTypeMacro.self,
        "BamlDynamic": SwamlDynamicMacro.self,
        "Description": DescriptionMacro.self,
        "Alias": AliasMacro.self,
    ]

    // MARK: - Struct Tests

    func testSimpleStruct() throws {
        assertMacroExpansion(
            """
            @SwamlType
            struct User {
                let name: String
                let age: Int
            }
            """,
            expandedSource: """
            struct User {
                let name: String
                let age: Int
            }

            extension User: SwamlTyped {
                public static var swamlTypeName: String { "User" }
                public static var swamlSchema: JSONSchema {
                    .object(properties: ["age": .integer, "name": .string], required: ["age", "name"])
                }
                public static var isDynamic: Bool { false }
                public static var fieldDescriptions: [String: String] { [:] }
                public static var fieldAliases: [String: String] { [:] }
            }
            """,
            macros: testMacros
        )
    }

    func testStructWithOptional() throws {
        assertMacroExpansion(
            """
            @SwamlType
            struct Profile {
                let username: String
                let bio: String?
            }
            """,
            expandedSource: """
            struct Profile {
                let username: String
                let bio: String?
            }

            extension Profile: SwamlTyped {
                public static var swamlTypeName: String { "Profile" }
                public static var swamlSchema: JSONSchema {
                    .object(properties: ["bio": .anyOf([.string, .null]), "username": .string], required: ["username"])
                }
                public static var isDynamic: Bool { false }
                public static var fieldDescriptions: [String: String] { [:] }
                public static var fieldAliases: [String: String] { [:] }
            }
            """,
            macros: testMacros
        )
    }

    func testStructWithDescriptions() throws {
        assertMacroExpansion(
            """
            @SwamlType
            struct Order {
                @Description("Unique order ID")
                let orderId: String

                @Description("Total in cents")
                let totalCents: Int
            }
            """,
            expandedSource: """
            struct Order {
                let orderId: String

                let totalCents: Int
            }

            extension Order: SwamlTyped {
                public static var swamlTypeName: String { "Order" }
                public static var swamlSchema: JSONSchema {
                    .object(properties: ["orderId": .string, "totalCents": .integer], required: ["orderId", "totalCents"])
                }
                public static var isDynamic: Bool { false }
                public static var fieldDescriptions: [String: String] { ["orderId": "Unique order ID", "totalCents": "Total in cents"] }
                public static var fieldAliases: [String: String] { [:] }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Enum Tests

    func testSimpleEnum() throws {
        assertMacroExpansion(
            """
            @SwamlType
            enum Status: String {
                case active
                case inactive
            }
            """,
            expandedSource: """
            enum Status: String {
                case active
                case inactive
            }

            extension Status: SwamlTyped {
                public static var swamlTypeName: String { "Status" }
                public static var swamlSchema: JSONSchema { .enum(values: ["active", "inactive"]) }
                public static var isDynamic: Bool { false }
                public static var fieldDescriptions: [String: String] { [:] }
                public static var fieldAliases: [String: String] { [:] }
            }
            """,
            macros: testMacros
        )
    }

    func testDynamicEnum() throws {
        assertMacroExpansion(
            """
            @SwamlType
            @SwamlDynamic
            enum Category: String {
                case electronics
                case clothing
            }
            """,
            expandedSource: """
            enum Category: String {
                case electronics
                case clothing
            }

            extension Category: SwamlTyped {
                public static var swamlTypeName: String { "Category" }
                public static var swamlSchema: JSONSchema { .enum(values: ["electronics", "clothing"]) }
                public static var isDynamic: Bool { true }
                public static var fieldDescriptions: [String: String] { [:] }
                public static var fieldAliases: [String: String] { [:] }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Array and Dictionary Tests

    func testStructWithArray() throws {
        assertMacroExpansion(
            """
            @SwamlType
            struct Team {
                let name: String
                let members: [String]
            }
            """,
            expandedSource: """
            struct Team {
                let name: String
                let members: [String]
            }

            extension Team: SwamlTyped {
                public static var swamlTypeName: String { "Team" }
                public static var swamlSchema: JSONSchema {
                    .object(properties: ["members": .array(items: .string), "name": .string], required: ["members", "name"])
                }
                public static var isDynamic: Bool { false }
                public static var fieldDescriptions: [String: String] { [:] }
                public static var fieldAliases: [String: String] { [:] }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Nested Type Reference Tests

    func testStructWithTypeReference() throws {
        assertMacroExpansion(
            """
            @SwamlType
            struct User {
                let name: String
                let status: UserStatus
            }
            """,
            expandedSource: """
            struct User {
                let name: String
                let status: UserStatus
            }

            extension User: SwamlTyped {
                public static var swamlTypeName: String { "User" }
                public static var swamlSchema: JSONSchema {
                    .object(properties: ["name": .string, "status": .ref("UserStatus")], required: ["name", "status"])
                }
                public static var isDynamic: Bool { false }
                public static var fieldDescriptions: [String: String] { [:] }
                public static var fieldAliases: [String: String] { [:] }
            }
            """,
            macros: testMacros
        )
    }
}
#endif
