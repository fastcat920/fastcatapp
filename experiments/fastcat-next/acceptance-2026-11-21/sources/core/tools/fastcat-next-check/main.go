package main

import (
	"bytes"
	"context"
	next "core/fastcatnext"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"time"
)

type configuration struct{ NextAddress, NextAccount, NextSecret, ServerName, CA string }

func main() {
	path := flag.String("config", "", "private config")
	udpMatrix := flag.Bool("udp-matrix", false, "compare direct UDP and FCN datagrams")
	flag.Parse()
	if e := run(*path, *udpMatrix); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
func run(path string, udpMatrix bool) error {
	b, e := os.ReadFile(path)
	if e != nil {
		return e
	}
	var cfg configuration
	if e = json.Unmarshal(b, &cfg); e != nil {
		return e
	}
	key, e := hex.DecodeString(cfg.NextSecret)
	if e != nil {
		return e
	}
	pem, e := os.ReadFile(cfg.CA)
	if e != nil {
		return e
	}
	roots := x509.NewCertPool()
	if !roots.AppendCertsFromPEM(pem) {
		return fmt.Errorf("CA unavailable")
	}
	ctx, stop := context.WithTimeout(context.Background(), 90*time.Second)
	defer stop()
	base := next.Config{Endpoint: cfg.NextAddress, ServerName: cfg.ServerName, Account: cfg.NextAccount, Key: key, Roots: roots, Congestion: "bbr"}
	enc := json.NewEncoder(os.Stdout)
	if udpMatrix {
		return compareUDP(ctx, base, enc)
	}
	emit := func(check, carrier string, start time.Time, e error) {
		row := map[string]any{"check": check, "carrier": carrier, "ok": e == nil, "elapsed_ms": time.Since(start).Milliseconds()}
		if e != nil {
			row["error"] = e.Error()
		}
		enc.Encode(row)
	}
	for _, carrier := range []string{"quic", "h2"} {
		cl, e := next.NewClient(ctx, base, carrier)
		if e != nil {
			return e
		}
		for _, name := range []string{"half-close-256KiB", "fresh-after-network-reset"} {
			if name == "fresh-after-network-reset" {
				cl.Reset()
			}
			start := time.Now()
			conn, e := cl.Dial(ctx, "191.223.214.8:19457")
			if e == nil {
				conn.SetDeadline(time.Now().Add(12 * time.Second))
				payload := bytes.Repeat([]byte{17, 23, 91, 4}, 65536)
				done := make(chan error, 1)
				go func() {
					_, e := conn.Write(payload)
					if e == nil {
						e = conn.(interface{ CloseWrite() error }).CloseWrite()
					}
					done <- e
				}()
				var got []byte
				got, e = io.ReadAll(conn)
				if e == nil {
					e = <-done
				}
				if e == nil && !bytes.Equal(got, payload) {
					e = fmt.Errorf("payload mismatch")
				}
				conn.Close()
			}
			emit(name, carrier, start, e)
		}
		cl.Close()
		bad := base
		bad.Key = bytes.Repeat([]byte{0}, 32)
		cl, e = next.NewClient(ctx, bad, carrier)
		if e != nil {
			return e
		}
		start := time.Now()
		conn, e := cl.Dial(ctx, "191.223.214.8:19457")
		if e == nil {
			conn.SetReadDeadline(time.Now().Add(5 * time.Second))
			var b [1]byte
			_, e = conn.Read(b[:])
			conn.Close()
		}
		if e == nil {
			e = fmt.Errorf("bad credential accepted")
		} else if e == next.ErrAuth {
			e = nil
		}
		emit("wrong-key-rejected", carrier, start, e)
		cl.Close()
	}
	cl, e := next.NewClient(ctx, base, "quic")
	if e != nil {
		return e
	}
	defer cl.Close()
	p, e := cl.DialPacket(ctx, "191.223.214.8:19456")
	if e != nil {
		return e
	}
	defer p.Close()
	for i := 0; i < 20; i++ {
		start := time.Now()
		payload := bytes.Repeat([]byte{byte(i)}, 1100)
		p.SetDeadline(time.Now().Add(2 * time.Second))
		_, e := p.WriteTo(payload, nil)
		if e == nil {
			b := make([]byte, 1200)
			var n int
			n, _, e = p.ReadFrom(b)
			if e == nil && !bytes.Equal(b[:n], payload) {
				e = fmt.Errorf("datagram mismatch")
			}
		}
		emit(fmt.Sprintf("udp1100-%02d", i+1), "quic", start, e)
	}
	start := time.Now()
	_, e = p.WriteTo(make([]byte, 1101), nil)
	if e != nil {
		e = nil
	} else {
		e = fmt.Errorf("oversized datagram accepted")
	}
	emit("udp-oversize-rejected", "quic", start, e)
	return nil
}

func compareUDP(ctx context.Context, base next.Config, enc *json.Encoder) error {
	cl, e := next.NewClient(ctx, base, "quic")
	if e != nil {
		return e
	}
	defer cl.Close()
	tunneled, e := cl.DialPacket(ctx, "191.223.214.8:19456")
	if e != nil {
		return e
	}
	defer tunneled.Close()
	direct, e := net.Dial("udp", "191.223.214.8:19456")
	if e != nil {
		return e
	}
	defer direct.Close()
	for round := 0; round < 30; round++ {
		for _, size := range []int{32, 1100} {
			for offset := 0; offset < 2; offset++ {
				mode := "direct-udp"
				isTunnel := (round+offset)%2 == 1
				if isTunnel {
					mode = "fcn-quic"
				}
				payload := bytes.Repeat([]byte{byte(round + 1)}, size)
				start := time.Now()
				deadline := start.Add(time.Second)
				buf := make([]byte, 1200)
				var n int
				var e error
				if isTunnel {
					tunneled.SetDeadline(deadline)
					_, e = tunneled.WriteTo(payload, nil)
					if e == nil {
						n, _, e = tunneled.ReadFrom(buf)
					}
				} else {
					direct.SetDeadline(deadline)
					_, e = direct.Write(payload)
					if e == nil {
						n, e = direct.Read(buf)
					}
				}
				if e == nil && !bytes.Equal(buf[:n], payload) {
					e = fmt.Errorf("payload mismatch or late datagram")
				}
				row := map[string]any{"mode": mode, "payload_bytes": size, "round": round + 1, "elapsed_us": time.Since(start).Microseconds(), "ok": e == nil}
				if e != nil {
					row["error"] = e.Error()
				}
				enc.Encode(row)
			}
		}
	}
	return nil
}
