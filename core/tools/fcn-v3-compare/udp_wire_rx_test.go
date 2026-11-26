package main

import (
	"bytes"
	"encoding/json"
	"testing"
	"time"
)

func TestUDPWireRXFingerprintAndCaptureLimit(t *testing.T) {
	recorder := new(udpWireRXRecorder)
	timestamp := time.Unix(123, 456)
	data := []byte("abc-scratch-buffer")
	recorder.record(timestamp, 3, data, false)
	data[0] = 'z'
	for i := 1; i < udpWireRXLimit; i++ {
		recorder.record(timestamp, 3, data, false)
	}
	recorder.record(timestamp, 3, data, false)
	recorder.record(timestamp, 3, data, true)
	var output bytes.Buffer
	counts, err := recorder.emit(json.NewEncoder(&output))
	if err != nil {
		t.Fatal(err)
	}
	if counts.Captured != udpWireRXLimit || counts.Dropped != 2 {
		t.Fatalf("unexpected capture counts: %+v", counts)
	}
	var row map[string]any
	if err := json.NewDecoder(&output).Decode(&row); err != nil {
		t.Fatal(err)
	}
	if len(row) != 4 || row["event"] != "udp_wire_rx" || row["bytes"] != float64(3) ||
		row["timestamp_unix_ns"] != float64(timestamp.UnixNano()) || row["sha256_64"] != "ba7816bf8f01cfea" {
		t.Fatalf("unexpected wire row: %+v", row)
	}
}

func TestUDPRXQOverflowSummaryPreservesUnknownCounts(t *testing.T) {
	enabled := &udpWireRXConn{rxqMode: udpRXQEnabled}
	unsupported := &udpWireRXConn{rxqMode: udpRXQUnsupported}
	unavailable := &udpWireRXConn{rxqMode: udpRXQUnavailable}
	reported := &udpWireRXConn{rxqMode: udpRXQEnabled, rxqReported: true, rxqDrops: 11}
	reportedZero := &udpWireRXConn{rxqMode: udpRXQEnabled, rxqReported: true}
	for _, tt := range []struct {
		name    string
		sockets []*udpWireRXConn
		known   bool
		drops   uint64
	}{
		{name: "not_observed"},
		{name: "unsupported", sockets: []*udpWireRXConn{unsupported}},
		{name: "unavailable", sockets: []*udpWireRXConn{unavailable}},
		{name: "no_notice", sockets: []*udpWireRXConn{enabled}},
		{name: "partial", sockets: []*udpWireRXConn{reported, enabled, unsupported, unavailable}, known: true, drops: 11},
		{name: "reported", sockets: []*udpWireRXConn{reported, reported}, known: true, drops: 22},
		{name: "reported zero", sockets: []*udpWireRXConn{reportedZero}, known: true},
	} {
		t.Run(tt.name, func(t *testing.T) {
			wantStatus := tt.name
			if tt.name == "reported zero" {
				wantStatus = "reported"
			}
			counts := summarizeUDPRXQOverflow(tt.sockets)
			if counts.Status != wantStatus || counts.Sockets != len(tt.sockets) ||
				counts.EnabledSockets+counts.UnsupportedSockets+counts.EnableFailedSockets != counts.Sockets ||
				(counts.ReportedDrops != nil) != tt.known {
				t.Fatalf("unexpected RXQ counts: %+v", counts)
			}
			if tt.known && *counts.ReportedDrops != tt.drops {
				t.Fatalf("reported drops = %d, want %d", *counts.ReportedDrops, tt.drops)
			}
		})
	}
}
