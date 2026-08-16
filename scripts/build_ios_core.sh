#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$(uname -s)" != "Darwin" ]; then
  echo "iOS core can only be built on macOS" >&2
  exit 1
fi

SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG_PATH="$(xcrun --sdk iphoneos -f clang)"
OUTPUT_DIR="ios/Frameworks/libclash.xcframework/ios-arm64"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "→ Building current iOS mihomo core..."
(
  cd core
  env \
    CGO_ENABLED=1 \
    GOOS=ios \
    GOARCH=arm64 \
    CC="$CLANG_PATH" \
    CGO_CFLAGS="-isysroot $SDK_PATH -miphoneos-version-min=13.0" \
    CGO_LDFLAGS="-isysroot $SDK_PATH -miphoneos-version-min=13.0" \
    go build \
      -trimpath \
      -buildmode=c-archive \
      -o "$BUILD_DIR/libclash.a" \
      .
)

mkdir -p "$OUTPUT_DIR"
cp "$BUILD_DIR/libclash.a" "$OUTPUT_DIR/libclash.a"
cp "$BUILD_DIR/libclash.h" "$OUTPUT_DIR/libclash.h"

echo "✓ Built $OUTPUT_DIR/libclash.a"
