package h2client

import (
	"context"
	"crypto/x509"
	"errors"
	"github.com/metacubex/mihomo/component/fastcatentry"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestRetirePreservesActiveStreamAndLimitsReplacement(t *testing.T) {
	c := testClient(t, true, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		if r.Method == "HEAD" {
			return
		}
		io.Copy(w, r.Body)
	})
	old, err := c.Dial(context.Background(), "target.test:443")
	if err != nil {
		t.Fatal(err)
	}
	defer old.Close()
	g := c.generation
	now := time.Now()
	if !c.retire(g, now) {
		t.Fatal("not replaced")
	}
	if c.retire(c.generation, now.Add(time.Second)) {
		t.Fatal("replacement storm")
	}
	old.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err = old.Write([]byte("alive")); err != nil {
		t.Fatal(err)
	}
	old.(interface{ CloseWrite() error }).CloseWrite()
	got, err := io.ReadAll(old)
	if err != nil || string(got) != "alive" {
		t.Fatal(string(got), err)
	}
	next, err := c.Dial(context.Background(), "target.test:443")
	if err != nil {
		t.Fatal(err)
	}
	next.Close()
	if c.retire(g, now.Add(time.Minute)) {
		t.Fatal("old observer replaced new generation")
	}
}
func TestSlowTargetDoesNotRetireHealthyGateway(t *testing.T) {
	c := testClient(t, true, func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "CONNECT" {
			select {
			case <-time.After(1300 * time.Millisecond):
			case <-r.Context().Done():
				return
			}
		}
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
	})
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	if err := c.Warm(ctx); err != nil {
		t.Fatal(err)
	}
	g := c.generation
	conn, err := c.Dial(ctx, "slow.test:443")
	if err != nil {
		t.Fatal(err)
	}
	conn.Close()
	if c.generation != g {
		t.Fatal("target latency evicted a healthy entry")
	}
}

type lossyTCP struct {
	net.Conn
	drop *atomic.Bool
}

func (c *lossyTCP) Read(p []byte) (int, error) {
	for {
		n, e := c.Conn.Read(p)
		if e != nil || !c.drop.Load() {
			return n, e
		}
	}
}
func (c *lossyTCP) Write(p []byte) (int, error) {
	if c.drop.Load() {
		return len(p), nil
	}
	return c.Conn.Write(p)
}
func TestBlackholedH2EntryReplacedForNewBusiness(t *testing.T) {
	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		if r.Method == "CONNECT" {
			<-r.Context().Done()
		}
	}))
	server.EnableHTTP2 = true
	server.StartTLS()
	defer server.Close()
	roots := x509.NewCertPool()
	roots.AddCert(server.Certificate())
	var drop atomic.Bool
	var dials atomic.Int32
	c, err := New(Config{Endpoint: server.Listener.Addr().String(), RootCAs: roots, Token: strings.Repeat("a", 24), DialContext: func(ctx context.Context, n, a string) (net.Conn, error) {
		conn, e := (&net.Dialer{}).DialContext(ctx, n, a)
		if e == nil && dials.Add(1) == 1 {
			return &lossyTCP{conn, &drop}, nil
		}
		return conn, e
	}})
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	prime, err := c.Dial(context.Background(), "target.test:443")
	if err != nil {
		t.Fatal(err)
	}
	prime.Close()
	g := c.generation
	drop.Store(true)
	if _, err = c.Dial(context.Background(), "target.test:443"); !errors.Is(err, fastcatentry.ErrUnresponsive) {
		t.Fatal("not classified as entry loss", err)
	}
	if c.generation == g {
		t.Fatal("kept dead entry")
	}
	next, err := c.Dial(context.Background(), "target.test:443")
	if err != nil {
		t.Fatal("fresh business failed", err)
	}
	next.Close()
}

func TestPrewarmedH2IdleConnectionReclaimed(t *testing.T) {
	closed := make(chan struct{}, 1)
	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200) }))
	server.EnableHTTP2 = true
	server.Config.ConnState = func(_ net.Conn, state http.ConnState) {
		if state == http.StateClosed {
			select {
			case closed <- struct{}{}:
			default:
			}
		}
	}
	server.StartTLS()
	defer server.Close()
	roots := x509.NewCertPool()
	roots.AddCert(server.Certificate())
	c, err := New(Config{Endpoint: server.Listener.Addr().String(), RootCAs: roots, Token: strings.Repeat("a", 24)})
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err = c.Warm(ctx); err != nil {
		t.Fatal(err)
	}
	select {
	case <-closed:
	case <-time.After(35 * time.Second):
		t.Fatal("idle prewarm socket was retained")
	}
}
