#!/usr/bin/env bash
set -euo pipefail

app_path="${1:-}"
if [[ -z "$app_path" ]]; then
  app_path="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' -print -quit)"
fi
if [[ -z "$app_path" || ! -d "$app_path" ]]; then
  echo "macOS application bundle was not found"
  exit 1
fi

executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_path/Contents/Info.plist")"
required_binaries=(
  "$app_path/Contents/MacOS/$executable_name"
  "$app_path/Contents/MacOS/fastcatCore"
  "$app_path/Contents/Frameworks/FlutterMacOS.framework/Versions/A/FlutterMacOS"
)

for binary in "${required_binaries[@]}"; do
  if [[ ! -f "$binary" ]]; then
    echo "Missing required binary: $binary"
    exit 1
  fi
  architectures="$(lipo -archs "$binary")"
  echo "$binary: $architectures"
  [[ " $architectures " == *" arm64 "* ]] || { echo "Missing arm64 slice"; exit 1; }
  [[ " $architectures " == *" x86_64 "* ]] || { echo "Missing x86_64 slice"; exit 1; }
done

mach_o_count=0
while IFS= read -r -d '' binary; do
  if ! file -b "$binary" | grep -q 'Mach-O'; then
    continue
  fi
  mach_o_count=$((mach_o_count + 1))
  architectures="$(lipo -archs "$binary")"
  if [[ " $architectures " != *" arm64 "* || " $architectures " != *" x86_64 "* ]]; then
    echo "Non-universal Mach-O binary: $binary ($architectures)"
    exit 1
  fi
done < <(find "$app_path/Contents" -type f -print0)

if [[ "$mach_o_count" -eq 0 ]]; then
  echo "No Mach-O binaries found in application bundle"
  exit 1
fi
echo "Verified $mach_o_count universal Mach-O binaries"

codesign --verify --deep --strict --verbose=2 "$app_path"
echo "macOS bundle architecture and signature verification passed"
