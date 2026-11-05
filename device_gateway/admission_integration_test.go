package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

// Opt in only against a throwaway local PostgreSQL database, for example a URI
// whose database is named fastcat_test_admission. Never use DG_POSTGRES_DSN.
// Each run creates and removes its own random schema; the rest of the database
// is untouched. Default unit/race runs skip this test and need no PostgreSQL.
func TestPostgresAdmissionIntegration(t *testing.T) {
	dsn := os.Getenv("FASTCAT_TEST_POSTGRES_DSN")
	if dsn == "" {
		t.Skip("set FASTCAT_TEST_POSTGRES_DSN to a dedicated local fastcat_test_* database")
	}
	u, err := url.Parse(dsn)
	if err != nil || (u.Scheme != "postgres" && u.Scheme != "postgresql") ||
		(u.Hostname() != "localhost" && u.Hostname() != "127.0.0.1" && u.Hostname() != "::1") ||
		!strings.HasPrefix(strings.TrimPrefix(u.Path, "/"), "fastcat_test_") {
		t.Fatal("integration test requires a PostgreSQL URI for localhost and a fastcat_test_* database")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	admin, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatal("cannot open isolated PostgreSQL connection")
	}
	defer admin.Close()
	schema := "fastcat_admission_" + randomHex(8)
	if _, err := admin.ExecContext(ctx, "CREATE SCHEMA "+schema); err != nil {
		t.Fatal("cannot create isolated admission test schema")
	}
	defer func() {
		cleanup, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if _, err := admin.ExecContext(cleanup, "DROP SCHEMA "+schema+" CASCADE"); err != nil {
			t.Error("could not remove isolated admission test schema")
		}
	}()
	q := u.Query()
	q.Set("search_path", schema)
	u.RawQuery = q.Encode()
	pg, err := NewPostgresStore(ctx, u.String())
	if err != nil {
		t.Fatal("cannot initialize isolated PostgreSQL schema")
	}
	defer pg.Close()
	t.Run("runtime_protection", func(t *testing.T) { runRuntimeProtectionIntegration(t, pg) })
	for _, scenario := range []struct {
		name, policy string
		sameDevice   bool
		wantSuccess  int
	}{{"strict", policyStrict, false, 1}, {"kick_oldest", policyKickOldest, false, 2}, {"same_device", policyStrict, true, 2}} {
		t.Run(scenario.name, func(t *testing.T) {
			if _, err := pg.db.ExecContext(ctx, "TRUNCATE dg_sessions,dg_devices,dg_users,dg_audit_logs"); err != nil {
				t.Fatal(err)
			}
			assertConcurrentAdmissions(t, pg, scenario.policy, scenario.sameDevice, scenario.wantSuccess)
			for _, query := range []string{
				"SELECT COUNT(*) FROM dg_devices WHERE status='active'",
				"SELECT COUNT(*) FROM dg_sessions WHERE status='active'",
				"SELECT COUNT(*) FROM dg_users",
			} {
				var count int
				if err := pg.db.QueryRowContext(ctx, query).Scan(&count); err != nil {
					t.Fatal(err)
				}
				if count != 1 {
					t.Fatalf("unexpected shared count %d for %s", count, query)
				}
			}
			if scenario.sameDevice {
				var count int
				if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM dg_devices").Scan(&count); err != nil || count != 1 {
					t.Fatal("same device was inserted twice")
				}
			}
		})
	}
	// Completion (e.g. writing the QR authorization result) is part of the same
	// rollback boundary as kicking an old device and creating its replacement.
	t.Run("completion_rollback", func(t *testing.T) {
		s := admissionServer(pg, policyKickOldest)
		_, _, _, _, err := runAdmission(s, "would-replace", func(context.Context, *sql.Tx, string, *DeviceRecord, int, int) error {
			return errors.New("completion refused")
		})
		if err == nil || len(s.store.Devices) != 0 || len(s.store.Sessions) != 0 {
			t.Fatal("failed completion published local login state")
		}
		var active, all int
		if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM dg_devices WHERE status='active'").Scan(&active); err != nil {
			t.Fatal(err)
		}
		if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM dg_devices").Scan(&all); err != nil {
			t.Fatal(err)
		}
		if active != 1 || all != 1 {
			t.Fatal("failed completion changed shared device state")
		}
	})
	t.Run("qr_cross_instance_delivery_and_atomic_expiry", func(t *testing.T) {
		if _, err := pg.db.ExecContext(ctx, "TRUNCATE dg_qr_login_sessions,dg_sessions,dg_devices,dg_users,dg_audit_logs"); err != nil {
			t.Fatal(err)
		}
		a, b, c := admissionServer(pg, policyKickOldest), admissionServer(pg, policyKickOldest), admissionServer(pg, policyKickOldest)
		for _, s := range []*Server{a, b, c} {
			s.cfg.APIPrefix = "/api/v1"
		}
		now := time.Now().UTC()
		item := &QRLoginSession{
			ID: "integration-qr", PollToken: "integration-poll-secret", Status: "pending", DeliveryACK: true,
			Device:    LoginRequest{DeviceID: "tv-device", DeviceName: "TV", Platform: "tvos"},
			CreatedAt: now, ExpiresAt: now.Add(time.Minute),
		}
		if err := a.createQRSession(ctx, item); err != nil {
			t.Fatal(err)
		}
		claim := "integration-claim"
		if err := b.mutateQRSession(ctx, nil, item.ID, func(qr *QRLoginSession) (bool, error) {
			if qr.Status != "pending" {
				return false, errQRUsed
			}
			qr.Status, qr.ApprovalClaim = "authorizing", claim
			return false, nil
		}); err != nil {
			t.Fatal(err)
		}
		r := httptest.NewRequest(http.MethodPost, "/approve", nil).WithContext(ctx)
		snapshot := SubscriptionSnapshot{Email: "user@example.test", UUID: "business-user", DeviceLimit: intPtr(1)}
		if _, _, err := b.approveQRDevice(r, item.Device, snapshot, "test-business", item.ID, claim); err != nil {
			t.Fatal(err)
		}
		status, first := callQR(t, c, http.MethodGet, item.ID, "?poll_token="+item.PollToken, "")
		if status != http.StatusOK || first["status"] != "approved" {
			t.Fatal("gateway C could not retrieve gateway B's approved response")
		}
		login, ok := first["login"].(map[string]any)
		if !ok || login["auth_data"] == "" || first["delivery_id"] == "" {
			t.Fatal("approved delivery omitted credentials/receipt")
		}
		status, second := callQR(t, c, http.MethodGet, item.ID, "?poll_token="+item.PollToken, "")
		secondLogin, ok := second["login"].(map[string]any)
		if status != http.StatusOK || !ok || secondLogin["auth_data"] != login["auth_data"] || second["delivery_id"] != first["delivery_id"] {
			t.Fatal("retry after lost poll response did not return the same committed delivery")
		}
		ack, _ := json.Marshal(map[string]any{"poll_token": item.PollToken, "delivery_id": first["delivery_id"]})
		if status, _ := callQR(t, c, http.MethodPost, item.ID+"/ack", "", string(ack)); status != http.StatusOK {
			t.Fatal("shared ACK failed")
		}
		_, after := callQR(t, a, http.MethodGet, item.ID, "?poll_token="+item.PollToken, "")
		if after["status"] != "consumed" || after["login"] != nil {
			t.Fatal("ACK did not clear delivery across instances")
		}
		var ciphertext string
		if err := pg.db.QueryRowContext(ctx, "SELECT payload_cipher FROM dg_qr_login_sessions WHERE id=$1", item.ID).Scan(&ciphertext); err != nil {
			t.Fatal(err)
		}
		cleared, err := a.decodeQR(item.ID, ciphertext)
		if err != nil || cleared.Response != nil {
			t.Fatal("ACK did not erase the persisted credential response")
		}
		for _, table := range []string{"dg_devices", "dg_sessions"} {
			var count int
			if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM "+table).Scan(&count); err != nil || count != 1 {
				t.Fatal("poll retry created an additional device/session")
			}
		}
		// The claim expires before admission completion. This invokes the real
		// QR row lock in the same transaction *after* preparing a kick/relogin.
		expired := &QRLoginSession{
			ID: "expired-integration-qr", PollToken: "expired-poll-secret", Status: "authorizing", ApprovalClaim: claim,
			Device:    LoginRequest{DeviceID: "new-tv-device", DeviceName: "TV2", Platform: "tvos"},
			CreatedAt: now.Add(-time.Minute), ExpiresAt: now.Add(-time.Second), DeliveryACK: true,
		}
		if err := a.createQRSession(ctx, expired); err != nil {
			t.Fatal(err)
		}
		if _, _, err := b.approveQRDevice(r, expired.Device, snapshot, "test-business", expired.ID, claim); !errors.Is(err, errQRExpired) {
			t.Fatal("expired approval completion was not rejected")
		}
		for _, table := range []string{"dg_devices", "dg_sessions"} {
			var all, active int
			if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*),COUNT(*) FILTER (WHERE status='active') FROM "+table).Scan(&all, &active); err != nil || all != 1 || active != 1 {
				t.Fatal("expired approval left a ghost record or kicked the old device/session")
			}
		}
		if len(b.store.Devices) != 1 || len(b.store.Sessions) != 1 {
			t.Fatal("expired approval polluted the admitting gateway cache")
		}
		for _, device := range b.store.Devices {
			if device.Status != statusActive {
				t.Fatal("expired approval revoked the local old device")
			}
		}
	})
	t.Run("failed_old_revocation_does_not_kill_new_login", func(t *testing.T) {
		if _, err := pg.db.ExecContext(ctx, "TRUNCATE dg_sessions,dg_devices,dg_users,dg_audit_logs"); err != nil {
			t.Fatal(err)
		}
		b := admissionServer(pg, policyStrict)
		_, old, _, _, err := runAdmission(b, "same-device", nil)
		if err != nil {
			t.Fatal(err)
		}
		t1 := time.Now().UTC().Add(-time.Second)
		t0 := t1.Add(-time.Minute)
		if _, err := pg.db.ExecContext(ctx, "UPDATE dg_devices SET last_login_at=$1,last_seen_at=$1 WHERE id=$2", t0, old.ID); err != nil {
			t.Fatal(err)
		}
		if _, err := pg.db.ExecContext(ctx, "UPDATE dg_sessions SET created_at=$1 WHERE device_id=$2", t0, old.ID); err != nil {
			t.Fatal(err)
		}
		a := admissionServer(pg, policyStrict)
		a.store.Devices[old.ID] = cloneDevice(old)
		a.revokeDeviceLocked(a.store.Devices[old.ID], "admin", t1)
		// A's T1 write fails locally; this opens no connection and simulates a
		// temporarily unavailable pool without disturbing the shared test DB.
		closed, err := sql.Open("postgres", u.String())
		if err != nil {
			t.Fatal(err)
		}
		_ = closed.Close()
		a.store.pg = &PostgresStore{db: closed}
		if err := a.store.Save(); err == nil {
			t.Fatal("test did not retain a failed revocation")
		}
		a.store.pg = pg
		_, fresh, _, _, err := runAdmission(b, "same-device", nil)
		if err != nil || fresh.ID != old.ID {
			t.Fatal("new login did not reuse the device")
		}
		var generation time.Time
		if err := pg.db.QueryRowContext(ctx, "SELECT last_login_at FROM dg_devices WHERE id=$1", old.ID).Scan(&generation); err != nil {
			t.Fatal(err)
		}
		heartbeat := cloneDevice(fresh)
		heartbeat.LastSeenAt = fresh.LastSeenAt.Add(time.Minute)
		if err := pg.SaveChanges(ctx, PostgresChanges{Devices: map[string]*DeviceRecord{old.ID: heartbeat}}); err != nil {
			t.Fatal(err)
		}
		if err := a.store.Save(); err != nil {
			t.Fatal(err)
		}
		var status string
		var unchanged time.Time
		if err := pg.db.QueryRowContext(ctx, "SELECT status,last_login_at FROM dg_devices WHERE id=$1", old.ID).Scan(&status, &unchanged); err != nil {
			t.Fatal(err)
		}
		var active int
		if err := pg.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM dg_sessions WHERE device_id=$1 AND status='active'", old.ID).Scan(&active); err != nil {
			t.Fatal(err)
		}
		if status != statusActive || active != 1 || !unchanged.Equal(generation) {
			t.Fatal("old failed revocation or heartbeat invalidated the new login generation")
		}
	})
	t.Run("failed_old_admin_override_does_not_replace_newer_change", func(t *testing.T) {
		var userID string
		if err := pg.db.QueryRowContext(ctx, "SELECT id FROM dg_users LIMIT 1").Scan(&userID); err != nil {
			t.Fatal(err)
		}
		t1 := time.Now().UTC().Add(-time.Minute)
		t2 := t1.Add(time.Second)
		old := &UserCache{ID: userID, DeviceLimitOverride: intPtr(2), UpdatedAt: t1}
		a := &Store{pg: pg, Users: map[string]*UserCache{userID: old}, Devices: map[string]*DeviceRecord{}, Sessions: map[string]*SessionRecord{}}
		a.markUserLimitOverrideLocked(userID)
		closed, err := sql.Open("postgres", u.String())
		if err != nil {
			t.Fatal(err)
		}
		_ = closed.Close()
		a.pg = &PostgresStore{db: closed}
		if err := a.Save(); err == nil {
			t.Fatal("test did not retain an unsuccessful administrator write")
		}
		a.pg = pg
		if err := pg.SaveChanges(ctx, PostgresChanges{
			Users:              map[string]*UserCache{userID: {ID: userID, DeviceLimitOverride: intPtr(7), UpdatedAt: t2}},
			UserLimitOverrides: map[string]time.Time{userID: t2},
		}); err != nil {
			t.Fatal(err)
		}
		old.UpdatedAt = time.Now().UTC() // an unrelated later profile refresh
		if err := a.Save(); err != nil {
			t.Fatal(err)
		}
		var limit int
		var event time.Time
		if err := pg.db.QueryRowContext(ctx, "SELECT device_limit_override,override_updated_at FROM dg_users WHERE id=$1", userID).Scan(&limit, &event); err != nil {
			t.Fatal(err)
		}
		if limit != 7 || event.Before(t2.Add(-time.Microsecond)) {
			t.Fatal("late old override replaced a newer explicit administrator change")
		}
	})
}
