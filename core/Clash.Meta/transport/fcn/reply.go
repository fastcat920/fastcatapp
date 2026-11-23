package fcn

import (
	"io"
	"net"
	"sync"
	"time"
)

// replyPrefix preserves the FCN/1 byte stream: exactly one status byte, then
// target payload. A short timer preserves silent/server-first target behavior.
// No request, payload or acknowledgement is replayed at the application level.
type replyPrefix struct {
	mu              sync.Mutex
	dst             io.Writer
	pending, closed bool
	err             error
	timer           *time.Timer
	trace           Trace
	started         time.Time
}

func newReplyPrefix(dst io.Writer, delay time.Duration, trace Trace) *replyPrefix {
	w := &replyPrefix{dst: dst, pending: true, trace: trace, started: time.Now()}
	w.mu.Lock()
	w.timer = time.AfterFunc(delay, func() { _ = w.Flush() })
	w.mu.Unlock()
	return w
}
func (w *replyPrefix) Write(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	w.mu.Lock()
	if w.closed {
		w.mu.Unlock()
		return 0, net.ErrClosed
	}
	if w.err != nil {
		e := w.err
		w.mu.Unlock()
		return 0, e
	}
	combined := w.pending
	if combined {
		w.pending = false
		w.timer.Stop()
	}
	var n int
	var e error
	if combined {
		b := make([]byte, len(p)+1)
		copy(b[1:], p)
		n, e = w.dst.Write(b)
		if n < len(b) && e == nil {
			e = io.ErrShortWrite
		}
		if n > 0 {
			n--
		}
		if n > len(p) {
			n = len(p)
		}
	} else {
		n, e = w.dst.Write(p)
		if n < len(p) && e == nil {
			e = io.ErrShortWrite
		}
	}
	if e != nil {
		w.err = e
	}
	w.mu.Unlock()
	if combined && w.trace != nil {
		w.trace(Event{Stage: "reply_combined", Carrier: "quic", DurationUS: time.Since(w.started).Microseconds(), OK: e == nil, WrittenBytes: int64(n)})
	}
	return n, e
}
func (w *replyPrefix) Flush() error {
	w.mu.Lock()
	if w.closed {
		w.mu.Unlock()
		return net.ErrClosed
	}
	if !w.pending {
		e := w.err
		w.mu.Unlock()
		return e
	}
	w.pending = false
	w.timer.Stop()
	n, e := w.dst.Write([]byte{0})
	if n != 1 && e == nil {
		e = io.ErrShortWrite
	}
	if e != nil {
		w.err = e
	}
	w.mu.Unlock()
	if w.trace != nil {
		w.trace(Event{Stage: "reply_status_flushed", Carrier: "quic", DurationUS: time.Since(w.started).Microseconds(), OK: e == nil})
	}
	return e
}
func (w *replyPrefix) Stop() { w.mu.Lock(); w.closed = true; w.timer.Stop(); w.mu.Unlock() }
