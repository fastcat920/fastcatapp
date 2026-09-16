#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

for command in codesign plutil unzip zip; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command"
    exit 1
  }
done

# Build the ordinary unsigned archive first. This also validates localized
# bundle names and embeds PacketTunnel.appex in the main application.
bash scripts/package_ipa.sh

version="$(awk '/^version:/ { print $2; exit }' pubspec.yaml)"
version="${version%+*}"
source_ipa="dist/FastCat-iOS-${version}.ipa"
output_ipa="dist/FastCat-iOS-${version}-TrollStore.ipa"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/fastcat-trollstore.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

unzip -q "$source_ipa" -d "$work_dir"
app_path="$(find "$work_dir/Payload" -maxdepth 1 -name '*.app' -print -quit)"
extension_path="$(find "$app_path/PlugIns" -maxdepth 1 -name 'PacketTunnel.appex' -print -quit)"

[[ -n "$app_path" && -d "$app_path" ]] || {
  echo "Main iOS application was not found"
  exit 1
}
[[ -n "$extension_path" && -d "$extension_path" ]] || {
  echo "PacketTunnel.appex was not embedded"
  exit 1
}

app_bundle_id="$(plutil -extract CFBundleIdentifier raw "$app_path/Info.plist")"
extension_bundle_id="$(plutil -extract CFBundleIdentifier raw "$extension_path/Info.plist")"
expected_extension_id="${app_bundle_id}.PacketTunnel"
[[ "$extension_bundle_id" == "$expected_extension_id" ]] || {
  echo "PacketTunnel bundle ID mismatch: $extension_bundle_id (expected $expected_extension_id)"
  exit 1
}

app_group="group.${app_bundle_id}"
main_entitlements="$work_dir/main.entitlements"
extension_entitlements="$work_dir/extension.entitlements"

cat >"$main_entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>application-identifier</key>
  <string>TROLLTROLL.${app_bundle_id}</string>
  <key>com.apple.developer.team-identifier</key>
  <string>TROLLTROLL</string>
  <key>keychain-access-groups</key>
  <array><string>TROLLTROLL.*</string></array>
  <key>com.apple.developer.networking.networkextension</key>
  <array><string>packet-tunnel-provider</string></array>
  <key>com.apple.security.application-groups</key>
  <array><string>${app_group}</string></array>
</dict>
</plist>
PLIST

cat >"$extension_entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>application-identifier</key>
  <string>TROLLTROLL.${extension_bundle_id}</string>
  <key>com.apple.developer.team-identifier</key>
  <string>TROLLTROLL</string>
  <key>keychain-access-groups</key>
  <array><string>TROLLTROLL.*</string></array>
  <key>com.apple.developer.networking.networkextension</key>
  <array><string>packet-tunnel-provider</string></array>
  <key>com.apple.security.application-groups</key>
  <array><string>${app_group}</string></array>
</dict>
</plist>
PLIST

plutil -lint "$main_entitlements" "$extension_entitlements"

# Sign nested code before its containing bundle. TrollStore reads the embedded
# entitlements from every Mach-O and preserves them while applying CoreTrust.
while IFS= read -r -d '' framework; do
  codesign --force --sign - --timestamp=none "$framework"
done < <(find "$app_path/Frameworks" -type d -name '*.framework' -print0)

while IFS= read -r -d '' dylib; do
  codesign --force --sign - --timestamp=none "$dylib"
done < <(find "$app_path" -type f -name '*.dylib' -print0)

codesign --force --sign - --timestamp=none \
  --entitlements "$extension_entitlements" "$extension_path"
codesign --force --sign - --timestamp=none \
  --entitlements "$main_entitlements" "$app_path"

codesign --verify --deep --strict --verbose=2 "$app_path"

verify_entitlement() {
  local bundle="$1"
  local key="$2"
  local entitlements
  entitlements="$(codesign -d --entitlements :- "$bundle" 2>/dev/null)"
  grep -q "<key>${key}</key>" <<<"$entitlements" || {
    echo "Missing entitlement ${key} in ${bundle}"
    exit 1
  }
}

for bundle in "$app_path" "$extension_path"; do
  verify_entitlement "$bundle" application-identifier
  verify_entitlement "$bundle" com.apple.developer.networking.networkextension
  verify_entitlement "$bundle" com.apple.security.application-groups
done

(cd "$work_dir" && zip -qry "$OLDPWD/$output_ipa" Payload)
echo "TrollStore IPA: $output_ipa"
