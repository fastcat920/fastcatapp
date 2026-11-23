package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestDeviceGrantProof(t *testing.T) {
	req := httptest.NewRequest("GET", "https://example.com/sub?fc_v2=1&token=account-token", nil)
	d := &DeviceRecord{ID: "dev_" + strings.Repeat("c", 24)}
	key := strings.Repeat("q", 32)
	now := time.Unix(1800000000, 0)
	req.Header.Set(deviceGrantHeader, "client-injected")
	setDeviceGrantProof(req, d, key, now)
	prefix := "v2." + d.ID + ".1800000000"
	mac := hmac.New(sha256.New, []byte(key))
	fmt.Fprintf(mac, "%s.%x", prefix, sha256.Sum256([]byte("account-token")))
	if got := req.Header.Get(deviceGrantHeader); got != fmt.Sprintf("%s.%x", prefix, mac.Sum(nil)) {
		t.Fatal("incorrect grant proof")
	}
	setDeviceGrantProof(req, d, "", now)
	if req.Header.Get(deviceGrantHeader) != "" {
		t.Fatal("disabled gateway forwarded a grant proof")
	}
}

func TestDeviceProofStaysAtItsUpstreamOrigin(t *testing.T) {
	received := make(chan string, 1)
	end := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { received <- r.Header.Get(deviceGrantHeader) }))
	defer end.Close()
	first := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get(deviceGrantHeader) != "local-proof" {
			t.Error("initial upstream missing proof")
		}
		http.Redirect(w, r, end.URL, http.StatusFound)
	}))
	defer first.Close()
	req, err := http.NewRequest(http.MethodGet, first.URL, nil)
	if err != nil {
		t.Fatal(err)
	}
	source := http.Header{}
	source.Set(deviceGrantHeader, "forged")
	copyProxyHeaders(req.Header, source)
	if req.Header.Get(deviceGrantHeader) != "" {
		t.Fatal("user-controlled proof copied")
	}
	req.Header.Set(deviceGrantHeader, "local-proof")
	resp, err := fetchDeviceSubscription(first.Client(), req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if <-received != "" {
		t.Error("proof crossed subscription origins")
	}
}
