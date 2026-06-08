#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${XOR_KEY:-}" ]; then
  echo "Usage: XOR_KEY=<your_key> ./scripts/package_apk.sh"
  exit 1
fi

VER=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo "→ Building APK for fastcat ${VER}..."

flutter clean
set +e
flutter build apk --release \
  --target-platform android-arm64,android-arm \
  --dart-define=XOR_KEY="${XOR_KEY}"
BUILD_EXIT=$?
set -e

APK_SRC="build/app/outputs/flutter-apk/app-mobile-release.apk"
if [ ! -f "$APK_SRC" ]; then
  APK_SRC="build/app/outputs/apk/mobile/release/app-mobile-release.apk"
fi
APK_DST="dist/fastcat-${VER}-mobile-release.apk"

if [ -f "$APK_SRC" ]; then
  mkdir -p dist
  cp "$APK_SRC" "$APK_DST"
  if [ "$BUILD_EXIT" -ne 0 ]; then
    echo "i Flutter reported an APK lookup error, but the APK was produced."
  fi
  echo "✓ $APK_DST"
else
  echo "→ Re-running Gradle with stacktrace for diagnostics..."
  (
    cd android
    ./gradlew assembleMobileRelease --stacktrace --no-daemon
  ) || true
  echo "✗ APK not found after build"
  exit "$BUILD_EXIT"
fi
