#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${XOR_KEY:-}" ]; then
  echo "Usage: XOR_KEY=<your_key> ./scripts/package_ipa.sh"
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

echo "→ Building IPA for ${APP_NAME_EN} ${VERSION}..."
mkdir -p dist

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME_EN}" ios/Runner/Info.plist

flutter build ipa --release --no-codesign --dart-define=XOR_KEY="${XOR_KEY}"

echo "→ Packaging IPA from xcarchive..."
cd build/ios
rm -rf Payload
mkdir -p Payload
cp -a archive/Runner.xcarchive/Products/Applications/Runner.app Payload/
IPA_NAME="${APP_NAME_EN}-iOS-${VERSION}.ipa"
zip -r -q "$IPA_NAME" Payload
rm -rf Payload

cp "$IPA_NAME" ../../dist/
echo "✓ dist/$IPA_NAME"
