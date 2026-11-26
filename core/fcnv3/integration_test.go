package fcnv3

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net"
	"net/url"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	http "github.com/metacubex/http"
	"github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	"github.com/metacubex/tls"
)

const (
	testAccount = "integration"
	testSecret  = "0101010101010101010101010101010101010101010101010101010101010101"
	wrongSecret = "0202020202020202020202020202020202020202020202020202020202020202"
	testTrailer = "upstream received EOF"
)

func TestHTTP3Connect(t *testing.T) {
	target, accepted := startTestEcho(t)
	blockedTarget, blockedAccepted := startTestEcho(t)
	server, config := startTestServer(t, target)
	client := newTestClient(t, config)
	ctx, cancel := context.WithTimeout(t.Context(), 15*time.Second)
	defer cancel()
	pooled, err := client.acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}

	t.Run("public GET on the pooled HTTP3 connection", func(t *testing.T) {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://"+config.Endpoint+"/", nil)
		if err != nil {
			t.Fatal(err)
		}
		res, err := pooled.http.RoundTrip(req)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		body, err := io.ReadAll(res.Body)
		if err != nil {
			t.Fatal(err)
		}
		if res.StatusCode != http.StatusOK || res.ProtoMajor != 3 || !bytes.Contains(body, []byte("<h1>FastCat</h1>")) {
			t.Fatalf("GET / = %s %d %q", res.Proto, res.StatusCode, body)
		}
	})

	t.Run("missing wrong and unknown credentials and forbidden target", func(t *testing.T) {
		for _, tt := range []struct {
			name   string
			target string
			id     string
			secret string
		}{
			{"missing", target, "", ""},
			{"wrong secret", target, testAccount, wrongSecret},
			{"unknown account", target, "unknown", testSecret},
			{"forbidden target", blockedTarget, testAccount, testSecret},
		} {
			t.Run(tt.name, func(t *testing.T) {
				before := accepted.Load()
				status := connectStatus(t, ctx, pooled, tt.target, tt.id, tt.secret)
				if status != http.StatusForbidden {
					t.Fatalf("CONNECT response = %d, want 403", status)
				}
				if accepted.Load() != before || blockedAccepted.Load() != 0 {
					t.Fatal("unauthorized request reached an upstream TCP listener")
				}
			})
		}

		badConfig := config
		badConfig.Secret = wrongSecret
		badClient := newTestClient(t, badConfig)
		conn := dialTestStream(t, ctx, badClient, target)
		if n, err := conn.Read(make([]byte, 1)); n != 0 || !errors.Is(err, ErrRejected) {
			t.Fatalf("rejected stream read = (%d, %v), want ErrRejected", n, err)
		}
	})

	t.Run("four concurrent echo streams and half-close", func(t *testing.T) {
		const streamCount = 4
		connections := make([]*streamConn, streamCount)
		ids := make(map[quic.StreamID]bool, streamCount)
		for i := range connections {
			conn := dialTestStream(t, ctx, client, target)
			id := conn.stream.StreamID()
			if ids[id] || conn.LocalAddr().String() != pooled.quic.LocalAddr().String() {
				t.Fatalf("stream %d has duplicate ID or a different QUIC socket", id)
			}
			connections[i], ids[id] = conn, true
		}
		for i, conn := range connections {
			t.Run(fmt.Sprintf("stream %d", i), func(t *testing.T) {
				t.Parallel()
				checkEchoAndHalfClose(t, conn, bytes.Repeat([]byte{byte(i + 1)}, 64*1024))
			})
		}
	})

	t.Run("sustained requests on the same connection", func(t *testing.T) {
		for i := range 48 {
			conn := dialTestStream(t, ctx, client, target)
			checkEchoAndHalfClose(t, conn, bytes.Repeat([]byte{byte(i)}, 4096))
			conn.Close()
		}
		current, err := client.acquire(ctx)
		if err != nil || current != pooled {
			t.Fatalf("pooled connection changed after sustained traffic: %v", err)
		}
	})

	t.Run("credential revocation terminates active stream and rejects new streams", func(t *testing.T) {
		conn := dialTestStream(t, ctx, client, target)
		checkEcho(t, conn, []byte("before revocation"))
		if err := server.ReplaceCredentials(nil); err != nil {
			t.Fatal(err)
		}
		_, err := conn.Read(make([]byte, 1))
		if !errors.Is(err, &http3.Error{Remote: true, ErrorCode: http3.ErrCodeRequestCanceled}) {
			t.Fatalf("active stream read after revocation = %v, want remote HTTP/3 stream cancellation", err)
		}
		conn = dialTestStream(t, ctx, client, target)
		if _, err := conn.Read(make([]byte, 1)); !errors.Is(err, ErrRejected) {
			t.Fatalf("new stream after revocation = %v, want ErrRejected", err)
		}
		current, err := client.acquire(ctx)
		if err != nil || current != pooled {
			t.Fatalf("revocation changed the underlying HTTP/3 connection: %v", err)
		}
	})
	if got := accepted.Load(); got != 53 || blockedAccepted.Load() != 0 {
		t.Fatalf("upstream accept counts = (%d allowed, %d forbidden), want (53, 0)", got, blockedAccepted.Load())
	}
}

type blockedTCPUpstream struct {
	net.Conn
	writeStarted chan struct{}
	closed       chan struct{}
	writeOnce    sync.Once
	closeOnce    sync.Once
}

func (c *blockedTCPUpstream) Write(payload []byte) (int, error) {
	c.writeOnce.Do(func() { close(c.writeStarted) })
	return c.Conn.Write(payload)
}

func (c *blockedTCPUpstream) CloseWrite() error { return nil }

func (c *blockedTCPUpstream) Close() error {
	err := c.Conn.Close()
	c.closeOnce.Do(func() { close(c.closed) })
	return err
}

func TestTCPFullCancellationReleasesBlockedStream(t *testing.T) {
	echo, _ := startTestEcho(t)
	upstream, silentPeer := net.Pipe()
	defer silentPeer.Close()
	defer upstream.Close()
	blocked := &blockedTCPUpstream{
		Conn: upstream, writeStarted: make(chan struct{}), closed: make(chan struct{}),
	}
	rejections := make(chan [2]string, 4)
	server, config := startTestServer(t, echo, func(cfg *ServerConfig) {
		cfg.Targets = nil
		cfg.Dispatch = func(setup, _ context.Context, request DispatchRequest) (net.Conn, error) {
			switch request.Target {
			case "hold.example:443":
				return blocked, nil
			case "echo.example:443":
				return (&net.Dialer{}).DialContext(setup, "tcp", echo)
			default:
				return nil, errors.New("unknown local test target")
			}
		}
		cfg.OnConnectRejected = func(network, reason string) { rejections <- [2]string{network, reason} }
	})
	config.AllowDomainTargets = true
	client := newTestClient(t, config)
	ctx, cancel := context.WithTimeout(t.Context(), 10*time.Second)
	defer cancel()

	held := dialTestStream(t, ctx, client, "hold.example:443")
	if _, err := held.Write([]byte("blocked upload")); err != nil {
		t.Fatal(err)
	}
	select {
	case <-blocked.writeStarted:
	case <-ctx.Done():
		t.Fatal("server never began the blocked upstream write")
	}

	existing := make([]*streamConn, 15)
	for i := range existing {
		existing[i] = dialTestStream(t, ctx, client, "echo.example:443")
		checkEcho(t, existing[i], []byte("established stream"))
	}
	pooled, err := client.acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	for range 2 {
		if status := connectStatus(t, ctx, pooled, "echo.example:443", testAccount, testSecret); status != http.StatusForbidden {
			t.Fatalf("CONNECT at the stream limit = %d, want %d", status, http.StatusForbidden)
		}
	}
	select {
	case got := <-rejections:
		if want := [2]string{"tcp", "connection_stream_limit"}; got != want {
			t.Fatalf("CONNECT diagnostic = %v, want %v", got, want)
		}
	default:
		t.Fatal("CONNECT rejection did not report its reason")
	}
	select {
	case got := <-rejections:
		t.Fatalf("same rejection was reported twice: %v", got)
	default:
	}

	if err := held.Close(); err != nil {
		t.Fatal(err)
	}
	select {
	case <-blocked.closed:
	case <-time.After(time.Second):
		t.Fatal("full stream cancellation left the upstream blocked")
	}
	waitForUDPLeases(t, server, len(existing))
	replacement := dialTestStream(t, ctx, client, "echo.example:443")
	if replacement.LocalAddr().String() != pooled.quic.LocalAddr().String() {
		t.Fatal("opening a replacement stream changed the QUIC connection")
	}
	checkEcho(t, replacement, []byte("reused stream slot"))
	checkEcho(t, existing[0], []byte("existing stream still transfers"))
}

func TestProofBindsConnectionStreamAndTarget(t *testing.T) {
	key, err := credentialKey(testAccount, testSecret)
	if err != nil {
		t.Fatal(err)
	}
	keys := map[string][32]byte{testAccount: key}
	binding := bytes.Repeat([]byte{1}, 32)
	const target = "127.0.0.1:6443"
	const streamID = quic.StreamID(4)
	value := authValue(key, binding, testAccount, target, streamID)
	if account, gotKey, valid := verifyValue(value, binding, target, streamID, keys); !valid || account != testAccount || gotKey != key {
		t.Fatal("verification rejected the original proof")
	}
	for _, tt := range []struct {
		name    string
		binding []byte
		target  string
		stream  quic.StreamID
	}{
		{"another connection exporter", bytes.Repeat([]byte{2}, 32), target, streamID},
		{"another stream", binding, target, streamID + 4},
		{"another target", binding, "127.0.0.1:6444", streamID},
	} {
		t.Run(tt.name, func(t *testing.T) {
			if _, _, valid := verifyValue(value, tt.binding, tt.target, tt.stream, keys); valid {
				t.Fatal("verification accepted the original proof outside its binding")
			}
		})
	}
}

func connectStatus(t *testing.T, ctx context.Context, s *session, target, account, secret string) int {
	t.Helper()
	stream, err := s.http.OpenRequestStream(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer stream.CancelRead(cancelCode)
	defer stream.CancelWrite(cancelCode)
	stream.SetDeadline(time.Now().Add(5 * time.Second))
	req := &http.Request{Method: http.MethodConnect, Host: target, URL: &url.URL{Host: target}, Header: make(http.Header)}
	if account != "" {
		key, err := credentialKey(account, secret)
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set(authHeader, authValue(key, s.binding, account, target, stream.StreamID()))
	}
	if err := stream.SendRequestHeader(req); err != nil {
		t.Fatal(err)
	}
	if err := stream.Close(); err != nil {
		t.Fatal(err)
	}
	res, err := stream.ReadResponse()
	if err != nil {
		t.Fatal(err)
	}
	return res.StatusCode
}

func dialTestStream(t *testing.T, ctx context.Context, client *Client, target string) *streamConn {
	t.Helper()
	conn, err := client.Dial(ctx, target)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close() })
	if err := conn.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatal(err)
	}
	return conn.(*streamConn)
}

func checkEcho(t *testing.T, conn *streamConn, payload []byte) {
	t.Helper()
	if n, err := conn.Write(payload); n != len(payload) || err != nil {
		t.Fatalf("write = (%d, %v), want %d bytes", n, err, len(payload))
	}
	echo := make([]byte, len(payload))
	if _, err := io.ReadFull(conn, echo); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(payload, echo) {
		t.Fatal("echo did not match sent payload")
	}
}

func checkEchoAndHalfClose(t *testing.T, conn *streamConn, payload []byte) {
	t.Helper()
	checkEcho(t, conn, payload)
	if err := conn.CloseWrite(); err != nil {
		t.Fatal(err)
	}
	trailer, err := io.ReadAll(io.LimitReader(conn, int64(len(testTrailer)+1)))
	if err != nil || string(trailer) != testTrailer {
		t.Fatalf("response after CloseWrite = (%q, %v), want upstream EOF trailer", trailer, err)
	}
}

func startTestEcho(t *testing.T) (string, *atomic.Int32) {
	t.Helper()
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	accepts := new(atomic.Int32)
	done := make(chan struct{})
	go func() {
		defer close(done)
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			accepts.Add(1)
			go func() {
				defer conn.Close()
				conn.SetDeadline(time.Now().Add(7 * time.Second))
				if _, err := io.Copy(conn, conn); err == nil {
					io.WriteString(conn, testTrailer)
				}
			}()
		}
	}()
	t.Cleanup(func() {
		listener.Close()
		<-done
	})
	return listener.Addr().String(), accepts
}

func startTestServer(t *testing.T, target string, options ...func(*ServerConfig)) (*Server, Config) {
	t.Helper()
	return startTestServerObservingConnection(t, target, nil, options...)
}

func startTestServerObservingConnection(t *testing.T, target string, observe func(*serverConnection), options ...func(*ServerConfig)) (*Server, Config) {
	t.Helper()
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	cert := &x509.Certificate{
		SerialNumber: big.NewInt(1), NotBefore: now.Add(-time.Minute), NotAfter: now.Add(time.Hour),
		DNSNames: []string{"fcn3.test"}, KeyUsage: x509.KeyUsageDigitalSignature,
		ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	der, err := x509.CreateCertificate(rand.Reader, cert, cert, public, private)
	if err != nil {
		t.Fatal(err)
	}
	cert, err = x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	roots := x509.NewCertPool()
	roots.AddCert(cert)
	packet, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { packet.Close() })
	serverConfig := ServerConfig{
		TLSConfig:   &tls.Config{Certificates: []tls.Certificate{{Certificate: [][]byte{der}, PrivateKey: private, Leaf: cert}}},
		Credentials: []Credential{{ID: testAccount, Secret: testSecret}},
		Targets:     []string{target},
	}
	for _, option := range options {
		option(&serverConfig)
	}
	server, err := NewServer(serverConfig)
	if err != nil {
		t.Fatal(err)
	}
	if observe != nil {
		prepare := server.http.ConnContext
		server.http.ConnContext = func(ctx context.Context, q *quic.Conn) context.Context {
			ctx = prepare(ctx, q)
			if conn, ok := ctx.Value(serverConnectionKey{}).(*serverConnection); ok {
				observe(conn)
			}
			return ctx
		}
	}
	done := make(chan error, 1)
	go func() { done <- server.Serve(packet) }()
	t.Cleanup(func() {
		server.Close()
		if err := <-done; err != nil && !errors.Is(err, net.ErrClosed) && !errors.Is(err, context.Canceled) {
			t.Errorf("serve: %v", err)
		}
	})
	return server, Config{Endpoint: packet.LocalAddr().String(), ServerName: "fcn3.test", Account: testAccount, Secret: testSecret, Roots: roots}
}

func newTestClient(t *testing.T, config Config) *Client {
	t.Helper()
	client, err := NewClient(config)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}
