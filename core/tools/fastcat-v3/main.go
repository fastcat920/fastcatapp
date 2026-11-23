// fastcat-v3 is an isolated experimental protocol prototype.
package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	v3 "core/fastcatv3"
)

func main() {
	if e := run(); e != nil {
		log.Print(e)
		os.Exit(1)
	}
}
func run() error {
	if len(os.Args) < 2 {
		return errors.New("usage: fastcat-v3 init|serve|probe|client [options]")
	}
	mode := os.Args[1]
	flags := flag.NewFlagSet(mode, flag.ContinueOnError)
	profile := flags.String("profile", "legacy", "legacy or independent server profile")
	debug := flags.Bool("debug", false, "log protocol stages without credentials")
	dir := flags.String("dir", "", "new private configuration directory (init)")
	config := flags.String("config", "", "private JSON credential file")
	listen := flags.String("listen", "127.0.0.1:19443", "server listen address")
	endpoint := flags.String("endpoint", "", "server host:port")
	name := flags.String("server-name", "", "TLS certificate hostname")
	carrier := flags.String("carrier", "h2", "h2 or h3")
	ca := flags.String("ca", "", "PEM CA bundle (required on standalone Android)")
	cert := flags.String("cert", "", "server certificate PEM")
	key := flags.String("key", "", "server private key PEM")
	target := flags.String("target", "example.com:443", "HTTPS HEAD target for probe")
	udpTarget := flags.String("udp-target", "", "optional fixed UDP echo target for probe")
	local := flags.String("proxy-listen", "127.0.0.1:18083", "loopback HTTP CONNECT listener")
	samples := flags.Int("samples", 3, "probe requests through one multiplexed session")
	allowPrivate := flags.Bool("allow-private-targets", false, "isolated lab only: allow private targets")
	if e := flags.Parse(os.Args[2:]); e != nil {
		return e
	}
	if flags.NArg() != 0 {
		return errors.New("unexpected positional arguments")
	}
	if mode == "init" {
		if *dir == "" {
			return errors.New("init requires -dir")
		}
		if e := os.Mkdir(*dir, 0700); e != nil {
			return e
		}
		c := v3.GenerateConfig()
		if e := save(filepath.Join(*dir, "server.json"), c); e != nil {
			return e
		}
		c.ServerPrivate = nil
		if e := save(filepath.Join(*dir, "client.json"), c); e != nil {
			return e
		}
		fmt.Println("Private server.json and client.json created")
		return nil
	}
	data, e := os.ReadFile(*config)
	if e != nil {
		return e
	}
	var c v3.Config
	if e = json.Unmarshal(data, &c); e != nil {
		return errors.New("invalid configuration JSON")
	}
	c.AllowPrivate = *allowPrivate
	if *debug {
		c.Trace = func(event string) { log.Print(event) }
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if mode == "serve" {
		if *cert == "" || *key == "" {
			return errors.New("serve requires -cert and -key")
		}
		log.Printf("FastCat v3 prototype H2/H3 listen=%s", *listen)
		if *profile == "independent" {
			return v3.ServeIndependent(ctx, c, *listen, *cert, *key)
		}
		if *profile != "legacy" {
			return errors.New("unknown server profile")
		}
		return v3.Serve(ctx, c, *listen, *cert, *key)
	}
	if mode != "probe" && mode != "client" {
		return errors.New("unknown command")
	}
	roots, e := loadRoots(*ca)
	if e != nil {
		return e
	}
	dc := v3.DialConfig{Config: c, Endpoint: *endpoint, ServerName: *name, Roots: roots}
	if mode == "probe" {
		if *samples < 1 || *samples > 100 {
			return errors.New("samples must be 1–100")
		}
		return probe(ctx, dc, *carrier, *target, *udpTarget, *samples)
	}
	return localProxy(ctx, dc, *carrier, *local)
}
func save(path string, v any) error {
	data, e := json.MarshalIndent(v, "", "  ")
	if e != nil {
		return e
	}
	return os.WriteFile(path, append(data, '\n'), 0600)
}
func loadRoots(path string) (*x509.CertPool, error) {
	if path == "" {
		return nil, nil
	}
	pem, e := os.ReadFile(path)
	if e != nil {
		return nil, e
	}
	roots := x509.NewCertPool()
	if !roots.AppendCertsFromPEM(pem) {
		return nil, errors.New("invalid CA bundle")
	}
	return roots, nil
}
func probe(ctx context.Context, dc v3.DialConfig, carrier, target, udpTarget string, n int) error {
	start := time.Now()
	s, e := v3.Dial(ctx, dc, carrier)
	if e != nil {
		return e
	}
	defer s.Close()
	handshake := time.Since(start).Microseconds()
	host, _, e := net.SplitHostPort(target)
	if e != nil {
		return e
	}
	result := struct {
		Carrier     string  `json:"carrier"`
		Handshake   int64   `json:"handshake_us"`
		Samples     []int64 `json:"target_first_byte_us"`
		Multiplexed int     `json:"concurrent_requests"`
		UDP         bool    `json:"udp_echo_verified"`
		KeyUpdate   bool    `json:"key_update_verified"`
	}{Carrier: carrier, Handshake: handshake}
	request := func() (int64, error) {
		ctx, stop := context.WithTimeout(ctx, 15*time.Second)
		defer stop()
		start := time.Now()
		stream, e := s.Open(ctx, 0, target)
		if e != nil {
			return 0, e
		}
		defer stream.Close()
		stream.SetDeadline(time.Now().Add(12 * time.Second))
		conn := tls.Client(stream, &tls.Config{ServerName: host, MinVersion: tls.VersionTLS12, RootCAs: dc.Roots})
		if e = conn.HandshakeContext(ctx); e != nil {
			return 0, e
		}
		if _, e = fmt.Fprintf(conn, "HEAD / HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n", host); e != nil {
			return 0, e
		}
		reader := bufio.NewReader(conn)
		if _, e = reader.Peek(1); e != nil {
			return 0, e
		}
		first := time.Since(start).Microseconds()
		res, e := http.ReadResponse(reader, &http.Request{Method: "HEAD"})
		if e != nil {
			return 0, e
		}
		res.Body.Close()
		if res.StatusCode != 200 {
			return 0, fmt.Errorf("target returned HTTP %d", res.StatusCode)
		}
		return first, nil
	}
	for i := 0; i < n; i++ {
		elapsed, e := request()
		if e != nil {
			return e
		}
		result.Samples = append(result.Samples, elapsed)
	}
	if e = s.UpdateKeys(); e != nil {
		return e
	}
	if _, e = request(); e != nil {
		return e
	}
	result.KeyUpdate = true
	errs := make(chan error, 4)
	for i := 0; i < 4; i++ {
		go func() { _, e := request(); errs <- e }()
	}
	for i := 0; i < 4; i++ {
		if e := <-errs; e != nil {
			return e
		}
		result.Multiplexed++
	}
	if udpTarget != "" {
		ctx, stop := context.WithTimeout(ctx, 8*time.Second)
		defer stop()
		stream, e := s.Open(ctx, 1, udpTarget)
		if e != nil {
			return e
		}
		defer stream.Close()
		payload := []byte("FastCat-v3-UDP-echo")
		if e = stream.SendDatagram(payload); e != nil {
			return e
		}
		reply, e := stream.ReceiveDatagram(ctx)
		if e != nil || string(reply) != string(payload) {
			return fmt.Errorf("UDP echo verification failed: %v", e)
		}
		result.UDP = true
	}
	return json.NewEncoder(os.Stdout).Encode(result)
}
func localProxy(ctx context.Context, dc v3.DialConfig, carrier, address string) error {
	host, _, e := net.SplitHostPort(address)
	if e != nil || net.ParseIP(host) == nil || !net.ParseIP(host).IsLoopback() {
		return errors.New("prototype proxy must bind a loopback IP")
	}
	s, e := v3.Dial(ctx, dc, carrier)
	if e != nil {
		return e
	}
	defer s.Close()
	ln, e := net.Listen("tcp", address)
	if e != nil {
		return e
	}
	defer ln.Close()
	server := &http.Server{ReadHeaderTimeout: 5 * time.Second, MaxHeaderBytes: 16 << 10, Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "CONNECT" {
			http.Error(w, "CONNECT required", 405)
			return
		}
		open, stop := context.WithTimeout(r.Context(), 10*time.Second)
		defer stop()
		target, e := s.Open(open, 0, r.Host)
		if e != nil {
			http.Error(w, "target unavailable", 502)
			return
		}
		defer target.Close()
		conn, rw, e := w.(http.Hijacker).Hijack()
		if e != nil {
			return
		}
		defer conn.Close()
		if _, e = rw.WriteString("HTTP/1.1 200 Connection Established\r\n\r\n"); e != nil {
			return
		}
		if e = rw.Flush(); e != nil {
			return
		}
		done := make(chan struct{}, 1)
		go func() { io.Copy(target, rw); target.CloseWrite(); done <- struct{}{} }()
		io.Copy(conn, target)
		conn.Close()
		target.Close()
		<-done
	})}
	var once sync.Once
	closeServer := func() { once.Do(func() { server.Close(); s.Close() }) }
	defer closeServer()
	go func() { <-ctx.Done(); closeServer() }()
	log.Printf("FastCat v3 HTTP CONNECT proxy listen=%s carrier=%s", address, carrier)
	e = server.Serve(ln)
	if errors.Is(e, http.ErrServerClosed) {
		return nil
	}
	return e
}
