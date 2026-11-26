// Standalone loopback-only, bounded deterministic origin shared by both tunnels.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"time"
)

var diagnosticID = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)

type bodyTrace struct {
	Event        string  `json:"event"`
	DiagnosticID string  `json:"diagnostic_id"`
	Size         int     `json:"size"`
	BytesWritten int     `json:"bytes_written"`
	StartUnixNS  int64   `json:"start_unix_ns"`
	EndUnixNS    int64   `json:"end_unix_ns"`
	MaxWriteMS   float64 `json:"max_write_ms"`
	Error        bool    `json:"error"`
}

func main() {
	listen := flag.String("listen", "127.0.0.1:18476", "loopback origin address")
	traceBody := flag.Bool("trace-body", false, "write JSONL receipts for diagnostic /bytes requests to stdout")
	flag.Parse()
	host, _, err := net.SplitHostPort(*listen)
	if err != nil || net.ParseIP(host) == nil || !net.ParseIP(host).IsLoopback() {
		panic("origin must listen on a literal loopback IP")
	}
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "GET" && r.URL.Path == "/bytes" {
			n, err := strconv.Atoi(r.URL.Query().Get("n"))
			if err != nil || n < 1 || n > 8*1048576 {
				http.Error(w, "size", 400)
				return
			}
			var trace *bodyTrace
			if id := r.Header.Get("X-FCN-Diagnostic-ID"); *traceBody && diagnosticID.MatchString(id) {
				trace = &bodyTrace{Event: "origin_body", DiagnosticID: id, Size: n, StartUnixNS: time.Now().UnixNano()}
				defer func() {
					trace.EndUnixNS = time.Now().UnixNano()
					_ = json.NewEncoder(os.Stdout).Encode(trace)
				}()
			}
			w.Header().Set("Content-Length", strconv.Itoa(n))
			w.Header().Set("Content-Type", "application/octet-stream")
			var b [32768]byte
			for off := 0; off < n; {
				v := min(n-off, len(b))
				for i := 0; i < v; i++ {
					b[i] = byte((off + i) % 251)
				}
				var started time.Time
				if trace != nil {
					started = time.Now()
				}
				written, err := w.Write(b[:v])
				if trace != nil {
					trace.BytesWritten += written
					trace.MaxWriteMS = max(trace.MaxWriteMS, float64(time.Since(started))/float64(time.Millisecond))
					trace.Error = err != nil || written != v
				}
				if err != nil || written != v {
					return
				}
				off += v
			}
			return
		}
		if r.Method == "POST" && r.URL.Path == "/upload" {
			if r.ContentLength < 1 || r.ContentLength > 8*1048576 {
				http.Error(w, "size", 400)
				return
			}
			rd := io.LimitReader(r.Body, r.ContentLength+1)
			var b [32768]byte
			off := int64(0)
			for {
				n, err := rd.Read(b[:])
				for i := 0; i < n; i++ {
					if b[i] != byte((off+int64(i))%251) {
						http.Error(w, "pattern", 400)
						return
					}
				}
				off += int64(n)
				if err == io.EOF {
					break
				}
				if err != nil {
					http.Error(w, "read", 400)
					return
				}
			}
			if off != r.ContentLength {
				http.Error(w, "length", 400)
				return
			}
			_, _ = fmt.Fprint(w, off)
			return
		}
		http.NotFound(w, r)
	})
	s := &http.Server{Addr: *listen, Handler: h, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 60 * time.Second, WriteTimeout: 60 * time.Second, IdleTimeout: 5 * time.Second, MaxHeaderBytes: 4096}
	if err := s.ListenAndServe(); err != nil {
		panic(err)
	}
}
