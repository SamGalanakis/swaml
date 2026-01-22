#!/bin/bash
set -e

# Build BAML FFI shared library for Linux
# This script compiles the BAML Rust runtime for Linux

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

echo "==> Building for Linux..."
cargo build --release

# Create output directory
mkdir -p "$PROJECT_ROOT/lib"

# Copy shared library
echo "==> Copying shared library..."
if [ -f "target/release/libbaml_cffi.so" ]; then
    cp target/release/libbaml_cffi.so "$PROJECT_ROOT/lib/libbaml_ffi.so"
elif [ -f "target/release/libbaml_ffi.so" ]; then
    cp target/release/libbaml_ffi.so "$PROJECT_ROOT/lib/libbaml_ffi.so"
else
    echo "Error: Could not find shared library"
    exit 1
fi

# Copy header file
echo "==> Copying header file..."
cp pkg/cffi/baml_cffi_generated.h "$PROJECT_ROOT/lib/"

# Copy proto files for reference
echo "==> Copying proto files..."
mkdir -p "$PROJECT_ROOT/lib/proto"
cp -r types/baml "$PROJECT_ROOT/lib/proto/"

echo "==> Cleaning up build directory..."
rm -rf "$BUILD_DIR"

echo "==> Done!"
echo ""
echo "Output files:"
echo "  - $PROJECT_ROOT/lib/libbaml_ffi.so"
echo "  - $PROJECT_ROOT/lib/baml_cffi_generated.h"
echo "  - $PROJECT_ROOT/lib/proto/ (protobuf definitions)"
echo ""
echo "Usage:"
echo "  1. Add to Package.swift:"
echo "     linkerSettings: ["
echo "         .linkedLibrary(\"baml_ffi\", .when(platforms: [.linux])),"
echo "         .unsafeFlags([\"-Llib\"], .when(platforms: [.linux]))"
echo "     ]"
echo ""
echo "  2. Run with library path:"
echo "     LD_LIBRARY_PATH=./lib:\$LD_LIBRARY_PATH swift run YourApp"
