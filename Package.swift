// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SWAML",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "SWAML",
            targets: ["SWAML"]
        ),
        .library(
            name: "SwamlMacros",
            targets: ["SwamlMacros"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // Main SWAML target - pure Swift LLM client
        .target(
            name: "SWAML",
            dependencies: [],
            path: "Sources/SWAML"
        ),
        // Macro declarations (public interface)
        .target(
            name: "SwamlMacros",
            dependencies: ["SwamlMacrosPlugin", "SWAML"],
            path: "Sources/SwamlMacros"
        ),
        // Macro implementations (compiler plugin)
        .macro(
            name: "SwamlMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/SwamlMacrosPlugin"
        ),
        .testTarget(
            name: "SWAMLTests",
            dependencies: ["SWAML"],
            path: "Tests/SWAMLTests"
        ),
        .testTarget(
            name: "SwamlMacrosTests",
            dependencies: [
                "SwamlMacros",
                "SWAML",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            path: "Tests/SwamlMacrosTests"
        ),
    ]
)

// Swift-Native LLM Client (Pure Swift - No FFI Required)
//
// SWAML provides structured LLM calls with robust JSON parsing:
// - SwamlClient: High-level API for typed LLM calls
// - PromptBuilder: Swift DSL for building prompts
// - TypeBuilder: Runtime type extension for dynamic schemas
// - @BamlType/@BamlDynamic macros: Type-safe schema generation
// - JsonishParser: Pure Swift parser for LLM output (handles trailing commas, comments, etc.)
//
// Output format matches BAML exactly:
// - Classes: "Answer in JSON using this schema:\n{ field: type, }"
// - Enums: "Answer with any of the categories:\nName\n----\n- Value1"
// - Arrays: "string[]" syntax
// - Descriptions as comments above fields
