package fcn

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
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
	BudgetWaitUS      int64  `json:"budget_wait_us,omitempty"`
	BudgetYields      int64  `json:"budget_yields,omitempty"`
	TotalReadWaitUS   int64  `json:"total_read_wait_us,omitempty"`
	TotalWriteWaitUS  int64  `json:"total_write_wait_us,omitempty"`
	PeerTag           string `json:"peer_tag,omitempty"`
	ECNMark           string `json:"ecn_mark,omitempty"`
	DropReason        string `json:"drop_reason,omitempty"`
	ECNState          string `json:"ecn_state,omitempty"`
	DroppedPackets    int64  `json:"dropped_packets,omitempty"`
	PacketBytes       int64  `json:"packet_bytes,omitempty"`
	GSO               *bool  `json:"gso,omitempty"`
	Packet            uint64 `json:"packet,omitempty"`
	PacketSpace       string `json:"packet_space,omitempty"`
	FrameOffset       int64  `json:"frame_offset,omitempty"`
	FrameLength       int64  `json:"frame_length,omitempty"`
	MetaDropped       int64  `json:"meta_dropped,omitempty"`
	AtUnixUS          int64  `json:"at_unix_us,omitempty"`
	RequestTag        string `json:"request_tag,omitempty"`
	Stream            uint64 `json:"stream,omitempty"`
	PTOEvents         int64  `json:"pto_events,omitempty"`
	CurrentPTO        int64  `json:"current_pto,omitempty"`
	LatestRTTUS       int64  `json:"latest_rtt_us,omitempty"`
	MinRTTUS          int64  `json:"min_rtt_us,omitempty"`
	WireBytesSent     int64  `json:"wire_bytes_sent,omitempty"`
	WireBytesReceived int64  `json:"wire_bytes_received,omitempty"`
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
	dropped                                                                                   atomic.Int64
	prefix                                                                                    bool
	metaMu                                                                                    sync.Mutex
	interest                                                                                  map[tracePacket]int64
	metaEvents, metaDropped                                                                   atomic.Int64
	wireSent, wireReceived                                                                    atomic.Int64
	sent, received, lost, pto, cwnd, inFlight, rtt, blockedSent, blockedReceived, updatesSent atomic.Int64
	producers                                                                                 atomic.Int64
	ptoEvents, currentPTO, latestRTT, minRTT                                                  atomic.Int64
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
	case "transport:packet_dropped":
		t.dropped.Add(1)
	case "recovery:packet_lost":
		t.lost.Add(1)
	}
	switch p := e.(type) {
	case qlog.PacketDropped:
		if t.prefix {
			t.emitMeta(Event{AtUnixUS: time.Now().UnixMicro(), Session: t.session, Stage: t.side + "_packet_dropped", Carrier: "quic", DropReason: string(p.Trigger), PacketBytes: int64(p.Raw.Length), Packet: uint64(p.Header.PacketNumber), PacketSpace: string(p.Header.PacketType)})
		}
	case qlog.ECNStateUpdated:
		if t.prefix {
			t.emitMeta(Event{AtUnixUS: time.Now().UnixMicro(), Session: t.session, Stage: t.side + "_ecn_state", Carrier: "quic", ECNState: string(p.State), DropReason: p.Trigger})
		}
	case qlog.PTOCountUpdated:
		n := int64(p.PTOCount)
		old := t.currentPTO.Swap(n)
		if n > old {
			t.ptoEvents.Add(n - old)
		}
		setMax(&t.pto, n)
		if t.prefix && n > old {
			t.trace(t.snapshot(t.side+"_pto_raised", t.started, nil))
		}
	case qlog.MetricsUpdated:
		if p.LatestRTT > 0 {
			t.latestRTT.Store(p.LatestRTT.Microseconds())
		}
		if p.MinRTT > 0 {
			t.minRTT.Store(p.MinRTT.Microseconds())
		}
		if p.CongestionWindow > 0 {
			t.cwnd.Store(int64(p.CongestionWindow))
		}
		t.inFlight.Store(int64(p.BytesInFlight))
		if p.SmoothedRTT > 0 {
			t.rtt.Store(p.SmoothedRTT.Microseconds())
		}
	case qlog.PacketLost:
		if t.prefix {
			t.recordPrefixLost(p)
		}
	case qlog.PacketSent:
		if t.prefix {
			t.recordPrefixFrames(p.Header, p.Frames, true, int64(p.Raw.Length), string(p.ECN))
		}
		t.wireSent.Add(int64(p.Raw.Length))
		b, u := frameCounts(p.Frames)
		t.blockedSent.Add(b)
		t.updatesSent.Add(u)
	case qlog.PacketReceived:
		if t.prefix {
			t.recordPrefixFrames(p.Header, p.Frames, false, int64(p.Raw.Length), string(p.ECN))
		}
		t.wireReceived.Add(int64(p.Raw.Length))
		b, _ := frameCounts(p.Frames)
		t.blockedReceived.Add(b)
	}
}
func (t *quicTrace) snapshot(stage string, start time.Time, err error) Event {
	return Event{DroppedPackets: t.dropped.Load(), MetaDropped: t.metaDropped.Load(), AtUnixUS: time.Now().UnixMicro(), PTOEvents: t.ptoEvents.Load(), CurrentPTO: t.currentPTO.Load(), LatestRTTUS: t.latestRTT.Load(), MinRTTUS: t.minRTT.Load(), WireBytesSent: t.wireSent.Load(), WireBytesReceived: t.wireReceived.Load(), Session: t.session, CwndBytes: t.cwnd.Load(), BytesInFlight: t.inFlight.Load(), SmoothedRTTUS: t.rtt.Load(), BlockedSent: t.blockedSent.Load(), BlockedReceived: t.blockedReceived.Load(), WindowUpdatesSent: t.updatesSent.Load(), Stage: stage, Carrier: "quic", DurationUS: time.Since(start).Microseconds(), OK: err == nil, PacketsSent: t.sent.Load(), PacketsReceived: t.received.Load(), DeclaredLost: t.lost.Load(), MaxPTO: t.pto.Load()}
}
func attachQUICTrace(cfg *quic.Config, stats *quicTrace) {
	cfg.Tracer = func(context.Context, bool, quic.ConnectionID) qlogwriter.Trace { return stats }
}

func attachServerQUICTrace(cfg *quic.Config, trace Trace, registry *sync.Map, prefix bool) {
	if trace == nil {
		return
	}
	cfg.Tracer = func(ctx context.Context, _ bool, _ quic.ConnectionID) qlogwriter.Trace {
		t := &quicTrace{prefix: prefix, trace: trace, started: time.Now(), side: "server", session: traceSession.Add(1)}
		if registry != nil {
			registry.Store(ctx, t)
		}
		go func() {
			if registry != nil {
				defer registry.Delete(ctx)
			}
			ticker := time.NewTicker(250 * time.Millisecond)
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

type measuredCopy struct {
	read, written, reading, writing, maxRead, maxWrite, totalRead, totalWrite atomic.Int64
	trace                                                                     Trace
	carrier, stage                                                            string
	slow                                                                      atomic.Int64
}
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
	elapsed := time.Since(start).Microseconds()
	setMax(&r.m.maxRead, elapsed)
	r.m.totalRead.Add(elapsed)
	if n > 0 && r.m.read.Load() == int64(n) {
		r.m.trace(Event{Stage: r.m.stage + "_first_data_ready", Carrier: r.m.carrier, ReadBytes: int64(n), ReadWaitUS: elapsed, OK: e == nil})
	}
	if elapsed >= 50000 && r.m.slow.Add(1) <= 8 {
		r.m.trace(Event{Stage: r.m.stage + "_read_wait", Carrier: r.m.carrier, ReadBytes: r.m.read.Load(), ReadWaitUS: elapsed, OK: e == nil})
	}
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
	elapsed := time.Since(start).Microseconds()
	setMax(&w.m.maxWrite, elapsed)
	w.m.totalWrite.Add(elapsed)
	if n > 0 && w.m.written.Load() == int64(n) {
		w.m.trace(Event{Stage: w.m.stage + "_first_write_accepted", Carrier: w.m.carrier, WrittenBytes: int64(n), WriteWaitUS: elapsed, OK: e == nil})
	}
	if elapsed >= 50000 && w.m.slow.Add(1) <= 8 {
		w.m.trace(Event{Stage: w.m.stage + "_write_wait", Carrier: w.m.carrier, WrittenBytes: w.m.written.Load(), WriteWaitUS: elapsed, OK: e == nil})
	}
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
	m := &measuredCopy{trace: trace, carrier: carrier, stage: stage}
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
	trace(Event{Stage: stage + "_end", Carrier: carrier, DurationUS: time.Since(start).Microseconds(), OK: e == nil, ReadBytes: m.read.Load(), WrittenBytes: m.written.Load(), ReadWaitUS: m.maxRead.Load(), WriteWaitUS: m.maxWrite.Load(), TotalReadWaitUS: m.totalRead.Load(), TotalWriteWaitUS: m.totalWrite.Load()})
	return n, e
}

func (t *quicTrace) progress(ctx context.Context) {
	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			t.trace(t.snapshot(t.side+"_quic_progress", t.started, nil))
		}
	}
}

// A one-way hash of a random per-OPEN nonce joins diagnostics across ends.
// Neither the nonce itself, credentials, target nor business payload is logged.
func diagnosticTag(n [16]byte) string { h := sha256.Sum256(n[:]); return hex.EncodeToString(h[:16]) }

type tracePacket struct {
	space  string
	number uint64
}

func (t *quicTrace) emitMeta(e Event) {
	if t.trace == nil {
		return
	}
	if t.metaEvents.Add(1) > 8192 {
		t.metaDropped.Add(1)
		return
	}
	t.trace(e)
}
func (t *quicTrace) recordPrefixFrames(h qlog.PacketHeader, frames []qlog.Frame, sent bool, packetBytes int64, ecn string) {
	for _, frame := range frames {
		f, ok := frame.Frame.(*qlog.StreamFrame)
		if !ok || f.Offset >= 8192 || f.Length <= 0 {
			continue
		}
		key := tracePacket{string(h.PacketType), uint64(h.PacketNumber)}
		if sent {
			t.metaMu.Lock()
			if t.interest == nil {
				t.interest = make(map[tracePacket]int64)
			}
			if len(t.interest) < 4096 {
				t.interest[key] = packetBytes
			} else {
				t.metaDropped.Add(1)
			}
			t.metaMu.Unlock()
		}
		stage := t.side + "_stream_prefix_received"
		if sent {
			stage = t.side + "_stream_prefix_sent"
		}
		t.emitMeta(Event{AtUnixUS: time.Now().UnixMicro(), Session: t.session, Stage: stage, Carrier: "quic", OK: true, Stream: uint64(f.StreamID), Packet: key.number, PacketBytes: packetBytes, ECNMark: ecn, PacketSpace: key.space, FrameOffset: f.Offset, FrameLength: f.Length})
	}
}
func (t *quicTrace) recordPrefixLost(p qlog.PacketLost) {
	key := tracePacket{string(p.Header.PacketType), uint64(p.Header.PacketNumber)}
	t.metaMu.Lock()
	interest := t.interest[key]
	t.metaMu.Unlock()
	if interest > 0 {
		t.emitMeta(Event{AtUnixUS: time.Now().UnixMicro(), Session: t.session, Stage: t.side + "_stream_prefix_lost", Carrier: "quic", PacketBytes: interest, Packet: key.number, PacketSpace: key.space})
	}
}

func diagnosticPeerTag(salt []byte, addr string) string {
	if len(salt) != 32 {
		return ""
	}
	h := hmac.New(sha256.New, salt)
	h.Write([]byte("FCN-DIAG-PEER-1"))
	h.Write([]byte(addr))
	return hex.EncodeToString(h.Sum(nil)[:16])
}
