package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	qhttp "github.com/metacubex/http"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/http3"
	qtls "github.com/metacubex/tls"
	"github.com/wyx2685/v2node/internal/fastcatv2/h2server"
	congestion "github.com/wyx2685/v2node/.codex-next-lab/congestion_v2"
	cc "github.com/metacubex/quic-go/congestion"
	"net"
	"net/http"
	"os"
	"time"
)

func main() {
	if e := run(); e != nil {
		panic(e)
	}
}
func run() error {
	var c struct{ Listen, Cert, Key, Token, Congestion string }
	b, e := os.ReadFile(os.Args[1])
	if e != nil {
		return e
	}
	if e = json.Unmarshal(b, &c); e != nil {
		return e
	}
	cfg := h2server.Config{Token: c.Token}
	h2, e := h2server.New(cfg)
	if e != nil {
		return e
	}
	h3, e := h2server.NewH3(cfg)
	if e != nil {
		return e
	}
	cert, e := tls.LoadX509KeyPair(c.Cert, c.Key)
	if e != nil {
		return e
	}
	qcert := qtls.Certificate{Certificate: cert.Certificate, PrivateKey: cert.PrivateKey}
	pc, e := net.ListenPacket("udp", c.Listen)
	if e != nil {
		return e
	}
	defer pc.Close()
	srv := &http3.Server{Handler: qhttp.HandlerFunc(h3.ServeHTTP), TLSConfig: &qtls.Config{Certificates: []qtls.Certificate{qcert}, NextProtos: []string{"h3"}, MinVersion: qtls.VersionTLS13}, EnableDatagrams: true, MaxHeaderBytes: 16 << 10, QUICConfig: &quic.Config{EnableDatagrams: true, MaxIdleTimeout: 60 * time.Second}}
	if c.Congestion == "bbr" {
		srv.ConnContext = func(ctx context.Context, q *quic.Conn) context.Context {
			q.SetCongestionControl(congestion.NewBbrSender(congestion.GetInitialPacketSize(q), cc.ByteCount(32), congestion.Profile("")))
			return ctx
		}
	}
	errs := make(chan error, 2)
	go func() { errs <- srv.Serve(pc) }()
	go func() {
		errs <- (&http.Server{Addr: c.Listen, Handler: h2, TLSConfig: &tls.Config{MinVersion: tls.VersionTLS13}}).ListenAndServeTLS(c.Cert, c.Key)
	}()
	return <-errs
}
