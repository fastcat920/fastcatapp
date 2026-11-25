package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/fastcat920/fcnv3"
)

var errVerification = errors.New("target verification failed")

type sampleRow struct {
	Event               string              `json:"event"`
	Protocol            string              `json:"protocol"`
	Phase               string              `json:"phase"`
	Sample              int                 `json:"sample"`
	DiagnosticID        string              `json:"diagnostic_id,omitempty"`
	Workers             int                 `json:"workers"`
	Bytes               int                 `json:"bytes"`
	VerifiedBytes       int                 `json:"verified_bytes"`
	StartUnixMS         int64               `json:"start_unix_ms"`
	FirstInBatch        bool                `json:"first_in_batch"`
	ClientLifecycle     string              `json:"client_lifecycle"`
	Success             bool                `json:"success"`
	ClientMS            float64             `json:"client_ms"`
	EntryMS             *float64            `json:"entry_ms,omitempty"`
	HeadersMS           *float64            `json:"headers_ms,omitempty"`
	FirstByteMS         *float64            `json:"first_byte_ms,omitempty"`
	BodyMS              *float64            `json:"body_ms,omitempty"`
	BodyBytesReceived   int                 `json:"body_bytes_received"`
	BodyProgress        []bodyProgressPoint `json:"body_progress"`
	MaxBodyNoProgressMS *float64            `json:"max_body_no_progress_ms,omitempty"`
	TotalMS             float64             `json:"total_ms"`
	CleanupMS           float64             `json:"cleanup_ms"`
	E2EMbps             *float64            `json:"e2e_mbps,omitempty"`
	BodyMbps            *float64            `json:"body_mbps,omitempty"`
	TargetStatus        int                 `json:"target_status,omitempty"`
	ErrorStage          string              `json:"error_stage,omitempty"`
	ErrorCategory       string              `json:"error_category,omitempty"`
	CleanupError        string              `json:"cleanup_error,omitempty"`
}

func milliseconds(d time.Duration) float64 { return float64(d) / float64(time.Millisecond) }
func floatPointer(v float64) *float64      { return &v }

const (
	bodyByteMilestones = 12
	bodyTimeMilestones = 8
)

type bodyProgressPoint struct {
	OffsetMS      float64 `json:"offset_ms"`
	BytesReceived int     `json:"bytes_received"`
}

type bodyProgressReader struct {
	io.Reader
	sampleStarted time.Time
	bodyStartedAt time.Duration
	byteStep      int
	timeStep      time.Duration
	points        []bodyProgressPoint
	bytes         int
	lastReadAt    time.Duration
	maxGap        time.Duration
	byteMilestone int
	timeMilestone int
}

func (r *bodyProgressReader) Read(p []byte) (int, error) {
	n, err := r.Reader.Read(p)
	if n > 0 {
		r.observe(n, time.Since(r.sampleStarted))
	}
	return n, err
}

func (r *bodyProgressReader) observe(n int, at time.Duration) {
	r.maxGap = max(r.maxGap, at-r.lastReadAt)
	r.lastReadAt = at
	r.bytes += n

	// Byte milestones capture fast transfers, while time milestones preserve
	// progress even when a slow transfer stops short of its first byte milestone.
	byteMilestone := min(bodyByteMilestones, r.bytes/r.byteStep)
	timeMilestone := min(bodyTimeMilestones, int((at-r.bodyStartedAt)/r.timeStep))
	if len(r.points) == 0 || byteMilestone > r.byteMilestone || timeMilestone > r.timeMilestone {
		r.points = append(r.points, bodyProgressPoint{OffsetMS: milliseconds(at), BytesReceived: r.bytes})
		r.byteMilestone = byteMilestone
		r.timeMilestone = timeMilestone
	}
}

func (r *bodyProgressReader) record(row *sampleRow, endedAt time.Duration) {
	row.BodyBytesReceived = r.bytes
	row.MaxBodyNoProgressMS = floatPointer(milliseconds(max(r.maxGap, endedAt-r.lastReadAt)))
	if len(r.points) == 0 {
		return
	}
	if r.points[len(r.points)-1].BytesReceived != r.bytes {
		r.points = append(r.points, bodyProgressPoint{OffsetMS: milliseconds(r.lastReadAt), BytesReceived: r.bytes})
	}
	row.BodyProgress = r.points
	row.FirstByteMS = floatPointer(r.points[0].OffsetMS)
}

// patternReader generates bounded-memory payloads identical to the origin.
type patternReader struct{ offset int }

func (r *patternReader) Read(p []byte) (int, error) {
	for i := range p {
		p[i] = byte((r.offset + i) % 251)
	}
	r.offset += len(p)
	return len(p), nil
}

func verifyPattern(r io.Reader, size int) error {
	var b [32768]byte
	offset := 0
	limited := io.LimitReader(r, int64(size)+1)
	for {
		n, err := limited.Read(b[:])
		for i := 0; i < n; i++ {
			if offset+i >= size || b[i] != byte((offset+i)%251) {
				return errVerification
			}
		}
		offset += n
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}
	if offset != size {
		return errVerification
	}
	return nil
}

func errorCategory(err error) string {
	if errors.Is(err, fcnv3.ErrECHRejected) {
		return "ech_rejected"
	}
	if errors.Is(err, fcnv3.ErrECHHandshake) {
		return "ech_handshake"
	}
	if errors.Is(err, fcnv3.ErrEntryDNS) {
		return "entry_doh"
	}
	if errors.Is(err, fcnv3.ErrRejected) {
		return "connect_rejected"
	}
	if errors.Is(err, errVerification) {
		return "verification"
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "timeout"
	}
	if errors.Is(err, context.Canceled) {
		return "cancelled"
	}
	var timeout net.Error
	if errors.As(err, &timeout) && timeout.Timeout() {
		return "timeout"
	}
	var dns *net.DNSError
	if errors.As(err, &dns) {
		return "dns"
	}
	var certificate *tls.CertificateVerificationError
	var unknown x509.UnknownAuthorityError
	var hostname x509.HostnameError
	if errors.As(err, &certificate) || errors.As(err, &unknown) || errors.As(err, &hostname) {
		return "certificate"
	}
	if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) || errors.Is(err, syscall.ECONNRESET) {
		return "truncated"
	}
	return "transport_or_protocol"
}

func measureSample(parent context.Context, o options, target string, index int, shared *benchClient, sharedErr error, factory clientFactory) (row sampleRow) {
	started := time.Now()
	row = sampleRow{Event: "sample", Protocol: o.Protocol, Phase: o.Phase, Sample: index, Workers: o.Workers,
		Bytes: o.Bytes, StartUnixMS: started.UnixMilli(), FirstInBatch: index == 1, ClientLifecycle: "retained",
		BodyProgress: []bodyProgressPoint{}}
	if o.DiagnosticID != "" {
		row.DiagnosticID = o.DiagnosticID + "-" + strconv.Itoa(index)
	}
	ctx, cancel := context.WithTimeout(parent, o.Timeout)
	defer cancel()
	var conn net.Conn
	var client benchClient
	stage := "client"
	var stopCancel func() bool
	// Every path, including constructor/dial failures, produces a timed row.
	defer func() {
		row.TotalMS = milliseconds(time.Since(started))
		if row.Success {
			row.VerifiedBytes = o.Bytes
			row.E2EMbps = floatPointer(float64(o.Bytes) * 8 / row.TotalMS / 1000)
		}
		cleanup := time.Now()
		if stopCancel != nil {
			stopCancel()
		}
		if conn != nil {
			if err := conn.Close(); err != nil {
				row.CleanupError = errorCategory(err)
			}
		}
		if shared == nil && client.close != nil {
			client.close()
		}
		row.CleanupMS = milliseconds(time.Since(cleanup))
	}()
	fail := func(err error) {
		row.ErrorStage = stage
		if ctx.Err() != nil {
			err = ctx.Err()
		}
		row.ErrorCategory = errorCategory(err)
	}
	if err := ctx.Err(); err != nil {
		fail(err)
		return
	}
	if shared == nil {
		row.ClientLifecycle = "new"
		var err error
		client, err = factory()
		row.ClientMS = milliseconds(time.Since(started))
		if err != nil {
			fail(err)
			return
		}
	} else {
		if sharedErr != nil {
			fail(sharedErr)
			return
		}
		client = *shared
	}
	stage = "entry"
	var err error
	conn, err = client.dial(ctx, target)
	row.EntryMS = floatPointer(milliseconds(time.Since(started)))
	if err != nil {
		fail(err)
		return
	}
	// Cancellation closes the stream even if a transport has limited deadline
	// support. The context remains alive through verified body completion.
	stopCancel = context.AfterFunc(ctx, func() { conn.Close() })
	if deadline, ok := ctx.Deadline(); ok {
		_ = conn.SetDeadline(deadline)
	}
	stage = "request"
	request := fmt.Sprintf("GET /bytes?n=%d HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n", o.Bytes, target)
	if o.Phase == "upload" {
		request = fmt.Sprintf("POST /upload HTTP/1.1\r\nHost: %s\r\nContent-Length: %d\r\nConnection: close\r\n", target, o.Bytes)
	}
	if row.DiagnosticID != "" {
		request += "X-FCN-Diagnostic-ID: " + row.DiagnosticID + "\r\n"
	}
	request += "\r\n"
	if _, err = io.Copy(conn, strings.NewReader(request)); err == nil && o.Phase == "upload" {
		_, err = io.CopyN(conn, &patternReader{}, int64(o.Bytes))
	}
	if err != nil {
		fail(err)
		return
	}
	stage = "headers"
	response, err := http.ReadResponse(bufio.NewReader(conn), nil)
	row.HeadersMS = floatPointer(milliseconds(time.Since(started)))
	if err != nil {
		fail(err)
		return
	}
	defer response.Body.Close()
	row.TargetStatus = response.StatusCode
	if response.StatusCode != http.StatusOK {
		fail(errVerification)
		return
	}
	stage = "body"
	bodyStartedAt := time.Since(started)
	expectedBodyBytes := o.Bytes
	var uploadAck string
	if o.Phase == "upload" {
		uploadAck = strconv.Itoa(o.Bytes)
		expectedBodyBytes = len(uploadAck)
	}
	body := bodyProgressReader{
		Reader: response.Body, sampleStarted: started, bodyStartedAt: bodyStartedAt, lastReadAt: bodyStartedAt,
		byteStep: max(1, (expectedBodyBytes+bodyByteMilestones-1)/bodyByteMilestones),
		timeStep: max(time.Nanosecond, o.Timeout/bodyTimeMilestones),
	}
	if o.Phase == "upload" {
		// The origin acknowledges only after checking every upload byte.
		var b []byte
		b, err = io.ReadAll(io.LimitReader(&body, 65))
		if err == nil && string(b) != uploadAck {
			err = errVerification
		}
	} else {
		err = verifyPattern(&body, o.Bytes)
	}
	bodyEndedAt := time.Since(started)
	row.BodyMS = floatPointer(milliseconds(bodyEndedAt - bodyStartedAt))
	body.record(&row, bodyEndedAt)
	if err != nil {
		fail(err)
		return
	}
	if o.Phase != "upload" && *row.BodyMS > 0 {
		row.BodyMbps = floatPointer(float64(o.Bytes) * 8 / *row.BodyMS / 1000)
	}
	row.Success = true
	return
}

type distribution struct {
	N   int      `json:"n"`
	P50 *float64 `json:"p50"`
	P95 *float64 `json:"p95"`
}

func stats(values []float64) distribution {
	s := distribution{N: len(values)}
	if len(values) == 0 {
		return s
	}
	sort.Float64s(values)
	quantile := func(p float64) *float64 {
		i := float64(len(values)-1) * p
		lo, hi := int(math.Floor(i)), int(math.Ceil(i))
		return floatPointer(values[lo] + (values[hi]-values[lo])*(i-float64(lo)))
	}
	s.P50, s.P95 = quantile(.5), quantile(.95)
	return s
}

func latencyStats(rows []sampleRow, omitFirst bool, field func(sampleRow) *float64) distribution {
	values := make([]float64, 0, len(rows))
	for _, row := range rows {
		if row.Success && (!omitFirst || !row.FirstInBatch) {
			if value := field(row); value != nil {
				values = append(values, *value)
			}
		}
	}
	return stats(values)
}

func runBench(parent context.Context, out io.Writer, o options, target string, factory clientFactory) error {
	ctx, cancel := context.WithCancel(parent)
	defer cancel()
	var shared *benchClient
	var sharedErr error
	clientStarted := time.Now()
	if o.Phase != "cold" {
		client, err := factory()
		shared, sharedErr = &client, err
		if err == nil {
			defer client.close()
		}
	}
	clientMS := milliseconds(time.Since(clientStarted))
	var preconnectMS float64
	if o.Preconnect && sharedErr == nil {
		started := time.Now()
		warmCtx, stopWarm := context.WithTimeout(ctx, o.Timeout)
		if shared == nil || shared.warm == nil {
			sharedErr = errors.New("preconnect unsupported")
		} else {
			sharedErr = shared.warm(warmCtx)
		}
		stopWarm()
		preconnectMS = milliseconds(time.Since(started))
	}
	rows := make([]sampleRow, o.Count)
	jobs := make(chan int)
	var wg sync.WaitGroup
	var mu sync.Mutex
	enc := json.NewEncoder(out)
	var writeErr error
	begin := time.Now()
	for w := 0; w < o.Workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range jobs {
				row := measureSample(ctx, o, target, i+1, shared, sharedErr, factory)
				rows[i] = row
				mu.Lock()
				if writeErr == nil {
					writeErr = enc.Encode(row)
					if writeErr != nil {
						cancel()
					}
				}
				mu.Unlock()
				if o.Interval > 0 && i+1 < o.Count {
					timer := time.NewTimer(o.Interval)
					select {
					case <-ctx.Done():
						timer.Stop()
					case <-timer.C:
					}
				}
			}
		}()
	}
	for i := 0; i < o.Count; i++ {
		jobs <- i
	}
	close(jobs)
	wg.Wait()
	elapsed := time.Since(begin)
	if writeErr != nil {
		return fmt.Errorf("result write failed: %w", writeErr)
	}
	verified, failed := 0, 0
	var payloadEndMS float64
	for _, row := range rows {
		verified += row.VerifiedBytes
		if !row.Success {
			failed++
		}
		payloadEndMS = math.Max(payloadEndMS, float64(row.StartUnixMS-begin.UnixMilli())+row.TotalMS)
	}
	summary := map[string]any{
		"event": "batch-ended", "protocol": o.Protocol, "phase": o.Phase, "bytes": o.Bytes,
		"count": o.Count, "workers": o.Workers, "failed": failed, "success": o.Count - failed,
		"interval_ms":    milliseconds(o.Interval),
		"verified_bytes": verified, "elapsed_ms": milliseconds(elapsed), "client_ms": clientMS,
		"aggregate_verified_mbps": float64(verified) * 8 / elapsed.Seconds() / 1e6,
		"first_byte_ms":           latencyStats(rows, false, func(r sampleRow) *float64 { return r.FirstByteMS }),
		"total_ms":                latencyStats(rows, false, func(r sampleRow) *float64 { return &r.TotalMS }),
		"entry_ms":                latencyStats(rows, false, func(r sampleRow) *float64 { return r.EntryMS }),
	}
	if payloadEndMS > 0 {
		summary["payload_makespan_ms"] = payloadEndMS
		summary["payload_aggregate_mbps"] = float64(verified) * 8 / payloadEndMS / 1000
	}
	if o.Preconnect {
		summary["preconnect_ms"] = preconnectMS
	}
	if o.Phase == "warm" {
		summary["retained_first_byte_ms"] = latencyStats(rows, true, func(r sampleRow) *float64 { return r.FirstByteMS })
		summary["retained_total_ms"] = latencyStats(rows, true, func(r sampleRow) *float64 { return &r.TotalMS })
	}
	if err := enc.Encode(summary); err != nil {
		return fmt.Errorf("summary write failed: %w", err)
	}
	if failed > 0 {
		return fmt.Errorf("%d of %d measured requests failed", failed, o.Count)
	}
	return nil
}
