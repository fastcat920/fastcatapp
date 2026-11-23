package fcn

import (
	"github.com/metacubex/quic-go/qlog"
	"sync/atomic"
	"testing"
	"time"
)

func TestTransportTraceCountsWithoutPayload(t *testing.T) {
	var emitted atomic.Int64
	stats := &quicTrace{started: time.Now(), side: "server", trace: func(e Event) {
		emitted.Add(1)
		if e.WireBytesSent != 1200 || e.WireBytesReceived != 80 || e.PacketsSent != 1 || e.PacketsReceived != 1 || e.BlockedSent != 1 || e.BlockedReceived != 1 || e.WindowUpdatesSent != 1 || e.CwndBytes != 12345 || e.MaxPTO != 3 {
			t.Errorf("bad transport counters: %+v", e)
		}
	}}
	a, b := stats.AddProducer(), stats.AddProducer()
	a.RecordEvent(qlog.PacketSent{Raw: qlog.RawInfo{Length: 1200}, Frames: []qlog.Frame{{Frame: &qlog.DataBlockedFrame{}}, {Frame: &qlog.MaxDataFrame{}}}})
	b.RecordEvent(qlog.PacketReceived{Raw: qlog.RawInfo{Length: 80}, Frames: []qlog.Frame{{Frame: &qlog.StreamDataBlockedFrame{}}}})
	a.RecordEvent(qlog.MetricsUpdated{CongestionWindow: 12345, BytesInFlight: 100, SmoothedRTT: time.Millisecond})
	a.RecordEvent(qlog.PTOCountUpdated{PTOCount: 3})
	a.Close()
	a.Close()
	if emitted.Load() != 0 {
		t.Fatal("premature trace close")
	}
	b.Close()
	if emitted.Load() != 1 {
		t.Fatal("missing transport summary")
	}
}
