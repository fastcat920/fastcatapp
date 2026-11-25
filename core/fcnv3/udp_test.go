package fcnv3

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"net"
	"net/netip"
	"net/url"
	"sync/atomic"
	"testing"
	"time"

	http "github.com/metacubex/http"
	"github.com/metacubex/quic-go/http3"
	"github.com/metacubex/quic-go/quicvarint"
)

func TestHTTP3ConnectUDP(t *testing.T) {
	target, received := startUDPTestEcho(t)
	tcpTarget, _ := startTestEcho(t)
	const outerName = "outer.example"
	key := testServerECHKey(t, outerName)
	server, config := startStrictECHTestServer(t, tcpTarget, outerName, key, func(cfg *ServerConfig) {
		cfg.UDPTargets = []string{target}
		cfg.UDPIdleTimeout = 750 * time.Millisecond
	})
	config.EnableUDP = true
	ctx, cancel := context.WithTimeout(t.Context(), 10*time.Second)
	defer cancel()

	t.Run("ECH is required for authenticated UDP", func(t *testing.T) {
		clear := newTestClient(t, config)
		if _, err := clear.DialUDP(ctx, target); !errors.Is(err, ErrRejected) {
			t.Fatalf("DialUDP without ECH = %v, want ErrRejected", err)
		}
	})
	config.EntryDNS = udpTestEntryDNS{EntryDNSResult{
		ECHConfigList: append(binary.BigEndian.AppendUint16(nil, uint16(len(key.Config))), key.Config...),
		Addresses:     []netip.Addr{netip.MustParseAddr("127.0.0.1")},
	}}
	client := newTestClient(t, config)
	pooled, err := client.acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if !pooled.quic.ConnectionState().TLS.ECHAccepted {
		t.Fatal("UDP session was established without ECH")
	}

	t.Run("authorization and separate numeric allowlists", func(t *testing.T) {
		for _, tc := range []struct {
			name   string
			kind   string
			target string
			secret string
		}{
			{name: "missing", target: target},
			{"TCP proof", "CONNECT", target, testSecret},
			{"wrong key", udpAuthKind, target, wrongSecret},
			{"TCP-only allowed address", udpAuthKind, tcpTarget, testSecret},
		} {
			t.Run(tc.name, func(t *testing.T) {
				before := received.Load()
				stream, err := pooled.http.OpenRequestStream(ctx)
				if err != nil {
					t.Fatal(err)
				}
				defer stream.CancelRead(cancelCode)
				defer stream.CancelWrite(cancelCode)
				stream.SetDeadline(time.Now().Add(time.Second))
				req := udpRequest(config.Endpoint, tc.target)
				if tc.kind != "" {
					key, err := credentialKey(testAccount, tc.secret)
					if err != nil {
						t.Fatal(err)
					}
					req.Header.Set(authHeader, authValueFor(tc.kind, key, pooled.binding, testAccount, tc.target, stream.StreamID()))
				}
				if err := stream.SendRequestHeader(req); err != nil {
					t.Fatal(err)
				}
				res, err := stream.ReadResponse()
				if err != nil {
					t.Fatal(err)
				}
				if res.StatusCode != http.StatusForbidden || received.Load() != before {
					t.Fatalf("CONNECT-UDP = HTTP %d with %d upstream packets, want HTTP 403 with 0 packets", res.StatusCode, received.Load()-before)
				}
			})
		}
		if _, err := client.DialUDP(ctx, "localhost:53"); err == nil {
			t.Fatal("accepted a DNS name as a UDP target")
		}
	})

	t.Run("packet boundaries and shared QUIC session", func(t *testing.T) {
		first := dialTestUDP(t, ctx, client, target)
		second := dialTestUDP(t, ctx, client, target)
		if first.stream.StreamID() == second.stream.StreamID() {
			t.Fatal("associations used the same request stream")
		}
		checkUDPEcho(t, ctx, first, nil)
		checkUDPEcho(t, ctx, second, bytes.Repeat([]byte{3}, MaxUDPPayload))
		checkUDPEcho(t, ctx, first, []byte("first"))
		checkEchoAndHalfClose(t, dialTestStream(t, ctx, client, tcpTarget), []byte("TCP on same QUIC connection"))
		if got, err := client.acquire(ctx); err != nil || got != pooled {
			t.Fatalf("UDP changed the pooled connection: %v", err)
		}
	})

	t.Run("payload bounds context IDs and no stream fallback", func(t *testing.T) {
		assoc := dialTestUDP(t, ctx, client, target)
		if err := assoc.SendDatagram(make([]byte, MaxUDPPayload+1)); !errors.Is(err, ErrUDPPayloadTooLarge) {
			t.Fatalf("oversized SendDatagram = %v", err)
		}
		if err := assoc.stream.SendDatagram([]byte{1, 23, 45}); err != nil {
			t.Fatal(err)
		}
		if err := assoc.stream.SendDatagram(make([]byte, MaxUDPPayload+2)); err != nil {
			t.Fatal(err)
		}
		checkUDPEcho(t, ctx, assoc, []byte("oversize response"))
		before := received.Load()
		if err := http3.WriteCapsule(quicvarint.NewWriter(assoc.stream), 0, []byte{0, 42}); err != nil {
			t.Fatal(err)
		}
		checkUDPClosed(t, assoc)
		if received.Load() != before {
			t.Fatal("a reliable DATAGRAM capsule reached the UDP target")
		}
	})

	t.Run("association quota releases after FIN", func(t *testing.T) {
		const perConnection = 8
		waitForUDPLeases(t, server, 0)
		associations := make([]*UDPAssociation, perConnection)
		for i := range associations {
			associations[i] = dialTestUDP(t, ctx, client, target)
		}
		if _, err := client.DialUDP(ctx, target); !errors.Is(err, ErrRejected) {
			t.Fatalf("association above per-connection quota = %v, want ErrRejected", err)
		}
		if err := associations[0].stream.Close(); err != nil {
			t.Fatal(err)
		}
		waitForUDPLeases(t, server, perConnection-1)
		replacement := dialTestUDP(t, ctx, client, target)
		checkUDPEcho(t, ctx, replacement, []byte("reused quota"))
	})

	t.Run("idle expiry and credential revocation", func(t *testing.T) {
		idle := dialTestUDP(t, ctx, client, target)
		checkUDPClosed(t, idle)
		revoked := dialTestUDP(t, ctx, client, target)
		checkUDPEcho(t, ctx, revoked, []byte("before revocation"))
		if err := server.ReplaceCredentials(nil); err != nil {
			t.Fatal(err)
		}
		checkUDPClosed(t, revoked)
		if _, err := client.DialUDP(ctx, target); !errors.Is(err, ErrRejected) {
			t.Fatalf("new UDP association after revocation = %v, want ErrRejected", err)
		}
	})
}

func TestHTTP3ConnectUDPRequiresDatagramSupport(t *testing.T) {
	tcpTarget, _ := startTestEcho(t)
	_, config := startTestServer(t, tcpTarget)
	ctx, cancel := context.WithTimeout(t.Context(), 3*time.Second)
	defer cancel()
	for _, enabled := range []bool{false, true} {
		config.EnableUDP = enabled
		client := newTestClient(t, config)
		if _, err := client.DialUDP(ctx, tcpTarget); !errors.Is(err, ErrUDPUnavailable) {
			t.Fatalf("DialUDP with client EnableUDP=%t and UDP-disabled server = %v", enabled, err)
		}
		checkEchoAndHalfClose(t, dialTestStream(t, ctx, client, tcpTarget), []byte("TCP"))
	}
}

func TestHTTP3ConnectUDPNetworkChange(t *testing.T) {
	target, _ := startUDPTestEcho(t)
	const outerName = "outer.example"
	key := testServerECHKey(t, outerName)
	server, config := startStrictECHTestServer(t, "", outerName, key, func(cfg *ServerConfig) {
		cfg.Targets = nil
		cfg.UDPTargets = []string{target}
		cfg.ECHKeys = nil
	})
	config.EnableUDP = true
	client := newTestClient(t, config)
	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()
	if err := client.UpdateNetwork("first"); err != nil {
		t.Fatal(err)
	}
	old := dialTestUDP(t, ctx, client, target)
	original, err := client.acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if err := client.UpdateNetwork("first"); err != nil {
		t.Fatal(err)
	}
	if current, err := client.acquire(ctx); err != nil || current != original {
		t.Fatalf("same network identity changed the pooled session: %v", err)
	}
	checkUDPEcho(t, ctx, old, []byte("on first network"))
	if err := client.UpdateNetwork("second"); err != nil {
		t.Fatal(err)
	}
	checkUDPClosed(t, old)
	waitForUDPLeases(t, server, 0)
	fresh := dialTestUDP(t, ctx, client, target)
	if current, err := client.acquire(ctx); err != nil || current == original {
		t.Fatalf("new network identity did not create a new session: %v", err)
	}
	checkUDPEcho(t, ctx, fresh, []byte("after network change"))
}

func TestConnectUDPAddressTemplateAndSettings(t *testing.T) {
	req := udpRequest("proxy.example:443", "[2001:db8::42]:5353")
	if got := req.URL.EscapedPath(); got != udpPrefix+"2001%3Adb8%3A%3A42/5353/" {
		t.Fatalf("IPv6 URI path = %q", got)
	}
	if target, err := udpRequestTarget(req.URL, true); err != nil || target != "[2001:db8::42]:5353" {
		t.Fatalf("IPv6 target = (%q, %v)", target, err)
	}
	for _, suffix := range []string{
		"2001:db8::42/5353/", "fe80%3A%3A1%25eth0/5353/", "relay.example/5353/",
		"127.0.0.1/0/", "127.0.0.1/5353/?", "127.0.0.1/5353/extra/", "127.0.0.1/5353",
	} {
		u, err := url.Parse("https://proxy.example" + udpPrefix + suffix)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := udpRequestTarget(u, true); err == nil {
			t.Errorf("accepted invalid UDP target URI suffix %q", suffix)
		}
	}
	for _, invalid := range []string{"localhost:53", "0.0.0.0:53", "[::]:53", "224.0.0.1:53", "255.255.255.255:53"} {
		if _, _, err := normalizeUDPConfig([]string{invalid}, 0); err == nil {
			t.Errorf("accepted invalid UDP allowlist entry %q", invalid)
		}
	}
	if _, _, err := normalizeUDPConfig(nil, -time.Second); err == nil {
		t.Fatal("accepted a negative UDP idle timeout")
	}
}

type udpTestEntryDNS struct{ EntryDNSResult }

func (r udpTestEntryDNS) Resolve(context.Context, string) (EntryDNSResult, error) {
	return r.EntryDNSResult, nil
}

func (r udpTestEntryDNS) Refresh(context.Context, string) (EntryDNSResult, error) {
	return r.EntryDNSResult, nil
}

func startUDPTestEcho(t *testing.T) (string, *atomic.Int32) {
	t.Helper()
	socket, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	count := new(atomic.Int32)
	done := make(chan struct{})
	go func() {
		defer close(done)
		var buf [65536]byte
		for {
			n, peer, err := socket.ReadFromUDP(buf[:])
			if err != nil {
				return
			}
			count.Add(1)
			if string(buf[:n]) == "oversize response" {
				socket.WriteToUDP(make([]byte, MaxUDPPayload+1), peer)
			}
			socket.WriteToUDP(buf[:n], peer)
		}
	}()
	t.Cleanup(func() {
		socket.Close()
		<-done
	})
	return socket.LocalAddr().String(), count
}

func dialTestUDP(t *testing.T, ctx context.Context, c *Client, target string) *UDPAssociation {
	t.Helper()
	assoc, err := c.DialUDP(ctx, target)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { assoc.Close() })
	return assoc
}

func checkUDPEcho(t *testing.T, ctx context.Context, assoc *UDPAssociation, payload []byte) {
	t.Helper()
	if err := assoc.SendDatagram(payload); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	got, err := assoc.ReceiveDatagram(ctx)
	if err != nil || !bytes.Equal(got, payload) {
		t.Fatalf("UDP echo = (%d bytes, %v), want %d matching bytes", len(got), err, len(payload))
	}
}

func checkUDPClosed(t *testing.T, assoc *UDPAssociation) {
	t.Helper()
	ctx, cancel := context.WithTimeout(t.Context(), 2*time.Second)
	defer cancel()
	if _, err := assoc.ReceiveDatagram(ctx); err == nil || errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("ReceiveDatagram after closure = %v, want association error", err)
	}
}

func waitForUDPLeases(t *testing.T, server *Server, want int) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for {
		server.mu.Lock()
		got := len(server.leases)
		server.mu.Unlock()
		if got == want {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("active leases = %d, want %d", got, want)
		}
		time.Sleep(time.Millisecond)
	}
}
