// Package verify exercises the real HTTP/2 client and server over local TLS and TCP.
package verify

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/transport/fastcath2"
	"fastcat.local/https-h2/internal/h2server"
)

const (
	testToken = "local-integration-test-token-only"
	timeout   = 8 * time.Second
)

type gateway struct {
	accepted atomic.Int32
	requests atomic.Int32
	active   atomic.Int32
	server   *httptest.Server
	roots    *x509.CertPool
}

func startGateway(t *testing.T, limit int, allowPrivate bool) *gateway {
	t.Helper()
	handler, err := h2server.New(h2server.Config{Token: testToken, MaxTunnels: limit, AllowPrivateTargets: allowPrivate})
	if err != nil {
		t.Fatal(err)
	}
	g := &gateway{roots: x509.NewCertPool()}
	g.server = httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor != 2 || r.TLS == nil || r.TLS.Version != tls.VersionTLS13 ||
			r.TLS.NegotiatedProtocol != "h2" || r.Method != http.MethodConnect {
			t.Errorf("unexpected transport for %s %s", r.Method, r.Proto)
		}
		g.requests.Add(1)
		g.active.Add(1)
		defer g.active.Add(-1)
		handler.ServeHTTP(w, r)
	}))
	g.server.EnableHTTP2 = true
	g.server.Config.ConnState = func(_ net.Conn, state http.ConnState) {
		if state == http.StateNew {
			g.accepted.Add(1)
		}
	}
	g.server.StartTLS()
	t.Cleanup(g.server.Close)
	g.roots.AddCert(g.server.Certificate())
	return g
}

func (g *gateway) client(t *testing.T, token string, roots *x509.CertPool, serverName string) *h2client.Client {
	t.Helper()
	client, err := h2client.New(h2client.Config{
		Endpoint: g.server.Listener.Addr().String(), ServerName: serverName, Token: token, RootCAs: roots,
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func dial(client *h2client.Client, addr string) (net.Conn, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	return client.Dial(ctx, addr)
}

func tunnel(t *testing.T, client *h2client.Client, addr string) net.Conn {
	t.Helper()
	conn, err := dial(client, addr)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close() })
	if err := conn.SetDeadline(time.Now().Add(timeout)); err != nil {
		t.Fatal(err)
	}
	return conn
}

// target gives each test a real, isolated TCP origin. Closing its listener first
// ensures no more workers can be added before the cleanup waits on workers.
func target(t *testing.T, serve func(net.Conn)) string {
	t.Helper()
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	var workers sync.WaitGroup
	stopped := make(chan struct{})
	go func() {
		defer close(stopped)
		for {
			conn, err := l.Accept()
			if err != nil {
				return
			}
			workers.Add(1)
			go func() {
				defer workers.Done()
				defer conn.Close()
				conn.SetDeadline(time.Now().Add(2 * timeout))
				serve(conn)
			}()
		}
	}()
	t.Cleanup(func() {
		l.Close()
		<-stopped
		workers.Wait()
	})
	return l.Addr().String()
}

func echoTarget(t *testing.T) string {
	return target(t, func(conn net.Conn) { io.Copy(conn, conn) })
}

func exchange(conn net.Conn, data []byte) error {
	if _, err := conn.Write(data); err != nil {
		return err
	}
	reply := make([]byte, len(data))
	if _, err := io.ReadFull(conn, reply); err != nil {
		return err
	}
	if !bytes.Equal(reply, data) {
		return fmt.Errorf("corrupted response (%d bytes)", len(reply))
	}
	return nil
}

func waitActive(t *testing.T, g *gateway, want int32) {
	t.Helper()
	until := time.Now().Add(timeout)
	for g.active.Load() != want {
		if time.Now().After(until) {
			t.Fatalf("active streams = %d, want %d", g.active.Load(), want)
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func TestMultiplexAndStreamIsolation(t *testing.T) {
	const count = 8
	var visits [2]atomic.Int32
	var origins [2]string
	for i := range origins {
		origins[i] = target(t, func(conn net.Conn) {
			visits[i].Add(1)
			io.Copy(conn, conn)
		})
	}
	g := startGateway(t, count, true)
	client := g.client(t, testToken, g.roots, "example.com")
	streams := []net.Conn{tunnel(t, client, origins[0])}

	// Keep the first stream open during the concurrent dials and all payloads.
	type result struct {
		conn net.Conn
		err  error
	}
	opened := make(chan result, count-1)
	for i := 1; i < count; i++ {
		go func() {
			conn, err := dial(client, origins[i%2])
			opened <- result{conn, err}
		}()
	}
	for i := 1; i < count; i++ {
		r := <-opened
		if r.err != nil {
			t.Fatal(r.err)
		}
		t.Cleanup(func() { r.conn.Close() })
		if err := r.conn.SetDeadline(time.Now().Add(timeout)); err != nil {
			t.Fatal(err)
		}
		streams = append(streams, r.conn)
	}
	if g.active.Load() != count || g.accepted.Load() != 1 {
		t.Fatalf("got %d live CONNECTs on %d connections", g.active.Load(), g.accepted.Load())
	}
	errs := make(chan error, count)
	for i, stream := range streams {
		go func() { errs <- exchange(stream, bytes.Repeat([]byte{byte(i), 42}, 32*1024)) }()
	}
	for range streams {
		if err := <-errs; err != nil {
			t.Fatal(err)
		}
	}
	if visits[0].Load() != count/2 || visits[1].Load() != count/2 {
		t.Fatalf("incorrect routing: origin connections = %d and %d", visits[0].Load(), visits[1].Load())
	}
	streams[0].Close()
	waitActive(t, g, count-1)
	if err := exchange(streams[1], []byte("sibling survives")); err != nil {
		t.Fatal(err)
	}
	if err := exchange(tunnel(t, client, origins[1]), []byte("new stream")); err != nil {
		t.Fatal(err)
	}
	if g.accepted.Load() != 1 {
		t.Fatalf("opened another TLS connection after closing one stream")
	}
	t.Logf("%d concurrent tunnels, %d accepted TLS connection, 64 KiB echoed per tunnel; sibling and replacement stream usable", count, g.accepted.Load())
}

func TestClientHalfCloseAndLateResponse(t *testing.T) {
	data := bytes.Repeat([]byte("upload-"), 32*1024)
	addr := target(t, func(conn net.Conn) {
		body, err := io.ReadAll(conn)
		if err == nil {
			conn.Write(append([]byte("confirmed:"), body...))
		}
	})
	g := startGateway(t, 1, true)
	conn := tunnel(t, g.client(t, testToken, g.roots, "example.com"), addr)
	if _, err := conn.Write(data); err != nil {
		t.Fatal(err)
	}
	writer, ok := conn.(interface{ CloseWrite() error })
	if !ok {
		t.Fatal("tunnel does not implement CloseWrite")
	}
	if err := writer.CloseWrite(); err != nil {
		t.Fatal(err)
	}
	reply, err := io.ReadAll(conn)
	if err != nil || !bytes.Equal(reply, append([]byte("confirmed:"), data...)) {
		t.Fatalf("late response = %d bytes, err = %v", len(reply), err)
	}
}

func TestOriginFinEndsOnlyItsStream(t *testing.T) {
	addr := target(t, func(conn net.Conn) {
		conn.Write([]byte("bye"))
		conn.(*net.TCPConn).CloseWrite()
		io.Copy(io.Discard, conn)
	})
	echo := echoTarget(t)
	g := startGateway(t, 2, true)
	client := g.client(t, testToken, g.roots, "example.com")
	stream := tunnel(t, client, addr)
	reply, err := io.ReadAll(stream)
	if err != nil || string(reply) != "bye" {
		t.Fatalf("origin-first close: reply=%q err=%v", reply, err)
	}
	if err := exchange(tunnel(t, client, echo), []byte("alive")); err != nil {
		t.Fatal(err)
	}
	if g.accepted.Load() != 1 {
		t.Fatal("lost shared connection when origin closed")
	}
}

func expectStatus(t *testing.T, client *h2client.Client, target string, code int) {
	t.Helper()
	conn, err := dial(client, target)
	if err == nil {
		conn.Close()
		t.Fatalf("expected CONNECT rejection %d", code)
	}
	if !strings.Contains(err.Error(), strconv.Itoa(code)) {
		t.Fatalf("rejection = %v, want %d", err, code)
	}
}

func TestAuthenticationCertificateAndTargetPolicy(t *testing.T) {
	var touched atomic.Bool
	addr := target(t, func(_ net.Conn) { touched.Store(true) })
	g := startGateway(t, 2, false)
	for _, client := range []*h2client.Client{
		g.client(t, testToken, x509.NewCertPool(), "example.com"),
		g.client(t, testToken, g.roots, "untrusted.invalid"),
	} {
		conn, err := dial(client, addr)
		if err == nil {
			conn.Close()
			t.Fatal("unexpectedly trusted invalid gateway certificate")
		}
	}
	if g.requests.Load() != 0 {
		t.Fatal("authentication reached gateway despite failed TLS verification")
	}
	expectStatus(t, g.client(t, "wrong-local-test-token-long-enough", g.roots, "example.com"), addr, 407)
	expectStatus(t, g.client(t, testToken, g.roots, "example.com"), addr, 403)
	if touched.Load() {
		t.Fatal("policy rejection contacted private origin")
	}
}

func TestQuotaRecoversAfterClosingStream(t *testing.T) {
	addr := echoTarget(t)
	g := startGateway(t, 1, true)
	client := g.client(t, testToken, g.roots, "example.com")
	first := tunnel(t, client, addr)
	expectStatus(t, client, addr, 503)
	if err := exchange(first, []byte("still active")); err != nil {
		t.Fatal(err)
	}
	first.Close()
	waitActive(t, g, 0)
	if err := exchange(tunnel(t, client, addr), []byte("slot recovered")); err != nil {
		t.Fatal(err)
	}
}

func TestStalledReaderAndDeadlineDoNotBlockSibling(t *testing.T) {
	started := make(chan struct{})
	finished := make(chan struct{})
	sender := target(t, func(conn net.Conn) {
		defer close(finished)
		chunk := make([]byte, 32<<10)
		if _, err := conn.Write(chunk); err != nil {
			return
		}
		close(started)
		for {
			if _, err := conn.Write(chunk); err != nil {
				return
			}
		}
	})
	echo := echoTarget(t)
	g := startGateway(t, 2, true)
	client := g.client(t, testToken, g.roots, "example.com")
	stalled := tunnel(t, client, sender)
	select {
	case <-started:
	case <-time.After(timeout):
		t.Fatal("slow download did not start")
	}
	sibling := tunnel(t, client, echo)
	if err := sibling.SetReadDeadline(time.Now().Add(25 * time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	var one [1]byte
	_, err := sibling.Read(one[:])
	var timeoutErr net.Error
	if !errors.As(err, &timeoutErr) || !timeoutErr.Timeout() {
		t.Fatalf("expected stream read timeout, got %v", err)
	}
	if err := sibling.SetReadDeadline(time.Now().Add(timeout)); err != nil {
		t.Fatal(err)
	}
	if err := exchange(sibling, []byte("sibling is responsive")); err != nil {
		t.Fatal(err)
	}
	stalled.Close()
	select {
	case <-finished:
	case <-time.After(timeout):
		t.Fatal("target remained open after stream cancellation")
	}
	waitActive(t, g, 1)
	if err := exchange(sibling, []byte("unaffected by reset")); err != nil {
		t.Fatal(err)
	}
	if g.accepted.Load() != 1 {
		t.Fatal("slow download forced another TLS connection")
	}
}

func TestLostConnectionReopensOnlyForNewStream(t *testing.T) {
	var visits atomic.Int32
	received := make(chan string, 4)
	addr := target(t, func(conn net.Conn) {
		visits.Add(1)
		var body bytes.Buffer
		io.Copy(io.MultiWriter(&body, conn), conn)
		received <- body.String()
	})
	g := startGateway(t, 2, true)
	client := g.client(t, testToken, g.roots, "example.com")
	first := tunnel(t, client, addr)
	if err := exchange(first, []byte("first upload")); err != nil {
		t.Fatal(err)
	}
	g.server.CloseClientConnections()
	var one [1]byte
	if n, err := first.Read(one[:]); n != 0 || err == nil {
		t.Fatalf("old stream remained readable: read %d bytes, err=%v", n, err)
	}
	// The caller explicitly starts new work after detecting the disconnect.
	second := tunnel(t, client, addr)
	if err := exchange(second, []byte("second upload")); err != nil {
		t.Fatal(err)
	}
	second.Close()
	payloads := make(map[string]int)
	for i := 0; i < 2; i++ {
		select {
		case data := <-received:
			payloads[data]++
		case <-time.After(timeout):
			t.Fatal("target did not finish both independent requests")
		}
	}
	if visits.Load() != 2 || g.accepted.Load() != 2 || payloads["first upload"] != 1 || payloads["second upload"] != 1 {
		t.Fatalf("reconnect or replay mismatch: %d target connections, %d gateway connections, %v", visits.Load(), g.accepted.Load(), payloads)
	}
}
