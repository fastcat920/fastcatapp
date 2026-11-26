package fcnv3

import (
	"bytes"
	"context"
	"crypto/x509"
	"encoding/base64"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	D "github.com/miekg/dns"
)

const testEntryDNSName = "private.example"

func newEntryDNSList(t *testing.T, publicName string) []byte {
	t.Helper()
	value, _, err := genTestECHConfig(publicName)
	if err != nil {
		t.Fatal(err)
	}
	config, err := base64.StdEncoding.DecodeString(value)
	if err != nil {
		t.Fatal(err)
	}
	return config
}

func newEntryDNSTestConfig(t *testing.T, handler http.HandlerFunc) EntryDNSConfig {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	host, port, err := net.SplitHostPort(server.Listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	roots := x509.NewCertPool()
	roots.AddCert(server.Certificate())
	return EntryDNSConfig{URL: "https://example.com:" + port + "/dns-query", BootstrapIP: host, RootCAs: roots}
}

func testEntryDNSQuery(t *testing.T, r *http.Request) *D.Msg {
	t.Helper()
	body, err := io.ReadAll(r.Body)
	if err != nil {
		t.Errorf("reading DNS request: %v", err)
		return nil
	}
	var query D.Msg
	if err := query.Unpack(body); err != nil || len(query.Question) != 1 {
		t.Errorf("invalid DNS request: %v", err)
		return nil
	}
	if r.Method != http.MethodPost || r.TLS == nil || r.TLS.ServerName != "example.com" ||
		r.Header.Get("Content-Type") != entryDNSMessageType || r.Header.Get("Cache-Control") != "no-cache" ||
		query.Id != 0 || query.Question[0].Name != D.Fqdn(testEntryDNSName) {
		t.Error("unexpected DNS request")
		return nil
	}
	return &query
}

func testEntryDNSReply(query *D.Msg, list []byte) *D.Msg {
	q := query.Question[0]
	message := new(D.Msg).SetReply(query)
	header := D.RR_Header{Name: q.Name, Rrtype: q.Qtype, Class: D.ClassINET, Ttl: 60}
	switch q.Qtype {
	case D.TypeHTTPS:
		if list != nil {
			message.Answer = []D.RR{&D.HTTPS{SVCB: D.SVCB{Hdr: header, Priority: 1, Target: ".", Value: []D.SVCBKeyValue{&D.SVCBECHConfig{ECH: list}}}}}
		}
	case D.TypeA:
		header.Ttl = 15
		message.Answer = []D.RR{&D.A{Hdr: header, A: net.ParseIP("192.0.2.100")}}
	case D.TypeAAAA:
		message.Answer = []D.RR{&D.AAAA{Hdr: header, AAAA: net.ParseIP("2001:db8::100")}}
	}
	return message
}

func writeEntryDNSReply(t *testing.T, w http.ResponseWriter, response *D.Msg) {
	t.Helper()
	wire, err := response.Pack()
	if err != nil {
		t.Errorf("packing DNS response: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", entryDNSMessageType)
	_, _ = w.Write(wire)
}

func TestEntryDNSCacheAndRefresh(t *testing.T) {
	first := newEntryDNSList(t, "outer.example")
	rotated := newEntryDNSList(t, "outer.example")
	var generation atomic.Int32
	var lookups atomic.Int32
	started, release := make(chan struct{}), make(chan struct{})
	var startOnce sync.Once
	config := newEntryDNSTestConfig(t, func(w http.ResponseWriter, r *http.Request) {
		query := testEntryDNSQuery(t, r)
		if query == nil {
			return
		}
		lookups.Add(1)
		list := first
		switch generation.Load() {
		case 1:
			list = rotated
		case 2:
			list = nil
		}
		if query.Question[0].Qtype == D.TypeHTTPS {
			startOnce.Do(func() { close(started) })
			select {
			case <-release:
			case <-r.Context().Done():
				return
			}
		}
		w.Header().Set("Age", "5")
		writeEntryDNSReply(t, w, testEntryDNSReply(query, list))
	})
	resolver, err := NewEntryDNSResolver(config)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(t.Context(), 8*time.Second)
	defer cancel()
	timestamp := time.Now()
	var elapsed atomic.Int64
	resolver.now = func() time.Time { return timestamp.Add(time.Duration(elapsed.Load())) }

	wantIPs := []netip.Addr{netip.MustParseAddr("192.0.2.100"), netip.MustParseAddr("2001:db8::100")}
	initial, cancelInitial := context.WithCancel(ctx)
	canceled := make(chan error, 1)
	go func() {
		_, err := resolver.Resolve(initial, testEntryDNSName)
		canceled <- err
	}()
	select {
	case <-started:
	case <-ctx.Done():
		t.Fatal("DoH request did not start")
	}
	cancelInitial()
	if err := <-canceled; !errors.Is(err, context.Canceled) {
		t.Fatalf("canceled waiter returned %v", err)
	}
	var waiters sync.WaitGroup
	for range 16 {
		waiters.Go(func() {
			result, err := resolver.Resolve(ctx, "PRIVATE.Example.")
			if err != nil || !bytes.Equal(result.ECHConfigList, first) || !slices.Equal(result.Addresses, wantIPs) {
				t.Errorf("unexpected encrypted resolution: %v, %v", result.Addresses, err)
				return
			}
			result.ECHConfigList[0] ^= 1
			result.Addresses[0] = netip.Addr{}
		})
	}
	close(release)
	waiters.Wait()
	check := func(resolve func(context.Context, string) (EntryDNSResult, error), want []byte, queries int32) {
		t.Helper()
		result, err := resolve(ctx, testEntryDNSName)
		if err != nil || !bytes.Equal(result.ECHConfigList, want) || !slices.Equal(result.Addresses, wantIPs) || lookups.Load() != queries {
			t.Fatalf("expected %d DNS queries, got %d with %v", queries, lookups.Load(), err)
		}
	}
	check(resolver.Resolve, first, 3)
	generation.Store(1)
	check(resolver.Refresh, rotated, 6)
	elapsed.Store(int64(9 * time.Second))
	check(resolver.Resolve, rotated, 6)
	elapsed.Store(int64(10 * time.Second))
	check(resolver.Resolve, rotated, 9)
	resolver.Invalidate("PRIVATE.Example.")
	check(resolver.Resolve, rotated, 12)
	generation.Store(2)
	if _, err := resolver.Refresh(ctx, testEntryDNSName); err == nil {
		t.Fatal("refresh reused a cached result after ECH was removed")
	}
	if _, err := resolver.Resolve(ctx, testEntryDNSName); err == nil {
		t.Fatal("ordinary lookup reused a stale result after refresh failed")
	}
}

func TestEntryDNSRejectsInvalidData(t *testing.T) {
	good := newEntryDNSList(t, "outer.example")
	badName := newEntryDNSList(t, testEntryDNSName)
	for _, mode := range []string{"missing ECH", "malformed ECH", "private outer name", "unrelated ECH owner", "invalid question", "truncated answer", "incorrect response type", "zero addresses", "redirect"} {
		t.Run(mode, func(t *testing.T) {
			var redirected atomic.Bool
			config := newEntryDNSTestConfig(t, func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == "/redirected" {
					redirected.Store(true)
					return
				}
				query := testEntryDNSQuery(t, r)
				if query == nil {
					return
				}
				message := testEntryDNSReply(query, good)
				if mode == "zero addresses" && query.Question[0].Qtype != D.TypeHTTPS {
					message.Answer = nil
				}
				if query.Question[0].Qtype == D.TypeHTTPS {
					switch mode {
					case "missing ECH":
						message.Answer = nil
					case "malformed ECH":
						message = testEntryDNSReply(query, []byte{0, 2, 1, 2})
					case "private outer name":
						message = testEntryDNSReply(query, badName)
					case "unrelated ECH owner":
						message.Answer[0].Header().Name = "unrelated.example."
					case "invalid question":
						message.Question[0].Name = "unrelated.example."
					case "truncated answer":
						message.Truncated = true
					case "incorrect response type":
						w.Header().Set("Content-Type", "application/dns-message-plausible")
						w.WriteHeader(http.StatusOK)
						return
					case "redirect":
						http.Redirect(w, r, "/redirected", http.StatusTemporaryRedirect)
						return
					}
				}
				writeEntryDNSReply(t, w, message)
			})
			resolver, err := NewEntryDNSResolver(config)
			if err != nil {
				t.Fatal(err)
			}
			result, err := resolver.Resolve(t.Context(), testEntryDNSName)
			if err == nil || strings.Contains(err.Error(), testEntryDNSName) || len(result.ECHConfigList)+len(result.Addresses) != 0 || redirected.Load() {
				t.Fatalf("invalid DNS data was not rejected safely: %v", err)
			}
		})
	}
}

func TestEntryDNSValidatesBootstrapAndTLS(t *testing.T) {
	config := newEntryDNSTestConfig(t, func(w http.ResponseWriter, _ *http.Request) {
		t.Error("DNS query reached an unauthenticated DoH endpoint")
		w.WriteHeader(http.StatusBadRequest)
	})
	for _, invalid := range []EntryDNSConfig{
		{URL: config.URL},
		{URL: config.URL, BootstrapIP: "localhost"},
		{URL: strings.Replace(config.URL, "https:", "http:", 1), BootstrapIP: config.BootstrapIP},
		{URL: config.URL + "?dns=unexpected", BootstrapIP: config.BootstrapIP},
	} {
		if _, err := NewEntryDNSResolver(invalid); err == nil {
			t.Errorf("accepted unsafe DNS resolver settings: %+v", invalid)
		}
	}
	if _, err := NewEntryDNSResolver(EntryDNSConfig{URL: "https://[2001:db8::1]/dns-query"}); err != nil {
		t.Fatalf("rejected literal HTTPS DNS endpoint: %v", err)
	}
	for _, invalid := range []EntryDNSConfig{
		{URL: config.URL, BootstrapIP: config.BootstrapIP, RootCAs: x509.NewCertPool()},
		{URL: strings.Replace(config.URL, "example.com", "invalid.example", 1), BootstrapIP: config.BootstrapIP, RootCAs: config.RootCAs},
	} {
		resolver, err := NewEntryDNSResolver(invalid)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := resolver.Resolve(t.Context(), testEntryDNSName); err == nil {
			t.Fatal("accepted unauthenticated encrypted DNS")
		}
	}
	resolver, err := NewEntryDNSResolver(config)
	if err != nil {
		t.Fatal(err)
	}
	for _, invalid := range []string{"example.com", "example.com..", "127.0.0.1", "*.example", "single", "n ame.example", "bad_.example"} {
		if _, err := resolver.Resolve(t.Context(), invalid); err == nil {
			t.Errorf("accepted unsafe entry DNS name %q", invalid)
		}
	}
}
