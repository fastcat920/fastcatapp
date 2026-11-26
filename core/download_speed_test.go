package main

import (
	"context"
	"strings"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

func TestFCNV3DiagnosticUsesUDP(t *testing.T) {
	if network := proxyDiagnosticNetwork(C.FCNv3); network != "udp" {
		t.Fatalf("FCN v3 uses QUIC over UDP, got %q", network)
	}
}

func TestDownloadSpeedSampleCapsBodyBytes(t *testing.T) {
	body := strings.NewReader("abcdefghijklmnopqrstuvwxyz")
	ctx := context.Background()
	result := sampleDownloadSpeed(ctx, ctx, body, 10)
	if result.Bytes != 10 || body.Len() != 16 {
		t.Fatalf("download exceeded byte budget: %+v, unread=%d", result, body.Len())
	}
}

func TestDownloadSpeedSampleHandlesCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	result := sampleDownloadSpeed(ctx, ctx, strings.NewReader(""), 10)
	if result.Status != "cancelled" {
		t.Fatalf("expected cancellation, got %+v", result)
	}
}
