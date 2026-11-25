package fcnv3

import (
	"context"
	"errors"
	"net"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestEmbeddedDispatch(t *testing.T) {
	uuid := "d67eaa2d-eaf6-49ee-a765-d58b20b6e21d"
	credential, err := CredentialFromUUID(uuid)
	if err != nil {
		t.Fatal(err)
	}
	upper, err := CredentialFromUUID(strings.ToUpper(uuid))
	if err != nil || upper != credential || strings.Contains(credential.ID, uuid) {
		t.Fatal("non-canonical FCN v3 account derivation")
	}
	tcpTarget, _ := startTestEcho(t)
	udpTarget, _ := startUDPTestEcho(t)
	var opened atomic.Int32
	server, config := startTestServer(t, tcpTarget, func(cfg *ServerConfig) {
		cfg.Targets = nil
		cfg.Credentials = []Credential{credential}
		cfg.EnableUDP = true
		cfg.Dispatch = func(setup, lifetime context.Context, request DispatchRequest) (net.Conn, error) {
			if request.Account != credential.ID || request.Peer == nil || setup.Err() != nil || lifetime.Err() != nil {
				t.Errorf("unexpected dispatch metadata")
				return nil, errors.New("invalid dispatch request")
			}
			var target string
			switch {
			case request.Network == "tcp" && request.Target == "origin.example:443":
				target = tcpTarget
			case request.Network == "udp" && request.Target == "echo.example:53":
				target = udpTarget
			default:
				return nil, ErrRejected
			}
			opened.Add(1)
			return (&net.Dialer{}).DialContext(setup, request.Network, target)
		}
	})
	config.Account, config.Secret = credential.ID, credential.Secret
	config.EnableUDP, config.AllowDomainTargets = true, true
	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
	defer cancel()

	invalid := config
	invalid.Secret = wrongSecret
	if _, err := newTestClient(t, invalid).DialUDP(ctx, "echo.example:53"); !errors.Is(err, ErrRejected) || opened.Load() != 0 {
		t.Fatal("a rejected credential reached the dispatch handler")
	}

	client := newTestClient(t, config)
	checkEchoAndHalfClose(t, dialTestStream(t, ctx, client, "ORIGIN.example:443"), []byte("verified TCP"))
	tcp := dialTestStream(t, ctx, client, "origin.example:443")
	checkEcho(t, tcp, []byte("before revocation"))
	udp := dialTestUDP(t, ctx, client, "echo.example:53")
	checkUDPEcho(t, ctx, udp, []byte("before revocation"))
	if got := opened.Load(); got != 3 {
		t.Fatalf("dispatch opens = %d, want 3", got)
	}
	if err := server.ReplaceCredentials(nil); err != nil {
		t.Fatal(err)
	}
	if n, err := tcp.Read(make([]byte, 1)); n != 0 || err == nil {
		t.Fatal("revoked TCP tunnel still readable")
	}
	checkUDPClosed(t, udp)
	if _, err := client.DialUDP(ctx, "echo.example:53"); !errors.Is(err, ErrRejected) || opened.Load() != 3 {
		t.Fatal("a revoked account reached dispatch")
	}
}
