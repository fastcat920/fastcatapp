// Standalone loopback-only bounded, deterministic download/upload target.
package main

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"
)

func main() {
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "GET" && r.URL.Path == "/bytes" {
			n, e := strconv.Atoi(r.URL.Query().Get("n"))
			if e != nil || n < 1 || n > 8*1048576 {
				http.Error(w, "size", 400)
				return
			}
			w.Header().Set("Content-Length", strconv.Itoa(n))
			w.Header().Set("Content-Type", "application/octet-stream")
			b := make([]byte, 16384)
			for off := 0; off < n; {
				v := n - off
				if v > len(b) {
					v = len(b)
				}
				for i := 0; i < v; i++ {
					b[i] = byte((off + i) % 251)
				}
				if _, e = w.Write(b[:v]); e != nil {
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
			b := make([]byte, 16384)
			off := int64(0)
			for {
				n, e := rd.Read(b)
				for i := 0; i < n; i++ {
					if b[i] != byte((off+int64(i))%251) {
						http.Error(w, "pattern", 400)
						return
					}
				}
				off += int64(n)
				if e == io.EOF {
					break
				}
				if e != nil {
					http.Error(w, "read", 400)
					return
				}
			}
			if off != r.ContentLength {
				http.Error(w, "length", 400)
				return
			}
			fmt.Fprint(w, off)
			return
		}
		http.NotFound(w, r)
	})
	s := &http.Server{Addr: "127.0.0.1:18476", Handler: h, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 60 * time.Second, WriteTimeout: 60 * time.Second, IdleTimeout: 5 * time.Second, MaxHeaderBytes: 4096}
	if e := s.ListenAndServe(); e != nil {
		panic(e)
	}
}
