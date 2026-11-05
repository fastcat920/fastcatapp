#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$(uname -s)" != "Darwin" ]; then
  echo "iOS core can only be built on macOS" >&2
  exit 1
fi

SDK_NAME=iphoneos
APPLE_TARGET=arm64-apple-ios15.0
LIBRARY_ID=ios-arm64
if [ "${APPLE_SIMULATOR:-0}" = 1 ]; then
  SDK_NAME=iphonesimulator
  APPLE_TARGET=arm64-apple-ios15.0-simulator
  LIBRARY_ID=ios-arm64-simulator
fi
SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"
CLANG_PATH="$(xcrun --sdk "$SDK_NAME" -f clang)"
OUTPUT_DIR="ios/Frameworks/libclash.xcframework/$LIBRARY_ID"
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
    CGO_CFLAGS="-isysroot $SDK_PATH -target $APPLE_TARGET" \
    CGO_LDFLAGS="-isysroot $SDK_PATH -target $APPLE_TARGET" \
    go build \
      -tags with_gvisor \
      -trimpath \
      -buildmode=c-archive \
      -o "$BUILD_DIR/libclash.a" \
      .
)

mkdir -p "$OUTPUT_DIR"
cp "$BUILD_DIR/libclash.a" "$OUTPUT_DIR/libclash.a"
cp "$BUILD_DIR/libclash.h" "$OUTPUT_DIR/libclash.h"
mkdir -p "$OUTPUT_DIR/Headers"
cp ios/PacketTunnel/PacketTunnel-Bridging-Header.h "$OUTPUT_DIR/Headers/PacketTunnel-Bridging-Header.h"

echo "✓ Built $OUTPUT_DIR/libclash.a"
