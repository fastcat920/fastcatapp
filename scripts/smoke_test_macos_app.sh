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
executable="$app_path/Contents/MacOS/$executable_name"
smoke_home="$(mktemp -d "${RUNNER_TEMP:-/tmp}/fastcat-smoke-home.XXXXXX")"
diagnostic_log="$smoke_home/Library/Application Support/FastCat/boot_diag.log"
process_log="${RUNNER_TEMP:-/tmp}/fastcat-macos-smoke.log"
rm -f "$diagnostic_log" "$process_log"

HOME="$smoke_home" "$executable" >"$process_log" 2>&1 &
app_pid=$!
cleanup() {
  kill "$app_pid" 2>/dev/null || true
  wait "$app_pid" 2>/dev/null || true
  rm -rf "$smoke_home"
}
trap cleanup EXIT

for _ in {1..30}; do
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "Application exited during startup"
    cat "$process_log"
    exit 1
  fi
  if [[ -f "$diagnostic_log" ]] && grep -q 'flutter first frame callback reached' "$diagnostic_log"; then
    if grep -q "Couldn't find vertexMain() in library" "$process_log"; then
      echo "Metal shader startup failure detected"
      cat "$process_log"
      exit 1
    fi
    echo "macOS first-frame smoke test passed"
    exit 0
  fi
  sleep 1
done

echo "Application did not reach the Flutter first frame within 30 seconds"
cat "$process_log"
[[ -f "$diagnostic_log" ]] && cat "$diagnostic_log"
exit 1
