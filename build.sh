#!/usr/bin/env bash
set -e

# Build WASM
echo "Building WASM..."
cargo build --release --target wasm32-unknown-unknown

# Prepare distribution folder
VERSION=$(grep '^version' typst.toml | cut -d'"' -f2)
DIST_DIR="dist/typst-mmdr-$VERSION"
mkdir -p "$DIST_DIR"

echo "Copying files to $DIST_DIR..."
cp typst.toml "$DIST_DIR/"
# Copy lib.typ and patch the plugin path
sed 's|target/wasm32-unknown-unknown/release/||g' lib.typ > "$DIST_DIR/lib.typ"

cp target/wasm32-unknown-unknown/release/typst_mmdr.wasm "$DIST_DIR/"
# Copy README/LICENSE if they exist
cp README.md "$DIST_DIR/" 2>/dev/null || true
cp LICENSE "$DIST_DIR/" 2>/dev/null || true

echo "Done! Package is ready in $DIST_DIR"
