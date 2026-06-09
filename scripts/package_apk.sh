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

# Flutter may place split APKs in either location
APK_DIR="build/app/outputs/flutter-apk"
if [ ! -d "$APK_DIR" ]; then
  APK_DIR="build/app/outputs/apk/mobile/release"
fi

mkdir -p dist

V8A_SRC="$APK_DIR/app-mobile-arm64-v8a-release.apk"
V7A_SRC="$APK_DIR/app-mobile-armeabi-v7a-release.apk"

copied=0
if [ -f "$V8A_SRC" ]; then
  cp "$V8A_SRC" "dist/fastcat-${VER}-arm64-v8a-release.apk"
  echo "✓ dist/fastcat-${VER}-arm64-v8a-release.apk"
  ((copied++))
fi
if [ -f "$V7A_SRC" ]; then
  cp "$V7A_SRC" "dist/fastcat-${VER}-armeabi-v7a-release.apk"
  echo "✓ dist/fastcat-${VER}-armeabi-v7a-release.apk"
  ((copied++))
fi

if [ "$copied" -gt 0 ]; then
  if [ "$BUILD_EXIT" -ne 0 ]; then
    echo "i Flutter reported a build error, but the APKs were produced."
  fi
else
  echo "→ Re-running Gradle with stacktrace for diagnostics..."
  (
    cd android
    ./gradlew assembleMobileRelease --stacktrace --no-daemon
  ) || true
  echo "✗ APKs not found after build"
  exit "$BUILD_EXIT"
fi
