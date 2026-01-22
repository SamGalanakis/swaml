// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Check if BamlFFI.xcframework exists for FFI support
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
let bamlFFIAvailable = FileManager.default.fileExists(atPath: "BamlFFI.xcframework")
#else
let bamlFFIAvailable = false
#endif

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
    ],
    targets: [
        // Main SWAML target - pure Swift runtime
        .target(
            name: "SWAML",
            dependencies: [],
            path: "Sources/SWAML",
            exclude: [],
            swiftSettings: [
                // Enable FFI support when building with xcframework
                // Users can define BAML_FFI_ENABLED to enable FFI code paths
            ]
        ),
        .testTarget(
            name: "SWAMLTests",
            dependencies: ["SWAML"],
            path: "Tests/SWAMLTests"
        ),
    ]
)

// Note: To use the FFI runtime with the BAML Rust backend:
// 1. Run: ./scripts/build-xcframework.sh
// 2. Add BamlFFI.xcframework to your Xcode project
// 3. Link against BamlFFI in your target's build settings
// 4. Import both SWAML and BamlFFI in your Swift code
//
// The FFI runtime (BamlRuntimeFFI) provides full BAML functionality including:
// - TypeBuilder for dynamic types
// - ctx.output_format support
// - Streaming responses
// - All BAML Rust runtime features
