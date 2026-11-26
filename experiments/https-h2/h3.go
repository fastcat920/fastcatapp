package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	"fastcat.local/https-h2/internal/h2server"
	http "github.com/metacubex/http"
	"github.com/metacubex/mihomo/component/fastcattls/quicprofile"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	tls "github.com/metacubex/tls"
)

func runH3Server(ctx context.Context, args []string) error {
	f := flag.NewFlagSet("h3-server", flag.ContinueOnError)
	listen := f.String("listen", "127.0.0.1:18444", "UDP listener")
	certPath := f.String("cert", "", "certificate chain PEM")
	keyPath := f.String("key", "", "certificate private key PEM")
	file := f.String("tokens-file", "", "device tokens, one per line, reload with SIGHUP (default FASTCAT_H3_TOKEN)")
	private := f.Bool("allow-private-targets", false, "allow private destinations on a loopback-only listener")
	limit := f.Int("max-tunnels", 128, "maximum active tunnels")
	lifetime := f.Duration("session-timeout", 30*time.Minute, "absolute tunnel lifetime")
	mode := f.String("tls-key-exchange", "default", "default, x25519, or x25519mlkem768")
	if err := f.Parse(args); err != nil {
		return helpOrError(err)
	}
	if f.NArg() != 0 || *limit < 1 || *lifetime <= 0 {
		return errors.New("invalid HTTP/3 arguments or limits")
	}
	if *private && !loopbackAddress(*listen) {
		return errors.New("private targets require a loopback listener")
	}
	cfg := h2server.Config{TokensFile: *file, AllowPrivateTargets: *private, MaxTunnels: *limit, SessionTimeout: *lifetime}
	if *file == "" {
		cfg.Token = os.Getenv("FASTCAT_H3_TOKEN")
	}
	handler, err := h2server.NewH3(cfg)
	if err != nil {
		return err
	}
	cert, err := tls.LoadX509KeyPair(*certPath, *keyPath)
	if err != nil {
		return fmt.Errorf("load certificate: %w", err)
	}
	t := &tls.Config{Certificates: []tls.Certificate{cert}, NextProtos: []string{"h3"}}
	if err := quicprofile.ApplyQUIC(t, *mode); err != nil {
		return err
	}
	srv := &http3.Server{Handler: handler, TLSConfig: t, EnableDatagrams: true, MaxHeaderBytes: 16 << 10, QUICConfig: &quic.Config{EnableDatagrams: true, MaxIdleTimeout: 60 * time.Second}}
	l, err := net.ListenPacket("udp", *listen)
	if err != nil {
		return err
	}
	defer l.Close()
	done := tokenReload(ctx, *file, handler)
	defer done()
	stop := context.AfterFunc(ctx, func() { srv.Close() })
	defer stop()
	log.Printf("HTTP/3 server listen=%s", l.LocalAddr())
	err = srv.Serve(l)
	if ctx.Err() != nil && (errors.Is(err, http.ErrServerClosed) || errors.Is(err, net.ErrClosed)) {
		return nil
	}
	return err
}
