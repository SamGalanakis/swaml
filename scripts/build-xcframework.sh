#!/bin/bash
set -e

# Build BAML FFI as XCFramework for iOS/macOS
# This script compiles the vendored BAML Rust runtime for Apple platforms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
BAML_ENGINE_DIR="$PROJECT_ROOT/vendor/baml/engine"
HEADERS_DIR="$PROJECT_ROOT/vendor/baml/include"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$BAML_ENGINE_DIR"

echo "==> Checking Rust targets..."
# Add required targets if not present
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-darwin aarch64-apple-darwin 2>/dev/null || true

echo "==> Building for iOS Device (arm64)..."
cargo build --release --target aarch64-apple-ios -p baml_cffi

echo "==> Building for iOS Simulator (arm64)..."
cargo build --release --target aarch64-apple-ios-sim -p baml_cffi

echo "==> Building for macOS (arm64)..."
cargo build --release --target aarch64-apple-darwin -p baml_cffi

echo "==> Building for macOS (x86_64)..."
cargo build --release --target x86_64-apple-darwin -p baml_cffi

# Create universal macOS binary
echo "==> Creating universal macOS binary..."
mkdir -p "$BUILD_DIR/universal-macos/release"
lipo -create \
    "target/aarch64-apple-darwin/release/libbaml_cffi.a" \
    "target/x86_64-apple-darwin/release/libbaml_cffi.a" \
    -output "$BUILD_DIR/universal-macos/release/libbaml_cffi.a"

# Copy header files
echo "==> Preparing header files..."
XCFRAMEWORK_HEADERS_DIR="$BUILD_DIR/headers"
mkdir -p "$XCFRAMEWORK_HEADERS_DIR"

# Copy the generated FFI header
cp "$HEADERS_DIR/baml_ffi.h" "$XCFRAMEWORK_HEADERS_DIR/"

# Create module map for Swift
cat > "$XCFRAMEWORK_HEADERS_DIR/module.modulemap" << 'EOF'
module BamlFFI {
    header "baml_ffi.h"
    export *
}
EOF

# Create XCFramework
echo "==> Creating XCFramework..."
XCFRAMEWORK_PATH="$PROJECT_ROOT/BamlFFI.xcframework"
rm -rf "$XCFRAMEWORK_PATH"

xcodebuild -create-xcframework \
    -library "target/aarch64-apple-ios/release/libbaml_cffi.a" \
    -headers "$XCFRAMEWORK_HEADERS_DIR" \
    -library "target/aarch64-apple-ios-sim/release/libbaml_cffi.a" \
    -headers "$XCFRAMEWORK_HEADERS_DIR" \
    -library "$BUILD_DIR/universal-macos/release/libbaml_cffi.a" \
    -headers "$XCFRAMEWORK_HEADERS_DIR" \
    -output "$XCFRAMEWORK_PATH"

echo "==> XCFramework created at: $XCFRAMEWORK_PATH"

# Cleanup
echo "==> Cleaning up build directory..."
rm -rf "$BUILD_DIR"

echo "==> Done!"
echo ""
echo "Next steps:"
echo "1. Add BamlFFI.xcframework to your Xcode project"
echo "2. In Package.swift, the SWAML target should link against the xcframework"
echo "3. Import BamlFFI in your Swift code to use the FFI functions"
