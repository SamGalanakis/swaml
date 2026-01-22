#!/bin/bash
set -e

# Build BAML FFI as XCFramework for iOS/macOS
# This script compiles the BAML Rust runtime for Apple platforms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
BAML_REPO="https://github.com/BoundaryML/baml"
BAML_BRANCH="canary"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Cloning BAML repository..."
git clone --depth 1 --branch "$BAML_BRANCH" "$BAML_REPO" "$BUILD_DIR/baml-src"

cd "$BUILD_DIR/baml-src/engine/language_client_go"

echo "==> Checking Rust targets..."
# Add required targets if not present
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-darwin aarch64-apple-darwin 2>/dev/null || true

echo "==> Building for iOS Device (arm64)..."
cargo build --release --target aarch64-apple-ios

echo "==> Building for iOS Simulator (arm64)..."
cargo build --release --target aarch64-apple-ios-sim

echo "==> Building for macOS (arm64)..."
cargo build --release --target aarch64-apple-darwin

echo "==> Building for macOS (x86_64)..."
cargo build --release --target x86_64-apple-darwin

# Create universal macOS binary
echo "==> Creating universal macOS binary..."
mkdir -p "$BUILD_DIR/universal-macos/release"
lipo -create \
    "target/aarch64-apple-darwin/release/libbaml_ffi.a" \
    "target/x86_64-apple-darwin/release/libbaml_ffi.a" \
    -output "$BUILD_DIR/universal-macos/release/libbaml_ffi.a"

# Copy header files
echo "==> Preparing header files..."
HEADERS_DIR="$BUILD_DIR/headers"
mkdir -p "$HEADERS_DIR"

# Copy the generated FFI header
cp pkg/cffi/baml_cffi_generated.h "$HEADERS_DIR/"

# Create module map for Swift
cat > "$HEADERS_DIR/module.modulemap" << 'EOF'
module BamlFFI {
    header "baml_cffi_generated.h"
    export *
}
EOF

# Create XCFramework
echo "==> Creating XCFramework..."
XCFRAMEWORK_PATH="$PROJECT_ROOT/BamlFFI.xcframework"
rm -rf "$XCFRAMEWORK_PATH"

xcodebuild -create-xcframework \
    -library "target/aarch64-apple-ios/release/libbaml_ffi.a" \
    -headers "$HEADERS_DIR" \
    -library "target/aarch64-apple-ios-sim/release/libbaml_ffi.a" \
    -headers "$HEADERS_DIR" \
    -library "$BUILD_DIR/universal-macos/release/libbaml_ffi.a" \
    -headers "$HEADERS_DIR" \
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
