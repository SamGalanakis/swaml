#!/bin/bash
set -e

# Build BAML FFI for Linux
# This script compiles the vendored BAML Rust runtime for Linux

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BAML_ENGINE_DIR="$PROJECT_ROOT/vendor/baml/engine"
LIB_DIR="$PROJECT_ROOT/lib"
HEADERS_DIR="$PROJECT_ROOT/vendor/baml/include"

# Create lib directory
mkdir -p "$LIB_DIR"

cd "$BAML_ENGINE_DIR"

echo "==> Building BAML FFI for Linux (x86_64)..."
cargo build --release -p baml_cffi

echo "==> Copying library..."
cp "target/release/libbaml_cffi.so" "$LIB_DIR/"

# Also copy static library if needed
if [ -f "target/release/libbaml_cffi.a" ]; then
    cp "target/release/libbaml_cffi.a" "$LIB_DIR/"
fi

echo "==> Build complete!"
echo ""
echo "Library: $LIB_DIR/libbaml_cffi.so"
echo "Header:  $HEADERS_DIR/baml_ffi.h"
echo ""

# Show library size
ls -lh "$LIB_DIR/libbaml_cffi.so"
