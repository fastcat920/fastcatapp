package main

import (
	"bufio"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"time"
)

func diagnosticTLS(cfg settings) (*tls.Conn, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	c, _, _, err := connectTLS(ctx, cfg, nil)
	if err == nil {
		c.SetDeadline(phaseDeadline(ctx, 15*time.Second))
	}
	return c, err
}

func inspect(cfg settings, target string, count int) error {
	if count < 1 || count > 100 {
		return fmt.Errorf("invalid sample count")
	}
	cases := []string{"ordinary-missing", "missing-auth", "bad-base64", "short-token", "wrong-key", "oversized-token", "stream-without-body", "public-root"}
	encoder := json.NewEncoder(os.Stdout)
	for round := 0; round < count; round++ {
		order := append([]string(nil), cases...)
		for i := len(order) - 1; i > 0; i-- {
			var b [1]byte
			rand.Read(b[:])
			j := int(b[0]) % (i + 1)
			order[i], order[j] = order[j], order[i]
		}
		for _, name := range order {
			started := time.Now()
			c, e := diagnosticTLS(cfg)
			row := map[string]any{"case": name, "round": round + 1}
			if e != nil {
				row["error"] = e.Error()
				encoder.Encode(row)
				continue
			}
			state := c.ConnectionState()
			path := route
			method := "POST"
			cookie := ""
			switch name {
			case "ordinary-missing":
				path = "/not-present"
			case "bad-base64":
				cookie = "***"
			case "short-token":
				cookie = base64.RawURLEncoding.EncodeToString([]byte{1, 2, 3})
			case "wrong-key":
				key, _ := keyBytes(cfg.Key)
				key[0] ^= 1
				cookie, _ = capability(&state, key, target)
			case "oversized-token":
				cookie = strings.Repeat("A", 600)
			case "public-root":
				path = "/"
				method = "GET"
			}
			header := fmt.Sprintf("%s %s HTTP/1.1\r\nHost: %s\r\n", method, path, cfg.Name)
			if cookie != "" {
				header += "Cookie: session=" + cookie + "\r\n"
			}
			if name == "stream-without-body" {
				header += "Transfer-Encoding: chunked\r\n"
			} else {
				header += "Content-Length: 0\r\n"
			}
			header += "\r\n"
			writeAt := time.Now()
			_, e = io.WriteString(c, header)
			if e == nil {
				var r *http.Response
				r, e = http.ReadResponse(bufio.NewReader(c), nil)
				row["response_headers_ms"] = float64(time.Since(writeAt).Microseconds()) / 1000
				if e == nil {
					body, readErr := io.ReadAll(io.LimitReader(r.Body, 8193))
					r.Body.Close()
					e = readErr
					sum := sha256.Sum256(body)
					row["status"] = r.StatusCode
					row["body_sha256"] = hex.EncodeToString(sum[:])
					row["body_bytes"] = len(body)
					row["connection_close"] = r.Close
					row["content_type"] = r.Header.Get("Content-Type")
				}
			}
			c.Close()
			row["total_ms"] = float64(time.Since(started).Microseconds()) / 1000
			if e != nil {
				row["error"] = e.Error()
			}
			encoder.Encode(row)
		}
	}
	return nil
}

func hold(cfg settings, count int) error {
	if count < 1 || count > 16 {
		return fmt.Errorf("hold limited to 16 sockets")
	}
	var sockets []net.Conn
	defer func() {
		for _, c := range sockets {
			c.Close()
		}
	}()
	for i := 0; i < count; i++ {
		c, e := net.DialTimeout("tcp", cfg.Server, 5*time.Second)
		if e != nil {
			return e
		}
		c.Write([]byte{0x16})
		sockets = append(sockets, c)
	}
	json.NewEncoder(os.Stdout).Encode(map[string]any{"event": "sockets-opened", "count": len(sockets)})
	pending, closed := 0, 0
	results := make(chan bool, len(sockets))
	deadline := time.Now().Add(2 * time.Second)
	for _, c := range sockets {
		go func(c net.Conn) {
			c.SetReadDeadline(deadline)
			var b [1]byte
			_, e := c.Read(b[:])
			n, ok := e.(net.Error)
			results <- ok && n.Timeout()
		}(c)
	}
	for range sockets {
		if <-results {
			pending++
		} else {
			closed++
		}
	}
	json.NewEncoder(os.Stdout).Encode(map[string]any{"requested": count, "pending": pending, "closed": closed, "scope": "partial TLS headers; single source; sockets released on exit"})
	return nil
}

func baseline(cfg settings, count int, stream bool) error {
	if count < 1 || count > 100 {
		return fmt.Errorf("invalid sample count")
	}
	for i := 0; i < count; i++ {
		started := time.Now()
		c, e := diagnosticTLS(cfg)
		row := map[string]any{"sample": i + 1, "mode": "ordinary-https-32k"}
		if e == nil {
			path := "/assets/sample.bin"
			if stream {
				path += "?stream=1"
				row["mode"] = "streaming-https-32k"
			}
			_, e = io.WriteString(c, "GET "+path+" HTTP/1.1\r\nHost: "+cfg.Name+"\r\nConnection: close\r\n\r\n")
			if e == nil {
				var r *http.Response
				r, e = http.ReadResponse(bufio.NewReader(c), nil)
				row["first_response_headers_ms"] = float64(time.Since(started).Microseconds()) / 1000
				if e == nil {
					var b []byte
					b, e = io.ReadAll(io.LimitReader(r.Body, 32769))
					r.Body.Close()
					if e == nil && (r.StatusCode != 200 || len(b) != 32768) {
						e = fmt.Errorf("invalid baseline response")
					}
					if e == nil {
						for j, v := range b {
							if v != byte(j%251) {
								e = fmt.Errorf("baseline integrity mismatch")
								break
							}
						}
					}
					row["bytes"] = len(b)
				}
			}
			c.Close()
		}
		row["full_request_ms"] = float64(time.Since(started).Microseconds()) / 1000
		if e != nil {
			row["error"] = e.Error()
		}
		json.NewEncoder(os.Stdout).Encode(row)
	}
	return nil
}
