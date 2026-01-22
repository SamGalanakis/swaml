// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
        // Main SWAML target - pure Swift runtime with optional FFI support
        .target(
            name: "SWAML",
            dependencies: [],
            path: "Sources/SWAML"
        ),
        .testTarget(
            name: "SWAMLTests",
            dependencies: ["SWAML"],
            path: "Tests/SWAMLTests"
        ),
    ]
)

// FFI Runtime Support:
// The FFI code uses dlopen/dlsym to dynamically load the BAML library at runtime.
// This means the package compiles without the library, but BamlRuntimeFFI will
// throw BamlFFIError.libraryNotLoaded if you try to use it without the library.
//
// To use the FFI runtime:
// 1. Build the library: ./scripts/build-xcframework.sh (Apple) or build libbaml_ffi.so (Linux)
// 2. For Apple: Add BamlFFI.xcframework to your Xcode project
// 3. For Linux: Ensure libbaml_ffi.so is in LD_LIBRARY_PATH
// 4. Check BamlFFI.isAvailable before using BamlRuntimeFFI
