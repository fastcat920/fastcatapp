#!/bin/bash
set -euo pipefail

# Build the static mihomo bridge used by the tvOS Packet Tunnel extension.
# tvOS has no Go GOOS value; build for Darwin and explicitly select the
# shared Apple proxy-mode bridge with the `ios` build tag.
cd "$(dirname "$0")/.."

if [ "$(uname -s)" != "Darwin" ]; then
  echo "tvOS core can only be built on macOS" >&2
  exit 1
fi

SDK_PATH="$(xcrun --sdk appletvos --show-sdk-path)"
CLANG_PATH="$(xcrun --sdk appletvos -f clang)"
OUTPUT_DIR="tvos/Frameworks/libclash.xcframework/tvos-arm64"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "→ Building tvOS mihomo core..."
(
  cd core
  env \
    CGO_ENABLED=1 \
    GOOS=darwin \
    GOARCH=arm64 \
    CC="$CLANG_PATH" \
    CGO_CFLAGS="-isysroot $SDK_PATH -target arm64-apple-tvos17.0" \
    CGO_LDFLAGS="-isysroot $SDK_PATH -target arm64-apple-tvos17.0" \
    go build -tags ios -trimpath -buildmode=c-archive -o "$BUILD_DIR/libclash.a" .
)

mkdir -p "$OUTPUT_DIR/Headers"
cp "$BUILD_DIR/libclash.a" "$OUTPUT_DIR/libclash.a"
cp "$BUILD_DIR/libclash.h" "$OUTPUT_DIR/libclash.h"
cp tvos/PacketTunnel/PacketTunnel-Bridging-Header.h "$OUTPUT_DIR/Headers/PacketTunnel-Bridging-Header.h"
cat > tvos/Frameworks/libclash.xcframework/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>AvailableLibraries</key><array><dict>
<key>LibraryIdentifier</key><string>tvos-arm64</string>
<key>LibraryPath</key><string>libclash.a</string>
<key>SupportedArchitectures</key><array><string>arm64</string></array>
<key>SupportedPlatform</key><string>tvos</string>
</dict></array><key>CFBundlePackageType</key><string>XFWK</string><key>XCFrameworkFormatVersion</key><string>1.0</string></dict></plist>
PLIST

echo "✓ Built $OUTPUT_DIR/libclash.a"
