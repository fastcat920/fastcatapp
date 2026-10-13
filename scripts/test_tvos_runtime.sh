#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/fastcat-tvos-protocols.XXXXXX")
# Keep the small executables in a unique temporary folder for local inspection.
xcrun swiftc tvos/Shared/TVCoreProtocol.swift tvos/FastCatTV/TVProxyRouting.swift \
  tvos/FastCatTV/TVBuildConfiguration.swift test/tvos/runtime_protocol_test.swift -o "$test_dir/runtime"
"$test_dir/runtime"
xcrun swiftc tvos/FastCatTV/GatewayClient.swift tvos/FastCatTV/TVQRLoginCoordinator.swift \
  test/tvos/qr_login_test.swift -o "$test_dir/qr"
"$test_dir/qr"
