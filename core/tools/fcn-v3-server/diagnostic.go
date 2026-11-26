package main

import (
	"context"
	"encoding/json"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/quic-go"
	"github.com/metacubex/quic-go/qlog"
	"github.com/metacubex/quic-go/qlogwriter"
)

const (
	diagnosticBuckets = 120
	diagnosticPeriod  = 250 * time.Millisecond
)

type diagnosticBucket struct {
	Period       int     `json:"period"`
	StreamBytes  int64   `json:"stream_bytes,omitempty"`
	DatagramsOut int     `json:"datagrams_out,omitempty"`
	DatagramsIn  int     `json:"datagrams_in,omitempty"`
	Acks         int     `json:"acks,omitempty"`
	Lost         int     `json:"lost,omitempty"`
	Blocked      int     `json:"blocked,omitempty"`
	PTO          uint32  `json:"pto,omitempty"`
	SmoothedRTT  float64 `json:"smoothed_rtt_ms,omitempty"`
	Cwnd         int     `json:"cwnd_bytes,omitempty"`
	InFlight     int     `json:"in_flight_bytes,omitempty"`
}

type diagnosticTrace struct {
	mu      sync.Mutex
	id      uint64
	start   time.Time
	buckets [diagnosticBuckets]diagnosticBucket
}

func newDiagnosticTracer() func(context.Context, bool, quic.ConnectionID) qlogwriter.Trace {
	var connections atomic.Uint64
	return func(context.Context, bool, quic.ConnectionID) qlogwriter.Trace {
		id := connections.Add(1)
		if id > 256 {
			return nil
		}
		return &diagnosticTrace{id: id, start: time.Now()}
	}
}

func (t *diagnosticTrace) AddProducer() qlogwriter.Recorder { return t }
func (*diagnosticTrace) SupportsSchemas(schema string) bool { return schema == qlog.EventSchema }

func (t *diagnosticTrace) RecordEvent(event qlogwriter.Event) {
	i := int(time.Since(t.start) / diagnosticPeriod)
	if i >= len(t.buckets) {
		return
	}

	t.mu.Lock()
	defer t.mu.Unlock()
	b := &t.buckets[i]
	switch event := event.(type) {
	case qlog.PacketSent:
		for _, f := range event.Frames {
			switch frame := f.Frame.(type) {
			case *qlog.StreamFrame:
				b.StreamBytes += frame.Length
			case *qlog.DatagramFrame:
				b.DatagramsOut++
			case *qlog.DataBlockedFrame, *qlog.StreamDataBlockedFrame:
				b.Blocked++
			}
		}
	case qlog.PacketReceived:
		for _, f := range event.Frames {
			switch f.Frame.(type) {
			case *qlog.AckFrame:
				b.Acks++
			case *qlog.DatagramFrame:
				b.DatagramsIn++
			}
		}
	case qlog.PacketLost:
		b.Lost++
	case qlog.PTOCountUpdated:
		b.PTO = max(b.PTO, event.PTOCount)
	case qlog.MetricsUpdated:
		b.SmoothedRTT = float64(event.SmoothedRTT) / float64(time.Millisecond)
		b.Cwnd = event.CongestionWindow
		b.InFlight = event.BytesInFlight
	}
}

func (t *diagnosticTrace) Close() error {
	t.mu.Lock()
	defer t.mu.Unlock()
	buckets := make([]diagnosticBucket, 0, diagnosticBuckets)
	for i, b := range t.buckets {
		if b == (diagnosticBucket{}) {
			continue
		}
		b.Period = i
		buckets = append(buckets, b)
	}
	return json.NewEncoder(os.Stdout).Encode(struct {
		Event       string             `json:"event"`
		Connection  uint64             `json:"connection"`
		StartUnixMS int64              `json:"start_unix_ms"`
		BucketMS    int64              `json:"bucket_ms"`
		Buckets     []diagnosticBucket `json:"buckets"`
	}{"quic_progress", t.id, t.start.UnixMilli(), diagnosticPeriod.Milliseconds(), buckets})
}
