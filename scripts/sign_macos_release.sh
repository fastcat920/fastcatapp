#!/usr/bin/env bash
set -euo pipefail

mode="${1:?Expected sign-app or notarize-dmg}"
artifact="${2:?Expected an application or disk image path}"
identity="${MACOS_SIGN_IDENTITY:?Set MACOS_SIGN_IDENTITY to a Developer ID Application identity}"

case "$mode" in
  sign-app)
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
    ;;
  notarize-dmg)
    profile="${MACOS_NOTARY_PROFILE:?Set MACOS_NOTARY_PROFILE to your notarytool keychain profile}"
    codesign --force --sign "$identity" --timestamp "$artifact"
    result="$(mktemp)"
    trap 'rm -f "$result"' EXIT
    if ! xcrun notarytool submit "$artifact" --keychain-profile "$profile" \
        --wait --output-format json > "$result"; then
      cat "$result" >&2
      exit 1
    fi
    if [[ "$(plutil -extract status raw -o - "$result")" != Accepted ]]; then
      cat "$result" >&2
      submission="$(plutil -extract id raw -o - "$result")"
      xcrun notarytool log "$submission" --keychain-profile "$profile" >&2
      exit 1
    fi
    xcrun stapler staple "$artifact"
    xcrun stapler validate "$artifact"
    codesign --verify --verbose=2 "$artifact"
    ;;
  *)
    echo "Unknown macOS release operation: $mode" >&2
    exit 2
    ;;
esac
