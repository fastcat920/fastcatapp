package main

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"strconv"
	"time"

	C "github.com/metacubex/mihomo/constant"
)

const downloadSpeedLimit = 100_000_000
const downloadSpeedDuration = 10 * time.Second
const downloadSpeedEndpoint = "https://speed.cloudflare.com/__down"

// The endpoint rejects requests for exactly 100,000,000 bytes with HTTP 403.
const downloadSpeedRequestBytes = downloadSpeedLimit - 1

type downloadSpeedResult struct {
	Status       string `json:"status"`
	Bytes        int64  `json:"bytes"`
	SampleMicros int64  `json:"sample-us"`
	HTTPStatus   int    `json:"http-status,omitempty"`
}

func measureDownloadSpeed(runID string, proxy C.Proxy) *downloadSpeedResult {
	if proxy == nil {
		return &downloadSpeedResult{Status: "no-node"}
	}
	switch proxy.Type() {
	case C.Direct, C.Reject, C.RejectDrop, C.Compatible, C.Pass, C.PassRule,
		C.Rematch, C.Dns, C.Relay, C.Selector, C.Fallback, C.URLTest, C.LoadBalance:
		return &downloadSpeedResult{Status: "no-node"}
	}
	parent, release := acquireStreamingRun(runID)
	defer release()
	ctx, cancel := context.WithTimeout(parent, downloadSpeedDuration)
	defer cancel()
	transport := &http.Transport{
		DisableCompression: true,
		DisableKeepAlives:  true,
		DialContext: func(dialCtx context.Context, _, address string) (net.Conn, error) {
			metadata := &C.Metadata{NetWork: C.TCP, Type: C.INNER}
			if err := metadata.SetRemoteAddress(address); err != nil {
				return nil, err
			}
			dialCtx, cancelDial := context.WithCancel(dialCtx)
			defer cancelDial()
			stop := context.AfterFunc(ctx, cancelDial)
			defer stop()
			if err := ctx.Err(); err != nil {
				return nil, err
			}
			return proxy.DialContext(dialCtx, metadata)
		},
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{
		Transport: transport,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet,
		downloadSpeedEndpoint+"?bytes="+strconv.Itoa(downloadSpeedRequestBytes), nil)
	if err != nil {
		return &downloadSpeedResult{Status: "failed"}
	}
	request.Header.Set("Accept-Encoding", "identity")
	request.Header.Set("Cache-Control", "no-cache")
	response, err := client.Do(request)
	if err != nil {
		if parent.Err() != nil {
			return &downloadSpeedResult{Status: "cancelled"}
		}
		return &downloadSpeedResult{Status: "failed"}
	}
	defer response.Body.Close()
	encoding := response.Header.Get("Content-Encoding")
	if response.StatusCode != http.StatusOK || (encoding != "" && encoding != "identity") {
		return &downloadSpeedResult{Status: "failed", HTTPStatus: response.StatusCode}
	}
	return sampleDownloadSpeed(parent, ctx, response.Body, downloadSpeedLimit)
}

func sampleDownloadSpeed(parent, ctx context.Context, body io.Reader, limit int64) *downloadSpeedResult {
	started := time.Now()
	bytes, err := io.CopyN(io.Discard, body, limit)
	result := &downloadSpeedResult{
		Status:       "failed",
		Bytes:        bytes,
		SampleMicros: time.Since(started).Microseconds(),
	}
	switch {
	case parent.Err() != nil:
		result.Status = "cancelled"
	case bytes > 0 && result.SampleMicros > 0 &&
		(err == nil || errors.Is(err, io.EOF) || errors.Is(ctx.Err(), context.DeadlineExceeded)):
		result.Status = "complete"
	}
	return result
}
