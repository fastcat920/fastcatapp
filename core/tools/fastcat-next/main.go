package main

import (
	"context"
	next "core/fastcatnext"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	qtls "github.com/metacubex/tls"
	"golang.org/x/net/http2"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

type config struct {
	PrefixRedundancy                               bool
	DownstreamBudget                               bool
	DisableGSO                                     bool
	DisableECN                                     bool
	TracePeerSalt                                  string
	FixedPacketSize                                uint16
	ReplyCoalesceMillis                            int
	QUICProfile                                    string
	TCPMaxSegment                                  int
	Listen, Cert, Key, Account, Secret, Congestion string
	IdleSeconds                                    int
	Trace                                          bool
	PrefixTrace                                    bool
}

func main() {
	if e := run(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
func run() error {
	path := flag.String("config", "", "private JSON configuration")
	flag.Parse()
	b, e := os.ReadFile(*path)
	if e != nil {
		return e
	}
	var cfg config
	if e = json.Unmarshal(b, &cfg); e != nil {
		return e
	}
	if cfg.ReplyCoalesceMillis < 0 || cfg.ReplyCoalesceMillis > 10 {
		return fmt.Errorf("invalid reply coalescing delay")
	}
	if cfg.DisableECN {
		if err := os.Setenv("QUIC_GO_DISABLE_ECN", "true"); err != nil {
			return err
		}
	}
	if cfg.DisableGSO {
		if err := os.Setenv("QUIC_GO_DISABLE_GSO", "true"); err != nil {
			return err
		}
	}
	key, e := hex.DecodeString(cfg.Secret)
	if e != nil {
		return e
	}
	idle := time.Duration(cfg.IdleSeconds) * time.Second
	if idle == 0 {
		idle = 60 * time.Second
	}
	var trace next.Trace
	if cfg.Trace {
		enc := json.NewEncoder(os.Stderr)
		var mu sync.Mutex
		trace = func(e next.Event) { e.AtUnixUS = time.Now().UnixMicro(); mu.Lock(); defer mu.Unlock(); enc.Encode(e) }
	}
	peerSalt, e := hex.DecodeString(cfg.TracePeerSalt)
	if e != nil {
		return e
	}
	s, e := next.NewServer(next.ServerConfig{PrefixRedundancy: cfg.PrefixRedundancy, DownstreamBudget: cfg.DownstreamBudget, TracePeerSalt: peerSalt, ReplyCoalesceDelay: time.Duration(cfg.ReplyCoalesceMillis) * time.Millisecond, FixedPacketSize: cfg.FixedPacketSize, Accounts: map[string][]byte{cfg.Account: key}, Congestion: cfg.Congestion, IdleTimeout: idle, Trace: trace, PrefixTrace: cfg.PrefixTrace, QUICProfile: cfg.QUICProfile})
	if e != nil {
		return e
	}
	tc, e := tls.LoadX509KeyPair(cfg.Cert, cfg.Key)
	if e != nil {
		return e
	}
	tcp, e := listenTCP(cfg.Listen, cfg.TCPMaxSegment)
	if e != nil {
		return e
	}
	defer tcp.Close()
	pc, e := net.ListenPacket("udp", cfg.Listen)
	if e != nil {
		return e
	}
	defer pc.Close()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	httpserver := &http.Server{Handler: s, ConnContext: s.ConnContext, IdleTimeout: idle, ReadHeaderTimeout: 5 * time.Second, MaxHeaderBytes: 16 << 10, TLSConfig: &tls.Config{MinVersion: tls.VersionTLS13, Certificates: []tls.Certificate{tc}, NextProtos: []string{"h2"}}}
	if e = http2.ConfigureServer(httpserver, &http2.Server{MaxConcurrentStreams: 128, IdleTimeout: idle}); e != nil {
		return e
	}
	errs := make(chan error, 2)
	go func() { errs <- httpserver.ServeTLS(tcp, "", "") }()
	go func() {
		errs <- s.ServeQUIC(ctx, pc, &qtls.Config{Certificates: []qtls.Certificate{{Certificate: tc.Certificate, PrivateKey: tc.PrivateKey}}})
	}()
	go func() { <-ctx.Done(); httpserver.Close() }()
	select {
	case <-ctx.Done():
		return nil
	case e := <-errs:
		return e
	}
}
