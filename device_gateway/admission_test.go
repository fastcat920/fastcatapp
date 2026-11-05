package main

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// An isolated transactional driver tests gateway sequencing/rollback without a
// running database. It requires the actual advisory/row-lock SQL, but does not
// substitute for the opt-in PostgreSQL integration test's SQL/locking coverage.
type admissionDB struct {
	gate       chan struct{}
	store      *Store
	fail       string
	loginAt    map[string]time.Time
	overrideAt map[string]time.Time
}
type admissionConnector struct{ state *admissionDB }
type admissionDriver struct{}
type admissionConn struct {
	db *admissionDB
	tx *admissionTx
}
type admissionTx struct {
	conn       *admissionConn
	staged     *Store
	locked     bool
	loginAt    map[string]time.Time
	overrideAt map[string]time.Time
}
type admissionStmt struct {
	conn  *admissionConn
	query string
}

func (c admissionConnector) Connect(context.Context) (driver.Conn, error) {
	return &admissionConn{db: c.state}, nil
}
func (admissionConnector) Driver() driver.Driver { return admissionDriver{} }
func (admissionDriver) Open(string) (driver.Conn, error) {
	return nil, errors.New("use isolated connector")
}
func (c *admissionConn) Prepare(query string) (driver.Stmt, error) {
	return &admissionStmt{conn: c, query: query}, nil
}
func (*admissionConn) Close() error { return nil }
func (c *admissionConn) Begin() (driver.Tx, error) {
	return nil, errors.New("admission must have a context deadline")
}
func (c *admissionConn) BeginTx(ctx context.Context, opts driver.TxOptions) (driver.Tx, error) {
	if _, ok := ctx.Deadline(); !ok || opts.Isolation != driver.IsolationLevel(sql.LevelReadCommitted) {
		return nil, errors.New("admission transaction requires deadline and read committed isolation")
	}
	c.tx = &admissionTx{conn: c}
	return c.tx, nil
}
func (tx *admissionTx) Commit() error {
	defer tx.release()
	if tx.conn.db.fail == "commit" {
		return errors.New("injected commit failure")
	}
	if !tx.locked {
		return errors.New("admission committed without an account lock")
	}
	tx.conn.db.store = tx.staged
	tx.conn.db.loginAt, tx.conn.db.overrideAt = tx.loginAt, tx.overrideAt
	return nil
}
func (tx *admissionTx) Rollback() error { tx.release(); return nil }
func (tx *admissionTx) release() {
	if tx.locked {
		tx.locked = false
		tx.conn.db.gate <- struct{}{}
	}
	tx.conn.tx = nil
}
func (*admissionStmt) Close() error  { return nil }
func (*admissionStmt) NumInput() int { return -1 }
func (s *admissionStmt) Exec(args []driver.Value) (driver.Result, error) {
	return s.conn.exec(s.query, args)
}
func (*admissionStmt) Query([]driver.Value) (driver.Rows, error) {
	return nil, errors.New("unexpected prepared query")
}
func (c *admissionConn) ExecContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Result, error) {
	if query == admissionLockSQL {
		if c.tx == nil {
			return nil, errors.New("advisory lock must be transactional")
		}
		if !c.tx.locked {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-c.db.gate:
				c.tx.locked = true
				c.tx.staged = cloneAdmissionStore(c.db.store)
				c.tx.loginAt, c.tx.overrideAt = cloneEventTimes(c.db.loginAt), cloneEventTimes(c.db.overrideAt)
			}
		}
		return driver.RowsAffected(1), nil
	}
	values := make([]driver.Value, len(args))
	for i, arg := range args {
		values[i] = arg.Value
	}
	return c.exec(query, values)
}

func valueInt(v driver.Value) *int {
	if v == nil {
		return nil
	}
	return intPtr(int(v.(int64)))
}

func (c *admissionConn) exec(query string, a []driver.Value) (driver.Result, error) {
	if c.tx == nil || !c.tx.locked {
		return nil, errors.New("write before account lock")
	}
	s := c.tx.staged
	switch query {
	case upsertUserSQL:
		u := &UserCache{ID: a[0].(string), BusinessUserID: a[1].(string), Email: a[2].(string), PlanID: int(a[3].(int64)), PlanName: a[4].(string), DeviceLimit: valueInt(a[5]), DeviceLimitOverride: valueInt(a[6]), LastSyncedAt: a[7].(time.Time), CreatedAt: a[8].(time.Time), UpdatedAt: a[9].(time.Time)}
		if old := s.Users[u.ID]; old != nil {
			if u.LastSyncedAt.Before(old.LastSyncedAt) {
				u.BusinessUserID, u.Email, u.PlanID, u.PlanName, u.DeviceLimit, u.LastSyncedAt = old.BusinessUserID, old.Email, old.PlanID, old.PlanName, old.DeviceLimit, old.LastSyncedAt
			}
			if !a[10].(bool) || a[11].(time.Time).Before(c.tx.overrideAt[u.ID]) {
				u.DeviceLimitOverride = old.DeviceLimitOverride
			}
		}
		if a[10].(bool) && a[11].(time.Time).After(c.tx.overrideAt[u.ID]) {
			c.tx.overrideAt[u.ID] = a[11].(time.Time)
		}
		s.Users[u.ID] = u
	case upsertDeviceSQL:
		d := &DeviceRecord{ID: a[0].(string), UserID: a[1].(string), DeviceIDHash: a[2].(string), DeviceName: a[3].(string), Platform: a[4].(string), AppVersion: a[5].(string), OSVersion: a[6].(string), Status: a[7].(string), LastSeenAt: a[8].(time.Time), CreatedAt: a[9].(time.Time), RevokedBy: a[11].(string), LastIP: a[12].(string), LastIPRegion: a[13].(string), LastIPISP: a[14].(string), UserAgent: a[15].(string)}
		if v, ok := a[10].(time.Time); ok {
			d.RevokedAt = &v
		}
		if !allowTestDeviceUpsert(s.Devices[d.ID], d, a[16].(bool), c.tx.loginAt[d.ID]) {
			return driver.RowsAffected(0), nil
		}
		if a[16].(bool) {
			c.tx.loginAt[d.ID] = d.LastSeenAt
		}
		s.Devices[d.ID] = d
	case revokeDeviceSessionsSQL:
		for _, session := range s.Sessions {
			if session.DeviceID == a[0] && session.Status == statusActive && !session.CreatedAt.After(a[1].(time.Time)) {
				session.Status = statusRevoked
				if expires := a[1].(time.Time); session.ExpiresAt.After(expires) {
					session.ExpiresAt = expires
				}
			}
		}
	case upsertSessionSQL:
		if s.Sessions[a[0].(string)] == nil && !a[14].(bool) {
			return driver.RowsAffected(0), nil
		}
		if c.db.fail == "session" {
			return nil, errors.New("injected session persistence failure")
		}
		s.Sessions[a[0].(string)] = &SessionRecord{ID: a[0].(string), UserID: a[1].(string), DeviceID: a[2].(string), TokenHash: a[3].(string), BusinessTokenCipher: a[4].(string), BusinessSubURLCipher: a[5].(string), SubscribeTokenHash: a[6].(string), SubscribeTokenCipher: a[7].(string), Status: a[8].(string), ExpiresAt: a[9].(time.Time), CreatedAt: a[10].(time.Time), LastSeenAt: a[11].(time.Time), LastIP: a[12].(string), UserAgent: a[13].(string)}
	default:
		if !strings.HasPrefix(query, "INSERT INTO dg_audit_logs") {
			return nil, fmt.Errorf("unexpected admission SQL: %s", query)
		}
	}
	return driver.RowsAffected(1), nil
}

func (c *admissionConn) QueryContext(_ context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	if c.tx == nil || !c.tx.locked {
		return nil, errors.New("authoritative read before account lock")
	}
	s := c.tx.staged
	rows := &consistencyRows{}
	switch query {
	case admissionUserSQL:
		rows.columns = strings.Split("id,business,email,plan_id,plan_name,limit,override,synced,created,updated", ",")
		for _, u := range s.Users {
			if (args[0].Value != "" && u.BusinessUserID == args[0].Value) || strings.ToLower(u.Email) == args[1].Value {
				var limit, override driver.Value
				if u.DeviceLimit != nil {
					limit = int64(*u.DeviceLimit)
				}
				if u.DeviceLimitOverride != nil {
					override = int64(*u.DeviceLimitOverride)
				}
				rows.rows = append(rows.rows, []driver.Value{u.ID, u.BusinessUserID, u.Email, int64(u.PlanID), u.PlanName, limit, override, u.LastSyncedAt, u.CreatedAt, u.UpdatedAt})
				break
			}
		}
	case admissionDevicesSQL:
		rows.columns = strings.Split("id,user,hash,name,platform,app,os,status,seen,created,revoked,by,ip,region,isp,ua", ",")
		for _, d := range s.Devices {
			if d.UserID == args[0].Value {
				var revoked driver.Value
				if d.RevokedAt != nil {
					revoked = *d.RevokedAt
				}
				rows.rows = append(rows.rows, []driver.Value{d.ID, d.UserID, d.DeviceIDHash, d.DeviceName, d.Platform, d.AppVersion, d.OSVersion, d.Status, d.LastSeenAt, d.CreatedAt, revoked, d.RevokedBy, d.LastIP, d.LastIPRegion, d.LastIPISP, d.UserAgent})
			}
		}
	default:
		return nil, errors.New("unexpected admission read")
	}
	return rows, nil
}

func newAdmissionDB(t *testing.T) (*PostgresStore, *admissionDB) {
	t.Helper()
	state := &admissionDB{gate: make(chan struct{}, 1), store: emptyAdmissionStore()}
	state.gate <- struct{}{}
	db := sql.OpenDB(admissionConnector{state: state})
	t.Cleanup(func() { _ = db.Close() })
	return &PostgresStore{db: db}, state
}

func admissionServer(pg *PostgresStore, policy string) *Server {
	store := emptyAdmissionStore()
	store.pg = pg
	return &Server{cfg: Config{TokenSecret: "admission-test-key", SessionTTL: time.Hour, DefaultDeviceLimit: 1, DevicePolicy: policy}, key: deriveKey("admission-test-key"), store: store}
}

func runAdmission(s *Server, device string, complete admissionCompletion) (string, *DeviceRecord, int, int, error) {
	r := httptest.NewRequest(http.MethodPost, "/login", nil)
	return s.admitDeviceWithCompletion(r, LoginRequest{Email: "user@example.test", DeviceID: device, Platform: "test"}, SubscriptionSnapshot{Email: "user@example.test", UUID: "business-user", DeviceLimit: intPtr(1)}, "isolated-business-token", complete)
}

func TestPostgresConcurrentDeviceAdmission(t *testing.T) {
	for _, scenario := range []struct {
		name, policy string
		sameDevice   bool
		wantSuccess  int
	}{{"strict", policyStrict, false, 1}, {"kick_oldest", policyKickOldest, false, 2}, {"same_device", policyStrict, true, 2}} {
		t.Run(scenario.name, func(t *testing.T) {
			pg, state := newAdmissionDB(t)
			assertConcurrentAdmissions(t, pg, scenario.policy, scenario.sameDevice, scenario.wantSuccess)
			activeDevices, activeSessions := 0, 0
			for _, d := range state.store.Devices {
				if d.Status == statusActive {
					activeDevices++
				}
			}
			for _, s := range state.store.Sessions {
				if s.Status == statusActive {
					activeSessions++
				}
			}
			if activeDevices != 1 || activeSessions != 1 || len(state.store.Users) != 1 {
				t.Fatalf("admission exceeded limit or left old session active: devices=%d sessions=%d users=%d", activeDevices, activeSessions, len(state.store.Users))
			}
			if scenario.sameDevice && len(state.store.Devices) != 1 {
				t.Fatal("simultaneous relogin created duplicate device records")
			}
		})
	}
}

func assertConcurrentAdmissions(t *testing.T, pg *PostgresStore, policy string, sameDevice bool, wantSuccess int) {
	t.Helper()
	start := make(chan struct{})
	results := make(chan error, 2)
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			s := admissionServer(pg, policy) // deliberately independent empty caches
			device := fmt.Sprintf("device-%d", i)
			if sameDevice {
				device = "same-device"
			}
			<-start
			_, _, _, _, err := runAdmission(s, device, nil)
			if err != nil && (len(s.store.Users) != 0 || len(s.store.Devices) != 0 || len(s.store.Sessions) != 0) {
				results <- errors.New("rejected admission polluted local cache")
				return
			}
			results <- err
		}(i)
	}
	close(start)
	wg.Wait()
	close(results)
	success := 0
	for err := range results {
		if err == nil {
			success++
		} else if !errors.Is(err, errDeviceLimitExceeded) {
			t.Fatal(err)
		}
	}
	if success != wantSuccess {
		t.Fatalf("successful admissions = %d, want %d", success, wantSuccess)
	}
}

func TestPostgresAdmissionFailureRollsBackKicksAndNewSession(t *testing.T) {
	for _, failure := range []string{"session", "completion", "commit"} {
		t.Run(failure, func(t *testing.T) {
			pg, db := newAdmissionDB(t)
			s := admissionServer(pg, policyKickOldest)
			_, old, _, _, err := runAdmission(s, "old", nil)
			if err != nil {
				t.Fatal(err)
			}
			db.fail = failure
			called := false
			complete := admissionCompletion(nil)
			if failure == "completion" {
				complete = func(_ context.Context, tx *sql.Tx, _ string, _ *DeviceRecord, _, _ int) error {
					called = true
					if tx == nil {
						t.Fatal("PG completion must join the admission transaction")
					}
					return errors.New("injected QR completion failure")
				}
			}
			token, _, _, _, err := runAdmission(s, "new", complete)
			if err == nil || token != "" {
				t.Fatal("failed admission returned credentials")
			}
			if failure == "completion" && !called {
				t.Fatal("completion was not exercised")
			}
			if len(s.store.Devices) != 1 || s.store.Devices[old.ID].Status != statusActive || len(s.store.Sessions) != 1 ||
				len(db.store.Devices) != 1 || db.store.Devices[old.ID].Status != statusActive || len(db.store.Sessions) != 1 {
				t.Fatal("failed transaction left a ghost device/session or revoked the old device")
			}
		})
	}
}

func TestPostgresAdmissionUsesSharedLimitWhenSubscriptionUnavailable(t *testing.T) {
	pg, db := newAdmissionDB(t)
	db.store.Users["user"] = &UserCache{ID: "user", Email: "user@example.test", BusinessUserID: "business-user", PlanID: 5, DeviceLimit: intPtr(2), DeviceLimitOverride: intPtr(1)}
	db.store.Devices["old"] = &DeviceRecord{ID: "old", UserID: "user", DeviceIDHash: "different-device", Status: statusActive}
	s := admissionServer(pg, policyStrict)
	s.store.Users["user"] = &UserCache{ID: "user", Email: "user@example.test", DeviceLimit: intPtr(10)} // stale instance cache
	r := httptest.NewRequest(http.MethodPost, "/login", nil)
	req := LoginRequest{Email: "user@example.test", DeviceID: "new-device"}
	snapshot := SubscriptionSnapshot{Email: req.Email, Unavailable: true}
	_, _, limit, active, err := s.admitDevice(r, req, snapshot, "test-business")
	if !errors.Is(err, errDeviceLimitExceeded) || limit != 1 || active != 1 {
		t.Fatal("admission used stale local limits instead of the shared administrator override")
	}
	if *s.store.Users["user"].DeviceLimit != 10 || len(s.store.Devices) != 0 {
		t.Fatal("rejected admission changed local cache")
	}
	db.store.Users["user"].DeviceLimitOverride = nil
	_, _, limit, active, err = s.admitDevice(r, req, snapshot, "test-business")
	if err != nil || limit != 2 || active != 2 || db.store.Users["user"].PlanID != 5 {
		t.Fatalf("fallback admission must preserve shared plan/limit: limit=%d active=%d err=%v", limit, active, err)
	}
}

func TestJSONAdmissionWriteFailureLeavesMemoryUnchanged(t *testing.T) {
	s := admissionServer(nil, policyKickOldest)
	s.store.path = t.TempDir() // rename to an existing directory must fail
	_, _, _, _, err := runAdmission(s, "new", nil)
	if err == nil || len(s.store.Users) != 0 || len(s.store.Devices) != 0 || len(s.store.Sessions) != 0 {
		t.Fatal("failed JSON persistence polluted in-memory admission state")
	}
	s.store.path = filepath.Join(t.TempDir(), "store.json")
	_, _, _, _, err = runAdmission(s, "new", func(_ context.Context, tx *sql.Tx, _ string, _ *DeviceRecord, _, _ int) error {
		if tx != nil {
			t.Fatal("JSON completion must not receive a PostgreSQL transaction")
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	oldDeviceCount, oldSessionCount := len(s.store.Devices), len(s.store.Sessions)
	_, _, _, _, err = runAdmission(s, "other", func(_ context.Context, tx *sql.Tx, _ string, _ *DeviceRecord, _, _ int) error {
		return errors.New("QR expired while waiting for admission")
	})
	if err == nil || len(s.store.Devices) != oldDeviceCount || len(s.store.Sessions) != oldSessionCount {
		t.Fatal("failed JSON precommit validation published an admission")
	}
	loaded, _, err := LoadStore(s.store.path, "")
	if err != nil || len(loaded.Devices) != oldDeviceCount || len(loaded.Sessions) != oldSessionCount {
		t.Fatal("failed JSON precommit validation persisted an admission")
	}
	for _, device := range loaded.Devices {
		if device.Status != statusActive {
			t.Fatal("failed JSON precommit validation kicked the old device")
		}
	}
}

func TestAdmissionSQLAndIdentityLockContract(t *testing.T) {
	if !strings.Contains(admissionLockSQL, "pg_advisory_xact_lock") || !strings.Contains(admissionUserSQL, "FOR UPDATE") || !strings.Contains(admissionDevicesSQL, "FOR UPDATE") {
		t.Fatal("admission lost shared account/row locking")
	}
	known := admissionLockKeys(SubscriptionSnapshot{Email: "User@Example.Test", UUID: "business-user"}, "")
	unknown := admissionLockKeys(SubscriptionSnapshot{Unavailable: true}, " user@example.test ")
	if known[0] != unknown[0] {
		t.Fatal("fallback login no longer shares the account email lock")
	}
	if !strings.Contains(upsertUserSQL, "CASE WHEN $11 AND EXCLUDED.override_updated_at>=dg_users.override_updated_at THEN EXCLUDED.device_limit_override ELSE dg_users.device_limit_override END") ||
		!strings.Contains(upsertUserSQL, "EXCLUDED.last_synced_at>=dg_users.last_synced_at") {
		t.Fatal("stale business snapshots can replace current limits or administrator overrides")
	}
}

func TestAdmissionAccountLockHonorsRequestDeadline(t *testing.T) {
	pg, db := newAdmissionDB(t)
	<-db.gate // simulate another instance holding the account transaction lock
	defer func() { db.gate <- struct{}{} }()
	s := admissionServer(pg, policyStrict)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()
	r := httptest.NewRequest(http.MethodPost, "/login", nil).WithContext(ctx)
	_, _, _, _, err := s.admitDevice(r, LoginRequest{Email: "user@example.test", DeviceID: "device"}, SubscriptionSnapshot{}, "business-test")
	if !errors.Is(err, context.DeadlineExceeded) || len(s.store.Devices) != 0 {
		t.Fatal("blocked admission must stop at the request deadline without a local login")
	}
}

func TestUserBusinessSnapshotCannotOverrideAdminLimit(t *testing.T) {
	pg, db := newAdmissionDB(t)
	now := time.Now().UTC()
	db.store.Users["user"] = &UserCache{ID: "user", PlanID: 3, DeviceLimit: intPtr(5), DeviceLimitOverride: intPtr(7), LastSyncedAt: now}
	write := func(user *UserCache, explicit bool) {
		t.Helper()
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		tx, err := pg.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
		if err != nil {
			t.Fatal(err)
		}
		defer tx.Rollback()
		if _, err := tx.ExecContext(ctx, admissionLockSQL, "test-user"); err != nil {
			t.Fatal(err)
		}
		var overrides map[string]time.Time
		if explicit {
			overrides = map[string]time.Time{"user": time.Now().UTC()}
		}
		if err := pg.upsertUsers(ctx, tx, &Store{Users: map[string]*UserCache{"user": user}}, overrides); err != nil {
			t.Fatal(err)
		}
		if err := tx.Commit(); err != nil {
			t.Fatal(err)
		}
	}
	stale := &UserCache{ID: "user", PlanID: 1, DeviceLimit: intPtr(1), LastSyncedAt: now.Add(-time.Hour)}
	write(stale, false)
	if u := db.store.Users["user"]; u.PlanID != 3 || *u.DeviceLimit != 5 || *u.DeviceLimitOverride != 7 {
		t.Fatal("stale snapshot replaced current plan/limit/override")
	}
	stale.LastSyncedAt = now.Add(time.Second)
	write(stale, false)
	if u := db.store.Users["user"]; *u.DeviceLimit != 1 || *u.DeviceLimitOverride != 7 {
		t.Fatal("fresh business snapshot must preserve admin override")
	}
	stale.DeviceLimitOverride = intPtr(2)
	write(stale, true)
	if *db.store.Users["user"].DeviceLimitOverride != 2 {
		t.Fatal("explicit admin override was not saved")
	}
	stale.DeviceLimitOverride = nil
	write(stale, true)
	if db.store.Users["user"].DeviceLimitOverride != nil {
		t.Fatal("explicit admin override clear was not saved")
	}
}

func TestOnlyExplicitLimitChangesCarryOverrideWriteIntent(t *testing.T) {
	s := emptyAdmissionStore()
	original := time.Now().UTC()
	s.Users["user"] = &UserCache{ID: "user", DeviceLimitOverride: intPtr(3), UpdatedAt: original}
	s.markUserLocked("user")
	if len(s.postgresChangesLocked().UserLimitOverrides) != 0 {
		t.Fatal("ordinary user refresh can change the administrator override")
	}
	s.markUserLimitOverrideLocked("user")
	if _, ok := s.postgresChangesLocked().UserLimitOverrides["user"]; !ok {
		t.Fatal("administrator write intent was not propagated to SQL")
	}
	s.Users["user"].UpdatedAt = original.Add(time.Hour)
	if !s.postgresChangesLocked().UserLimitOverrides["user"].Equal(original) {
		t.Fatal("ordinary refresh changed the pending administrator event timestamp")
	}
	s.clearDirtyLocked()
	if len(s.postgresChangesLocked().UserLimitOverrides) != 0 {
		t.Fatal("administrator override write intent leaked into later heartbeats")
	}
}

func TestDelayedExplicitOverrideCannotOverwriteNewerAdminOperation(t *testing.T) {
	pg, db := newAdmissionDB(t)
	now := time.Now().UTC()
	db.store.Users["user"] = &UserCache{ID: "user", DeviceLimitOverride: intPtr(1)}
	write := func(limit *int, event time.Time) {
		t.Helper()
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		tx, err := pg.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
		if err != nil {
			t.Fatal(err)
		}
		defer tx.Rollback()
		if _, err := tx.ExecContext(ctx, admissionLockSQL, "user"); err != nil {
			t.Fatal(err)
		}
		// Simulate a later ordinary refresh updating UpdatedAt while an old
		// administrator write remains pending. Only event is its true age.
		u := &UserCache{ID: "user", DeviceLimitOverride: limit, UpdatedAt: now.Add(time.Hour)}
		if err := pg.upsertUsers(ctx, tx, &Store{Users: map[string]*UserCache{"user": u}}, map[string]time.Time{"user": event}); err != nil {
			t.Fatal(err)
		}
		if err := tx.Commit(); err != nil {
			t.Fatal(err)
		}
	}
	write(intPtr(7), now.Add(time.Second))
	write(intPtr(2), now)
	if *db.store.Users["user"].DeviceLimitOverride != 7 || !db.overrideAt["user"].Equal(now.Add(time.Second)) {
		t.Fatal("retry of an older failed override replaced the later administrator setting")
	}
	write(nil, now.Add(2*time.Second))
	write(intPtr(7), now.Add(time.Second))
	if db.store.Users["user"].DeviceLimitOverride != nil {
		t.Fatal("old override resurrected after a later clear")
	}
}

func cloneEventTimes(source map[string]time.Time) map[string]time.Time {
	copy := map[string]time.Time{}
	for id, at := range source {
		copy[id] = at
	}
	return copy
}

func allowTestDeviceUpsert(old, next *DeviceRecord, login bool, lastLoginAt time.Time) bool {
	if old == nil {
		return true
	}
	if next.Status == statusRevoked {
		return next.RevokedAt != nil && !next.RevokedAt.Before(lastLoginAt)
	}
	if login {
		return next.Status == statusActive && !next.LastSeenAt.Before(lastLoginAt) && (old.RevokedAt == nil || !next.LastSeenAt.Before(*old.RevokedAt))
	}
	return old.Status == statusActive
}
