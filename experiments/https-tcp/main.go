package main

import (
	"bufio"
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"crypto/tls"
	"crypto/x509"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"fastcat/https-tcp/entryauth"
)

func relay(a net.Conn, ar io.Reader, b net.Conn) {
	defer a.Close()
	defer b.Close()
	done := make(chan struct{})
	go func() {
		n, e := io.Copy(b, ar)
		log.Printf("stage=upload bytes=%d error=%v", n, e)
		if e != nil {
			a.Close()
			b.Close()
		} else if c, ok := b.(interface{ CloseWrite() error }); ok {
			c.CloseWrite()
		}
		close(done)
	}()
	n, e := io.Copy(a, b)
	log.Printf("stage=download bytes=%d error=%v", n, e)
	// Preserve reverse-direction writes after a clean EOF. Session deadlines
	// bound peers that never complete the other half of the connection.
	if e != nil {
		a.Close()
		b.Close()
	} else if c, ok := a.(interface{ CloseWrite() error }); ok {
		c.CloseWrite()
	}
	<-done
}
func main() {
	mode := flag.String("mode", "client", "client or server")
	listen := flag.String("listen", "127.0.0.1:18080", "local listener")
	entry := flag.String("entry", "localhost:18443", "TLS entry")
	target := flag.String("target", "127.0.0.1:19090", "fixed TCP target")
	cert := flag.String("cert", "", "server certificate PEM")
	key := flag.String("key", "", "server key PEM")
	tokensFile := flag.String("tokens-file", "", "server device tokens, one per line; reload on SIGHUP")
	ca := flag.String("ca", "", "client trust PEM (otherwise system roots)")
	dynamic := flag.Bool("dynamic-targets", false, "accept authenticated CONNECT targets instead of fixed target")
	allowPrivate := flag.Bool("allow-private-targets", false, "lab only: allow private targets in dynamic mode")
	maxTunnels := flag.Int("max-tunnels", 128, "maximum concurrent tunnels")
	sessionTimeout := flag.Duration("session-timeout", 30*time.Minute, "absolute tunnel lifetime limit")
	flag.Parse()
	if *maxTunnels < 1 || *sessionTimeout <= 0 {
		log.Fatal("invalid resource limits")
	}
	slots := make(chan struct{}, *maxTunnels)
	token := os.Getenv("FASTCAT_LAB_TOKEN")
	if *tokensFile != "" && *mode != "server" {
		log.Fatal("-tokens-file is a server option")
	}
	if *tokensFile == "" && (len(token) < 24 || strings.ContainsAny(token, "\r\n")) {
		log.Fatal("FASTCAT_LAB_TOKEN must contain at least 24 bytes")
	}
	if *mode == "server" {
		// Keep the single-token format used by existing installations.
		single := sha256.Sum256([]byte("Bearer " + token))
		authorized := func(values []string) bool {
			if len(values) != 1 {
				return false
			}
			got := sha256.Sum256([]byte(values[0]))
			return subtle.ConstantTimeCompare(got[:], single[:]) == 1
		}
		if *tokensFile != "" {
			grants, err := entryauth.New("", *tokensFile)
			if err != nil {
				log.Fatal(err)
			}
			authorized = grants.Authorized
			reloads := make(chan os.Signal, 1)
			signal.Notify(reloads, syscall.SIGHUP)
			defer signal.Stop(reloads)
			go func() {
				for range reloads {
					if err := grants.Reload(); err != nil {
						log.Printf("device token reload failed: %v", err)
					}
				}
			}()
		}
		handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method != "CONNECT" || !authorized(r.Header.Values("Authorization")) {
				log.Print("stage=authentication rejected")
				http.Error(w, "Forbidden", 403)
				return
			}
			select {
			case slots <- struct{}{}:
				defer func() { <-slots }()
			default:
				http.Error(w, "Busy", 503)
				return
			}
			if version := r.Header.Get("FastCat-Version"); version != "" && version != "1" {
				http.Error(w, "Unsupported version", 400)
				return
			}
			destination := *target
			if *dynamic {
				ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
				var err error
				destination, err = resolveTarget(ctx, r.Host, *allowPrivate)
				cancel()
				if err != nil {
					log.Print("stage=target_policy rejected")
					http.Error(w, "Forbidden", 403)
					return
				}
			}
			// Fixed mode remains the default for existing lab runs.
			if !*dynamic && r.Host != *target {
				http.Error(w, "Forbidden", 403)
				return
			}
			upstream, e := net.DialTimeout("tcp", destination, 5*time.Second)
			if e != nil {
				log.Printf("stage=target_tcp error=%v", e)
				http.Error(w, "Bad Gateway", 502)
				return
			}
			c, rw, e := w.(http.Hijacker).Hijack()
			if e != nil {
				upstream.Close()
				return
			}
			if _, e = rw.WriteString("HTTP/1.1 200 Connection Established\r\n\r\n"); e == nil {
				e = rw.Flush()
			}
			if e != nil {
				c.Close()
				upstream.Close()
				return
			}
			c.SetDeadline(time.Now().Add(*sessionTimeout))
			upstream.SetDeadline(time.Now().Add(*sessionTimeout))
			log.Print("stage=tunnel ready")
			relay(c, rw, upstream)
		})
		s := &http.Server{Addr: *listen, Handler: handler, ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 8192, TLSConfig: &tls.Config{MinVersion: tls.VersionTLS12, NextProtos: []string{"http/1.1"}}}
		log.Fatal(s.ListenAndServeTLS(*cert, *key))
		return
	}
	if *mode != "client" {
		log.Fatal("unknown mode")
	}
	cfg := &tls.Config{MinVersion: tls.VersionTLS12, NextProtos: []string{"http/1.1"}}
	host, _, e := net.SplitHostPort(*entry)
	if e != nil {
		log.Fatal(e)
	}
	cfg.ServerName = host
	if *ca != "" {
		pem, e := os.ReadFile(*ca)
		if e != nil {
			log.Fatal(e)
		}
		pool := x509.NewCertPool()
		if !pool.AppendCertsFromPEM(pem) {
			log.Fatal("invalid CA")
		}
		cfg.RootCAs = pool
	}
	l, e := net.Listen("tcp", *listen)
	if e != nil {
		log.Fatal(e)
	}
	defer l.Close()
	for {
		c, e := l.Accept()
		if e != nil {
			log.Fatal(e)
		}
		select {
		case slots <- struct{}{}:
		default:
			c.Close()
			continue
		}
		go func() {
			defer func() { <-slots }()
			start := time.Now()
			raw, e := net.DialTimeout("tcp", *entry, 5*time.Second)
			if e != nil {
				log.Printf("stage=entry_tcp error=%v", e)
				c.Close()
				return
			}
			log.Printf("stage=entry_tcp elapsed=%s", time.Since(start))
			t := tls.Client(raw, cfg.Clone())
			t.SetDeadline(time.Now().Add(8 * time.Second))
			if e = t.Handshake(); e != nil {
				log.Printf("stage=tls error=%v", e)
				t.Close()
				c.Close()
				return
			}
			req := &http.Request{Method: "CONNECT", URL: nil, Host: *target, Header: make(http.Header)}
			req.Header.Set("Authorization", "Bearer "+token)
			// Write an HTTP CONNECT authority request without embedding credentials in logs.
			_, e = fmt.Fprintf(t, "CONNECT %s HTTP/1.1\r\nHost: %s\r\nAuthorization: %s\r\nFastCat-Version: 1\r\n\r\n", *target, *target, req.Header.Get("Authorization"))
			br := bufio.NewReader(t)
			var resp *http.Response
			if e == nil {
				resp, e = http.ReadResponse(br, req)
			}
			if e != nil {
				log.Printf("stage=https_response error=%v", e)
				t.Close()
				c.Close()
				return
			}
			if resp.StatusCode != 200 {
				log.Printf("stage=https_response status=%d", resp.StatusCode)
				t.Close()
				c.Close()
				return
			}
			t.SetDeadline(time.Now().Add(*sessionTimeout))
			c.SetDeadline(time.Now().Add(*sessionTimeout))
			log.Printf("stage=tunnel elapsed=%s", time.Since(start))
			relay(c, c, &bufferedConn{Conn: t, r: br})
		}()
	}
}

type bufferedConn struct {
	net.Conn
	r *bufio.Reader
}

func (c *bufferedConn) Read(p []byte) (int, error) { return c.r.Read(p) }

func (c *bufferedConn) CloseWrite() error {
	if w, ok := c.Conn.(interface{ CloseWrite() error }); ok {
		return w.CloseWrite()
	}
	return nil
}
