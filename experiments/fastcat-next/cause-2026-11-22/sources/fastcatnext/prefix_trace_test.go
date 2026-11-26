package fastcatnext

import (
	"github.com/metacubex/quic-go/qlog"
	"testing"
	"time"
)

func TestPrefixTraceMetadataAndBound(t *testing.T) {
	var events []Event
	s := &quicTrace{prefix: true, side: "server", session: 1, started: time.Now(), trace: func(e Event) { events = append(events, e) }}
	h := qlog.PacketHeader{PacketType: qlog.PacketType("1RTT"), PacketNumber: 7}
	s.RecordEvent(qlog.PacketSent{Header: h, Frames: []qlog.Frame{{Frame: &qlog.StreamFrame{StreamID: 4, Offset: 0, Length: 1}}}})
	s.RecordEvent(qlog.PacketLost{Header: h})
	s.RecordEvent(qlog.PacketReceived{Header: h, Frames: []qlog.Frame{{Frame: &qlog.StreamFrame{StreamID: 4, Offset: 0, Length: 1}}}})
	if len(events) != 3 || events[0].Packet != 7 || events[0].FrameLength != 1 || events[1].Stage != "server_stream_prefix_lost" || events[2].Stage != "server_stream_prefix_received" {
		t.Fatal(events)
	}
	before := len(events)
	s.RecordEvent(qlog.PacketSent{Header: h, Frames: []qlog.Frame{{Frame: &qlog.StreamFrame{StreamID: 4, Offset: 8192, Length: 100}}}})
	if len(events) != before {
		t.Fatal("prefix capture exceeded offset bound")
	}
	s.metaEvents.Store(8192)
	s.RecordEvent(qlog.PacketSent{Header: h, Frames: []qlog.Frame{{Frame: &qlog.StreamFrame{StreamID: 4, Offset: 0, Length: 1}}}})
	if len(events) != before || s.metaDropped.Load() == 0 {
		t.Fatal("metadata output not bounded")
	}
}
