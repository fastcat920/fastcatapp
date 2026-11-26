package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestBrowserLabBoundsAndUnauthorizedQuota(t *testing.T) {
	b := &browserLab{token: strings.Repeat("a", 32), local: map[string]bool{}}
	b.remaining.Store(8192)
	for i := 0; i < 150; i++ {
		w := httptest.NewRecorder()
		b.ServeHTTP(w, httptest.NewRequest("GET", "https://example.com/data/1", nil))
		if w.Code != 404 {
			t.Fatal(w.Code)
		}
	}
	r := httptest.NewRequest("GET", "https://example.com/data/8192", nil)
	r.Header.Set("X-Lab-Run", b.token)
	w := httptest.NewRecorder()
	b.ServeHTTP(w, r)
	if w.Code != 200 || w.Body.Len() != 8192 {
		t.Fatal(w.Code, w.Body.Len())
	}
	r = httptest.NewRequest("GET", "https://example.com/data/1", nil)
	r.Header.Set("X-Lab-Run", b.token)
	w = httptest.NewRecorder()
	b.ServeHTTP(w, r)
	if w.Code != http.StatusTooManyRequests {
		t.Fatal(w.Code)
	}
}
func TestPACIncludesOnlySelectedHosts(t *testing.T) {
	p, e := makePAC([]string{"Example.COM"}, "127.0.0.1:18091")
	if e != nil || !strings.Contains(p, `"example.com"`) || !strings.Contains(p, `"DIRECT"`) {
		t.Fatal(p, e)
	}
	if _, e = makePAC([]string{"a\";evil()"}, "127.0.0.1:18091"); e == nil {
		t.Fatal("PAC injection accepted")
	}
}
