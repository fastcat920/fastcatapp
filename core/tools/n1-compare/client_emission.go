package main

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
)

// Only lengths and framing categories leave this observer. It never records
// capability cookies, targets, payload bytes or TLS secrets.
type writeEvent struct {
	Bytes     int    `json:"bytes"`
	Shape     string `json:"shape"`
	BodyBytes int    `json:"body_bytes,omitempty"`
}
type observedWriter struct {
	destination io.Writer
	observe     func(writeEvent)
}

func (w *observedWriter) Write(p []byte) (int, error) {
	n, e := w.destination.Write(p)
	if w.observe != nil {
		shape := "http-chunk"
		if bytes.HasPrefix(p, []byte("POST ")) {
			shape = "request-headers"
		}
		if bytes.Equal(p, []byte("0\r\n\r\n")) {
			shape = "http-ending-only"
		}
		body := 0
		if i := bytes.Index(p, []byte("\r\n")); shape == "http-chunk" && i > 0 {
			v, err := strconv.ParseInt(string(p[:i]), 16, 32)
			if err == nil {
				body = int(v)
			}
		}
		w.observe(writeEvent{Bytes: n, Shape: shape, BodyBytes: body})
	}
	return n, e
}

// Let net/http validate and serialize the exact headers of an empty chunked
// request, then retain only those headers. The real body follows incrementally.
// This is bounded to the locally generated request; no business data is held.
func streamingRequestHeaders(req *http.Request) ([]byte, error) {
	clone := req.Clone(req.Context())
	clone.Body = io.NopCloser(strings.NewReader(""))
	clone.ContentLength = -1
	clone.TransferEncoding = []string{"chunked"}
	var b bytes.Buffer
	if e := clone.Write(&b); e != nil {
		return nil, e
	}
	data := b.Bytes()
	boundary := bytes.Index(data, []byte("\r\n\r\n"))
	if boundary < 0 || !bytes.Equal(data[boundary+4:], []byte("0\r\n\r\n")) {
		return nil, fmt.Errorf("unexpected chunked header serialization")
	}
	return data[:boundary+4], nil
}
