package fcn

import (
	"github.com/metacubex/quic-go/qlog"
	"testing"
	"time"
)

func TestPrefixTraceMetadataAndBound(t *testing.T) {
	var events []Event
	s := &quicTrace{prefix: true, side: "server", session: 1, started: time.Now(), trace: func(e Event) { events = append(events, e) }}
	h := qlog.PacketHeader{PacketType: qlog.PacketType("1RTT"), PacketNumber: 7}
	s.RecordEvent(qlog.PacketSent{Header: h, Raw: qlog.RawInfo{Length: 55}, Frames: []qlog.Frame{{Frame: &qlog.StreamFrame{StreamID: 4, Offset: 0, Length: 1}}}})
	s.RecordEvent(qlog.PacketLost{Header: h})
	s.RecordEvent(qlog.PacketReceived{Header: h, Raw: qlog.RawInfo{Length: 55}, Frames: []qlog.Frame{{Frame: &qlog.StreamFrame{StreamID: 4, Offset: 0, Length: 1}}}})
	if len(events) != 3 || events[0].Packet != 7 || events[0].PacketBytes != 55 || events[0].FrameLength != 1 || events[1].Stage != "server_stream_prefix_lost" || events[2].Stage != "server_stream_prefix_received" {
		t.Fatal(events)
	}
	before := len(events)
	s.RecordEvent(qlog.PacketSent{Header: h, Raw: qlog.RawInfo{Length: 55}, Frames: []qlog.Frame{{Frame: &qlog.StreamFrame{StreamID: 4, Offset: 8192, Length: 100}}}})
	if len(events) != before {
		t.Fatal("prefix capture exceeded offset bound")
	}
	s.metaEvents.Store(8192)
	s.RecordEvent(qlog.PacketSent{Header: h, Raw: qlog.RawInfo{Length: 55}, Frames: []qlog.Frame{{Frame: &qlog.StreamFrame{StreamID: 4, Offset: 0, Length: 1}}}})
	if len(events) != before || s.metaDropped.Load() == 0 {
		t.Fatal("metadata output not bounded")
	}
}

func TestServerPacketSizeDiagnosticIsOptIn(t *testing.T) {
	s := &Server{cfg: ServerConfig{}}
	q := s.quicConfig()
	if q.InitialPacketSize != 0 || q.DisablePathMTUDiscovery {
		t.Fatal("default PMTU changed")
	}
	s.cfg.FixedPacketSize = 1200
	q = s.quicConfig()
	if q.InitialPacketSize != 1200 || !q.DisablePathMTUDiscovery {
		t.Fatal("fixed-size diagnostic not bounded")
	}
	for _, n := range []uint16{1199, 1453} {
		if _, e := NewServer(ServerConfig{FixedPacketSize: n}); e == nil {
			t.Fatal("invalid packet size accepted")
		}
	}
}

func TestDiagnosticPacketDropAndECNMetadata(t *testing.T) {
	var events []Event
	s := &quicTrace{prefix: true, side: "client", session: 1, started: time.Now(), trace: func(e Event) { events = append(events, e) }}
	s.RecordEvent(qlog.PacketDropped{Trigger: qlog.PacketDropReason("payload_decrypt_error"), Raw: qlog.RawInfo{Length: 1200}})
	s.RecordEvent(qlog.ECNStateUpdated{State: qlog.ECNState("failed"), Trigger: "validation_failure"})
	if s.dropped.Load() != 1 || len(events) != 2 || events[0].DropReason != "payload_decrypt_error" || events[1].ECNState != "failed" {
		t.Fatal(events)
	}
}
