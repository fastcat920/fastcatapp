package h2client

import (
	"context"
	"crypto/x509"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func testClient(t *testing.T, h2 bool, handler http.HandlerFunc) *Client {
	t.Helper()
	server := httptest.NewUnstartedServer(handler)
	server.EnableHTTP2 = h2
	server.StartTLS()
	t.Cleanup(server.Close)
	roots := x509.NewCertPool()
	roots.AddCert(server.Certificate())
	client, err := New(Config{Endpoint: server.Listener.Addr().String(), RootCAs: roots, Token: strings.Repeat("a", 24)})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func TestStreamOutlivesDialContextAndReadDeadline(t *testing.T) {
	client := testClient(t, true, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		b, err := io.ReadAll(r.Body)
		if err == nil {
			w.Write(b)
		}
	})
	ctx, cancel := context.WithCancel(context.Background())
	conn, err := client.Dial(ctx, "target.test:443")
	cancel()
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if err := conn.SetReadDeadline(time.Now().Add(5 * time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	if _, err := conn.Read(make([]byte, 1)); !errors.Is(err, os.ErrDeadlineExceeded) {
		t.Fatalf("read with expired deadline: %v", err)
	}
	if err := conn.SetDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatal(err)
	}
	if _, err := io.WriteString(conn, "late response"); err != nil {
		t.Fatal(err)
	}
	if err := conn.(interface{ CloseWrite() error }).CloseWrite(); err != nil {
		t.Fatal(err)
	}
	payload, err := io.ReadAll(conn)
	if err != nil || string(payload) != "late response" {
		t.Fatalf("response after half-close: %q, %v", payload, err)
	}
}

func TestHTTP1RejectedBeforeRequest(t *testing.T) {
	receivedRequest := make(chan struct{}, 1)
	client := testClient(t, false, func(http.ResponseWriter, *http.Request) {
		receivedRequest <- struct{}{}
	})
	if _, err := client.Dial(context.Background(), "target.test:443"); err == nil {
		t.Fatal("accepted HTTP/1 proxy")
	}
	select {
	case <-receivedRequest:
		t.Fatal("sent a request over HTTP/1")
	default:
	}
}

func TestConcurrentColdDialsShareConnection(t *testing.T) {
	const count = 12
	arrivals := make(chan string, count)
	client := testClient(t, true, func(w http.ResponseWriter, r *http.Request) {
		arrivals <- r.RemoteAddr
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	})
	start := make(chan struct{})
	dials := make(chan error, count)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	for i := 0; i < count; i++ {
		go func() {
			<-start
			// Client.Close releases all successful streams during cleanup.
			_, err := client.Dial(ctx, "target.test:443")
			dials <- err
		}()
	}
	close(start)
	var peer string
	for i := 0; i < count; i++ {
		if err := <-dials; err != nil {
			t.Fatal(err)
		}
		addr := <-arrivals
		if peer != "" && peer != addr {
			t.Fatal("cold start opened multiple connections")
		}
		peer = addr
	}
}

func TestSetupCancellationAndClientClose(t *testing.T) {
	entered := make(chan struct{})
	client := testClient(t, true, func(w http.ResponseWriter, r *http.Request) {
		close(entered)
		<-r.Context().Done()
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	result := make(chan error, 1)
	go func() {
		_, err := client.Dial(ctx, "target.test:443")
		result <- err
	}()
	select {
	case <-entered:
	case <-time.After(2 * time.Second):
		t.Fatal("CONNECT not received")
	}
	cancel()
	if err := <-result; !errors.Is(err, context.Canceled) {
		t.Fatalf("cancelled dial: %v", err)
	}
	client.Close()
	if _, err := client.Dial(context.Background(), "target.test:443"); !errors.Is(err, net.ErrClosed) {
		t.Fatalf("dial after Close: %v", err)
	}
}
