package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

type StreamingProbeParams struct {
	RunID       string            `json:"run-id"`
	ProxyName   string            `json:"proxy-name"`
	URL         string            `json:"url"`
	Method      string            `json:"method"`
	Body        string            `json:"body"`
	Timeout     int64             `json:"timeout"`
	MaxBodySize int64             `json:"max-body-size"`
	Headers     map[string]string `json:"headers"`
	NoRedirect  bool              `json:"no-redirect"`
}

type StreamingProbeResult struct {
	OK         bool              `json:"ok"`
	StatusCode int               `json:"status-code"`
	FinalURL   string            `json:"final-url"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
	ElapsedMs  int64             `json:"elapsed-ms"`
	Truncated  bool              `json:"truncated"`
	Error      string            `json:"error,omitempty"`
}

// A run owns all its concurrent requests. Keep cancellation tombstones briefly
// so requests already crossing the platform channel cannot restart a stopped run.
type streamingRun struct {
	ctx     context.Context
	cancel  context.CancelFunc
	active  int
	touched time.Time
}

var streamingRuns = struct {
	sync.Mutex
	items map[string]*streamingRun
}{items: make(map[string]*streamingRun)}

func streamingRunLocked(id string) *streamingRun {
	now := time.Now()
	for key, run := range streamingRuns.items {
		if run.active == 0 && now.Sub(run.touched) > 15*time.Minute {
			run.cancel()
			delete(streamingRuns.items, key)
		}
	}
	if run := streamingRuns.items[id]; run != nil {
		return run
	}
	// Bound retained idle runs without ever evicting an active request.
	if len(streamingRuns.items) >= 64 {
		var oldestKey string
		var oldest *streamingRun
		for key, run := range streamingRuns.items {
			if run.active == 0 && (oldest == nil || run.touched.Before(oldest.touched)) {
				oldestKey, oldest = key, run
			}
		}
		if oldest != nil {
			oldest.cancel()
			delete(streamingRuns.items, oldestKey)
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	run := &streamingRun{ctx: ctx, cancel: cancel, touched: now}
	streamingRuns.items[id] = run
	return run
}

func acquireStreamingRun(id string) (context.Context, func()) {
	if id == "" {
		return context.Background(), func() {}
	}
	streamingRuns.Lock()
	run := streamingRunLocked(id)
	run.active++
	streamingRuns.Unlock()
	return run.ctx, func() {
		streamingRuns.Lock()
		run.active--
		run.touched = time.Now()
		streamingRuns.Unlock()
	}
}

func cancelStreamingProbes(id string) {
	if id == "" {
		return
	}
	streamingRuns.Lock()
	defer streamingRuns.Unlock()
	run := streamingRunLocked(id)
	run.cancel()
	run.touched = time.Now()
}

func handleStreamingProbe(paramsString string) string {
	started := time.Now()
	params := &StreamingProbeParams{}
	result := &StreamingProbeResult{Headers: map[string]string{}}
	finish := func() string {
		result.ElapsedMs = time.Since(started).Milliseconds()
		data, _ := json.Marshal(result)
		return string(data)
	}
	if err := json.Unmarshal([]byte(paramsString), params); err != nil {
		result.Error = err.Error()
		return finish()
	}
	proxy := tunnel.Proxies()[params.ProxyName]
	if proxy == nil {
		result.Error = "proxy not found"
		return finish()
	}
	timeout := time.Duration(params.Timeout) * time.Millisecond
	if timeout <= 0 {
		timeout = 8 * time.Second
	}
	maxBodySize := params.MaxBodySize
	if maxBodySize <= 0 || maxBodySize > 2*1024*1024 {
		maxBodySize = 128 * 1024
	}
	transport := &http.Transport{
		DisableKeepAlives: true,
		DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
			metadata := &constant.Metadata{NetWork: constant.TCP, Type: constant.INNER}
			if err := metadata.SetRemoteAddress(address); err != nil {
				return nil, err
			}
			return proxy.DialContext(ctx, metadata)
		},
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{
		Transport: transport,
		Timeout:   timeout,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if params.NoRedirect {
				return http.ErrUseLastResponse
			}
			if len(via) >= 8 {
				return fmt.Errorf("too many redirects")
			}
			return nil
		},
	}
	parent, release := acquireStreamingRun(params.RunID)
	defer release()
	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()
	method := strings.ToUpper(strings.TrimSpace(params.Method))
	if method == "" {
		method = http.MethodGet
	}
	if method != http.MethodGet && method != http.MethodPost && method != http.MethodHead {
		result.Error = "unsupported HTTP method"
		return finish()
	}
	var requestBody io.Reader
	if params.Body != "" {
		requestBody = strings.NewReader(params.Body)
	}
	req, err := http.NewRequestWithContext(ctx, method, params.URL, requestBody)
	if err != nil {
		result.Error = err.Error()
		return finish()
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("Cache-Control", "no-cache")
	for key, value := range params.Headers {
		req.Header.Set(key, value)
	}
	response, err := client.Do(req)
	if err != nil {
		result.Error = err.Error()
		return finish()
	}
	defer response.Body.Close()
	data, readErr := io.ReadAll(io.LimitReader(response.Body, maxBodySize+1))
	if readErr != nil {
		result.Error = readErr.Error()
		return finish()
	}
	if int64(len(data)) > maxBodySize {
		data = data[:maxBodySize]
		result.Truncated = true
	}
	for key, values := range response.Header {
		result.Headers[key] = strings.Join(values, ", ")
	}
	result.OK = true
	result.StatusCode = response.StatusCode
	result.FinalURL = response.Request.URL.String()
	result.Body = string(data)
	return finish()
}
