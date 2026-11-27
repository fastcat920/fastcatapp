#!/usr/bin/env bash
set -euo pipefail

mode="${1:?Expected prepare-app or notarize-dmg}"
artifact="${2:?Expected an application or disk image path}"
identity="${MACOS_SIGN_IDENTITY:?Set MACOS_SIGN_IDENTITY to a Developer ID Application identity}"
profile="${MACOS_NOTARY_PROFILE:?Set MACOS_NOTARY_PROFILE to your notarytool keychain profile}"
work_dir="$(mktemp -d)"
mount_point=

cleanup() {
  if [[ -n "$mount_point" ]]; then
    hdiutil detach "$mount_point" >/dev/null || return
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT

notarize() {
  local upload="$1"
  local result="$work_dir/notary-result.json"
  local submission
  if ! xcrun notarytool submit "$upload" --keychain-profile "$profile" \
      --wait --output-format json > "$result"; then
    cat "$result" >&2
    return 1
  fi
  cat "$result"
  if [[ "$(plutil -extract status raw -o - "$result")" != Accepted ]]; then
    submission="$(plutil -extract id raw -o - "$result")"
    xcrun notarytool log "$submission" --keychain-profile "$profile" >&2
    return 1
  fi
}

case "$mode" in
  prepare-app)
    entitlements="${3:?Expected the Release entitlements path}"
    test -f "$artifact/Contents/MacOS/fastcatCore"
    test -f "$entitlements"

    # Sign Mach-O leaves and seal nested bundles as the traversal unwinds.
    while IFS= read -r -d '' item; do
      if [[ -d "$item" ]]; then
        case "$item" in
          *.app|*.appex|*.framework|*.xpc) ;;
          *) continue ;;
        esac
      elif [[ "$(file -b "$item")" != *Mach-O* ]]; then
        continue
      fi
      codesign --force --sign "$identity" --timestamp --options runtime \
        --preserve-metadata=entitlements "$item"
    done < <(find "$artifact/Contents" -depth \( -type f -o -type d \) -print0)

    codesign --force --sign "$identity" --timestamp --options runtime \
      --entitlements "$entitlements" "$artifact"
    codesign --verify --deep --strict --verbose=2 "$artifact"
    # Apple accepts the ZIP for submission. Staple to the app before making the DMG.
    archive="$work_dir/$(basename "${artifact%.app}").zip"
    ditto -c -k --sequesterRsrc --keepParent "$artifact" "$archive"
    notarize "$archive"
    xcrun stapler staple "$artifact"
    xcrun stapler validate "$artifact"
    codesign --verify --deep --strict --verbose=2 "$artifact"
    ;;
  notarize-dmg)
    app_name="${3:?Expected the application name inside the disk image}"
    # Verify that packaging preserved the app ticket before sending the DMG to Apple.
    mkdir "$work_dir/mount"
    hdiutil attach "$artifact" -readonly -nobrowse -mountpoint "$work_dir/mount" >/dev/null
    mount_point="$work_dir/mount"
    xcrun stapler validate "$mount_point/$app_name"
    codesign --verify --deep --strict --verbose=2 "$mount_point/$app_name"
    hdiutil detach "$mount_point" >/dev/null
    mount_point=

    codesign --force --sign "$identity" --timestamp "$artifact"
    notarize "$artifact"
    xcrun stapler staple "$artifact"
    xcrun stapler validate "$artifact"
    codesign --verify --verbose=2 "$artifact"
    ;;
  *)
    echo "Unknown macOS release operation: $mode" >&2
    exit 2
    ;;
esac
