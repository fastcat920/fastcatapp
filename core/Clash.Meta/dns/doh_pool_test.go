package dns

import (
	"context"
	"encoding/base64"
	"net"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"

	D "github.com/miekg/dns"
)

func TestDoHRetainsConnectionAfterHTTPError(t *testing.T) {
	var connections atomic.Int32
	var requests atomic.Int32
	var protocol atomic.Int32
	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		protocol.Store(int32(r.ProtoMajor))
		if requests.Add(1) == 1 {
			http.Error(w, "temporarily unavailable", http.StatusServiceUnavailable)
			return
		}
		wire, err := base64.RawURLEncoding.DecodeString(r.URL.Query().Get("dns"))
		var query D.Msg
		if err != nil || query.Unpack(wire) != nil {
			http.Error(w, "invalid DNS query", http.StatusBadRequest)
			return
		}
		reply := new(D.Msg).SetReply(&query)
		wire, err = reply.Pack()
		if err != nil {
			http.Error(w, "invalid DNS reply", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/dns-message")
		_, _ = w.Write(wire)
	}))
	server.Config.ConnState = func(_ net.Conn, state http.ConnState) {
		if state == http.StateNew {
			connections.Add(1)
		}
	}
	server.EnableHTTP2 = true
	server.StartTLS()
	defer server.Close()

	client := newDoHClient(server.URL, nil, false, map[string]string{"skip-cert-verify": "true"}, nil, "").(*dnsOverHTTPS)
	defer client.Close()
	query := new(D.Msg).SetQuestion("example.test.", D.TypeA)
	if _, err := client.ExchangeContext(context.Background(), query); err == nil {
		t.Fatal("expected the first request to fail")
	}
	if _, err := client.ExchangeContext(context.Background(), query); err != nil {
		t.Fatalf("retry with the live pool: %v", err)
	}
	if got := protocol.Load(); got != 2 {
		t.Fatalf("negotiated HTTP/%d, want HTTP/2", got)
	}
	if got := connections.Load(); got != 1 {
		t.Fatalf("opened %d connections, want 1", got)
	}
}
