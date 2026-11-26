package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"fastcat.local/https-h2/internal/h2server"
	"github.com/metacubex/mihomo/component/fastcattls"
	"github.com/metacubex/mihomo/transport/fastcath2"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := run(ctx, os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func run(ctx context.Context, args []string) error {
	const usage = "usage: fastcat-h2 server | h3-server | client [options]"
	if len(args) == 0 {
		return errors.New(usage)
	}
	switch args[0] {
	case "server":
		return runServer(ctx, args[1:])
	case "h3-server":
		return runH3Server(ctx, args[1:])
	case "client":
		return runClient(ctx, args[1:])
	case "-h", "--help", "help":
		fmt.Println(usage)
		return nil
	default:
		return errors.New(usage)
	}
}

func runServer(ctx context.Context, args []string) error {
	flags := flag.NewFlagSet("server", flag.ContinueOnError)
	curve := flags.String("tls-key-exchange", "", "default, x25519 or x25519mlkem768")
	listen := flags.String("listen", "127.0.0.1:18444", "TLS entry address")
	certFile := flags.String("cert", "", "certificate chain PEM")
	keyFile := flags.String("key", "", "certificate private key PEM")
	tokensFile := flags.String("tokens-file", "", "one device token per line, reload on SIGHUP (default: FASTCAT_H2_TOKEN)")
	private := flags.Bool("allow-private-targets", false, "allow private destinations for loopback-only tests")
	maxTunnels := flags.Int("max-tunnels", 128, "maximum active tunnels across all clients")
	session := flags.Duration("session-timeout", 30*time.Minute, "absolute tunnel lifetime")
	if err := flags.Parse(args); err != nil {
		return helpOrError(err)
	}
	if flags.NArg() != 0 || *maxTunnels < 1 || *session <= 0 {
		return errors.New("invalid server arguments or limits")
	}
	if *private && !loopbackAddress(*listen) {
		return errors.New("private targets require a loopback test listener")
	}
	cfg := h2server.Config{
		TokensFile: *tokensFile, MaxTunnels: *maxTunnels,
		AllowPrivateTargets: *private, SessionTimeout: *session,
	}
	if *tokensFile == "" {
		cfg.Token = os.Getenv("FASTCAT_H2_TOKEN")
	}
	handler, err := h2server.New(cfg)
	if err != nil {
		return err
	}
	cert, err := tls.LoadX509KeyPair(*certFile, *keyFile)
	if err != nil {
		return fmt.Errorf("load certificate: %w", err)
	}
	var protocols http.Protocols
	protocols.SetHTTP2(true)
	server := &http.Server{
		Handler: logFirstH2Request(handler), Protocols: &protocols, ReadHeaderTimeout: 8 * time.Second,
		IdleTimeout: 60 * time.Second, MaxHeaderBytes: 16 << 10,
		TLSConfig: &tls.Config{MinVersion: tls.VersionTLS13, NextProtos: []string{"h2"}, Certificates: []tls.Certificate{cert}},
		// Each TLS connection gets its own context. Streams sharing it emit just one ready event.
		ConnContext: func(ctx context.Context, conn net.Conn) context.Context {
			return context.WithValue(ctx, entryConnKey{}, &entryConn{})
		},
	}
	if err := fastcattls.Apply(server.TLSConfig, *curve); err != nil {
		return err
	}
	l, err := net.Listen("tcp", *listen)
	if err != nil {
		return err
	}
	defer l.Close()
	stopReload := tokenReload(ctx, *tokensFile, handler.(interface{ ReloadTokens() error }))
	defer stopReload()

	log.Printf("server listen=%s", l.Addr())
	return serveHTTP(ctx, server, func() error { return server.ServeTLS(l, "", "") })
}

func tokenReload(ctx context.Context, path string, handler interface{ ReloadTokens() error }) func() {
	if path == "" {
		return func() {}
	}
	reloads := make(chan os.Signal, 1)
	signal.Notify(reloads, syscall.SIGHUP)
	active, cancel := context.WithCancel(ctx)
	go func() {
		for {
			select {
			case <-active.Done():
				return
			case <-reloads:
				if err := handler.ReloadTokens(); err != nil {
					log.Printf("device token reload failed: %v", err)
				} else {
					log.Print("device tokens reloaded")
				}
			}
		}
	}()
	return func() { signal.Stop(reloads); cancel() }
}

type entryConnKey struct{}
type entryConn struct{ once sync.Once }

func logFirstH2Request(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor == 2 && r.TLS != nil {
			conn := r.Context().Value(entryConnKey{}).(*entryConn)
			conn.once.Do(func() { log.Print("entry negotiated=h2") })
		}
		next.ServeHTTP(w, r)
	})
}

func runClient(ctx context.Context, args []string) error {
	flags := flag.NewFlagSet("client", flag.ContinueOnError)
	curve := flags.String("tls-key-exchange", "", "default, x25519 or x25519mlkem768")
	listen := flags.String("listen", "127.0.0.1:18081", "loopback HTTP CONNECT proxy address")
	entry := flags.String("entry", "", "TLS gateway host:port")
	sni := flags.String("server-name", "", "certificate hostname (defaults to gateway host)")
	ca := flags.String("ca", "", "trusted CA PEM (defaults to system roots)")
	target := flags.String("target", "", "optional fixed destination host:port for raw TCP forwarding")
	if err := flags.Parse(args); err != nil {
		return helpOrError(err)
	}
	if flags.NArg() != 0 || !loopbackAddress(*listen) {
		return errors.New("client listener must use a numeric loopback address, e.g. 127.0.0.1:18081")
	}
	if *target != "" {
		if _, _, err := net.SplitHostPort(*target); err != nil {
			return fmt.Errorf("invalid fixed target: %w", err)
		}
	}
	var roots *x509.CertPool
	if *ca != "" {
		pem, err := os.ReadFile(*ca)
		if err != nil {
			return err
		}
		roots = x509.NewCertPool()
		if !roots.AppendCertsFromPEM(pem) {
			return errors.New("no certificates found in CA file")
		}
	}
	client, err := h2client.New(h2client.Config{
		CurveMode: *curve, Endpoint: *entry, ServerName: *sni, RootCAs: roots, Token: os.Getenv("FASTCAT_H2_TOKEN"),
	})
	if err != nil {
		return err
	}
	defer client.Close()
	l, err := net.Listen("tcp", *listen)
	if err != nil {
		return err
	}
	defer l.Close()
	log.Printf("client listen=%s", l.Addr())
	if *target != "" {
		return serveFixed(ctx, l, client, *target)
	}
	server := &http.Server{
		Handler: localProxy(client), ReadHeaderTimeout: 5 * time.Second,
		MaxHeaderBytes: 16 << 10, BaseContext: func(net.Listener) context.Context { return ctx },
	}
	return serveHTTP(ctx, server, func() error { return server.Serve(l) })
}

func helpOrError(err error) error {
	if errors.Is(err, flag.ErrHelp) {
		return nil
	}
	return err
}

func loopbackAddress(address string) bool {
	host, _, err := net.SplitHostPort(address)
	return err == nil && net.ParseIP(host).IsLoopback()
}

func serveHTTP(ctx context.Context, server *http.Server, serve func() error) error {
	stop := context.AfterFunc(ctx, func() { _ = server.Close() })
	defer stop()
	if err := serve(); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}

func serveFixed(ctx context.Context, l net.Listener, client *h2client.Client, target string) error {
	stop := context.AfterFunc(ctx, func() { _ = l.Close() })
	defer stop()
	for {
		local, err := l.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		go func() {
			defer local.Close()
			remote, err := client.Dial(ctx, target)
			if err != nil {
				log.Printf("CONNECT failed: %v", err)
				return
			}
			forward(local, local, remote)
		}()
	}
}

func localProxy(client *h2client.Client) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect {
			w.Header().Set("Allow", http.MethodConnect)
			http.Error(w, "HTTPS CONNECT proxy", http.StatusMethodNotAllowed)
			return
		}
		remote, err := client.Dial(r.Context(), r.Host)
		if err != nil {
			log.Printf("CONNECT failed: %v", err)
			http.Error(w, "gateway CONNECT failed", http.StatusBadGateway)
			return
		}
		local, rw, err := http.NewResponseController(w).Hijack()
		if err != nil {
			remote.Close()
			return
		}
		defer local.Close()
		if _, err = rw.WriteString("HTTP/1.1 200 Connection Established\r\n\r\n"); err == nil {
			err = rw.Flush()
		}
		if err != nil {
			remote.Close()
			return
		}
		// Requests can include target bytes already buffered by the local HTTP server.
		forward(local, rw.Reader, remote)
	})
}

func forward(local net.Conn, localReader io.Reader, remote net.Conn) {
	uploaded := make(chan struct{})
	go func() {
		defer close(uploaded)
		_, err := io.Copy(remote, localReader)
		if err == nil {
			err = remote.(interface{ CloseWrite() error }).CloseWrite()
		}
		if err != nil {
			remote.Close()
		}
	}()
	_, _ = io.Copy(local, remote)
	remote.Close()
	local.Close()
	<-uploaded
}
