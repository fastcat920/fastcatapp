package main

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// This isolated driver exercises SQL arguments and gateway control flow, not a
// real PostgreSQL parser/locking engine. The SQL guard assertions below keep
// the fake model coupled to the actual conflict predicates.
type consistencyDB struct {
	device      *DeviceRecord
	sessions    map[string]*SessionRecord
	user        *UserCache
	queryErr    error
	execErr     error
	queries     []string
	execs       []string
	lastLoginAt time.Time
}

type consistencyConnector struct{ state *consistencyDB }
type consistencyDriver struct{}
type consistencyConn struct{ state *consistencyDB }
type consistencyStmt struct {
	conn  *consistencyConn
	query string
}
type consistencyTx struct{}
type consistencyRows struct {
	columns []string
	rows    [][]driver.Value
}

func (c consistencyConnector) Connect(context.Context) (driver.Conn, error) {
	return &consistencyConn{state: c.state}, nil
}
func (c consistencyConnector) Driver() driver.Driver { return consistencyDriver{} }
func (consistencyDriver) Open(string) (driver.Conn, error) {
	return nil, errors.New("use isolated connector")
}
func (c *consistencyConn) Prepare(query string) (driver.Stmt, error) {
	return &consistencyStmt{conn: c, query: query}, nil
}
func (*consistencyConn) Close() error              { return nil }
func (*consistencyConn) Begin() (driver.Tx, error) { return consistencyTx{}, nil }
func (consistencyTx) Commit() error                { return nil }
func (consistencyTx) Rollback() error              { return nil }
func (*consistencyStmt) Close() error              { return nil }
func (*consistencyStmt) NumInput() int             { return -1 }
func (s *consistencyStmt) Exec(args []driver.Value) (driver.Result, error) {
	return s.conn.exec(s.query, args)
}
func (*consistencyStmt) Query([]driver.Value) (driver.Rows, error) {
	return nil, errors.New("unexpected prepared query")
}
func (c *consistencyConn) ExecContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Result, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	values := make([]driver.Value, len(args))
	for i, arg := range args {
		values[i] = arg.Value
	}
	return c.exec(query, values)
}
func (c *consistencyConn) exec(query string, args []driver.Value) (driver.Result, error) {
	s := c.state
	s.execs = append(s.execs, query)
	if s.execErr != nil {
		return nil, s.execErr
	}
	switch query {
	case upsertDeviceSQL:
		status, seen, login := args[7].(string), args[8].(time.Time), args[16].(bool)
		d := &DeviceRecord{ID: args[0].(string), Status: status, LastSeenAt: seen, RevokedBy: args[11].(string)}
		if revoked, ok := args[10].(time.Time); ok {
			d.RevokedAt = &revoked
		}
		if !allowTestDeviceUpsert(s.device, d, login, s.lastLoginAt) {
			return driver.RowsAffected(0), nil
		}
		if login {
			s.lastLoginAt = seen
		}
		if status == statusRevoked && s.device != nil && s.device.RevokedAt != nil &&
			(d.RevokedAt == nil || s.device.RevokedAt.After(*d.RevokedAt)) {
			d.RevokedAt, d.RevokedBy = s.device.RevokedAt, s.device.RevokedBy
		}
		s.device = d
	case upsertSessionSQL:
		id, status := args[0].(string), args[8].(string)
		if s.sessions[id] == nil && !args[14].(bool) {
			return driver.RowsAffected(0), nil
		}
		if old := s.sessions[id]; old != nil && old.Status != statusActive && status != statusRevoked {
			return driver.RowsAffected(0), nil
		}
		s.sessions[id] = &SessionRecord{ID: id, DeviceID: args[2].(string), Status: status, ExpiresAt: args[9].(time.Time), CreatedAt: args[10].(time.Time)}
	case revokeDeviceSessionsSQL:
		for _, session := range s.sessions {
			if session.DeviceID == args[0] && session.Status == statusActive && !session.CreatedAt.After(args[1].(time.Time)) {
				session.Status = statusRevoked
			}
		}
	default:
		return nil, errors.New("unexpected write in isolated session driver")
	}
	return driver.RowsAffected(1), nil
}
func (c *consistencyConn) QueryContext(ctx context.Context, query string, _ []driver.NamedValue) (driver.Rows, error) {
	s := c.state
	s.queries = append(s.queries, query)
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if _, ok := ctx.Deadline(); !ok {
		return nil, errors.New("shared authorization query has no deadline")
	}
	if s.queryErr != nil {
		return nil, s.queryErr
	}
	if strings.Contains(query, "FROM dg_sessions s") {
		rows := &consistencyRows{columns: []string{"status", "expires_at", "device_status", "revoked_by"}}
		if session := s.sessions["session"]; session != nil && s.device != nil {
			rows.rows = [][]driver.Value{{session.Status, session.ExpiresAt, s.device.Status, s.device.RevokedBy}}
		}
		return rows, nil
	}
	if strings.Contains(query, "FROM dg_users WHERE") {
		rows := &consistencyRows{columns: []string{"id", "business_user_id", "email", "plan_id", "plan_name", "device_limit", "device_limit_override", "last_synced_at", "created_at", "updated_at"}}
		if u := s.user; u != nil {
			var limit, override driver.Value
			if u.DeviceLimit != nil {
				limit = int64(*u.DeviceLimit)
			}
			if u.DeviceLimitOverride != nil {
				override = int64(*u.DeviceLimitOverride)
			}
			rows.rows = [][]driver.Value{{u.ID, u.BusinessUserID, u.Email, int64(u.PlanID), u.PlanName, limit, override, u.LastSyncedAt, u.CreatedAt, u.UpdatedAt}}
		}
		return rows, nil
	}
	return nil, errors.New("unexpected read in isolated session driver")
}
func (r *consistencyRows) Columns() []string { return r.columns }
func (*consistencyRows) Close() error        { return nil }
func (r *consistencyRows) Next(dest []driver.Value) error {
	if len(r.rows) == 0 {
		return io.EOF
	}
	copy(dest, r.rows[0])
	r.rows = r.rows[1:]
	return nil
}

func isolatedPostgres(t *testing.T, state *consistencyDB) *PostgresStore {
	t.Helper()
	if state.sessions == nil {
		state.sessions = map[string]*SessionRecord{}
	}
	db := sql.OpenDB(consistencyConnector{state: state})
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = db.Close() })
	return &PostgresStore{db: db}
}

func TestStaleHeartbeatCannotUndoSharedRevocation(t *testing.T) {
	for _, terminal := range []string{statusRevoked, statusExpired} {
		t.Run(terminal, func(t *testing.T) {
			now := time.Now().UTC()
			state := &consistencyDB{
				device:   &DeviceRecord{ID: "device", Status: statusRevoked, RevokedAt: &now, RevokedBy: "admin"},
				sessions: map[string]*SessionRecord{"session": {ID: "session", DeviceID: "device", Status: terminal}},
			}
			pg := isolatedPostgres(t, state)
			err := pg.SaveChanges(context.Background(), PostgresChanges{
				Devices:  map[string]*DeviceRecord{"device": {ID: "device", Status: statusActive, LastSeenAt: now.Add(time.Minute)}},
				Sessions: map[string]*SessionRecord{"session": {ID: "session", DeviceID: "device", Status: statusActive}},
			})
			if err != nil {
				t.Fatal(err)
			}
			if state.device.Status != statusRevoked || state.device.RevokedBy != "admin" || state.sessions["session"].Status != terminal {
				t.Fatal("old heartbeat resurrected inactive authorization state")
			}
		})
	}
}

func TestExplicitLoginCanReactivateDeviceButNotOldSession(t *testing.T) {
	now := time.Now().UTC()
	state := &consistencyDB{
		device: &DeviceRecord{ID: "device", Status: statusRevoked, RevokedAt: &now},
		sessions: map[string]*SessionRecord{
			"session": {ID: "session", DeviceID: "device", Status: statusRevoked},
			"remote":  {ID: "remote", DeviceID: "device", Status: statusActive},
		},
	}
	pg := isolatedPostgres(t, state)
	if err := pg.SaveChanges(context.Background(), PostgresChanges{
		Devices:      map[string]*DeviceRecord{"device": {ID: "device", Status: statusActive, LastSeenAt: now.Add(time.Second)}},
		LoginDevices: map[string]struct{}{"device": {}},
		Sessions:     map[string]*SessionRecord{"new": {ID: "new", DeviceID: "device", Status: statusActive}},
	}); err != nil {
		t.Fatal(err)
	}
	if state.device.Status != statusActive || state.sessions["new"].Status != statusActive ||
		state.sessions["session"].Status != statusRevoked || state.sessions["remote"].Status != statusRevoked {
		t.Fatal("login must create a fresh session without reviving old sessions")
	}
}

func TestLaterRevocationWinsAgainstPendingLogin(t *testing.T) {
	now := time.Now().UTC()
	state := &consistencyDB{device: &DeviceRecord{ID: "device", Status: statusRevoked, RevokedAt: &now}}
	pg := isolatedPostgres(t, state)
	err := pg.SaveChanges(context.Background(), PostgresChanges{
		Devices:      map[string]*DeviceRecord{"device": {ID: "device", Status: statusActive, LastSeenAt: now.Add(-time.Second)}},
		LoginDevices: map[string]struct{}{"device": {}},
	})
	if err == nil || state.device.Status != statusRevoked {
		t.Fatal("pending login cleared a later revocation")
	}
}

func TestStaleRevocationCannotRewindRevocationTime(t *testing.T) {
	now, old := time.Now().UTC(), time.Now().UTC().Add(-time.Hour)
	state := &consistencyDB{device: &DeviceRecord{ID: "device", Status: statusRevoked, RevokedAt: &now, RevokedBy: "admin"}}
	pg := isolatedPostgres(t, state)
	if err := pg.SaveChanges(context.Background(), PostgresChanges{
		Devices: map[string]*DeviceRecord{"device": {ID: "device", Status: statusRevoked, RevokedAt: &old, RevokedBy: "user"}},
	}); err != nil {
		t.Fatal(err)
	}
	if !state.device.RevokedAt.Equal(now) || state.device.RevokedBy != "admin" {
		t.Fatal("stale snapshot rewound a newer revocation")
	}
	if !strings.Contains(upsertDeviceSQL, "GREATEST(dg_devices.revoked_at,EXCLUDED.revoked_at)") {
		t.Fatal("SQL lost monotonic revocation time")
	}
}

func TestDelayedFailedRevocationCannotRevokeNewLogin(t *testing.T) {
	t0 := time.Now().UTC().Add(-time.Hour)
	t1, t2, heartbeat := t0.Add(time.Minute), t0.Add(2*time.Minute), t0.Add(4*time.Minute)
	db := &consistencyDB{
		device: &DeviceRecord{ID: "device", Status: statusActive, LastSeenAt: t0}, lastLoginAt: t0,
		sessions: map[string]*SessionRecord{"old": {ID: "old", DeviceID: "device", Status: statusActive, CreatedAt: t0, ExpiresAt: t0.Add(24 * time.Hour)}},
	}
	pg := isolatedPostgres(t, db)
	a := &Store{pg: pg, Users: map[string]*UserCache{}, Devices: map[string]*DeviceRecord{"device": cloneDevice(db.device)}, Sessions: map[string]*SessionRecord{}}
	server := &Server{store: a}
	server.revokeDeviceLocked(a.Devices["device"], "admin", t1)
	db.execErr = errors.New("write unavailable at T1")
	if err := a.Save(); err == nil || len(a.dirtyDevices) == 0 {
		t.Fatal("test failed to retain pending T1 revocation")
	}
	db.execErr = nil
	if err := pg.SaveChanges(context.Background(), PostgresChanges{
		Devices:      map[string]*DeviceRecord{"device": {ID: "device", Status: statusActive, LastSeenAt: t2}},
		LoginDevices: map[string]struct{}{"device": {}},
		Sessions:     map[string]*SessionRecord{"new": {ID: "new", DeviceID: "device", Status: statusActive, CreatedAt: t2, ExpiresAt: t2.Add(24 * time.Hour)}},
	}); err != nil {
		t.Fatal(err)
	}
	if err := pg.SaveChanges(context.Background(), PostgresChanges{Devices: map[string]*DeviceRecord{"device": {ID: "device", Status: statusActive, LastSeenAt: heartbeat}}}); err != nil {
		t.Fatal(err)
	}
	before := len(db.execs)
	if err := a.Save(); err != nil {
		t.Fatal(err)
	}
	if db.device.Status != statusActive || db.sessions["new"].Status != statusActive || !db.lastLoginAt.Equal(t2) {
		t.Fatal("delayed old revocation or heartbeat invalidated the newer login")
	}
	for _, query := range db.execs[before:] {
		if query == revokeDeviceSessionsSQL {
			t.Fatal("ignored old revocation still issued bulk session revocation")
		}
	}
	// A legitimate revocation after login must still work even if a heartbeat
	// has a later timestamp. A session created after the event is not its target.
	legitimate := t2.Add(time.Minute)
	db.sessions["future"] = &SessionRecord{ID: "future", DeviceID: "device", Status: statusActive, CreatedAt: heartbeat}
	if err := pg.SaveChanges(context.Background(), PostgresChanges{Devices: map[string]*DeviceRecord{"device": {ID: "device", Status: statusRevoked, RevokedAt: &legitimate}}}); err != nil {
		t.Fatal(err)
	}
	if db.device.Status != statusRevoked || db.sessions["new"].Status != statusRevoked || db.sessions["future"].Status != statusActive {
		t.Fatal("revocation did not use its original event cutoff independent of heartbeat time")
	}
	if !strings.Contains(revokeDeviceSessionsSQL, "created_at<=$2") {
		t.Fatal("SQL lost original-event session cutoff")
	}
}

func TestPostgresAuthorizationChecksCachedSessionsAndSubscriptionTokens(t *testing.T) {
	now := time.Now().UTC()
	state := &consistencyDB{
		device:   &DeviceRecord{ID: "device", Status: statusActive},
		sessions: map[string]*SessionRecord{"session": {ID: "session", Status: statusActive, ExpiresAt: now.Add(time.Hour)}},
	}
	key := deriveKey("isolated-test-key")
	businessCipher, _ := encryptString(key, "business-test")
	subCipher, _ := encryptString(key, "subscription-test")
	server := &Server{cfg: Config{TokenSecret: "isolated-test-key"}, key: key, store: &Store{
		pg:       isolatedPostgres(t, state),
		Users:    map[string]*UserCache{"user": {ID: "user"}},
		Devices:  map[string]*DeviceRecord{"device": {ID: "device", Status: statusActive}},
		Sessions: map[string]*SessionRecord{"session": {ID: "session", DeviceID: "device", UserID: "user", Status: statusActive, ExpiresAt: now.Add(time.Hour), LastSeenAt: now, BusinessTokenCipher: businessCipher, SubscribeTokenCipher: subCipher}},
	}}
	server.store.Sessions["session"].TokenHash = server.hashValue("session", "test-session")
	server.store.Sessions["session"].SubscribeTokenHash = server.hashValue("subscribe", "subscription-test")
	server.store.rebuildSessionIndexesLocked()
	r := httptest.NewRequest(http.MethodGet, "/", nil)
	r.Header.Set("Authorization", "Bearer test-session")
	if _, err := server.authorize(r); err != nil {
		t.Fatalf("active shared session rejected: %v", err)
	}
	state.sessions["session"].Status = statusRevoked
	state.device.Status, state.device.RevokedBy = statusRevoked, "admin"
	if _, err := server.authorize(r); err == nil {
		t.Fatal("cached active session bypassed shared revocation")
	}
	if _, err := server.authorizeSubscribeToken(r, "subscription-test"); err == nil {
		t.Fatal("subscription token bypassed shared revocation")
	}
	if !strings.Contains(state.queries[len(state.queries)-1], "s.subscribe_token_hash=$1") {
		t.Fatal("subscription check used the wrong token index")
	}
	state.sessions["session"].Status, state.device.Status = statusActive, statusActive
	delete(server.store.Sessions, "session")
	server.store.markDeviceLocked("device") // a pending write postpones cache reload
	w := httptest.NewRecorder()
	if _, ok := server.requireSession(w, r); ok || w.Code != http.StatusServiceUnavailable {
		t.Fatalf("valid shared token with cache reload pending should be 503, got %d", w.Code)
	}
	state.queryErr = errors.New("temporary database outage")
	w = httptest.NewRecorder()
	if _, ok := server.requireSession(w, r); ok || w.Code != http.StatusServiceUnavailable {
		t.Fatalf("DB outage should fail closed with 503, got %d", w.Code)
	}
	w = httptest.NewRecorder()
	server.handleSubscribe(w, httptest.NewRequest(http.MethodGet, "/?token=subscription-test", nil))
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("subscription DB outage should be 503, got %d", w.Code)
	}
}

func TestPostgresHeartbeatWriteFailureDoesNotInvalidateSession(t *testing.T) {
	for _, subscription := range []bool{false, true} {
		t.Run(fmt.Sprintf("subscription_%t", subscription), func(t *testing.T) {
			now := time.Now().UTC()
			state := &consistencyDB{
				device:   &DeviceRecord{ID: "device", Status: statusActive},
				sessions: map[string]*SessionRecord{"session": {ID: "session", Status: statusActive, ExpiresAt: now.Add(time.Hour)}},
				execErr:  errors.New("database became unavailable after authorization read"),
			}
			server := &Server{cfg: Config{TokenSecret: "isolated-test-key"}, store: &Store{
				pg:       isolatedPostgres(t, state),
				Users:    map[string]*UserCache{"user": {ID: "user"}},
				Devices:  map[string]*DeviceRecord{"device": {ID: "device", Status: statusActive}},
				Sessions: map[string]*SessionRecord{"session": {ID: "session", DeviceID: "device", UserID: "user", Status: statusActive, ExpiresAt: now.Add(time.Hour), LastSeenAt: now.Add(-2 * time.Minute)}},
			}}
			server.store.Sessions["session"].TokenHash = server.hashValue("session", "test-session")
			server.store.Sessions["session"].SubscribeTokenHash = server.hashValue("subscribe", "subscription-test")
			server.store.rebuildSessionIndexesLocked()
			r := httptest.NewRequest(http.MethodGet, "/?token=subscription-test", nil)
			r.Header.Set("Authorization", "Bearer test-session")
			w := httptest.NewRecorder()
			if subscription {
				server.handleSubscribe(w, r)
			} else if _, ok := server.requireSession(w, r); ok {
				t.Fatal("request must fail closed when the heartbeat cannot be persisted")
			}
			if len(state.queries) != 1 || len(state.execs) == 0 {
				t.Fatal("test did not exercise a successful authorization read followed by a failed heartbeat write")
			}
			if w.Code != http.StatusServiceUnavailable || !strings.Contains(w.Body.String(), "DEVICE_SESSION_CHECK_UNAVAILABLE") {
				t.Fatalf("heartbeat write failure should be retryable 503, got %d: %s", w.Code, w.Body.String())
			}
		})
	}
}

func TestSubscriptionFailurePreservesKnownLimitAndPlan(t *testing.T) {
	for _, limit := range []int{0, 3} {
		t.Run(fmt.Sprintf("limit_%d", limit), func(t *testing.T) {
			business := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				if strings.HasSuffix(r.URL.Path, "/login") {
					_, _ = io.WriteString(w, `{"data":{"auth_data":"Bearer isolated-business-token"}}`)
					return
				}
				w.WriteHeader(http.StatusServiceUnavailable)
				_, _ = io.WriteString(w, `{"message":"temporary error"}`)
			}))
			defer business.Close()
			store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
			if err != nil {
				t.Fatal(err)
			}
			synced := time.Now().UTC().Add(-time.Hour)
			store.Users["user"] = &UserCache{ID: "user", BusinessUserID: "business-user", Email: "user@example.com", PlanID: 9, PlanName: "known-plan", DeviceLimit: intPtr(limit), LastSyncedAt: synced}
			for _, id := range []string{"old-a", "old-b"} {
				store.Devices[id] = &DeviceRecord{ID: id, UserID: "user", Status: statusActive}
			}
			server := &Server{
				cfg:    Config{BusinessBaseURLs: []string{business.URL}, APIPrefix: "/api/v1", DefaultDeviceLimit: 1, DevicePolicy: policyKickOldest, SessionTTL: time.Hour},
				client: business.Client(), key: deriveKey("isolated-test-key"), store: store, log: log.New(io.Discard, "", 0),
			}
			r := httptest.NewRequest(http.MethodPost, "/api/v1/passport/auth/login", strings.NewReader(`{"email":"user@example.com","password":"test","device_id":"new-device"}`))
			w := httptest.NewRecorder()
			server.handleLogin(w, r)
			if w.Code != http.StatusOK {
				t.Fatalf("cached login status: %d", w.Code)
			}
			u := store.Users["user"]
			if *u.DeviceLimit != limit || u.PlanID != 9 || u.PlanName != "known-plan" || u.BusinessUserID != "business-user" || !u.LastSyncedAt.Equal(synced) {
				t.Fatal("temporary subscription failure overwrote verified user state")
			}
			if store.Devices["old-a"].Status != statusActive || store.Devices["old-b"].Status != statusActive {
				t.Fatal("temporary failure kicked existing devices")
			}
		})
	}
}

func TestFallbackFetchesSharedUserBeforeApplyingDefault(t *testing.T) {
	now := time.Now().UTC()
	state := &consistencyDB{user: &UserCache{ID: "user", Email: "user@example.com", DeviceLimit: intPtr(5), PlanID: 7, LastSyncedAt: now}}
	store := &Store{pg: isolatedPostgres(t, state), Users: map[string]*UserCache{"user": {ID: "user", Email: "user@example.com", DeviceLimit: intPtr(1)}}}
	if err := store.refreshLoginUser(context.Background(), "user@example.com"); err != nil {
		t.Fatal(err)
	}
	server := &Server{cfg: Config{DefaultDeviceLimit: 1}, store: store}
	user := server.upsertUserLocked(SubscriptionSnapshot{Email: "user@example.com", Unavailable: true}, "", now)
	if *user.DeviceLimit != 5 || user.PlanID != 7 || len(store.dirtyUsers) != 0 {
		t.Fatal("fallback must retain shared verified limit without writing a fake sync")
	}
	newUser := server.upsertUserLocked(SubscriptionSnapshot{Email: "new@example.com", Unavailable: true}, "", now)
	if *newUser.DeviceLimit != 1 {
		t.Fatal("unknown user's existing default-limit policy changed")
	}
}

func TestPostgresConflictGuardsAndLoginIntentAreExplicit(t *testing.T) {
	for query, guard := range map[string]string{
		upsertSessionSQL: "WHERE dg_sessions.status='active' OR EXCLUDED.status='revoked'",
		upsertDeviceSQL:  "EXCLUDED.revoked_at>=dg_devices.last_login_at",
	} {
		if !strings.Contains(query, guard) {
			t.Fatal("SQL lost its inactive-to-active conflict guard")
		}
	}
	store := &Store{Devices: map[string]*DeviceRecord{"device": {ID: "device"}}}
	store.markDeviceLocked("device")
	if len(store.postgresChangesLocked().LoginDevices) != 0 {
		t.Fatal("heartbeat was marked as explicit login")
	}
	store.markDeviceLoginLocked("device")
	if len(store.postgresChangesLocked().LoginDevices) != 1 {
		t.Fatal("explicit login intent was lost")
	}
	store.clearDirtyLocked()
	if len(store.postgresChangesLocked().LoginDevices) != 0 {
		t.Fatal("old login intent leaked into a later heartbeat")
	}
}
