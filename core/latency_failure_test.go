package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"testing"
	"time"

	fcnv3 "github.com/fastcat920/fcnv3"
	"github.com/metacubex/quic-go"
)

func TestDelayFailureKind(t *testing.T) {
	for _, tc := range []struct {
		name string
		err  error
		want string
	}{
		{"deadline", fmt.Errorf("wrapped: %w", context.DeadlineExceeded), "timeout"},
		{"handshake", fmt.Errorf("handshake: %w", &quic.HandshakeTimeoutError{}), "timeout"},
		{"CONNECT rejection", fmt.Errorf("%w (HTTP 403)", fcnv3.ErrRejected), "failed"},
		{"cancellation", context.Canceled, "failed"},
		{"timeout in hostname", &url.Error{Op: "Head", URL: "https://timeout.example", Err: errors.New("refused")}, "failed"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := delayFailureKind(tc.err); got != tc.want {
				t.Fatalf("delayFailureKind(%v) = %q, want %q", tc.err, got, tc.want)
			}
		})
	}
}

func TestAsyncDelayMissingProxyReportsFailure(t *testing.T) {
	const proxy = "missing-latency-test-proxy"
	data, err := json.Marshal(TestDelayParams{ProxyName: proxy, Timeout: 1000})
	if err != nil {
		t.Fatal(err)
	}
	result := make(chan string, 1)
	handleAsyncTestDelay(string(data), func(value string) { result <- value })
	select {
	case raw := <-result:
		var delay Delay
		if err := json.Unmarshal([]byte(raw), &delay); err != nil {
			t.Fatal(err)
		}
		if delay.Name != proxy || delay.Value != -1 || delay.FailureKind != "failed" {
			t.Fatalf("unexpected delay response: %+v", delay)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("latency core returned no result")
	}
}
