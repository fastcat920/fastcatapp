package fcn

import (
	"encoding/binary"
	quic "github.com/metacubex/quic-go"
	"io"
	"net"
	"os"
	"sync"
	"sync/atomic"
	"time"
)

// Kind 2 explicitly requests this extension. Never enabled for legacy kind 0.
const prefixCopyLimit = 8193 // one status byte plus at most 8 KiB of business data
const prefixCopyMagic = 0xfc31
const prefixCopyPackets = 12

type prefixCopyWriter struct {
	stream        io.Writer
	q             *quic.Conn
	id            uint64
	offset        int
	copies, bytes int
	trace         Trace
}

func (w *prefixCopyWriter) duplicate(p []byte) {
	for len(p) > 0 && w.offset < prefixCopyLimit && w.copies < prefixCopyPackets {
		n := len(p)
		if n > 1024 {
			n = 1024
		}
		if n > prefixCopyLimit-w.offset {
			n = prefixCopyLimit - w.offset
		}
		b := binary.BigEndian.AppendUint64(nil, w.id)
		b = binary.BigEndian.AppendUint16(b, prefixCopyMagic)
		b = binary.BigEndian.AppendUint16(b, uint16(w.offset))
		b = append(b, p[:n]...)
		// A full datagram queue drops the optional copy; reliable STREAM bytes remain canonical.
		w.copies++
		if w.q.SendDatagram(b) == nil {
			w.bytes += n
		}
		w.offset += n
		p = p[n:]
	}
	// No later bytes can be copied once the prefix boundary is crossed. Saturate
	// the cursor so arbitrarily long streams cannot wrap it on 32-bit builds.
	if len(p) > prefixCopyLimit-w.offset {
		w.offset = prefixCopyLimit
	} else {
		w.offset += len(p)
	}
}
func (w *prefixCopyWriter) Write(p []byte) (int, error) {
	n, e := w.stream.Write(p)
	if n > 0 {
		w.duplicate(p[:n])
	}
	return n, e
}

type prefixPart struct {
	offset int
	data   []byte
}
type prefixRawResult struct {
	data []byte
	err  error
}
type prefixCopyReader struct {
	raw                 io.Reader
	mu                  sync.Mutex
	parts               chan prefixPart
	future              chan prefixRawResult
	pending             bool
	rawOffset, pos      int
	data                []byte
	err                 error
	values              []byte
	known               []bool
	fast                bool
	done                chan struct{}
	ended               sync.Once
	unregister          func()
	deadline            atomic.Int64
	changed             chan struct{}
	received, delivered atomic.Int64
	trace               Trace
}

func newPrefixCopyReader(raw io.Reader, unregister func(), trace Trace) *prefixCopyReader {
	return &prefixCopyReader{raw: raw, parts: make(chan prefixPart, 16), future: make(chan prefixRawResult, 1), values: make([]byte, prefixCopyLimit), known: make([]bool, prefixCopyLimit), done: make(chan struct{}), unregister: unregister, changed: make(chan struct{}, 1), trace: trace}
}
func (r *prefixCopyReader) close() {
	r.ended.Do(func() {
		close(r.done)
		if r.unregister != nil {
			r.unregister()
		}
	})
}
func (r *prefixCopyReader) setDeadline(t time.Time) {
	var n int64
	if !t.IsZero() {
		n = t.UnixNano()
	}
	r.deadline.Store(n)
	select {
	case r.changed <- struct{}{}:
	default:
	}
}
func (r *prefixCopyReader) offer(b []byte) {
	if len(b) < 5 || len(b) > 1028 || binary.BigEndian.Uint16(b) != prefixCopyMagic {
		return
	}
	off := int(binary.BigEndian.Uint16(b[2:4]))
	if off+len(b)-4 > prefixCopyLimit {
		return
	}
	select {
	case <-r.done:
		return
	default:
	}
	part := prefixPart{off, append([]byte(nil), b[4:]...)}
	select {
	case r.parts <- part:
		r.received.Add(int64(len(part.data)))
		if r.trace != nil {
			r.trace(Event{Stage: "prefix_copy_received", Carrier: "quic", FrameOffset: int64(off), FrameLength: int64(len(part.data)), OK: true})
		}
	default:
	}
}
func (r *prefixCopyReader) remember(offset int, p []byte) error {
	for i, b := range p {
		at := offset + i
		if at >= prefixCopyLimit {
			break
		}
		if r.known[at] && r.values[at] != b {
			return ErrProtocol
		}
		r.known[at] = true
		r.values[at] = b
	}
	return nil
}
func (r *prefixCopyReader) consumeRaw(x prefixRawResult) error {
	start := r.rawOffset
	r.rawOffset += len(x.data)
	if e := r.remember(start, x.data); e != nil {
		return e
	}
	skip := r.pos - start
	if skip < 0 {
		return ErrProtocol
	}
	if skip > len(x.data) {
		skip = len(x.data)
	}
	r.data = x.data[skip:]
	r.err = x.err
	if ne, ok := r.err.(net.Error); ok && ne.Timeout() {
		d := r.deadline.Load()
		if d == 0 || time.Now().UnixNano() < d {
			r.err = nil
		}
	}
	if r.err == io.EOF && r.rawOffset < r.pos {
		return ErrProtocol
	}
	return nil
}
func (r *prefixCopyReader) startRaw() {
	if r.pending {
		return
	}
	r.pending = true
	go func() { b := make([]byte, 32<<10); n, e := r.raw.Read(b); r.future <- prefixRawResult{b[:n], e} }()
}
func (r *prefixCopyReader) Read(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	for {
		if r.fast {
			return r.raw.Read(p)
		}
		select {
		case <-r.done:
			return 0, net.ErrClosed
		default:
		}
		if d := r.deadline.Load(); d != 0 && time.Now().UnixNano() >= d {
			return 0, os.ErrDeadlineExceeded
		}
		if ne, ok := r.err.(net.Error); ok && ne.Timeout() {
			r.err = nil
		}
		if r.pending {
			select {
			case x := <-r.future:
				r.pending = false
				if e := r.consumeRaw(x); e != nil {
					return 0, e
				}
			default:
			}
		}
		for i := 0; i < 16; i++ {
			select {
			case part := <-r.parts:
				if e := r.remember(part.offset, part.data); e != nil {
					return 0, e
				}
			default:
				i = 16
			}
		}
		if len(r.data) > 0 {
			n := copy(p, r.data)
			r.data = r.data[n:]
			r.pos += n
			if len(r.data) == 0 && r.err != nil {
				e := r.err
				r.err = nil
				return n, e
			}
			return n, nil
		}
		if r.err != nil {
			e := r.err
			r.err = nil
			return 0, e
		}
		if r.pos < prefixCopyLimit && r.known[r.pos] {
			n := 0
			for n < len(p) && r.pos+n < prefixCopyLimit && r.known[r.pos+n] {
				p[n] = r.values[r.pos+n]
				n++
			}
			r.pos += n
			r.delivered.Add(int64(n))
			return n, nil
		}
		if r.pos >= prefixCopyLimit && r.rawOffset == r.pos && !r.pending {
			r.fast = true
			r.values = nil
			r.known = nil
			r.close()
			return r.raw.Read(p)
		}
		r.startRaw()
		var timer *time.Timer
		var tick <-chan time.Time
		if d := r.deadline.Load(); d != 0 {
			timer = time.NewTimer(time.Until(time.Unix(0, d)))
			tick = timer.C
		}
		var err error
		select {
		case x := <-r.future:
			r.pending = false
			err = r.consumeRaw(x)
		case part := <-r.parts:
			err = r.remember(part.offset, part.data)
		case <-r.changed:
		case <-tick:
			err = os.ErrDeadlineExceeded
		case <-r.done:
			err = net.ErrClosed
		}
		if timer != nil {
			timer.Stop()
		}
		if err != nil {
			return 0, err
		}
	}
}

// The reliable read may temporarily be pending while a copy is consumed. Closing
// the owning QUIC stream cancels that read; no unbounded pump or payload queue exists.
var _ io.Reader = (*prefixCopyReader)(nil)
