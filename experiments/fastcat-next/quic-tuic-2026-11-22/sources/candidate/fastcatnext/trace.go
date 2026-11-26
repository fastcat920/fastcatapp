package fastcatnext

import (
	"context"
	quic "github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/qlog"
	"github.com/metacubex/quic-go/qlogwriter"
	"io"
	"sync"
	"sync/atomic"
	"time"
)

// Event contains only timings and counters, never credentials, destinations,
// packet bodies, connection IDs or TLS key material. Trace is opt-in.
type Event struct {
	Session           uint64 `json:"session,omitempty"`
	CwndBytes         int64  `json:"cwnd_bytes,omitempty"`
	BytesInFlight     int64  `json:"bytes_in_flight,omitempty"`
	SmoothedRTTUS     int64  `json:"smoothed_rtt_us,omitempty"`
	BlockedSent       int64  `json:"blocked_sent,omitempty"`
	BlockedReceived   int64  `json:"blocked_received,omitempty"`
	WindowUpdatesSent int64  `json:"window_updates_sent,omitempty"`
	Stage             string `json:"stage"`
	Carrier           string `json:"carrier"`
	DurationUS        int64  `json:"duration_us,omitempty"`
	OK                bool   `json:"ok"`
	ReadBytes         int64  `json:"read_bytes,omitempty"`
	WrittenBytes      int64  `json:"written_bytes,omitempty"`
	ReadWaitUS        int64  `json:"read_wait_us,omitempty"`
	WriteWaitUS       int64  `json:"write_wait_us,omitempty"`
	PacketsSent       int64  `json:"packets_sent,omitempty"`
	PacketsReceived   int64  `json:"packets_received,omitempty"`
	DeclaredLost      int64  `json:"declared_lost,omitempty"`
	MaxPTO            int64  `json:"max_pto,omitempty"`
}
type Trace func(Event)

func emitStage(trace Trace, carrier, stage string, start time.Time, err error) {
	if trace != nil {
		trace(Event{Stage: stage, Carrier: carrier, DurationUS: time.Since(start).Microseconds(), OK: err == nil})
	}
}

var traceSession atomic.Uint64

type quicTrace struct {
	sent, received, lost, pto, cwnd, inFlight, rtt, blockedSent, blockedReceived, updatesSent atomic.Int64
	producers                                                                                 atomic.Int64
	trace                                                                                     Trace
	started                                                                                   time.Time
	side                                                                                      string
	session                                                                                   uint64
}
type statsRecorder struct {
	stats *quicTrace
	once  sync.Once
}

func (r *statsRecorder) RecordEvent(e qlogwriter.Event) { r.stats.RecordEvent(e) }
func (r *statsRecorder) Close() error {
	r.once.Do(func() {
		t := r.stats
		if t.producers.Add(-1) == 0 && t.trace != nil {
			t.trace(t.snapshot(t.side+"_quic_end", t.started, nil))
		}
	})
	return nil
}
func (t *quicTrace) AddProducer() qlogwriter.Recorder {
	t.producers.Add(1)
	return &statsRecorder{stats: t}
}
func (t *quicTrace) SupportsSchemas(string) bool { return true }
func frameCounts(frames []qlog.Frame) (blocked, updates int64) {
	for _, f := range frames {
		switch f.Frame.(type) {
		case *qlog.DataBlockedFrame, *qlog.StreamDataBlockedFrame:
			blocked++
		case *qlog.MaxDataFrame, *qlog.MaxStreamDataFrame:
			updates++
		}
	}
	return
}
func (t *quicTrace) RecordEvent(e qlogwriter.Event) {
	switch e.Name() {
	case "transport:packet_sent":
		t.sent.Add(1)
	case "transport:packet_received":
		t.received.Add(1)
	case "recovery:packet_lost":
		t.lost.Add(1)
	}
	switch p := e.(type) {
	case qlog.PTOCountUpdated:
		setMax(&t.pto, int64(p.PTOCount))
	case qlog.MetricsUpdated:
		if p.CongestionWindow > 0 {
			t.cwnd.Store(int64(p.CongestionWindow))
		}
		t.inFlight.Store(int64(p.BytesInFlight))
		if p.SmoothedRTT > 0 {
			t.rtt.Store(p.SmoothedRTT.Microseconds())
		}
	case qlog.PacketSent:
		b, u := frameCounts(p.Frames)
		t.blockedSent.Add(b)
		t.updatesSent.Add(u)
	case qlog.PacketReceived:
		b, _ := frameCounts(p.Frames)
		t.blockedReceived.Add(b)
	}
}
func (t *quicTrace) snapshot(stage string, start time.Time, err error) Event {
	return Event{Session: t.session, CwndBytes: t.cwnd.Load(), BytesInFlight: t.inFlight.Load(), SmoothedRTTUS: t.rtt.Load(), BlockedSent: t.blockedSent.Load(), BlockedReceived: t.blockedReceived.Load(), WindowUpdatesSent: t.updatesSent.Load(), Stage: stage, Carrier: "quic", DurationUS: time.Since(start).Microseconds(), OK: err == nil, PacketsSent: t.sent.Load(), PacketsReceived: t.received.Load(), DeclaredLost: t.lost.Load(), MaxPTO: t.pto.Load()}
}
func attachQUICTrace(cfg *quic.Config, stats *quicTrace) {
	cfg.Tracer = func(context.Context, bool, quic.ConnectionID) qlogwriter.Trace { return stats }
}

func attachServerQUICTrace(cfg *quic.Config, trace Trace) {
	if trace == nil {
		return
	}
	cfg.Tracer = func(ctx context.Context, _ bool, _ quic.ConnectionID) qlogwriter.Trace {
		t := &quicTrace{trace: trace, started: time.Now(), side: "server", session: traceSession.Add(1)}
		go func() {
			ticker := time.NewTicker(5 * time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-ctx.Done():
					return
				case <-ticker.C:
					trace(t.snapshot("server_quic_progress", t.started, nil))
				}
			}
		}()
		return t
	}
}

type measuredCopy struct{ read, written, reading, writing, maxRead, maxWrite atomic.Int64 }
type measuredReader struct {
	r io.Reader
	m *measuredCopy
}

func (r measuredReader) Read(p []byte) (int, error) {
	start := time.Now()
	r.m.reading.Store(start.UnixNano())
	n, e := r.r.Read(p)
	r.m.reading.Store(0)
	r.m.read.Add(int64(n))
	setMax(&r.m.maxRead, time.Since(start).Microseconds())
	return n, e
}

type measuredWriter struct {
	w io.Writer
	m *measuredCopy
}

func (w measuredWriter) Write(p []byte) (int, error) {
	start := time.Now()
	w.m.writing.Store(start.UnixNano())
	n, e := w.w.Write(p)
	w.m.writing.Store(0)
	w.m.written.Add(int64(n))
	setMax(&w.m.maxWrite, time.Since(start).Microseconds())
	return n, e
}
func setMax(v *atomic.Int64, n int64) {
	for old := v.Load(); n > old; old = v.Load() {
		if v.CompareAndSwap(old, n) {
			return
		}
	}
}
func copyTrace(ctx context.Context, dst io.Writer, src io.Reader, trace Trace, carrier, stage string) (int64, error) {
	if trace == nil {
		return io.Copy(dst, src)
	}
	m := &measuredCopy{}
	start := time.Now()
	done := make(chan struct{})
	finished := make(chan struct{})
	go func() {
		defer close(finished)
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-done:
				return
			case <-ctx.Done():
				return
			case <-ticker.C:
				rw, ww := int64(0), int64(0)
				if t := m.reading.Load(); t != 0 {
					rw = time.Since(time.Unix(0, t)).Microseconds()
				}
				if t := m.writing.Load(); t != 0 {
					ww = time.Since(time.Unix(0, t)).Microseconds()
				}
				if rw > 500000 || ww > 500000 {
					trace(Event{Stage: stage + "_blocked", Carrier: carrier, DurationUS: time.Since(start).Microseconds(), ReadBytes: m.read.Load(), WrittenBytes: m.written.Load(), ReadWaitUS: rw, WriteWaitUS: ww})
				}
			}
		}
	}()
	n, e := io.CopyBuffer(measuredWriter{dst, m}, measuredReader{src, m}, make([]byte, 32<<10))
	close(done)
	<-finished
	trace(Event{Stage: stage + "_end", Carrier: carrier, DurationUS: time.Since(start).Microseconds(), OK: e == nil, ReadBytes: m.read.Load(), WrittenBytes: m.written.Load(), ReadWaitUS: m.maxRead.Load(), WriteWaitUS: m.maxWrite.Load()})
	return n, e
}
