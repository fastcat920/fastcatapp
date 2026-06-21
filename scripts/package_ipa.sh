#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${XOR_KEY:-}" ]; then
  echo "Usage: XOR_KEY=<your_key> ./scripts/package_ipa.sh"
  exit 1
fi

VER=$(grep '^version:' pubspec.yaml | awk '{print $2}')
VERSION="${VER%+*}"
echo "→ Building IPA for fastcat ${VERSION}..."
mkdir -p dist

flutter build ipa --release --no-codesign --dart-define=XOR_KEY="${XOR_KEY}"

echo "→ Packaging IPA from xcarchive..."
cd build/ios
rm -rf Payload
mkdir -p Payload
cp -a archive/Runner.xcarchive/Products/Applications/Runner.app Payload/
zip -r -q "fastcat-iOS-${VERSION}.ipa" Payload
rm -rf Payload

cp "fastcat-iOS-${VERSION}.ipa" ../../dist/
echo "✓ dist/fastcat-iOS-${VERSION}.ipa"
