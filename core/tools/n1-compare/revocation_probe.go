package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"
)

// Explicit bounded diagnostic for a loopback-only echo target. Readiness means
// actual data has been echoed and verified; the tunnel then remains open.
func revocationProbe(cfg settings, target string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	c, e := dial(ctx, cfg, target)
	if e != nil {
		return e
	}
	defer c.Close()
	c.conn.SetDeadline(time.Now().Add(30 * time.Second))
	payload := bytes.Repeat([]byte("lease-proof"), 64)
	if _, e = c.Write(payload); e != nil {
		return e
	}
	got := make([]byte, len(payload))
	if _, e = io.ReadFull(c, got); e != nil {
		return e
	}
	if !bytes.Equal(got, payload) {
		return fmt.Errorf("echo mismatch")
	}
	json.NewEncoder(os.Stdout).Encode(map[string]any{"event": "payload-ready", "received": len(got), "unix_ms": time.Now().UnixMilli()})
	n, e := c.Read(make([]byte, 1))
	json.NewEncoder(os.Stdout).Encode(map[string]any{"event": "session-ended", "unexpected_bytes": n, "error_category": errorCategory(e), "unix_ms": time.Now().UnixMilli()})
	if e == nil {
		return fmt.Errorf("unexpected echo bytes")
	}
	if errorCategory(e) == "timeout" {
		return e
	}
	return nil
}
