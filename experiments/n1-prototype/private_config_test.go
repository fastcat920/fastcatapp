package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestPrivateConfigRejectsUnsafeFiles(t *testing.T) {
	p := filepath.Join(t.TempDir(), "config")
	if e := os.WriteFile(p, []byte(`{}`), 0600); e != nil {
		t.Fatal(e)
	}
	if _, e := readPrivateConfig(p); e != nil {
		t.Fatal(e)
	}
	os.Chmod(p, 0644)
	if _, e := readPrivateConfig(p); e == nil {
		t.Fatal("public config accepted")
	}
	os.Chmod(p, 0600)
	os.Symlink(p, p+"-link")
	if _, e := readPrivateConfig(p + "-link"); e == nil {
		t.Fatal("symlink accepted")
	}
	os.WriteFile(p, make([]byte, 16385), 0600)
	if _, e := readPrivateConfig(p); e == nil {
		t.Fatal("oversize accepted")
	}
}
func TestScopedProxyRejectsUnknownHostBeforeDial(t *testing.T) {
	h := makeProxyHandler(settings{Server: "not-a-real-server.invalid:1", PACHosts: []string{"example.com"}}, "")
	r := httptest.NewRequest(http.MethodConnect, "http://outside.invalid:443", nil)
	r.Host = "outside.invalid:443"
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != 403 {
		t.Fatalf("outside target was dialed: %d", w.Code)
	}
}
