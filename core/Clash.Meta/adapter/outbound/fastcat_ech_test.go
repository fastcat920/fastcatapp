//go:build go1.24

package outbound

import (
	"bufio"

	"context"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"

	"encoding/pem"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	h3http "github.com/metacubex/http"
	"github.com/metacubex/mihomo/component/ech"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
	D "github.com/miekg/dns"
)

func TestFastCatEntryDoHECH(t *testing.T) {
	const inner = "example.com"
	const token = "local-validated-example-device-token"
	list, keyPEM, err := ech.GenECHConfig("public.example")
	if err != nil {
		t.Fatal(err)
	}
	keyBlock, _ := pem.Decode([]byte(keyPEM))
	keys, err := ech.UnmarshalECHKeys(keyBlock.Bytes)
	if err != nil {
		t.Fatal(err)
	}
	config, err := base64.StdEncoding.DecodeString(list)
	if err != nil {
		t.Fatal(err)
	}

	var noConfig, wrongConfig, dropResponse atomic.Bool
	dropResponse.Store(true)
	var lookups atomic.Int32
	httpsStarted, addressStarted := make(chan struct{}), make(chan struct{})
	var markHTTPS, markAddress sync.Once
	waitFor := func(ctx context.Context, ready <-chan struct{}) bool {
		timer := time.NewTimer(2 * time.Second)
		defer timer.Stop()
		select {
		case <-ready:
			return true
		case <-ctx.Done():
			return false
		case <-timer.C:
			return false
		}
	}

	doh := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, err := base64.RawURLEncoding.DecodeString(r.URL.Query().Get("dns"))
		var query D.Msg
		if err != nil || query.Unpack(raw) != nil || len(query.Question) != 1 {
			w.WriteHeader(400)
			return
		}
		message := new(D.Msg).SetReply(&query)
		q := query.Question[0]
		header := D.RR_Header{Name: q.Name, Rrtype: q.Qtype, Class: D.ClassINET, Ttl: 60}
		switch q.Qtype {
		case D.TypeHTTPS:
			markHTTPS.Do(func() { close(httpsStarted) })
			if !waitFor(r.Context(), addressStarted) {
				w.WriteHeader(http.StatusGatewayTimeout)
				return
			}
			lookups.Add(1)
			if dropResponse.Swap(false) {
				panic(http.ErrAbortHandler)
			}
			if !noConfig.Load() {
				value := append([]byte(nil), config...)
				if wrongConfig.Load() {
					value[6] ^= 1
				}
				message.Answer = []D.RR{&D.HTTPS{SVCB: D.SVCB{
					Hdr: header, Priority: 1, Target: ".", Value: []D.SVCBKeyValue{&D.SVCBECHConfig{ECH: value}},
				}}}
			}
		case D.TypeA:
			markAddress.Do(func() { close(addressStarted) })
			if !waitFor(r.Context(), httpsStarted) {
				w.WriteHeader(http.StatusGatewayTimeout)
				return
			}
			message.Answer = []D.RR{&D.A{Hdr: header, A: net.IPv4(127, 0, 0, 1)}}
		}
		wire, err := message.Pack()
		if err != nil {
			w.WriteHeader(500)
			return
		}
		w.Header().Set("Content-Type", "application/dns-message")
		w.Write(wire)
	}))
	defer doh.Close()
	cert := doh.TLS.Certificates[0]
	ca := filepath.Join(t.TempDir(), "ca.pem")
	if err := os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: cert.Certificate[0]}), 0600); err != nil {
		t.Fatal(err)
	}

	var h2Connects, h3Connects atomic.Int32
	h2 := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h2Connects.Add(1)
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		var b [1]byte
		if _, err := io.ReadFull(r.Body, b[:]); err == nil {
			w.Write(b[:])
			w.(http.Flusher).Flush()
		}
	}))
	h2.EnableHTTP2 = true
	h2.TLS = &tls.Config{Certificates: []tls.Certificate{cert}, EncryptedClientHelloKeys: []tls.EncryptedClientHelloKey{{Config: keys[0].Config, PrivateKey: keys[0].PrivateKey}}}
	h2.StartTLS()
	defer h2.Close()
	socket, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer socket.Close()
	h3 := &http3.Server{
		TLSConfig: &qtls.Config{
			Certificates:             []qtls.Certificate{{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}},
			EncryptedClientHelloKeys: keys, NextProtos: []string{"h3"},
		},
		EnableDatagrams: true,
		Handler: h3http.HandlerFunc(func(w h3http.ResponseWriter, r *h3http.Request) {
			h3Connects.Add(1)
			w.WriteHeader(200)
			stream := w.(http3.HTTPStreamer).HTTPStream()
			defer stream.Close()
			var b [1]byte
			if _, err := io.ReadFull(stream, b[:]); err == nil {
				stream.Write(b[:])
			}
		}),
	}
	go h3.Serve(socket)
	defer h3.Close()

	_, dohPort, _ := net.SplitHostPort(doh.Listener.Addr().String())
	option := FastCatHTTPSOption{
		Name: "ECH test", Server: "entry.example", SNI: inner, Port: h2.Listener.Addr().(*net.TCPAddr).Port,
		Token: token, CAFile: ca, EntryDoH: "https://" + net.JoinHostPort("127.0.0.1", dohPort) + "/dns-query",
		EntryDoHIP: "127.0.0.1", BasicOption: BasicOption{DialerForAPI: new(v2TestSockets)},
	}
	for _, mode := range []string{"h2", "h3"} {
		t.Run(mode, func(t *testing.T) {
			open := func() ProxyAdapter {
				t.Helper()
				if mode == "h2" {
					a, err := NewFastCatH2(option)
					if err != nil {
						t.Fatal(err)
					}
					return a
				}
				a, err := NewFastCatAuto(FastCatAutoOption{
					FastCatHTTPSOption: option, V2Transport: "h3", H3Port: socket.LocalAddr().(*net.UDPAddr).Port, H3Token: token,
				})
				if err != nil {
					t.Fatal(err)
				}
				return a
			}
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			target := &C.Metadata{Host: "target.example", DstPort: 443}
			testDial := func(want bool) {
				t.Helper()
				a := open()
				defer a.Close()
				conn, err := a.DialContext(ctx, target)
				if !want {
					if err == nil {
						conn.Close()
						t.Fatal("entry unexpectedly accepted the tunnel")
					}
					return
				}
				if err != nil {
					t.Fatal(err)
				}
				defer conn.Close()
				conn.SetDeadline(time.Now().Add(2 * time.Second))
				if _, err := conn.Write([]byte{42}); err != nil {
					t.Fatal(err)
				}
				var b [1]byte
				if _, err := io.ReadFull(conn, b[:]); err != nil || b[0] != 42 {
					t.Fatal(b, err)
				}
			}
			testDial(true)
			before := h2Connects.Load() + h3Connects.Load()
			noConfig.Store(true)
			testDial(false)
			noConfig.Store(false)
			wrongConfig.Store(true)
			testDial(false)
			wrongConfig.Store(false)
			if h2Connects.Load()+h3Connects.Load() != before {
				t.Fatal("failed ECH exposed a tunnel request")
			}
		})
	}
	if n := lookups.Load(); n != 7 {
		t.Fatalf("unexpected HTTPS record query count: %d", n)
	}
}

// TestFastCatEntryECHPublic runs against an explicitly supplied test node.
// The descriptor is kept in a private file so credentials never enter output.
func TestFastCatEntryECHPublic(t *testing.T) {
	path := os.Getenv("FASTCAT_ECH_TEST_NODE")
	if path == "" {
		t.Skip("no public test node configured")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var node struct {
		Server, DoH, Bootstrap, H2Token, H3Token string
		Port                                     int
	}
	if err := json.Unmarshal(b, &node); err != nil {
		t.Fatal("invalid public test node descriptor")
	}
	opts := FastCatHTTPSOption{
		Name: "public ECH test", Server: node.Server, Port: node.Port, Token: node.H2Token,
		EntryDoH: node.DoH, EntryDoHIP: node.Bootstrap,
	}
	target := &C.Metadata{Host: "example.com", DstPort: 443}
	for _, protocol := range []string{"h2", "h3"} {
		t.Run(protocol, func(t *testing.T) {
			for i := 0; i < 3; i++ {
				func() {
					t.Helper()
					var a ProxyAdapter
					if protocol == "h2" {
						a, err = NewFastCatH2(opts)
					} else {
						a, err = NewFastCatAuto(FastCatAutoOption{
							FastCatHTTPSOption: opts, V2Transport: "h3", H3Port: node.Port, H3Token: node.H3Token,
						})
					}
					if err != nil {
						t.Fatal(err)
					}
					defer a.Close()
					ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
					defer cancel()
					c, err := a.DialContext(ctx, target)
					if err != nil {
						t.Fatal(err)
					}
					defer c.Close()
					c.SetDeadline(time.Now().Add(6 * time.Second))
					tlsTarget := tls.Client(c, &tls.Config{ServerName: target.Host})
					if err := tlsTarget.HandshakeContext(ctx); err != nil {
						t.Fatal(err)
					}
					if _, err := io.WriteString(tlsTarget, "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n"); err != nil {
						t.Fatal(err)
					}
					response, err := http.ReadResponse(bufio.NewReader(tlsTarget), nil)
					if err != nil {
						t.Fatal(err)
					}
					response.Body.Close()
					if response.StatusCode != http.StatusOK {
						t.Fatalf("unexpected target HTTP status: %d", response.StatusCode)
					}
					t.Logf("cold dial %d: HTTP 200 through verified ECH", i+1)
				}()
			}
		})
	}
}
