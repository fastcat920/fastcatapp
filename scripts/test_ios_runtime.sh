#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/fastcat-ios-ipc.XXXXXX")
# Compile the actual Foundation-only policy from the existing Runner target;
# NetworkExtension and Flutter modules are not available to a macOS CLI test.
awk '
  BEGIN { print "import Foundation" }
  /^\/\/ MARK: - Foundation-only IPC acknowledgement policy/ { capture = 1 }
  /^\/\/ MARK: - Status event stream handler/ { capture = 0 }
  capture { print }
' ios/Runner/VPNManager.swift > "$test_dir/IOSVPNIPC.swift"
xcrun swiftc "$test_dir/IOSVPNIPC.swift" test/ios/vpn_ipc_test.swift -o "$test_dir/ipc"
"$test_dir/ipc"
xcrun swiftc -frontend -parse ios/Runner/VPNManager.swift
