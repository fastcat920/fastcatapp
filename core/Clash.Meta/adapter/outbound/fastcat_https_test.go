package outbound

import (
	"bytes"
	"context"
	"crypto/x509"
	"encoding/pem"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/fastcatprobe"
	C "github.com/metacubex/mihomo/constant"
)

func TestFastCatHTTPSExchange(t *testing.T) {
	token := "test-token-with-at-least-24-bytes"
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "CONNECT" || r.Host != "example.com:443" || r.Header.Get("Authorization") != "Bearer "+token || r.Header.Get("FastCat-Version") != "1" {
			http.Error(w, "bad handshake", 403)
			return
		}
		c, rw, e := w.(http.Hijacker).Hijack()
		if e != nil {
			return
		}
		defer c.Close()
		rw.WriteString("HTTP/1.1 200 Connection Established\r\n\r\nbanner")
		rw.Flush()
		io.Copy(c, rw)
	}))
	defer server.Close()
	host, port, _ := net.SplitHostPort(server.Listener.Addr().String())
	n, _ := strconv.Atoi(port)
	h, e := NewFastCatHTTPS(FastCatHTTPSOption{Name: "test", Server: host, Port: n, Token: token})
	if e != nil {
		t.Fatal(e)
	}
	roots := x509.NewCertPool()
	roots.AddCert(server.Certificate())
	h.config.RootCAs = roots
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	timing := new(fastcatprobe.Timing)
	c, e := h.DialContext(timing.WithContext(ctx), &C.Metadata{Host: "example.com", DstPort: 443})
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	phases := timing.Snapshot()
	if phases["gateway-reused"] != false || phases["gateway-tcp-ms"] == nil || phases["gateway-tls-ms"] == nil {
		t.Fatalf("missing v1 gateway phases: %v", phases)
	}
	c.SetDeadline(time.Now().Add(3 * time.Second))
	banner := make([]byte, 6)
	if _, e = io.ReadFull(c, banner); e != nil || string(banner) != "banner" {
		t.Fatalf("buffered banner: %q %v", banner, e)
	}
	c.Write([]byte("payload"))
	data := make([]byte, 7)
	if _, e = io.ReadFull(c, data); e != nil || string(data) != "payload" {
		t.Fatalf("echo %q %v", data, e)
	}
	if h.SupportUDP() {
		t.Fatal("must reject UDP")
	}
	if h.Type().String() != "FastCatHTTPS" {
		t.Fatal("incorrect protocol type")
	}
}
func TestFastCatHTTPSRejectInvalid(t *testing.T) {
	for _, token := range []string{"short", "valid-length-token-but-injected\r\nheader: value"} {
		if _, e := NewFastCatHTTPS(FastCatHTTPSOption{Server: "localhost", Port: 443, Token: token}); e == nil {
			t.Fatal("accepted invalid token")
		}
	}
}

// Runs the separately built server, not an in-process HTTP imitation.
func TestFastCatHTTPSStandaloneServer(t *testing.T) {
	testFastCatStandalone(t, false)
}

func TestFastCatH2StandaloneServer(t *testing.T) {
	testFastCatStandalone(t, true)
}

func testFastCatStandalone(t *testing.T, h2 bool) {
	t.Helper()
	name := "FASTCAT_TEST_SERVER"
	if h2 {
		name = "FASTCAT_TEST_H2_SERVER"
	}
	binary := os.Getenv(name)
	if binary == "" {
		t.Skipf("set %s to built standalone server", name)
	}
	template := httptest.NewTLSServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	pair := template.TLS.Certificates[0]
	template.Close()
	dir := t.TempDir()
	certFile := filepath.Join(dir, "cert.pem")
	keyFile := filepath.Join(dir, "key.pem")
	os.WriteFile(certFile, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: pair.Certificate[0]}), 0600)
	key, e := x509.MarshalPKCS8PrivateKey(pair.PrivateKey)
	if e != nil {
		t.Fatal(e)
	}
	os.WriteFile(keyFile, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: key}), 0600)
	target, e := net.Listen("tcp", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer target.Close()
	go func() {
		for {
			c, e := target.Accept()
			if e != nil {
				return
			}
			go func() { defer c.Close(); io.Copy(c, c) }()
		}
	}()
	reservation, e := net.Listen("tcp", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	entry := reservation.Addr().String()
	reservation.Close()
	token := "integration-token-at-least-24-bytes"
	args := []string{"-mode", "server", "-dynamic-targets"}
	tokenEnv := "FASTCAT_LAB_TOKEN"
	if h2 {
		args = []string{"server"}
		tokenEnv = "FASTCAT_H2_TOKEN"
	}
	args = append(args, "-listen", entry, "-cert", certFile, "-key", keyFile, "-allow-private-targets", "-session-timeout", "10s", "-max-tunnels", "1")
	cmd := exec.Command(binary, args...)
	cmd.Env = append(os.Environ(), tokenEnv+"="+token)
	if e = cmd.Start(); e != nil {
		t.Fatal(e)
	}
	defer func() { cmd.Process.Kill(); cmd.Wait() }()
	end := time.Now().Add(10 * time.Second)
	for {
		c, e := net.DialTimeout("tcp", entry, 100*time.Millisecond)
		if e == nil {
			c.Close()
			break
		}
		if time.Now().After(end) {
			t.Fatal("server startup timeout")
		}
		time.Sleep(50 * time.Millisecond)
	}
	host, port, _ := net.SplitHostPort(entry)
	n, _ := strconv.Atoi(port)
	option := FastCatHTTPSOption{Name: "standalone", Server: host, Port: n, Token: token, CAFile: certFile}
	var h ProxyAdapter
	if h2 {
		h, e = NewFastCatH2(option)
	} else {
		h, e = NewFastCatHTTPS(option)
	}
	if e != nil {
		t.Fatal(e)
	}
	defer h.Close()
	_, p, _ := net.SplitHostPort(target.Addr().String())
	pn, _ := strconv.Atoi(p)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c, e := h.DialContext(ctx, &C.Metadata{Host: "127.0.0.1", DstPort: uint16(pn)})
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	c.SetDeadline(time.Now().Add(5 * time.Second))
	second, secondErr := h.DialContext(ctx, &C.Metadata{Host: "127.0.0.1", DstPort: uint16(pn)})
	if secondErr == nil {
		second.Close()
		t.Fatal("server exceeded tunnel quota")
	}
	if !strings.Contains(secondErr.Error(), "503") {
		t.Fatalf("incorrect quota failure: %v", secondErr)
	}
	data := bytes.Repeat([]byte("FastCat"), 8192)
	go func() { c.Write(data) }()
	got := make([]byte, len(data))
	if _, e = io.ReadFull(c, got); e != nil {
		t.Fatal(e)
	}
	if !bytes.Equal(data, got) {
		t.Fatal("standalone payload mismatch")
	}
}
