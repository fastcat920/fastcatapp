package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"time"
)

// Each Write is exactly one encoded N1 record. Keep HTTP chunk delimiters in
// the same plaintext TLS Write, and append the terminating HTTP chunk to FIN.
// No timer, lookahead or artificial waiting is introduced.
type chunkBatchWriter struct {
	destination io.Writer
	ended       bool
	observe     func(serverWriteEvent)
	maxWrite    int
}

func (w *chunkBatchWriter) Write(p []byte) (int, error) {
	if w.ended {
		return 0, io.ErrClosedPipe
	}
	if len(p) < 8 || int(binary.BigEndian.Uint16(p))+2 != len(p) {
		return 0, fmt.Errorf("expected one complete record")
	}
	fin := binary.BigEndian.Uint16(p[6:8]) == 0
	frame := append([]byte(fmt.Sprintf("%x\r\n", len(p))), p...)
	frame = append(frame, '\r', '\n')
	if fin {
		frame = append(frame, []byte("0\r\n\r\n")...)
	}
	if w.maxWrite > 0 && len(frame) > w.maxWrite {
		return 0, fmt.Errorf("complete write exceeds configured cap")
	}
	if w.observe != nil {
		stage := "n1-data"
		if fin {
			stage = "n1-fin"
		} else if bytes.HasPrefix(p[8:], []byte("HTTP/1.1 ")) {
			stage = "target-http-prefix"
		}
		w.observe(serverWriteEvent{Stage: stage, PlainBytes: len(frame), PayloadBytes: int(binary.BigEndian.Uint16(p[6:8]))})
	}
	for len(frame) > 0 {
		n, e := w.destination.Write(frame)
		if e != nil {
			return 0, e
		}
		if n == 0 {
			return 0, io.ErrShortWrite
		}
		frame = frame[n:]
	}
	w.ended = fin
	return len(p), nil
}

func serveCoalesced(w http.ResponseWriter, r *http.Request, up net.Conn, observers ...func(serverWriteEvent)) error {
	return serveCoalescedLimited(w, r, up, 0, observers...)
}

func serveCoalescedLimited(w http.ResponseWriter, r *http.Request, up net.Conn, limit int, observers ...func(serverWriteEvent)) error {
	if limit != 0 && limit != 16384 {
		return fmt.Errorf("invalid complete write cap")
	}
	var observe func(serverWriteEvent)
	if len(observers) > 0 {
		observe = observers[0]
	}
	hijacker, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "Service unavailable", 503)
		return fmt.Errorf("HTTP/1 hijacking unavailable")
	}
	connection, buffer, e := hijacker.Hijack()
	if e != nil {
		return e
	}
	defer connection.Close()
	// Detach from net/http's connReader and Body lifecycle after Hijack.
	// Preserve only bytes that were already buffered with the request headers.
	prefix := make([]byte, buffer.Reader.Buffered())
	if _, e = io.ReadFull(buffer.Reader, prefix); e != nil {
		return e
	}
	input := bufio.NewReader(io.MultiReader(bytes.NewReader(prefix), connection))
	var requestBody io.Reader
	chunked := len(r.TransferEncoding) == 1 && r.TransferEncoding[0] == "chunked"
	if chunked {
		requestBody = httputil.NewChunkedReader(input)
	} else if len(r.TransferEncoding) == 0 && r.ContentLength >= 0 {
		requestBody = io.LimitReader(input, r.ContentLength)
	} else {
		return fmt.Errorf("unsupported request framing")
	}
	sessionDeadline := time.Now().Add(2 * time.Minute)
	connection.SetDeadline(sessionDeadline)
	// This response must remain immediate. Waiting for target payload here
	// would deadlock protocols where the application waits for Dial/CONNECT.
	if _, e = fmt.Fprintf(buffer, "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nDate: %s\r\nTransfer-Encoding: chunked\r\n\r\n", time.Now().UTC().Format(http.TimeFormat)); e != nil {
		return e
	}
	headerBytes := buffer.Writer.Buffered()
	if e = buffer.Flush(); e != nil {
		return e
	}
	if observe != nil {
		observe(serverWriteEvent{Stage: "response-headers", PlainBytes: headerBytes})
	}
	record := &records{r: requestBody, w: &chunkBatchWriter{destination: connection, observe: observe, maxWrite: limit}}
	if limit > 0 {
		record.payloadLimit = limit - 47
	}
	done := make(chan error, 1)
	go func() {
		e := receiveRecords(up, record)
		if c, ok := up.(*net.TCPConn); ok {
			c.CloseWrite()
		}
		if e != nil {
			up.Close()
		}
		done <- e
	}()
	down := sendRecords(record, up)
	if down != nil {
		up.Close()
		connection.SetReadDeadline(time.Now())
	}
	upError := <-done
	// FIN ends N1 forwarding, not the outer HTTP request. Closing with its
	// chunk terminator unread can cause TCP RST and truncate queued output.
	// Wait only for outer EOF, not for more business data, under a hard bound.
	if down == nil && upError == nil {
		drainDeadline := time.Now().Add(5 * time.Second)
		if drainDeadline.After(sessionDeadline) {
			drainDeadline = sessionDeadline
		}
		connection.SetReadDeadline(drainDeadline)
		var extra [1]byte
		if n, e := io.ReadFull(requestBody, extra[:]); n != 0 || e != io.EOF {
			upError = fmt.Errorf("invalid outer request ending: bytes=%d error=%v", n, e)
		}
		if upError == nil && chunked {
			if line, e := input.ReadSlice('\n'); e != nil || !bytes.Equal(line, []byte("\r\n")) {
				upError = fmt.Errorf("unsupported HTTP trailers")
			}
		}
		if upError == nil {
			// Finish TLS in both directions before closing the raw socket. An
			// immediate raw close can reset a peer's in-flight close_notify.
			connection.SetDeadline(drainDeadline)
			if closer, ok := connection.(interface{ CloseWrite() error }); ok {
				if e := closer.CloseWrite(); e != nil {
					upError = e
				}
			}
			if upError == nil {
				if _, e := input.ReadByte(); e != io.EOF {
					upError = fmt.Errorf("invalid TLS ending: %v", e)
				}
			}
		}
	}
	connection.SetReadDeadline(time.Now())
	if down != nil {
		return down
	}
	return upError
}
