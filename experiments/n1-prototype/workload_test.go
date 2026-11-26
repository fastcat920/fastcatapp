package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
)

func TestWorkloadBoundsAndPattern(t *testing.T) {
	for _, s := range []workload{{N: 0, Chunk: 1}, {N: 1048577, Chunk: 1}, {N: 1, Chunk: 0}, {N: 1, Chunk: 16385}, {N: 1, Chunk: 1, GapMS: 51}, {N: 131072, Chunk: 1, GapMS: 1}} {
		if s.validate() == nil {
			t.Fatal("invalid workload accepted", s)
		}
	}
	if _, e := parseWorkload(url.Values{"n": []string{"invalid"}}); e == nil {
		t.Fatal("invalid query accepted")
	}
	if _, e := parseWorkloadLimit(url.Values{"n": []string{"8388608"}}, 32*1024*1024); e != nil {
		t.Fatal("existing 8MiB origin benchmark was broken", e)
	}
	p := make([]byte, 10000)
	for i := range p {
		p[i] = byte(i % 251)
	}
	if e := verifyPattern(bytes.NewReader(p), len(p)); e != nil {
		t.Fatal(e)
	}
	if e := verifyPattern(bytes.NewReader(append(p, 0)), len(p)); e == nil {
		t.Fatal("oversized response accepted")
	}
	if e := verifyPattern(bytes.NewReader(p[:9999]), len(p)); e == nil {
		t.Fatal("truncated response accepted")
	}
}

func TestMatchedWorkloadModes(t *testing.T) {
	cfg, n, _ := fixtureWithEmission(t, "coalesced")
	n.controls = true
	origin := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		s, e := parseWorkloadLimit(r.URL.Query(), 32*1024*1024)
		if e != nil {
			http.NotFound(w, r)
			return
		}
		servePattern(w, r, s, false)
	}))
	defer origin.Close()
	target := strings.TrimPrefix(origin.URL, "http://")
	n.targets[target] = true
	for _, kind := range []string{"n1", "get", "rpc"} {
		for _, gap := range []int{0, 1} {
			if e := runWorkload(cfg, target, kind, workload{N: 4096, Chunk: 512, GapMS: gap}); e != nil {
				t.Fatalf("%s gap=%d: %v", kind, gap, e)
			}
		}
	}
}

func TestPublicWorkloadRejectsUnboundedRequest(t *testing.T) {
	_, n, _ := fixture(t)
	n.controls = true
	r := httptest.NewRequest("GET", "https://example.com/assets/sample.bin?n=999999999", nil)
	w := httptest.NewRecorder()
	n.ServeHTTP(w, r)
	if w.Code != 404 {
		t.Fatal("oversized public payload accepted")
	}
	response := httptest.NewRecorder()
	request := httptest.NewRequest("GET", "https://example.com/assets/sample.bin?n=513&chunk=128&stream=1", nil)
	n.ServeHTTP(response, request)
	if response.Body.Len() != 513 {
		t.Fatal("custom sample size ignored")
	}
	if e := verifyPattern(bytes.NewReader(response.Body.Bytes()), 513); e != nil {
		t.Fatal(e)
	}
}

func TestWorkloadControlsDisabledByDefault(t *testing.T) {
	_, n, _ := fixture(t)
	for _, path := range []string{"/api/sample-stream", "/assets/sample.bin?n=512"} {
		r := httptest.NewRequest("POST", "https://example.com"+path, nil)
		w := httptest.NewRecorder()
		n.ServeHTTP(w, r)
		if w.Code != 404 {
			t.Fatal("diagnostic route exposed by default", path)
		}
	}
	r := httptest.NewRequest("GET", "https://example.com/assets/sample.bin?n=512", nil)
	w := httptest.NewRecorder()
	n.ServeHTTP(w, r)
	if w.Code != 404 {
		t.Fatal("variable diagnostic asset exposed by default")
	}
}

func TestFailedPayloadDoesNotReportRequestedSizeAsRate(t *testing.T) {
	cfg, n, _ := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = "coalesced"
	source := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("bad!")) }))
	defer source.Close()
	target := strings.TrimPrefix(source.URL, "http://")
	n.targets[target] = true
	original := os.Stdout
	read, write, e := os.Pipe()
	if e != nil {
		t.Fatal(e)
	}
	os.Stdout = write
	defer func() { os.Stdout = original; read.Close(); write.Close() }()
	err := runWorkload(cfg, target, "matched-n1", workload{N: 4, Chunk: 4})
	os.Stdout = original
	write.Close()
	data, e := io.ReadAll(read)
	if e != nil {
		t.Fatal(e)
	}
	if err == nil {
		t.Fatal("corrupt payload accepted")
	}
	var row map[string]any
	if e = json.Unmarshal(data, &row); e != nil {
		t.Fatal(e)
	}
	if _, exists := row["payload_read_mbps"]; exists {
		t.Fatal("failed partial payload reported requested-size rate")
	}
	if _, exists := row["payload_read_ms"]; !exists {
		t.Fatal("missing failed read duration")
	}
}
