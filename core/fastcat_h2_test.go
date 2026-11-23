package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"encoding/json"
	"encoding/pem"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func TestFastCatH2AppleConfigurationsReuseGatewayBetweenURLTests(t *testing.T) {
	const target = "probe.example:80"
	const nodeName = "FastCat HTTP/2 test"
	const token = "credential-for-local-test-only"
	const originDelay = 30 * time.Millisecond
	requests := make(chan string, 4)
	gateway := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect || r.Host != target || r.ProtoMajor != 2 ||
			r.TLS == nil || r.TLS.Version != tls.VersionTLS13 || r.Header.Get("Proxy-Authorization") != "Bearer "+token {
			http.Error(w, "unexpected CONNECT", http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		req, err := http.ReadRequest(bufio.NewReader(r.Body))
		if err != nil {
			t.Errorf("read tunneled request: %v", err)
			return
		}
		switch {
		case req.Method == http.MethodHead && req.URL.Path == "/ping":
		case req.Method == http.MethodGet && req.URL.Path == "/ttfb":
			// A trace attributed to the CONNECT response would miss this delay.
			time.Sleep(originDelay)
		default:
			t.Errorf("unexpected tunneled request: %s %s", req.Method, req.URL.Path)
			return
		}
		requests <- r.RemoteAddr
		io.WriteString(w, "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
	}))
	gateway.EnableHTTP2 = true
	gateway.StartTLS()
	defer gateway.Close()

	dir := t.TempDir()
	oldHome := C.Path.HomeDir()
	C.SetHomeDir(dir)
	defer C.SetHomeDir(oldHome)
	caFile := filepath.Join(dir, "gateway.pem")
	cert := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: gateway.Certificate().Raw})
	if err := os.WriteFile(caFile, cert, 0600); err != nil {
		t.Fatal(err)
	}
	addr := gateway.Listener.Addr().(*net.TCPAddr)
	raw := config.DefaultRawConfig()
	raw.Proxy = []map[string]any{{
		"name": nodeName, "type": "fastcat-h2", "server": addr.IP.String(),
		"port": addr.Port, "sni": "example.com", "ca-file": caFile, "token": token,
	}}
	raw.ProxyGroup = []map[string]any{{"name": "test-select", "type": "select", "proxies": []string{nodeName, "DIRECT"}}}
	raw.Rule = []string{"MATCH,test-select"}

	for _, tc := range []struct {
		name string
		raw  *config.RawConfig
	}{{"tunnel", raw}, {"offline_probe", probeIOSConfig(raw)}} {
		t.Run(tc.name, func(t *testing.T) {
			parsed, err := config.ParseRawConfig(tc.raw)
			if err != nil {
				t.Fatal(err)
			}
			node := parsed.Proxies[nodeName]
			if node == nil || node.SupportUDP() {
				t.Fatal("missing TCP-only HTTP/2 node")
			}
			defer node.Close()
			var peer string
			// Exercise the actual Apple IPC handler on a cold node, then on the
			// existing session. The origin intentionally speaks HTTP, which
			// ensures the gateway TLS callbacks cannot masquerade as origin TLS.
			if tc.name == "tunnel" {
				defer tunnel.UpdateProxies(tunnel.Proxies(), tunnel.Providers())
				tunnel.UpdateProxies(parsed.Proxies, parsed.Providers)
				for i, timed := range []bool{true, true, false} {
					params := StreamingProbeParams{ProxyName: nodeName, URL: "http://probe.example/ttfb",
						NoRedirect: true, Timeout: 5000, PhaseTiming: timed}
					wire, err := json.Marshal(params)
					if err != nil {
						t.Fatal(err)
					}
					var report StreamingProbeResult
					if err := json.Unmarshal([]byte(handleStreamingProbe(string(wire))), &report); err != nil {
						t.Fatal(err)
					}
					if !report.OK || report.StatusCode != 204 || report.FirstByteMs == nil ||
						*report.FirstByteMs < originDelay.Milliseconds() || *report.FirstByteMs > report.ElapsedMs {
						t.Fatalf("invalid first byte for sample %d: %+v", i, report)
					}
					p := report.Phases
					if timed {
						fresh := i == 0
						if p["gateway-reused"] != !fresh || (p["gateway-tcp-ms"] != nil) != fresh ||
							(p["gateway-tls-ms"] != nil) != fresh || p["origin-tls-ms"] != nil ||
							p["connect-response-ms"] == nil || p["tunnel-ready-ms"] == nil {
							t.Fatalf("unexpected phases for sample %d: %+v", i, p)
						}
						if ms, ok := p["response-wait-ms"].(float64); !ok || ms < float64(originDelay.Milliseconds()-1) {
							t.Fatalf("missing origin response wait: %+v", p)
						}
					} else if p != nil {
						t.Fatal("timings present without opt-in")
					}
					select {
					case addr := <-requests:
						if i > 0 && addr != peer {
							t.Fatal("streaming probes needed a second gateway socket")
						}
						peer = addr
					default:
						t.Fatal("origin did not receive streaming probe")
					}
				}
			}
			for i := 0; i < 2; i++ {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				_, err := node.URLTest(ctx, "http://probe.example/ping", nil)
				cancel()
				if err != nil {
					t.Fatal(err)
				}
				select {
				case addr := <-requests:
					if i > 0 && addr != peer {
						t.Fatal("successive probes opened a second gateway connection")
					}
					peer = addr
				default:
					t.Fatal("probe did not reach test gateway")
				}
			}

		})
	}
}
