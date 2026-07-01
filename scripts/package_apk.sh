#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${XOR_KEY:-}" ]; then
  echo "Usage: XOR_KEY=<your_key> ./scripts/package_apk.sh"
  exit 1
fi

VER=$(grep '^version:' pubspec.yaml | awk '{print $2}')
VERSION="${VER%+*}"

APP_NAME="快猫"
APP_NAME_EN="FastCat"
CONFIG_YAML="assets/config/config.yaml"
if [ -f "$CONFIG_YAML" ]; then
  YAML_APP_NAME=$(grep -E '^app_name:' "$CONFIG_YAML" | sed 's/^app_name:[[:space:]]*//' | tr -d '\r' | xargs)
  [ -n "$YAML_APP_NAME" ] && APP_NAME="$YAML_APP_NAME"
  YAML_APP_NAME_EN=$(grep -E '^app_name_en:' "$CONFIG_YAML" | sed 's/^app_name_en:[[:space:]]*//' | tr -d '\r' | xargs)
  [ -n "$YAML_APP_NAME_EN" ] && APP_NAME_EN="$YAML_APP_NAME_EN"
fi

echo "→ Building split APKs for ${APP_NAME_EN} ${VERSION}..."

STRINGS_XML="android/app/src/main/res/values/strings.xml"
if [ -f "$STRINGS_XML" ]; then
  APP_NAME_FOR_PERL="$APP_NAME" perl -0pi -e '
    s#<string name="app_name">[^<]*</string>#<string name="app_name">$ENV{APP_NAME_FOR_PERL}</string>#g;
    s#<string name="fl_clash">[^<]*</string>#<string name="fl_clash">$ENV{APP_NAME_FOR_PERL}</string>#g;
  ' "$STRINGS_XML"
fi

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
  V8A_OUT="dist/${APP_NAME_EN}-Android-${VERSION}-arm64-v8a.apk"
  cp "$V8A_SRC" "$V8A_OUT"
  echo "✓ $V8A_OUT (from $V8A_SRC)"
  copied=$((copied + 1))
fi
if [ -n "${V7A_SRC:-}" ] && [ -f "$V7A_SRC" ]; then
  V7A_OUT="dist/${APP_NAME_EN}-Android-${VERSION}-armeabi-v7a.apk"
  cp "$V7A_SRC" "$V7A_OUT"
  echo "✓ $V7A_OUT (from $V7A_SRC)"
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
