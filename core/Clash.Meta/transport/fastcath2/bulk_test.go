package h2client

import (
	"bytes"
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"sync"
	"testing"
	"time"
)

type flushedTestWriter struct{ http.ResponseWriter }

func (w flushedTestWriter) Write(p []byte) (int, error) {
	n, e := w.ResponseWriter.Write(p)
	w.ResponseWriter.(http.Flusher).Flush()
	return n, e
}
func TestFourLargeStreamsPreservePayload(t *testing.T) {
	c := testClient(t, true, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		io.Copy(flushedTestWriter{w}, r.Body)
	})
	payload := bytes.Repeat([]byte("large-stream-check"), 250000)
	expected := sha256.Sum256(payload)
	start := time.Now()
	var wg sync.WaitGroup
	failures := make(chan error, 4)
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
			defer cancel()
			conn, e := c.Dial(ctx, "echo.test:443")
			if e != nil {
				failures <- e
				return
			}
			defer conn.Close()
			conn.SetDeadline(time.Now().Add(12 * time.Second))
			done := make(chan error, 1)
			go func() {
				_, e := io.Copy(conn, bytes.NewReader(payload))
				if e == nil {
					e = conn.(interface{ CloseWrite() error }).CloseWrite()
				}
				done <- e
			}()
			hash := sha256.New()
			n, e := io.Copy(hash, conn)
			if e != nil {
				conn.Close()
			}
			writeErr := <-done
			if e == nil {
				e = writeErr
			}
			if e == nil && (n != int64(len(payload)) || !bytes.Equal(hash.Sum(nil), expected[:])) {
				e = fmt.Errorf("payload mismatch")
			}
			failures <- e
		}()
	}
	wg.Wait()
	close(failures)
	for e := range failures {
		if e != nil {
			t.Fatal(e)
		}
	}
	t.Logf("verified %d bytes each way in %s", 4*len(payload), time.Since(start))
}
