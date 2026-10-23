#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${XOR_KEY:-}" ]; then
  echo "Usage: XOR_KEY=<your_key> ./scripts/package_apk.sh"
  exit 1
fi

: "${FASTCAT_KEY_CURRENT_ID:?FASTCAT_KEY_CURRENT_ID is required}"
: "${REMOTE_CONFIG_PUBLIC_KEY:?REMOTE_CONFIG_PUBLIC_KEY is required for fastcat-config-v2}"
: "${FASTCAT_KEY_CURRENT:?FASTCAT_KEY_CURRENT is required}"
: "${FASTCAT_KEY_NEXT_ID:?FASTCAT_KEY_NEXT_ID is required}"
: "${FASTCAT_KEY_NEXT:?FASTCAT_KEY_NEXT is required}"
: "${FASTCAT_SUBSCRIPTION_FLAG:=fastcat-v1}"
: "${FASTCAT_REQUIRE_ENCRYPTION:=true}"

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

FCM_DEFINES=()
if [ -n "${FASTCAT_FIREBASE_API_KEY:-}" ] && [ -n "${FASTCAT_FIREBASE_APP_ID:-}" ] && \
   [ -n "${FASTCAT_FIREBASE_PROJECT_ID:-}" ] && [ -n "${FASTCAT_FIREBASE_MESSAGING_SENDER_ID:-}" ]; then
  FCM_DEFINES+=(
    --dart-define=FASTCAT_FIREBASE_API_KEY="${FASTCAT_FIREBASE_API_KEY}"
    --dart-define=FASTCAT_FIREBASE_APP_ID="${FASTCAT_FIREBASE_APP_ID}"
    --dart-define=FASTCAT_FIREBASE_PROJECT_ID="${FASTCAT_FIREBASE_PROJECT_ID}"
    --dart-define=FASTCAT_FIREBASE_MESSAGING_SENDER_ID="${FASTCAT_FIREBASE_MESSAGING_SENDER_ID}"
  )
else
  echo "i Firebase client options are incomplete; APK will be built without push registration."
fi

flutter clean
BUILD_EXIT=1
for attempt in 1 2 3; do
  set +e
  flutter build apk --release \
    --flavor mobile \
    --split-per-abi \
    --target-platform android-arm64,android-arm \
    --dart-define=FASTCAT_BUILD_COMMIT="${FASTCAT_BUILD_COMMIT:-}" \
    --dart-define=FASTCAT_BUILD_CHANNEL="${FASTCAT_BUILD_CHANNEL:-local}" \
    --dart-define=XOR_KEY="${XOR_KEY}" \
    --dart-define=REMOTE_CONFIG_PUBLIC_KEY="${REMOTE_CONFIG_PUBLIC_KEY:-}" \
    --dart-define=FASTCAT_KEY_CURRENT_ID="${FASTCAT_KEY_CURRENT_ID}" \
    --dart-define=FASTCAT_KEY_CURRENT="${FASTCAT_KEY_CURRENT}" \
    --dart-define=FASTCAT_KEY_NEXT_ID="${FASTCAT_KEY_NEXT_ID}" \
    --dart-define=FASTCAT_KEY_NEXT="${FASTCAT_KEY_NEXT}" \
    --dart-define=FASTCAT_SUBSCRIPTION_FLAG="${FASTCAT_SUBSCRIPTION_FLAG}" \
    --dart-define=FASTCAT_REQUIRE_ENCRYPTION="${FASTCAT_REQUIRE_ENCRYPTION}" \
    ${FCM_DEFINES[@]+"${FCM_DEFINES[@]}"}
  BUILD_EXIT=$?
  set -e

  if [ "$BUILD_EXIT" -eq 0 ]; then
    break
  fi
  if [ "$attempt" -lt 3 ]; then
    wait_seconds=$((attempt * 30))
    echo "i APK build attempt $attempt failed; retrying in ${wait_seconds}s..."
    sleep "$wait_seconds"
  fi
done

if [ "$BUILD_EXIT" -ne 0 ]; then
  echo "APK build failed; refusing to publish partial output from a failed attempt."
  exit "$BUILD_EXIT"
fi

# List all APK files in the build tree for diagnostics
echo "→ APK files produced:"
find build -name "*.apk" -type f 2>/dev/null || true

# Match Flutter's mobile flavor output exactly; never select stale/debug APKs.
APK_DIR="build/app/outputs/flutter-apk"
V8A_SRC="$APK_DIR/app-arm64-v8a-mobile-release.apk"
V7A_SRC="$APK_DIR/app-armeabi-v7a-mobile-release.apk"

# Validate both architectures before copying either one to the upload directory.
for apk in "$V8A_SRC" "$V7A_SRC"; do
  if [ ! -s "$apk" ]; then
    echo "✗ Missing or empty required APK: $apk"
    exit 1
  fi
done

mkdir -p dist
V8A_OUT="dist/${APP_NAME_EN}-Android-${VERSION}-arm64-v8a.apk"
V7A_OUT="dist/${APP_NAME_EN}-Android-${VERSION}-armeabi-v7a.apk"
cp "$V8A_SRC" "$V8A_OUT"
cp "$V7A_SRC" "$V7A_OUT"
echo "✓ $V8A_OUT"
echo "✓ $V7A_OUT"
