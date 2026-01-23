import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwamlMacrosPlugin)
@testable import SwamlMacrosPlugin

final class BamlTypeMacroTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "BamlType": BamlTypeMacro.self,
        "BamlDynamic": BamlDynamicMacro.self,
        "Description": DescriptionMacro.self,
        "Alias": AliasMacro.self,
    ]

    // MARK: - Struct Tests

    func testSimpleStruct() throws {
        assertMacroExpansion(
            """
            @BamlType
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

            extension User: BamlTyped {
                public static var bamlTypeName: String { "User" }
                public static var bamlSchema: JSONSchema {
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
            @BamlType
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

            extension Profile: BamlTyped {
                public static var bamlTypeName: String { "Profile" }
                public static var bamlSchema: JSONSchema {
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
            @BamlType
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

            extension Order: BamlTyped {
                public static var bamlTypeName: String { "Order" }
                public static var bamlSchema: JSONSchema {
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
            @BamlType
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

            extension Status: BamlTyped {
                public static var bamlTypeName: String { "Status" }
                public static var bamlSchema: JSONSchema { .enum(values: ["active", "inactive"]) }
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
            @BamlType
            @BamlDynamic
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

            extension Category: BamlTyped {
                public static var bamlTypeName: String { "Category" }
                public static var bamlSchema: JSONSchema { .enum(values: ["electronics", "clothing"]) }
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
            @BamlType
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

            extension Team: BamlTyped {
                public static var bamlTypeName: String { "Team" }
                public static var bamlSchema: JSONSchema {
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
            @BamlType
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

            extension User: BamlTyped {
                public static var bamlTypeName: String { "User" }
                public static var bamlSchema: JSONSchema {
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
