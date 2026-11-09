# FastCat local patches

Upstream: github.com/metacubex/sing-tun v0.4.24. Upstream licenses are retained.

- `recoveringTCPListener` keeps the original NAT port and listener object stable,
  recreates a failed host TCP socket with bounded backoff, and cancels/discards
  in-flight replacements after Close. An explicit stop never recreates sockets.
- `SystemForwarderHealth` reports listener health by provided TUN descriptor for
  Android lifecycle/status checks; it contains no destinations or credentials.
- System/mixed partial initialization closes previously created listeners.
- `BorrowFileDescriptor` lets the Android caller keep ownership until construction
  ends. NativeTun duplicates borrowed descriptors; the caller always closes its
  original exactly once, including failures before NativeTun is constructed.
- Unknown NAT sessions close their accepted TCP connection.

The recovery path reuses the exact original address and port; it never updates
`tcpPort` concurrently with packet processing. Do not replace this with an
unprotected write to `System.tcpPort`.

Regression checks (run from `core`):

    go test -race -run TestRecoveringTCPListener github.com/metacubex/sing-tun

Tests use real loopback sockets and injected Accept failures. Device validation
must additionally exercise real IPv4 NO_PROXY traffic, reconnect, explicit stop,
background and network transitions. A browser using the OS HTTP proxy is not a
substitute for testing the raw TUN data path.
