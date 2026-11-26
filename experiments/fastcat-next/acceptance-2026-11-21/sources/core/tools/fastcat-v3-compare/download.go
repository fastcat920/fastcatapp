package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"time"
)

func runDownload(root context.Context, cfg configuration, roots *x509.CertPool, versions []string, target string, size, rounds int) error {
	for round := 0; round < rounds; round++ {
		protocols := comparisonProtocols(versions)
		for pi := range protocols {
			p := protocols[(round+pi)%len(protocols)]
			for vi := range versions {
				v := versions[(round+vi)%len(versions)]
				if !comparisonCase(v, p) {
					continue
				}
				row := downloadOne(root, cfg, roots, v, p, target, size)
				row["round"] = round + 1
				json.NewEncoder(os.Stderr).Encode(row)
			}
		}
	}
	return nil
}
func downloadOne(root context.Context, cfg configuration, roots *x509.CertPool, v, p, target string, size int) map[string]any {
	row := map[string]any{"phase": "download", "version": v, "protocol": p, "expected_bytes": size, "complete": false}
	start := time.Now()
	ctx, cancel := context.WithTimeout(root, 30*time.Second)
	defer cancel()
	finish := func(e error) map[string]any {
		row["total_ms"] = time.Since(start).Milliseconds()
		if n, ok := row["received_bytes"].(int64); ok {
			row["end_to_end_mbps"] = float64(n*8) / time.Since(start).Seconds() / 1e6
		}
		if e != nil {
			row["error"] = e.Error()
		}
		return row
	}
	c, e := newClient(ctx, cfg, roots, v, p)
	if e != nil {
		return finish(fmt.Errorf("prepare: %w", e))
	}
	defer c.close()
	conn, e := c.dial(ctx, target)
	row["connect_ms"] = time.Since(start).Milliseconds()
	if e != nil {
		return finish(fmt.Errorf("entry: %w", e))
	}
	defer conn.Close()
	conn.SetDeadline(start.Add(30 * time.Second))
	host, _, _ := net.SplitHostPort(target)
	if targetServerName != "" {
		host = targetServerName
	}
	inner := tls.Client(conn, &tls.Config{MinVersion: tls.VersionTLS13, ServerName: host, RootCAs: roots})
	ts := time.Now()
	if e = inner.HandshakeContext(ctx); e != nil {
		return finish(fmt.Errorf("target TLS: %w", e))
	}
	row["target_tls_ms"] = time.Since(ts).Milliseconds()
	if _, e = fmt.Fprintf(inner, "GET /bytes/%d HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n", size, host); e != nil {
		return finish(e)
	}
	reader := bufio.NewReader(inner)
	if _, e = reader.Peek(1); e != nil {
		return finish(e)
	}
	row["first_byte_ms"] = time.Since(start).Milliseconds()
	resp, e := http.ReadResponse(reader, &http.Request{Method: "GET"})
	if e != nil {
		return finish(e)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 || resp.ContentLength != int64(size) {
		return finish(fmt.Errorf("unexpected HTTP status or length"))
	}
	bodyStart := time.Now()
	hash := sha256.New()
	n, e := io.Copy(hash, resp.Body)
	elapsed := time.Since(bodyStart)
	row["received_bytes"] = n
	row["body_ms"] = elapsed.Milliseconds()
	row["download_mbps"] = float64(n*8) / elapsed.Seconds() / 1e6
	if e != nil {
		return finish(e)
	}
	if n != int64(size) {
		return finish(io.ErrUnexpectedEOF)
	}
	expected := sha256.New()
	block := bytes.Repeat([]byte{0, 1, 2, 3}, 8192)
	remaining := size
	for remaining > 0 {
		chunk := remaining
		if chunk > len(block) {
			chunk = len(block)
		}
		expected.Write(block[:chunk])
		remaining -= chunk
	}
	if !bytes.Equal(hash.Sum(nil), expected.Sum(nil)) {
		return finish(fmt.Errorf("payload checksum mismatch"))
	}
	row["complete"] = true
	row["checksum_ok"] = true
	return finish(nil)
}
