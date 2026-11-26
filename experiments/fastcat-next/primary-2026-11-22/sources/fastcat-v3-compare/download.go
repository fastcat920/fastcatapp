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
	"sync"
	"time"
)

var downloadTimeout = 30 * time.Second

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
	return downloadUsing(root, cfg, roots, v, p, target, size, nil)
}
func downloadUsing(root context.Context, cfg configuration, roots *x509.CertPool, v, p, target string, size int, shared *client) map[string]any {
	row := map[string]any{"phase": "download", "version": v, "protocol": p, "expected_bytes": size, "complete": false, "deadline_seconds": downloadTimeout.Seconds()}
	start := time.Now()
	ctx, cancel := context.WithTimeout(root, downloadTimeout)
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
	var c client
	var e error
	if shared == nil {
		c, e = newClient(ctx, cfg, roots, v, p)
		if e != nil {
			return finish(fmt.Errorf("prepare: %w", e))
		}
		defer c.close()
	} else {
		c = *shared
	}
	conn, e := c.dial(ctx, target)
	row["connect_ms"] = time.Since(start).Milliseconds()
	if e != nil {
		return finish(fmt.Errorf("entry: %w", e))
	}
	defer conn.Close()
	conn.SetDeadline(start.Add(downloadTimeout))
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

// All workers share one protocol client; this measures multiplexed download,
// rather than multiplying the number of client pools along with worker count.
func runParallelDownload(root context.Context, cfg configuration, roots *x509.CertPool, versions []string, target string, size, rounds, workers, jobs int) error {
	for round := 0; round < rounds; round++ {
		for _, protocol := range comparisonProtocols(versions) {
			for vi := range versions {
				version := versions[(round+vi)%len(versions)]
				if !comparisonCase(version, protocol) {
					continue
				}
				ctx, cancel := context.WithTimeout(root, downloadTimeout)
				start := time.Now()
				c, err := newClient(ctx, cfg, roots, version, protocol)
				if err != nil {
					cancel()
					return err
				}
				if c.warm != nil {
					_ = c.warm(ctx)
				}
				results := make([]map[string]any, jobs)
				slots := make([]int, jobs)
				queue := make(chan int, jobs)
				for i := 0; i < jobs; i++ {
					queue <- i
				}
				close(queue)
				var wg sync.WaitGroup
				for slot := 0; slot < workers; slot++ {
					wg.Add(1)
					go func(slot int) {
						defer wg.Done()
						for i := range queue {
							slots[i] = slot + 1
							results[i] = downloadUsing(ctx, cfg, roots, version, protocol, target, size, &c)
						}
					}(slot)
				}

				wg.Wait()
				elapsed := time.Since(start)
				usage := any(nil)
				if c.stats != nil {
					usage = c.stats()
				}
				c.close()
				cancel()
				var verified, partial int64
				complete := 0
				for i, row := range results {
					prefix := "parallel_download"
					if jobs > workers {
						prefix = "rolling_download"
					}
					row["phase"] = prefix + "_stream"
					row["slot"] = slots[i]
					row["round"] = round + 1
					row["worker"] = i + 1
					if n, ok := row["received_bytes"].(int64); ok {
						partial += n
						if row["complete"] == true {
							verified += n
						}
					}
					if row["complete"] == true {
						complete++
					}
					if err := json.NewEncoder(os.Stderr).Encode(row); err != nil {
						return err
					}
				}
				prefix := "parallel_download"
				if jobs > workers {
					prefix = "rolling_download"
				}
				row := map[string]any{"jobs": jobs, "lane_usage": usage, "phase": prefix, "version": version, "protocol": protocol, "round": round + 1, "workers": workers, "success": complete, "expected_bytes_each": size, "received_bytes": partial, "verified_bytes": verified, "elapsed_ms": elapsed.Milliseconds(), "verified_mbps": float64(verified*8) / elapsed.Seconds() / 1e6}
				if err := json.NewEncoder(os.Stderr).Encode(row); err != nil {
					return err
				}
			}
		}
	}
	return nil
}
