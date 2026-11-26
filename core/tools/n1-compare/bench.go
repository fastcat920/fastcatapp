package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
	clog "github.com/metacubex/mihomo/log"
	"io"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

type benchClient struct {
	dial  func(context.Context, string) (net.Conn, error)
	close func()
}
type n1BenchConn struct{ *tunnel }

func (c *n1BenchConn) LocalAddr() net.Addr                { return c.conn.LocalAddr() }
func (c *n1BenchConn) RemoteAddr() net.Addr               { return c.conn.RemoteAddr() }
func (c *n1BenchConn) SetDeadline(v time.Time) error      { c.deadline = v; return c.conn.SetDeadline(v) }
func (c *n1BenchConn) SetReadDeadline(v time.Time) error  { return c.conn.SetReadDeadline(v) }
func (c *n1BenchConn) SetWriteDeadline(v time.Time) error { return c.conn.SetWriteDeadline(v) }
func benchNew(cfg settings, proto string) (benchClient, error) {
	if proto == "n1" {
		return benchClient{dial: func(ctx context.Context, target string) (net.Conn, error) {
			c, e := dial(ctx, cfg, target)
			if e != nil {
				return nil, e
			}
			return &n1BenchConn{c}, nil
		}, close: func() {}}, nil
	}
	host, port, e := net.SplitHostPort(cfg.Server)
	if e != nil {
		return benchClient{}, e
	}
	p, e := strconv.Atoi(port)
	if e != nil {
		return benchClient{}, e
	}
	tracker := new(trackedDialer)
	base := outbound.BasicOption{DialerForAPI: tracker}
	var a C.ProxyAdapter
	switch proto {
	case "tuic":
		a, e = outbound.NewTuic(outbound.TuicOption{BasicOption: base, Name: "lab-tuic", Server: host, Port: p, UUID: cfg.NativeUUID, Password: cfg.NativeUUID, SNI: cfg.Name, CongestionController: "bbr", ReduceRtt: false, FastOpen: false})
	case "hysteria2":
		a, e = outbound.NewHysteria2(outbound.Hysteria2Option{BasicOption: base, Name: "lab-hy2", Server: host, Port: p, Password: cfg.NativePassword, SNI: cfg.Name})
	default:
		return benchClient{}, fmt.Errorf("unknown protocol")
	}
	if e != nil {
		tracker.Close()
		return benchClient{}, e
	}
	return benchClient{dial: func(ctx context.Context, target string) (net.Conn, error) {
		h, p, e := net.SplitHostPort(target)
		if e != nil {
			return nil, e
		}
		port, e := strconv.ParseUint(p, 10, 16)
		if e != nil {
			return nil, e
		}
		return a.DialContext(ctx, &C.Metadata{NetWork: C.TCP, Host: h, DstPort: uint16(port)})
	}, close: func() { a.Close(); tracker.Close() }}, nil
}
func benchSample(cfg settings, proto, phase, target string, size, index int, shared *benchClient) map[string]any {
	started := time.Now()
	row := map[string]any{"protocol": proto, "phase": phase, "sample": index, "bytes": size, "start_unix_ms": started.UnixMilli(), "success": false}
	var c net.Conn
	var cl benchClient
	var e error
	if shared == nil {
		cl, e = benchNew(cfg, proto)
		if e == nil {
			defer cl.close()
		}
	} else {
		cl = *shared
	}
	if e != nil {
		row["error_stage"] = "client"
		row["error_category"] = errorCategory(e)
		return row
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	stage := "entry"
	defer func() {
		if c != nil {
			c.Close()
		}
	}()
	c, e = cl.dial(ctx, target)
	row["entry_ms"] = float64(time.Since(started).Microseconds()) / 1000
	if e == nil {
		c.SetDeadline(started.Add(45 * time.Second))
		stage = "request"
		var req string
		if phase == "upload" {
			req = fmt.Sprintf("POST /upload HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: %d\r\nConnection: close\r\n\r\n", size)
		} else {
			req = fmt.Sprintf("GET /bytes?n=%d HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n", size)
		}
		_, e = io.WriteString(c, req)
		if e == nil && phase == "upload" {
			b := make([]byte, size)
			for i := range b {
				b[i] = byte(i % 251)
			}
			_, e = io.Copy(c, bytes.NewReader(b))
		}
		if e == nil {
			stage = "headers"
			r, err := http.ReadResponse(bufio.NewReader(c), nil)
			e = err
			row["headers_ms"] = float64(time.Since(started).Microseconds()) / 1000
			if e == nil {
				if r.StatusCode != 200 {
					e = fmt.Errorf("target status")
				} else {
					stage = "body"
					bodyStart := time.Now()
					first := func() { row["first_byte_ms"] = float64(time.Since(started).Microseconds()) / 1000 }
					if phase == "upload" {
						b, err := io.ReadAll(io.LimitReader(r.Body, 256))
						e = err
						first()
						if e == nil && string(b) != strconv.Itoa(size) {
							e = fmt.Errorf("upload verification")
						}
					} else {
						e = verifyPattern(r.Body, size, first)
					}
					row["body_ms"] = float64(time.Since(bodyStart).Microseconds()) / 1000
				}
				r.Body.Close()
			}
		}
	}
	row["total_ms"] = float64(time.Since(started).Microseconds()) / 1000
	if e != nil {
		row["error_stage"] = stage
		row["error_category"] = errorCategory(e)
	} else {
		row["success"] = true
		row["e2e_mbps"] = float64(size) * 8 / time.Since(started).Seconds() / 1e6
		if phase != "upload" {
			if ms, ok := row["body_ms"].(float64); ok && ms > 0 {
				row["body_mbps"] = float64(size) * 8 / ms / 1000
			}
		}
	}
	cleanup := time.Now()
	if c != nil {
		if n, ok := c.(*n1BenchConn); ok {
			ce := n.CloseWrite()
			if ce == nil {
				_, ce = io.Copy(io.Discard, n)
			}
			n.Close()
			row["n1_trace"] = n.trace.snapshot()
			if ce == nil {
				ce = n.shutdownErr
			}
			if ce != nil {
				row["cleanup_error"] = errorCategory(ce)
			}
		} else {
			c.Close()
		}
		c = nil
	}
	row["cleanup_ms"] = float64(time.Since(cleanup).Microseconds()) / 1000
	return row
}
func compareBench(cfg settings, proto, target, phase string, size, count, workers int) error {
	if count < 1 || count > 100 || workers < 1 || workers > 4 || size < 1 || size > 8*1048576 {
		return fmt.Errorf("bench bounds")
	}
	if phase != "cold" && phase != "warm" && phase != "concurrent" && phase != "download" && phase != "upload" {
		return fmt.Errorf("bench phase")
	}
	clog.SetLevel(clog.ERROR)
	var shared *benchClient
	if phase != "cold" {
		cl, e := benchNew(cfg, proto)
		if e != nil {
			return e
		}
		defer cl.close()
		shared = &cl
	}
	jobs := make(chan int)
	var wg sync.WaitGroup
	var mu sync.Mutex
	failures := 0
	begin := time.Now()
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for index := range jobs {
				row := benchSample(cfg, proto, phase, target, size, index, shared)
				mu.Lock()
				if row["success"] != true {
					failures++
				}
				json.NewEncoder(os.Stdout).Encode(row)
				mu.Unlock()
			}
		}()
	}
	for i := 1; i <= count; i++ {
		jobs <- i
	}
	close(jobs)
	wg.Wait()
	json.NewEncoder(os.Stdout).Encode(map[string]any{"event": "batch-ended", "protocol": proto, "phase": phase, "count": count, "workers": workers, "elapsed_ms": float64(time.Since(begin).Microseconds()) / 1000, "failed": failures})
	if failures > 0 {
		return fmt.Errorf("%d bench failures", failures)
	}
	return nil
}
