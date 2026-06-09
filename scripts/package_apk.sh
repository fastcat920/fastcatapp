#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${XOR_KEY:-}" ]; then
  echo "Usage: XOR_KEY=<your_key> ./scripts/package_apk.sh"
  exit 1
fi

VER=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo "→ Building split APKs for fastcat ${VER}..."

flutter clean
set +e
flutter build apk --release \
  --split-per-abi \
  --target-platform android-arm64,android-arm \
  --dart-define=XOR_KEY="${XOR_KEY}"
BUILD_EXIT=$?
set -e

# List all APK files in the build tree for diagnostics
echo "→ APK files produced:"
find build -name "*.apk" -type f 2>/dev/null || true

mkdir -p dist

# Find arm64-v8a APK
V8A_SRC=$(find build -name "*arm64*v8a*.apk" -o -name "*arm64-v8a*.apk" 2>/dev/null | head -1 || true)
V7A_SRC=$(find build -name "*armeabi*v7a*.apk" -o -name "*armeabi-v7a*.apk" 2>/dev/null | head -1 || true)

copied=0
if [ -n "${V8A_SRC:-}" ] && [ -f "$V8A_SRC" ]; then
  cp "$V8A_SRC" "dist/fastcat-${VER}-arm64-v8a-release.apk"
  echo "✓ dist/fastcat-${VER}-arm64-v8a-release.apk (from $V8A_SRC)"
  copied=$((copied + 1))
fi
if [ -n "${V7A_SRC:-}" ] && [ -f "$V7A_SRC" ]; then
  cp "$V7A_SRC" "dist/fastcat-${VER}-armeabi-v7a-release.apk"
  echo "✓ dist/fastcat-${VER}-armeabi-v7a-release.apk (from $V7A_SRC)"
  copied=$((copied + 1))
fi

if [ "$copied" -gt 0 ]; then
  if [ "$BUILD_EXIT" -ne 0 ]; then
    echo "i Flutter CLI reported an error, but APKs were produced successfully."
  fi
else
  echo "→ Re-running Gradle with stacktrace for diagnostics..."
  (
    cd android
    ./gradlew assembleMobileRelease --stacktrace --no-daemon
  ) || true
  echo "✗ APKs not found after build"
  exit "${BUILD_EXIT:-1}"
fi
