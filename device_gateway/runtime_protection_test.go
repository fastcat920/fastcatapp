package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestHTTPServerHasBoundedInboundTimeouts(t *testing.T) {
	s := (&Server{cfg: Config{APIPrefix: "/api/v1"}}).httpServer()
	if s.ReadHeaderTimeout <= 0 || s.ReadTimeout <= 0 || s.WriteTimeout <= 0 || s.IdleTimeout <= 0 || s.MaxHeaderBytes > 32<<10 {
		t.Fatal("unbounded inbound server")
	}
	t.Setenv("DG_SERVER_READ_TIMEOUT_SECONDS", "12")
	if got := (&Server{cfg: Config{APIPrefix: "/api/v1"}}).httpServer().ReadTimeout; got != 12*time.Second {
		t.Fatal("timeout override ignored")
	}
}

func TestBoundaryLimitsIsolateLoginPollingAndHeartbeat(t *testing.T) {
	t.Setenv("DG_LOGIN_RATE_PER_MINUTE", "2")
	t.Setenv("DG_QR_CREATE_RATE_PER_MINUTE", "2")
	s := &Server{cfg: Config{APIPrefix: "/api/v1"}}
	h := s.withBoundaryLimits(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(204) }))
	call := func(path string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(http.MethodPost, path, nil)
		r.RemoteAddr = "192.0.2.8:1234"
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w
	}
	for _, path := range []string{"/api/v1/passport/auth/login", "/api/v1/auth/qr/sessions"} {
		for i := 0; i < 2; i++ {
			if call(path).Code != 204 {
				t.Fatal("initial budget rejected")
			}
		}
		limited := call(path)
		if limited.Code != 429 || limited.Header().Get("Retry-After") == "" {
			t.Fatal("boundary did not throttle")
		}
	}
	for i := 0; i < 100; i++ {
		if call("/api/v1/auth/qr/sessions/challenge").Code != 204 || call("/api/v1/user/devices/heartbeat").Code != 204 {
			t.Fatal("login throttle affected polling/heartbeat")
		}
	}
}

func TestRequestLimiterBoundedStorageAndRefill(t *testing.T) {
	l := newGatewayRequestLimits()
	l.maxKeys = 2
	now := time.Now()
	if ok, _ := l.allow("a", 1, now); !ok {
		t.Fatal("initial request blocked")
	}
	if ok, retry := l.allow("a", 1, now); ok || retry != 60 {
		t.Fatal("bucket was not exhausted")
	}
	l.allow("b", 1, now)
	if ok, _ := l.allow("c", 1, now); ok || len(l.buckets) != 2 {
		t.Fatal("unbounded limiter keys")
	}
	if ok, _ := l.allow("a", 1, now.Add(time.Minute)); !ok {
		t.Fatal("token not refilled")
	}
	if ok, _ := l.allow("c", 1, now.Add(4*time.Minute)); !ok {
		t.Fatal("idle buckets not reclaimed")
	}
}

func TestQRCapacitySharedAcrossConcurrentInstances(t *testing.T) {
	t.Setenv("DG_QR_MAX_ACTIVE_SESSIONS", "3")
	pg, _ := newQRTestDB(t)
	a, b := qrTestServer(pg), qrTestServer(pg)
	var okCount, rejected atomic.Int32
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			s := a
			if i%2 == 0 {
				s = b
			}
			err := s.createQRSession(context.Background(), &QRLoginSession{ID: fmt.Sprint(i), ExpiresAt: time.Now().Add(time.Minute)})
			if err == nil {
				okCount.Add(1)
			} else if errors.Is(err, errQRCapacity) {
				rejected.Add(1)
			} else {
				t.Errorf("unexpected isolated store error: %v", err)
			}
		}(i)
	}
	wg.Wait()
	if okCount.Load() != 3 || rejected.Load() != 17 {
		t.Fatalf("capacity race admitted %d rejected %d", okCount.Load(), rejected.Load())
	}
	if err := a.cleanupExpiredQR(context.Background(), time.Now().Add(2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if err := b.createQRSession(context.Background(), &QRLoginSession{ID: "after-expiry", ExpiresAt: time.Now().Add(time.Minute)}); err != nil {
		t.Fatal("expired capacity was not reclaimed")
	}
}

func TestQRCapacityAndPeriodicExpiryInJSONMode(t *testing.T) {
	t.Setenv("DG_QR_MAX_ACTIVE_SESSIONS", "1")
	s := qrTestServer(nil)
	now := time.Now()
	if err := s.createQRSession(context.Background(), &QRLoginSession{ID: "first", ExpiresAt: now.Add(time.Minute)}); err != nil {
		t.Fatal(err)
	}
	err := s.createQRSession(context.Background(), &QRLoginSession{ID: "second", ExpiresAt: now.Add(time.Minute)})
	if !errors.Is(err, errQRCapacity) {
		t.Fatal("JSON capacity not enforced")
	}
	w := httptest.NewRecorder()
	writeQRError(w, err)
	if w.Code != 429 || w.Header().Get("Retry-After") == "" {
		t.Fatal("capacity not retryable")
	}
	s.cleanupExpiredQR(context.Background(), now.Add(2*time.Minute))
	if len(s.qrSessions) != 0 {
		t.Fatal("idle QR payload retained beyond expiry")
	}
}

func TestSessionRetentionOnlyRemovesLongExpiredSessions(t *testing.T) {
	t.Setenv("DG_SESSION_RETENTION_DAYS", "30")
	now := time.Now()
	st := emptyAdmissionStore()
	st.path = filepath.Join(t.TempDir(), "store.json")
	st.Devices["device"] = &DeviceRecord{ID: "device", Status: statusActive, LastSeenAt: now}
	for _, record := range []*SessionRecord{
		{ID: "old", DeviceID: "device", TokenHash: "old-token", Status: statusRevoked, ExpiresAt: now.Add(-31 * 24 * time.Hour)},
		{ID: "recent-expiry", DeviceID: "device", Status: statusActive, ExpiresAt: now.Add(-time.Hour)},
		{ID: "live", DeviceID: "device", Status: statusActive, ExpiresAt: now.Add(time.Hour)},
		{ID: "revoked-future", DeviceID: "device", Status: statusRevoked, ExpiresAt: now.Add(time.Hour)},
	} {
		st.Sessions[record.ID] = record
	}
	st.rebuildSessionIndexesLocked()
	s := &Server{store: st}
	count, err := s.cleanupOldSessions(context.Background(), now)
	if err != nil || count != 1 || len(st.Sessions) != 3 {
		t.Fatalf("unsafe retention: removed %d error %v", count, err)
	}
	if st.Devices["device"] == nil {
		t.Fatal("retention deleted active device")
	}
	if _, exists := st.sessionByTokenHash["old-token"]; exists {
		t.Fatal("deleted token remains indexed")
	}
	if !strings.Contains(cleanupSessionsSQL, "expires_at < $1") {
		t.Fatal("PG cleanup must predicate on authoritative expiry")
	}
}

func TestSessionRetentionFailedSaveLeavesMemoryUntouched(t *testing.T) {
	st := emptyAdmissionStore()
	st.path = t.TempDir()
	st.Sessions["old"] = &SessionRecord{ID: "old", ExpiresAt: time.Now().Add(-400 * 24 * time.Hour)}
	_, err := (&Server{store: st}).cleanupOldSessions(context.Background(), time.Now())
	if err == nil || st.Sessions["old"] == nil {
		t.Fatal("failed persistence removed local history")
	}
}

func TestDelayedHeartbeatCannotResurrectRetainedAwaySession(t *testing.T) {
	state := &consistencyDB{sessions: map[string]*SessionRecord{}}
	pg := isolatedPostgres(t, state)
	stale := &SessionRecord{ID: "deleted", DeviceID: "device", Status: statusActive, CreatedAt: time.Now().Add(-60 * 24 * time.Hour), ExpiresAt: time.Now().Add(24 * time.Hour)}
	if err := pg.SaveChanges(context.Background(), PostgresChanges{Sessions: map[string]*SessionRecord{stale.ID: stale}}); err != nil {
		t.Fatal(err)
	}
	if state.sessions[stale.ID] != nil {
		t.Fatal("stale instance revived physically deleted session")
	}
	if !strings.Contains(upsertSessionSQL, "WHERE $15::boolean OR EXISTS") {
		t.Fatal("session creation guard missing")
	}
}
