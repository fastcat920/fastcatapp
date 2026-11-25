package main

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"io"
	"path/filepath"
	"testing"
	"testing/synctest"
	"time"
)

func TestUDPPacketChecksWirePayloadAndIgnoresLateEcho(t *testing.T) {
	row := udpPacketRow{RunID: "0123456789abcdef", Sequence: 2, Bytes: 64}
	var payload []byte
	reads := 0
	conn := udpDiagnosticConn{
		send: func(p []byte) error {
			payload = p
			return nil
		},
		receive: func(context.Context) ([]byte, error) {
			reads++
			if reads == 1 {
				stale := bytes.Clone(payload)
				binary.BigEndian.PutUint32(stale[24:28], 1)
				return stale, nil
			}
			return payload, nil
		},
		abort: func() { t.Error("unexpected transport abort") },
	}
	if err := measureUDPPacket(t.Context(), conn, &row); err != nil {
		t.Fatal(err)
	}
	if !row.Attempted || !row.Submitted || !row.Echoed || row.UnmatchedReplies != 1 || row.EchoRTTMS == nil {
		t.Fatalf("unexpected row: %+v", row)
	}
	if len(payload) != 64 || string(payload[:24]) != "FCNUDP010123456789abcdef" ||
		binary.BigEndian.Uint32(payload[24:28]) != 2 || int64(binary.BigEndian.Uint64(payload[28:36])) != row.SendUnixNS {
		t.Fatalf("unexpected bytes: %x", payload)
	}
}

func TestUDPPacketAbortsBlockedSubmission(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		row := udpPacketRow{RunID: "0123456789abcdef", Sequence: 1, Bytes: 64}
		closed := make(chan struct{})
		conn := udpDiagnosticConn{
			send: func([]byte) error {
				<-closed
				return io.ErrClosedPipe
			},
			abort: func() { close(closed) },
		}
		if err := measureUDPPacket(t.Context(), conn, &row); !errors.Is(err, context.DeadlineExceeded) {
			t.Fatalf("expected submission timeout, got %v", err)
		}
		if !row.Attempted || row.Submitted || row.Echoed || row.ErrorStage != "submit" || row.ErrorCategory != "timeout" {
			t.Fatalf("unexpected row: %+v", row)
		}
	})
}

func TestUDPDiagnosticSetupFailurePreservesRows(t *testing.T) {
	var cfg config
	cfg.UDPTarget = "127.0.0.1:18477"
	cfg.FCNv3.CAFile = filepath.Join(t.TempDir(), "missing.pem")
	var output bytes.Buffer
	count := len(udpDiagnosticSizes) + 1
	if err := runUDPDiagnostic(t.Context(), &output, cfg, "fcnv3", count, time.Second); err == nil {
		t.Fatal("expected diagnostic to report missing echoes")
	}
	decoder := json.NewDecoder(&output)
	runID := ""
	for i := 0; i < count; i++ {
		var row udpPacketRow
		if err := decoder.Decode(&row); err != nil {
			t.Fatal(err)
		}
		if i == 0 {
			runID = row.RunID
		}
		if row.Event != "udp_packet" || len(runID) != 16 || row.RunID != runID || row.Sequence != i+1 ||
			row.Bytes != udpDiagnosticSizes[i%len(udpDiagnosticSizes)] || row.Attempted || row.Submitted || row.Echoed || row.ErrorStage != "setup" {
			t.Fatalf("unexpected row: %+v", row)
		}
	}
	var summary udpDiagnosticSummary
	if err := decoder.Decode(&summary); err != nil {
		t.Fatal(err)
	}
	if summary.Event != "udp_summary" || summary.RunID != runID || summary.Planned != count ||
		summary.Attempted != 0 || summary.Submitted != 0 || summary.Echoed != 0 || summary.SetupErrorCategory == "" ||
		len(summary.BySize) != len(udpDiagnosticSizes) || summary.BySize[0].Planned != 2 {
		t.Fatalf("unexpected summary: %+v", summary)
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		t.Fatalf("unexpected trailing output: %v", err)
	}
}
