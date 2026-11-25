package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"sync/atomic"
	"testing"
	"time"
)

func testDial(t *testing.T, corrupt bool) func(context.Context, string) (net.Conn, error) {
	t.Helper()
	return func(context.Context, string) (net.Conn, error) {
		client, peer := net.Pipe()
		go func() {
			defer peer.Close()
			r, err := http.ReadRequest(bufio.NewReader(peer))
			if err != nil {
				return
			}
			status := http.StatusOK
			var b []byte
			if r.URL.Path == "/upload" {
				if err := verifyPattern(r.Body, int(r.ContentLength)); err != nil {
					status = http.StatusBadRequest
				}
				b = []byte(strconv.FormatInt(r.ContentLength, 10))
			} else {
				n, _ := strconv.Atoi(r.URL.Query().Get("n"))
				b = make([]byte, n)
				_, _ = (&patternReader{}).Read(b)
				if corrupt {
					b[len(b)/2] ^= 1
				}
			}
			response := &http.Response{StatusCode: status, ProtoMajor: 1, ProtoMinor: 1,
				Header: make(http.Header), Body: io.NopCloser(bytes.NewReader(b)), ContentLength: int64(len(b))}
			_ = response.Write(peer)
		}()
		return client, nil
	}
}

func decodeRun(t *testing.T, b []byte) ([]sampleRow, map[string]any) {
	t.Helper()
	var rows []sampleRow
	var summary map[string]any
	d := json.NewDecoder(bytes.NewReader(b))
	for {
		var raw json.RawMessage
		if err := d.Decode(&raw); err == io.EOF {
			break
		} else if err != nil {
			t.Fatal(err)
		}
		var v map[string]any
		if err := json.Unmarshal(raw, &v); err != nil {
			t.Fatal(err)
		}
		if v["event"] == "sample" {
			var row sampleRow
			if err := json.Unmarshal(raw, &row); err != nil {
				t.Fatal(err)
			}
			rows = append(rows, row)
		} else {
			summary = v
		}
	}
	return rows, summary
}

func TestLifecycleAndVerifiedPayload(t *testing.T) {
	dial := testDial(t, false)
	for _, phase := range []string{"cold", "warm", "concurrent", "download", "upload"} {
		t.Run(phase, func(t *testing.T) {
			var created, closed atomic.Int32
			factory := func() (benchClient, error) {
				created.Add(1)
				return benchClient{dial: dial, close: func() { closed.Add(1) }}, nil
			}
			o := options{Protocol: "fcnv3", Phase: phase, Bytes: 65537, Count: 6, Workers: 1, Timeout: time.Second}
			if phase == "concurrent" || phase == "download" {
				o.Workers = 3
			}
			var out bytes.Buffer
			if err := runBench(context.Background(), &out, o, "127.0.0.1:1", factory); err != nil {
				t.Fatal(err)
			}
			rows, summary := decodeRun(t, out.Bytes())
			wantClients := int32(1)
			if phase == "cold" {
				wantClients = int32(o.Count)
			}
			if created.Load() != wantClients || closed.Load() != wantClients {
				t.Fatalf("created=%d closed=%d want=%d", created.Load(), closed.Load(), wantClients)
			}
			if len(rows) != o.Count || summary["failed"] != float64(0) || summary["verified_bytes"] != float64(o.Count*o.Bytes) {
				t.Fatalf("rows=%d summary=%v", len(rows), summary)
			}
			seen := map[int]bool{}
			wantBodyBytes := o.Bytes
			if phase == "upload" {
				wantBodyBytes = len(strconv.Itoa(o.Bytes))
			}
			for _, row := range rows {
				if seen[row.Sample] || !row.Success || row.VerifiedBytes != o.Bytes || row.FirstByteMS == nil || row.E2EMbps == nil {
					t.Fatalf("invalid sample: %+v", row)
				}
				if row.BodyBytesReceived != wantBodyBytes || row.MaxBodyNoProgressMS == nil || len(row.BodyProgress) == 0 ||
					row.BodyProgress[0].OffsetMS != *row.FirstByteMS || row.BodyProgress[len(row.BodyProgress)-1].BytesReceived != wantBodyBytes {
					t.Fatalf("missing body progress in sample: %+v", row)
				}
				seen[row.Sample] = true
			}
			if phase == "warm" && summary["retained_first_byte_ms"].(map[string]any)["n"] != float64(o.Count-1) {
				t.Fatal("warm summary must retain but separate first sample")
			}
		})
	}
}

func TestCorruptedBodyRetainsEveryFailure(t *testing.T) {
	dial := testDial(t, true)
	factory := func() (benchClient, error) {
		return benchClient{dial: dial, close: func() {}}, nil
	}
	o := options{Protocol: "tuic", Phase: "download", Bytes: 1024, Count: 5, Workers: 2, Timeout: time.Second}
	var out bytes.Buffer
	if runBench(context.Background(), &out, o, "127.0.0.1:1", factory) == nil {
		t.Fatal("corrupted body should fail the run")
	}
	rows, summary := decodeRun(t, out.Bytes())
	if len(rows) != o.Count || summary["failed"] != float64(o.Count) || summary["verified_bytes"] != float64(0) {
		t.Fatalf("failure rows missing: %v", summary)
	}
	for _, row := range rows {
		if row.Success || row.ErrorCategory != "verification" || row.ErrorStage != "body" || row.TotalMS <= 0 {
			t.Fatalf("invalid failure row: %+v", row)
		}
		if row.BodyBytesReceived == 0 || len(row.BodyProgress) == 0 || row.VerifiedBytes != 0 || row.E2EMbps != nil || row.BodyMbps != nil {
			t.Fatalf("invalid partial progress for corrupt body: %+v", row)
		}
	}
}

func TestConstructorFailureRetainsAllRows(t *testing.T) {
	for _, phase := range []string{"cold", "warm"} {
		o := options{Protocol: "fcnv3", Phase: phase, Bytes: 1, Count: 3, Workers: 1, Timeout: time.Second}
		var out bytes.Buffer
		err := runBench(context.Background(), &out, o, "127.0.0.1:1", func() (benchClient, error) {
			return benchClient{}, errors.New("synthetic constructor failure")
		})
		rows, summary := decodeRun(t, out.Bytes())
		if err == nil || len(rows) != o.Count || summary["failed"] != float64(o.Count) {
			t.Fatalf("missing constructor failure rows for %s", phase)
		}
		for _, row := range rows {
			if row.BodyBytesReceived != 0 || row.BodyProgress == nil || len(row.BodyProgress) != 0 || row.MaxBodyNoProgressMS != nil {
				t.Fatalf("unexpected body progress for constructor failure: %+v", row)
			}
		}
	}
}

func TestCancellationClosesBlockedStream(t *testing.T) {
	client, peer := net.Pipe()
	defer peer.Close()
	factory := func() (benchClient, error) {
		return benchClient{dial: func(context.Context, string) (net.Conn, error) { return client, nil }, close: func() {}}, nil
	}
	o := options{Protocol: "fcnv3", Phase: "cold", Bytes: 1, Count: 1, Workers: 1, Timeout: 25 * time.Millisecond}
	row := measureSample(context.Background(), o, "127.0.0.1:1", 1, nil, nil, factory)
	if row.Success || row.ErrorCategory != "timeout" || row.TotalMS > 1000 {
		t.Fatalf("blocked stream exceeded budget: %+v", row)
	}
}

func TestBodyTimeoutRetainsPartialProgressAndDiagnosticID(t *testing.T) {
	const partialBytes = 1024
	const payloadBytes = 65536
	client, peer := net.Pipe()
	defer peer.Close()
	header := make(chan string, 1)
	go func() {
		defer peer.Close()
		request, err := http.ReadRequest(bufio.NewReader(peer))
		if err != nil {
			return
		}
		header <- request.Header.Get("X-FCN-Diagnostic-ID")
		if _, err := fmt.Fprintf(peer, "HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n", payloadBytes); err != nil {
			return
		}
		if _, err := io.CopyN(peer, &patternReader{}, partialBytes); err != nil {
			return
		}
		// Keep the response unfinished until the client deadline closes the stream.
		_, _ = peer.Read(make([]byte, 1))
	}()
	factory := func() (benchClient, error) {
		return benchClient{dial: func(context.Context, string) (net.Conn, error) { return client, nil }, close: func() {}}, nil
	}
	o := options{Protocol: "fcnv3", Phase: "download", Bytes: payloadBytes, Count: 1, Workers: 1,
		Timeout: 100 * time.Millisecond, DiagnosticID: "test-download"}
	row := measureSample(context.Background(), o, "127.0.0.1:1", 1, nil, nil, factory)
	if row.Success || row.VerifiedBytes != 0 || row.ErrorCategory != "timeout" || row.ErrorStage != "body" ||
		row.E2EMbps != nil || row.BodyMbps != nil || row.BodyBytesReceived != partialBytes {
		t.Fatalf("invalid body timeout: %+v", row)
	}
	if got := <-header; got != "test-download-1" || row.DiagnosticID != got {
		t.Fatalf("request diagnostic ID %q does not match sample %q", got, row.DiagnosticID)
	}
	if row.MaxBodyNoProgressMS == nil || row.BodyMS == nil || len(row.BodyProgress) == 0 ||
		row.BodyProgress[len(row.BodyProgress)-1].BytesReceived != partialBytes {
		t.Fatalf("missing partial progress: %+v", row)
	}
	trailingMS := *row.BodyMS - (row.BodyProgress[len(row.BodyProgress)-1].OffsetMS - *row.HeadersMS)
	if *row.MaxBodyNoProgressMS < trailingMS-0.001 {
		t.Fatalf("maximum gap %.3f ms missed trailing %.3f ms: %+v", *row.MaxBodyNoProgressMS, trailingMS, row)
	}
}

func TestBodyProgressMilestonesAreBounded(t *testing.T) {
	r := bodyProgressReader{bodyStartedAt: 10 * time.Millisecond, lastReadAt: 10 * time.Millisecond,
		byteStep: 1000, timeStep: 53 * time.Millisecond}
	for i := 1; i <= 205; i++ {
		r.observe(100, time.Duration(10+5*i)*time.Millisecond)
	}
	var row sampleRow
	r.record(&row, 1200*time.Millisecond)
	if len(row.BodyProgress) < bodyByteMilestones || len(row.BodyProgress) > 2+bodyByteMilestones+bodyTimeMilestones {
		t.Fatalf("unexpected point count %d: %+v", len(row.BodyProgress), row.BodyProgress)
	}
	if row.BodyProgress[0] != (bodyProgressPoint{OffsetMS: 15, BytesReceived: 100}) ||
		row.BodyProgress[len(row.BodyProgress)-1] != (bodyProgressPoint{OffsetMS: 1035, BytesReceived: 20500}) ||
		*row.MaxBodyNoProgressMS != 165 {
		t.Fatalf("incorrect first progress, last progress or gap: %+v", row)
	}
	for i := 1; i < len(row.BodyProgress); i++ {
		prev, current := row.BodyProgress[i-1], row.BodyProgress[i]
		if current.OffsetMS <= prev.OffsetMS || current.BytesReceived <= prev.BytesReceived {
			t.Fatalf("unsorted progress points: %+v", row.BodyProgress)
		}
	}
}

func TestPatternRejectsTruncationExtensionAndCorruption(t *testing.T) {
	var valid [251]byte
	_, _ = (&patternReader{}).Read(valid[:])
	if err := verifyPattern(bytes.NewReader(valid[:]), len(valid)); err != nil {
		t.Fatal(err)
	}
	for _, b := range [][]byte{valid[:250], append(valid[:], 0), bytes.Repeat([]byte{0}, len(valid))} {
		if verifyPattern(bytes.NewReader(b), len(valid)) == nil {
			t.Fatal("invalid body accepted")
		}
	}
}

func TestPercentiles(t *testing.T) {
	s := stats([]float64{4, 1, 3, 2})
	if s.N != 4 || *s.P50 != 2.5 || *s.P95 < 3.849 || *s.P95 > 3.851 {
		t.Fatalf("wrong interpolated quantiles: %+v", s)
	}
}

func TestIntervalSeparatesRequestsWithoutInflatingSampleLatency(t *testing.T) {
	factory := func() (benchClient, error) {
		return benchClient{dial: testDial(t, false), close: func() {}}, nil
	}
	o := options{Protocol: "fcnv3", Phase: "warm", Bytes: 1, Count: 3, Workers: 1,
		Timeout: time.Second, Interval: 25 * time.Millisecond}
	var out bytes.Buffer
	if err := runBench(context.Background(), &out, o, "127.0.0.1:1", factory); err != nil {
		t.Fatal(err)
	}
	rows, summary := decodeRun(t, out.Bytes())
	if summary["interval_ms"] != float64(25) || summary["elapsed_ms"].(float64) < 50 {
		t.Fatalf("interval absent from batch timing: %v", summary)
	}
	for i := 1; i < len(rows); i++ {
		previousEnd := float64(rows[i-1].StartUnixMS) + rows[i-1].TotalMS + rows[i-1].CleanupMS
		if float64(rows[i].StartUnixMS)-previousEnd < 24 {
			t.Fatalf("requests were not separated by interval: %+v", rows)
		}
	}
}

func TestIntervalBounds(t *testing.T) {
	o := options{Protocol: "fcnv3", Phase: "download", Bytes: 1, Count: 2, Workers: 1, Timeout: time.Second}
	for _, interval := range []time.Duration{-time.Second, 6 * time.Second} {
		o.Interval = interval
		if o.validate() == nil {
			t.Fatalf("invalid interval %v accepted", interval)
		}
	}
	o.Interval, o.Workers = time.Second, 2
	if o.validate() == nil {
		t.Fatal("multiworker interval accepted")
	}
	o.Interval = 0
	if err := o.validate(); err != nil {
		t.Fatalf("default interval changed existing behavior: %v", err)
	}
}
