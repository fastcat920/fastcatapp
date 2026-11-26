package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

type serverWriteEvent struct {
	Stage        string `json:"stage"`
	PlainBytes   int    `json:"plain_bytes"`
	PayloadBytes int    `json:"payload_bytes,omitempty"`
}

var traceSequence atomic.Uint64

func (n *node) newWriteTrace(kind string) func(serverWriteEvent) {
	if !n.traceWrites || !n.controls {
		return nil
	}
	id := traceSequence.Add(1)
	return func(e serverWriteEvent) {
		b, _ := json.Marshal(struct {
			ID   uint64 `json:"id"`
			Kind string `json:"kind"`
			serverWriteEvent
		}{id, kind, e})
		log.Printf("WRITE_TRACE %s", b)
	}
}

type matchShape struct{ Header, Data, End int }

func parseMatchShape(s string) (matchShape, error) {
	var m matchShape
	v := strings.Split(s, ",")
	if len(v) != 3 {
		return m, fmt.Errorf("expected header,data,end sizes")
	}
	for i, dst := range []*int{&m.Header, &m.Data, &m.End} {
		n, e := strconv.Atoi(v[i])
		if e != nil {
			return m, e
		}
		*dst = n
	}
	if m.Header < 256 || m.Header > 4096 || m.Data < 64 || m.Data > 512 || m.End < 8 || m.End > 39 {
		return m, fmt.Errorf("invalid bounded match sizes")
	}
	return m, nil
}
func paddedJSON(v any, size int) ([]byte, error) {
	b, e := json.Marshal(v)
	if e != nil {
		return nil, e
	}
	if len(b)+1 > size {
		return nil, fmt.Errorf("command exceeds matching body")
	}
	b = append(b, bytes.Repeat([]byte(" "), size-len(b)-1)...)
	return append(b, '\n'), nil
}
func ordinaryChunk(w io.Writer, p []byte, end bool, observe func(serverWriteEvent)) error {
	frame := append([]byte(fmt.Sprintf("%x\r\n", len(p))), p...)
	frame = append(frame, '\r', '\n')
	if end {
		frame = []byte("0\r\n\r\n")
	}
	if observe != nil {
		stage := "rpc-data"
		if end {
			stage = "rpc-end"
		}
		observe(serverWriteEvent{Stage: stage, PlainBytes: len(frame), PayloadBytes: len(p)})
	}
	_, e := w.Write(frame)
	return e
}

// A bounded, synthetic streaming job: headers acknowledge the job session;
// a newline-delimited JSON command starts output; the client keeps upload open
// until all output is verified, then sends JSON 0 as a completion receipt.
// No N1 records, authentication, exporter or proxy forwarding are used here.
func serveMatchedRPC(w http.ResponseWriter, r *http.Request, observe func(serverWriteEvent)) error {
	if r.Method != "POST" || len(r.TransferEncoding) != 1 || r.TransferEncoding[0] != "chunked" {
		unavailable(w, r)
		return nil
	}
	h, ok := w.(http.Hijacker)
	if !ok {
		return fmt.Errorf("hijacking unavailable")
	}
	c, b, e := h.Hijack()
	if e != nil {
		return e
	}
	defer c.Close()
	c.SetDeadline(time.Now().Add(30 * time.Second))
	prefix := make([]byte, b.Reader.Buffered())
	if _, e = io.ReadFull(b.Reader, prefix); e != nil {
		return e
	}
	input := bufio.NewReader(io.MultiReader(bytes.NewReader(prefix), c))
	body := bufio.NewReaderSize(httputil.NewChunkedReader(input), 512)
	head := fmt.Sprintf("HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nDate: %s\r\nTransfer-Encoding: chunked\r\n\r\n", time.Now().UTC().Format(http.TimeFormat))
	if _, e = io.WriteString(c, head); e != nil {
		return e
	}
	if observe != nil {
		observe(serverWriteEvent{Stage: "response-headers", PlainBytes: len(head)})
	}
	// LimitedReader bounds malicious unterminated lines, without reading the
	// next stage early or mixing net/http's Body with post-Hijack reads.
	command, e := body.ReadSlice('\n')
	if e != nil || len(command) > 512 {
		return fmt.Errorf("invalid bounded command")
	}
	var s workload
	if e = json.Unmarshal(command, &s); e != nil {
		return e
	}
	if e = s.validate(); e != nil {
		return e
	}
	offset := 0
	for offset < s.N {
		count := s.Chunk
		if count > s.N-offset {
			count = s.N - offset
		}
		p := make([]byte, count)
		for i := range p {
			p[i] = byte((offset + i) % 251)
		}
		if e = ordinaryChunk(c, p, false, observe); e != nil {
			return e
		}
		offset += count
		if s.GapMS > 0 && offset < s.N {
			time.Sleep(time.Duration(s.GapMS) * time.Millisecond)
		}
	}
	if e = ordinaryChunk(c, nil, true, observe); e != nil {
		return e
	}
	// The client sends its receipt only after HTTP output EOF, not before data.
	receipt, e := io.ReadAll(io.LimitReader(body, 40))
	if e != nil || len(receipt) > 39 {
		return fmt.Errorf("invalid bounded receipt")
	}
	var ack int
	if e = json.Unmarshal(receipt, &ack); e != nil || ack != 0 {
		return fmt.Errorf("invalid receipt JSON")
	}
	if line, e := input.ReadSlice('\n'); e != nil || !bytes.Equal(line, []byte("\r\n")) {
		return fmt.Errorf("unsupported trailers")
	}
	if closer, ok := c.(interface{ CloseWrite() error }); ok {
		if e = closer.CloseWrite(); e != nil {
			return e
		}
	}
	if _, e = input.ReadByte(); e != io.EOF {
		return fmt.Errorf("TLS ending: %v", e)
	}
	return nil
}
func runMatchedRPC(cfg settings, s workload, encodedShape string) (err error) {
	if err = s.validate(); err != nil {
		return err
	}
	shape, err := parseMatchShape(encodedShape)
	if err != nil {
		return err
	}
	start := time.Now()
	row := map[string]any{"kind": "matched-rpc", "bytes": s.N, "chunk": s.Chunk, "gap_ms": s.GapMS}
	defer func() {
		row["full_request_ms"] = float64(time.Since(start).Microseconds()) / 1000
		if err != nil {
			row["error"] = err.Error()
		} else {
			row["payload_verified"] = true
			row["shutdown_eof_observed"] = true
		}
		json.NewEncoder(os.Stdout).Encode(row)
	}()
	c, err := diagnosticTLS(cfg)
	if err != nil {
		return err
	}
	defer c.Close()
	c.SetDeadline(start.Add(30 * time.Second))
	var cookie [72]byte
	if _, err = rand.Read(cookie[:]); err != nil {
		return err
	}
	req, err := http.NewRequest("POST", "https://"+cfg.Name+"/j", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	req.AddCookie(&http.Cookie{Name: "session", Value: base64.RawURLEncoding.EncodeToString(cookie[:])})
	head, err := streamingRequestHeaders(req)
	if err != nil {
		return err
	}
	// A bounded ordinary application header equalizes header bytes. It is a
	// deliberately matched control, not evidence of prevalence in real traffic.
	extra := shape.Header - len(head) - len("X-Job: \r\n")
	if extra < 0 {
		return fmt.Errorf("matching header too short")
	}
	req.Header.Set("X-Job", strings.Repeat("j", extra))
	head, err = streamingRequestHeaders(req)
	if err != nil {
		return err
	}
	if len(head) != shape.Header {
		return fmt.Errorf("header byte mismatch")
	}
	var writes []writeEvent
	out := &observedWriter{destination: c, observe: func(e writeEvent) { writes = append(writes, e); row["request_writes"] = writes }}
	if _, err = out.Write(head); err != nil {
		return err
	}
	response, err := http.ReadResponse(bufio.NewReader(c), req)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	row["ack_headers_ms"] = float64(time.Since(start).Microseconds()) / 1000
	if response.StatusCode != 200 {
		return fmt.Errorf("HTTP %d", response.StatusCode)
	}
	command, err := paddedJSON(s, shape.Data)
	if err != nil {
		return err
	}
	if err = ordinaryChunk(out, command, false, nil); err != nil {
		return err
	}
	err = verifyPattern(response.Body, s.N, func() { row["first_payload_ms"] = float64(time.Since(start).Microseconds()) / 1000 })
	if err != nil {
		return err
	}
	receipt, err := paddedJSON(0, shape.End)
	if err != nil {
		return err
	}
	// Receipt and HTTP terminator share one Write, matching the N1 FIN phase.
	frame := append([]byte(fmt.Sprintf("%x\r\n", len(receipt))), receipt...)
	frame = append(frame, []byte("\r\n0\r\n\r\n")...)
	if _, err = out.Write(frame); err != nil {
		return err
	}
	return observeTLSClose(c)
}
