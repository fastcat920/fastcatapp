package main

import (
	"context"
	"crypto/x509"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
)

type testFlush struct{ http.ResponseWriter }

func (w testFlush) Write(p []byte) (int, error) {
	n, e := w.ResponseWriter.Write(p)
	w.ResponseWriter.(http.Flusher).Flush()
	return n, e
}
func TestVerifiedDownloadThroughH2(t *testing.T) {
	for _, corrupt := range []bool{false, true} {
		t.Run(map[bool]string{false: "valid", true: "corrupt"}[corrupt], func(t *testing.T) {
			data := make([]byte, 1<<20)
			for i := range data {
				data[i] = byte(i % 4)
			}
			if corrupt {
				data[len(data)-1] ^= 1
			}
			web := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Length", "1048576")
				w.Write(data)
			}))
			defer web.Close()
			proxy := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				c, e := net.Dial("tcp", r.Host)
				if e != nil {
					w.WriteHeader(502)
					return
				}
				defer c.Close()
				w.WriteHeader(200)
				w.(http.Flusher).Flush()
				done := make(chan struct{})
				go func() { io.Copy(c, r.Body); close(done) }()
				io.Copy(testFlush{w}, c)
				r.Body.Close()
				c.Close()
				<-done
			}))
			proxy.EnableHTTP2 = true
			proxy.StartTLS()
			defer proxy.Close()
			roots := x509.NewCertPool()
			roots.AddCert(web.Certificate())
			roots.AddCert(proxy.Certificate())
			cfg := configuration{V2Address: proxy.Listener.Addr().String(), V2Token: "local-only-token-long-enough"}
			row := downloadOne(context.Background(), cfg, roots, "v2", "h2", web.Listener.Addr().String(), len(data))
			if row["complete"] == corrupt {
				t.Fatal(row)
			}
		})
	}
}

func TestBorrowedDownloadClientRemainsOpen(t *testing.T) {
	data := make([]byte, 1<<20)
	for i := range data {
		data[i] = byte(i % 4)
	}
	web := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", "1048576")
		w.Write(data)
	}))
	defer web.Close()
	roots := x509.NewCertPool()
	roots.AddCert(web.Certificate())
	var closes atomic.Int64
	c := client{dial: func(ctx context.Context, target string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, "tcp", target)
	}, close: func() { closes.Add(1) }}
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r := downloadUsing(context.Background(), configuration{}, roots, "test", "quic", web.Listener.Addr().String(), len(data), &c)
			if r["complete"] != true || r["checksum_ok"] != true {
				t.Error(r)
			}
		}()
	}
	wg.Wait()
	if closes.Load() != 0 {
		t.Fatal("borrowed client was closed")
	}
	c.close()
	if closes.Load() != 1 {
		t.Fatal("owner close not recorded")
	}
}
