package h2server

import (
	"context"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/http/httptrace"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestReloadDeviceTokensOnLiveHTTP2Connection(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tokens")
	write := func(contents string) {
		t.Helper()
		if err := os.WriteFile(path, []byte(contents), 0600); err != nil {
			t.Fatal(err)
		}
	}
	const a, b = "alpha-device-token-0000001", "bravo-device-token-0000002"
	write(a + "\r\n" + b + "\r\n")
	handler, err := New(Config{TokensFile: path})
	if err != nil {
		t.Fatal(err)
	}
	reload := handler.(interface{ ReloadTokens() error }).ReloadTokens
	server := httptest.NewUnstartedServer(handler)
	server.EnableHTTP2 = true
	server.StartTLS()
	defer server.Close()
	var conn net.Conn
	// An accepted credential reaches the target policy, which denies loopback
	// with 403. Unknown credentials stop at 407, before any outbound dialing.
	check := func(token string, want int) {
		t.Helper()
		trace := &httptrace.ClientTrace{GotConn: func(info httptrace.GotConnInfo) {
			if conn == nil {
				conn = info.Conn
			} else if conn != info.Conn {
				t.Error("test replaced the underlying TLS connection")
			}
		}}
		req, err := http.NewRequestWithContext(httptrace.WithClientTrace(context.Background(), trace), http.MethodConnect, server.URL, nil)
		if err != nil {
			t.Fatal(err)
		}
		req.Host = "127.0.0.1:9"
		req.Header.Set("Proxy-Authorization", "Bearer "+token)
		resp, err := server.Client().Do(req)
		if err != nil {
			t.Fatal(err)
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		if resp.ProtoMajor != 2 || resp.StatusCode != want {
			t.Fatalf("%s status %d, want HTTP/2 status %d", resp.Proto, resp.StatusCode, want)
		}
	}

	check(a, 403)
	check(b, 403)
	write(b + "\n")
	if err := reload(); err != nil {
		t.Fatal(err)
	}
	check(a, 407)
	check(b, 403)

	for _, bad := range []string{a + "\nshort", a + "\n" + a, b + "\n\n" + a} {
		write(bad)
		err := reload()
		if err == nil || strings.Contains(err.Error(), a) || strings.Contains(err.Error(), b) {
			t.Fatal("invalid reload accepted or exposed a token")
		}
		check(a, 407)
		check(b, 403)
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if err := reload(); err == nil {
		t.Fatal("missing file on reload")
	}
	check(b, 403)
	write("")
	if err := reload(); err != nil {
		t.Fatal(err)
	}
	check(a, 407)
	check(b, 407)
	write(a)
	if err := reload(); err != nil {
		t.Fatal(err)
	}
	check(a, 403)
}

func TestCredentialSourceChoice(t *testing.T) {
	if _, err := New(Config{}); err == nil {
		t.Fatal("missing credential source")
	}
	if _, err := New(Config{Token: strings.Repeat("a", 24), TokensFile: "other"}); err == nil {
		t.Fatal("ambiguous credential sources")
	}
	h, err := New(Config{Token: strings.Repeat("a", 24)})
	if err != nil || h.(interface{ ReloadTokens() error }).ReloadTokens() == nil {
		t.Fatal("single-token mode must reject file reload")
	}
}
