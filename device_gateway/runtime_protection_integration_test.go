package main

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// Called only by the guarded, disposable local-database integration fixture.
func runRuntimeProtectionIntegration(t *testing.T, pg *PostgresStore) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if _, err := pg.db.ExecContext(ctx, "TRUNCATE dg_qr_login_sessions,dg_sessions,dg_devices,dg_users,dg_audit_logs"); err != nil {
		t.Fatal(err)
	}
	t.Setenv("DG_QR_MAX_ACTIVE_SESSIONS", "1")
	a, b := qrTestServer(pg), qrTestServer(pg)
	var admitted atomic.Int32
	var wg sync.WaitGroup
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			s := a
			if i%2 == 0 {
				s = b
			}
			err := s.createQRSession(ctx, &QRLoginSession{ID: fmt.Sprintf("capacity-%d", i), ExpiresAt: time.Now().Add(time.Minute)})
			if err == nil {
				admitted.Add(1)
			} else if !errors.Is(err, errQRCapacity) {
				t.Errorf("concurrent QR create failed: %v", err)
			}
		}(i)
	}
	wg.Wait()
	if admitted.Load() != 1 {
		t.Fatalf("PG capacity admitted %d", admitted.Load())
	}
	if _, err := pg.db.ExecContext(ctx, "UPDATE dg_qr_login_sessions SET expires_at=$1", time.Now().Add(-time.Second)); err != nil {
		t.Fatal(err)
	}
	if err := b.cleanupExpiredQR(ctx, time.Now()); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM dg_qr_login_sessions").Scan(&count); err != nil || count != 0 {
		t.Fatal("periodic QR cleanup retained expired payload")
	}

	server := admissionServer(pg, policyStrict)
	_, device, _, _, err := runAdmission(server, "live-device", nil)
	if err != nil {
		t.Fatal(err)
	}
	var live *SessionRecord
	for _, session := range server.store.Sessions {
		live = session
	}
	if live == nil {
		t.Fatal("missing live session")
	}
	old := *live
	old.ID = "retained-away"
	old.Status = statusRevoked
	old.ExpiresAt = time.Now().Add(-40 * 24 * time.Hour)
	tx, err := pg.db.BeginTx(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := pg.upsertSessions(ctx, tx, &Store{Sessions: map[string]*SessionRecord{old.ID: &old}}); err != nil {
		tx.Rollback()
		t.Fatal(err)
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}
	server.store.Sessions[old.ID] = &old
	staleRevokedAt := time.Now().Add(-100 * 24 * time.Hour)
	server.store.Devices[device.ID].Status = statusRevoked
	server.store.Devices[device.ID].RevokedAt = &staleRevokedAt
	if err := server.cleanupPostgresDevices(ctx, time.Now()); err != nil {
		t.Fatal(err)
	}
	var status string
	if err := pg.db.QueryRowContext(ctx, "SELECT status FROM dg_devices WHERE id=$1", device.ID).Scan(&status); err != nil || status != statusActive {
		t.Fatal("stale local device view deleted/reactivated shared login")
	}
	removed, err := server.cleanupOldSessions(ctx, time.Now())
	if err != nil || removed != 1 {
		t.Fatalf("retention removed %d error %v", removed, err)
	}
	if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM dg_sessions WHERE id=$1 AND status='active'", live.ID).Scan(&count); err != nil || count != 1 {
		t.Fatal("retention removed current session")
	}
	// A lagging instance may hold the pre-revocation (longer) expiry. It must
	// not recreate a physically purged ID through the heartbeat UPSERT path.
	old.Status = statusActive
	old.ExpiresAt = time.Now().Add(24 * time.Hour)
	if err := pg.SaveChanges(ctx, PostgresChanges{Sessions: map[string]*SessionRecord{old.ID: &old}}); err != nil {
		t.Fatal(err)
	}
	if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM dg_sessions WHERE id=$1", old.ID).Scan(&count); err != nil || count != 0 {
		t.Fatal("delayed heartbeat resurrected purged session")
	}
	// Even a historically revoked device is retained if an independently
	// persisted, still-valid session exists; cleanup never deletes that token.
	if _, err := pg.db.ExecContext(ctx, "UPDATE dg_devices SET status='revoked',revoked_at=$2 WHERE id=$1", device.ID, staleRevokedAt); err != nil {
		t.Fatal(err)
	}
	if err := server.cleanupPostgresDevices(ctx, time.Now()); err != nil {
		t.Fatal(err)
	}
	if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM dg_devices WHERE id=$1", device.ID).Scan(&count); err != nil || count != 1 {
		t.Fatal("old device cleanup ignored live session guard")
	}
}
