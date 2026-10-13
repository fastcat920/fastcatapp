package main

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// This models transactional store visibility, not PostgreSQL SQL/lock behavior.
// A real PG integration test remains necessary before a multi-instance rollout.
type qrDBRow struct {
	expires time.Time
	cipher  string
}
type qrDB struct {
	gate chan struct{}
	rows map[string]qrDBRow
	fail bool
}
type qrConnector struct{ state *qrDB }
type qrDriver struct{}
type qrConn struct {
	db *qrDB
	tx *qrTx
}
type qrTx struct {
	conn *qrConn
	rows map[string]qrDBRow
}

func (c qrConnector) Connect(context.Context) (driver.Conn, error) { return &qrConn{db: c.state}, nil }
func (qrConnector) Driver() driver.Driver                          { return qrDriver{} }
func (qrDriver) Open(string) (driver.Conn, error)                  { return nil, errors.New("isolated connector only") }
func (*qrConn) Prepare(string) (driver.Stmt, error)                { return nil, errors.New("unexpected prepare") }
func (*qrConn) Close() error                                       { return nil }
func (*qrConn) Begin() (driver.Tx, error)                          { return nil, errors.New("deadline required") }
func (c *qrConn) BeginTx(ctx context.Context, _ driver.TxOptions) (driver.Tx, error) {
	if _, ok := ctx.Deadline(); !ok {
		return nil, errors.New("QR transaction requires deadline")
	}
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-c.db.gate:
	}
	if c.db.fail {
		c.db.gate <- struct{}{}
		return nil, errors.New("isolated store unavailable")
	}
	tx := &qrTx{conn: c, rows: map[string]qrDBRow{}}
	for id, row := range c.db.rows {
		tx.rows[id] = row
	}
	c.tx = tx
	return tx, nil
}
func (tx *qrTx) Commit() error {
	tx.conn.db.rows = tx.rows
	tx.conn.tx = nil
	tx.conn.db.gate <- struct{}{}
	return nil
}
func (tx *qrTx) Rollback() error {
	tx.conn.tx = nil
	tx.conn.db.gate <- struct{}{}
	return nil
}
func (c *qrConn) QueryContext(_ context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	if c.tx != nil && query == qrCountSQL {
		count := int64(0)
		for _, row := range c.tx.rows {
			if row.expires.After(args[0].Value.(time.Time)) {
				count++
			}
		}
		return &consistencyRows{columns: []string{"count"}, rows: [][]driver.Value{{count}}}, nil
	}
	if c.tx == nil || query != qrSelectSQL || !strings.Contains(query, "FOR UPDATE") {
		return nil, errors.New("QR read requires transaction row lock")
	}
	rows := &consistencyRows{columns: []string{"payload_cipher"}}
	if row, ok := c.tx.rows[args[0].Value.(string)]; ok {
		rows.rows = [][]driver.Value{{row.cipher}}
	}
	return rows, nil
}
func (c *qrConn) ExecContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Result, error) {
	var rows map[string]qrDBRow
	if c.tx == nil {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-c.db.gate:
		}
		defer func() { c.db.gate <- struct{}{} }()
		rows = c.db.rows
	} else {
		rows = c.tx.rows
	}
	if c.db.fail {
		return nil, errors.New("isolated store unavailable")
	}
	switch query {
	case qrCapacityLockSQL:
		if c.tx == nil {
			return nil, errors.New("QR capacity lock requires transaction")
		}
	case qrInsertSQL:
		rows[args[0].Value.(string)] = qrDBRow{expires: args[1].Value.(time.Time), cipher: args[2].Value.(string)}
	case qrUpdateSQL:
		row := rows[args[0].Value.(string)]
		row.cipher = args[1].Value.(string)
		rows[args[0].Value.(string)] = row
	case qrDeleteSQL:
		delete(rows, args[0].Value.(string))
	case `DELETE FROM dg_qr_login_sessions WHERE expires_at <= $1`:
		for id, row := range rows {
			if !row.expires.After(args[0].Value.(time.Time)) {
				delete(rows, id)
			}
		}
	default:
		return nil, fmt.Errorf("unexpected QR SQL: %s", query)
	}
	return driver.RowsAffected(1), nil
}

func newQRTestDB(t *testing.T) (*PostgresStore, *qrDB) {
	t.Helper()
	state := &qrDB{gate: make(chan struct{}, 1), rows: map[string]qrDBRow{}}
	state.gate <- struct{}{}
	db := sql.OpenDB(qrConnector{state})
	t.Cleanup(func() { _ = db.Close() })
	return &PostgresStore{db: db}, state
}

func qrTestServer(pg *PostgresStore) *Server {
	return &Server{cfg: Config{APIPrefix: "/api/v1"}, key: deriveKey("test-qr-key"), store: &Store{pg: pg}, qrSessions: map[string]*QRLoginSession{}}
}

func callQR(t *testing.T, s *Server, method, id, query, body string) (int, map[string]any) {
	t.Helper()
	path := "/api/v1/auth/qr/sessions"
	if id != "" {
		path += "/" + id
	}
	r := httptest.NewRequest(method, path+query, strings.NewReader(body))
	w := httptest.NewRecorder()
	if id == "" {
		s.handleQRSession(w, r)
	} else {
		s.handleQRSessionByID(w, r)
	}
	if w.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("credential-bearing QR response must not be cached")
	}
	var response map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	data, _ := response["data"].(map[string]any)
	return w.Code, data
}

func TestQRDeliveryLegacyAndAcknowledgedAcrossGateways(t *testing.T) {
	for _, ack := range []bool{false, true} {
		t.Run(fmt.Sprintf("ack=%t", ack), func(t *testing.T) {
			pg, db := newQRTestDB(t)
			a, b, c := qrTestServer(pg), qrTestServer(pg), qrTestServer(pg)
			status, data := callQR(t, a, "POST", "", "", fmt.Sprintf(`{"device_id":"test-device","device_name":"TV","email":"must-not-persist","password":"must-not-persist","delivery_ack":%t}`, ack))
			if status != 200 || (data["delivery_ack"] == true) != ack {
				t.Fatalf("create negotiation failed: %d %v", status, data)
			}
			id, secret := data["id"].(string), data["poll_token"].(string)
			if data["qr_data"] != "fastcat://login/qr?challenge="+id || strings.Contains(data["qr_data"].(string), secret) {
				t.Fatal("QR payload leaked secret or broke legacy format")
			}
			if err := b.mutateQRSession(context.Background(), nil, id, func(item *QRLoginSession) (bool, error) {
				if item.Device.Email != "" || item.Device.Password != "" {
					t.Fatal("target account credentials persisted")
				}
				item.Status, item.DeliveryID = "approved", "delivery-receipt"
				item.Response = map[string]any{"auth_data": "Bearer test-approved-token", "email": "user@example.test"}
				return false, nil
			}); err != nil {
				t.Fatal(err)
			}
			if cipher := db.rows[id].cipher; strings.Contains(cipher, secret) || strings.Contains(cipher, "test-approved-token") {
				t.Fatal("QR DB row stored plaintext credentials")
			}
			wrongKey := qrTestServer(pg)
			wrongKey.key = deriveKey("wrong-instance-key")
			if status, _ := callQR(t, wrongKey, "GET", id, "?poll_token="+secret, ""); status != 503 {
				t.Fatal("wrong-key gateway must fail closed")
			}
			if status, _ := callQR(t, c, "GET", id, "?poll_token=wrong", ""); status != 404 {
				t.Fatal("invalid polling secret accepted")
			}
			status, first := callQR(t, c, "GET", id, "?poll_token="+secret, "")
			if status != 200 || first["status"] != "approved" || first["login"].(map[string]any)["auth_data"] != "Bearer test-approved-token" {
				t.Fatal("shared approved result missing")
			}
			_, second := callQR(t, a, "GET", id, "?poll_token="+secret, "")
			if !ack {
				if second["status"] != "consumed" || second["login"] != nil || first["delivery_id"] != nil {
					t.Fatal("legacy single consumption changed")
				}
				return
			}
			if second["status"] != "approved" || second["delivery_id"] != first["delivery_id"] || second["login"].(map[string]any)["auth_data"] != "Bearer test-approved-token" {
				t.Fatal("lost poll response cannot retrieve identical delivery")
			}
			for _, body := range []string{`{"poll_token":"wrong","delivery_id":"delivery-receipt"}`, fmt.Sprintf(`{"poll_token":%q,"delivery_id":"wrong"}`, secret)} {
				if status, _ := callQR(t, b, "POST", id+"/ack", "", body); status != 404 {
					t.Fatal("invalid ACK accepted")
				}
			}
			body := fmt.Sprintf(`{"poll_token":%q,"delivery_id":"delivery-receipt"}`, secret)
			for i := 0; i < 2; i++ {
				status, data := callQR(t, b, "POST", id+"/ack", "", body)
				if status != 200 || data["status"] != "consumed" {
					t.Fatal("ACK retry is not idempotent")
				}
			}
			_, after := callQR(t, c, "GET", id, "?poll_token="+secret, "")
			if after["status"] != "consumed" || after["login"] != nil {
				t.Fatal("acknowledged credentials served again")
			}
			item, err := a.decodeQR(id, db.rows[id].cipher)
			if err != nil || item.Response != nil {
				t.Fatal("ACK did not erase stored login response")
			}
		})
	}
}

func TestQRClaimsAreExclusiveAndFailedMutationsRollback(t *testing.T) {
	pg, _ := newQRTestDB(t)
	a, b := qrTestServer(pg), qrTestServer(pg)
	item := &QRLoginSession{ID: "claim", PollToken: "secret", Status: "pending", ExpiresAt: time.Now().Add(time.Minute)}
	if err := a.createQRSession(context.Background(), item); err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	var successes atomic.Int32
	for _, s := range []*Server{a, b} {
		wg.Add(1)
		go func(s *Server) {
			defer wg.Done()
			err := s.mutateQRSession(context.Background(), nil, "claim", func(item *QRLoginSession) (bool, error) {
				if item.Status != "pending" {
					return false, errQRUsed
				}
				item.Status, item.ApprovalClaim = "authorizing", "owner"
				return false, nil
			})
			if err == nil {
				successes.Add(1)
			} else if !errors.Is(err, errQRUsed) {
				t.Error(err)
			}
		}(s)
	}
	wg.Wait()
	if successes.Load() != 1 {
		t.Fatal("multiple approval requests acquired one challenge")
	}
	if status, _ := callQR(t, b, "DELETE", "claim", "?poll_token=secret", ""); status != 409 {
		t.Fatal("cancel removed an admission in progress")
	}
	injected := errors.New("completion failed")
	err := a.mutateQRSession(context.Background(), nil, "claim", func(item *QRLoginSession) (bool, error) {
		item.Status = "approved"
		return false, injected
	})
	if !errors.Is(err, injected) {
		t.Fatal(err)
	}
	b.failQRClaim("claim", "stale-owner")
	_, data := callQR(t, b, "GET", "claim", "?poll_token=secret", "")
	if data["status"] != "authorizing" {
		t.Fatal("failed write or stale completion changed challenge")
	}
}

func TestQRCancelAndApprovalCannotBothWin(t *testing.T) {
	pg, _ := newQRTestDB(t)
	a, b := qrTestServer(pg), qrTestServer(pg)
	for i := 0; i < 16; i++ {
		id := fmt.Sprintf("race-%d", i)
		if err := a.createQRSession(context.Background(), &QRLoginSession{ID: id, PollToken: "secret", Status: "pending", ExpiresAt: time.Now().Add(time.Minute)}); err != nil {
			t.Fatal(err)
		}
		start := make(chan struct{})
		results := make(chan error, 2)
		for _, remove := range []bool{false, true} {
			go func(remove bool) {
				<-start
				results <- b.mutateQRSession(context.Background(), nil, id, func(item *QRLoginSession) (bool, error) {
					if item.Status != "pending" {
						return false, errQRUsed
					}
					if !remove {
						item.Status = "authorizing"
					}
					return remove, nil
				})
			}(remove)
		}
		close(start)
		wins := 0
		for j := 0; j < 2; j++ {
			err := <-results
			if err == nil {
				wins++
			} else if !errors.Is(err, errQRUsed) && !errors.Is(err, errQRNotFound) {
				t.Fatal(err)
			}
		}
		if wins != 1 {
			t.Fatal("approval and cancellation both changed the same pending challenge")
		}
	}
}

func TestQRExpiryAndStoreFailureNeverDeliverCredentials(t *testing.T) {
	pg, db := newQRTestDB(t)
	s := qrTestServer(pg)
	item := &QRLoginSession{ID: "expired", PollToken: "secret", DeliveryACK: true, DeliveryID: "receipt", Status: "approved", ExpiresAt: time.Now().Add(-time.Second), Response: map[string]any{"token": "secret-token"}}
	if err := s.createQRSession(context.Background(), item); err != nil {
		t.Fatal(err)
	}
	if status, _ := callQR(t, s, "POST", item.ID+"/ack", "", `{"poll_token":"secret","delivery_id":"receipt"}`); status != 410 {
		t.Fatal("expired ACK accepted")
	}
	_, data := callQR(t, s, "GET", item.ID, "?poll_token=secret", "")
	if data["status"] != "expired" || data["login"] != nil || len(db.rows) != 0 {
		t.Fatal("expired delivery not removed")
	}
	db.fail = true
	// Deliberately seed a local shadow; PG failure must not serve it.
	s.qrSessions[item.ID] = item
	for _, req := range []struct{ method, id, query, body string }{
		{"POST", "", "", `{"device_id":"id","device_name":"TV"}`},
		{"GET", item.ID, "?poll_token=secret", ""},
		{"DELETE", item.ID, "?poll_token=secret", ""},
		{"POST", item.ID + "/ack", "", `{"poll_token":"secret","delivery_id":"receipt"}`},
	} {
		if status, _ := callQR(t, s, req.method, req.id, req.query, req.body); status != 503 {
			t.Fatal("shared-store failure fell back or was treated as logout/not-found")
		}
	}
}

func TestJSONQRAdmissionDoesNotKickOnExpiredOrFailedSave(t *testing.T) {
	s := admissionServer(nil, policyKickOldest)
	s.store.path = filepath.Join(t.TempDir(), "devices.json")
	_, old, _, _, err := runAdmission(s, "old", nil)
	if err != nil {
		t.Fatal(err)
	}
	s.qrSessions = map[string]*QRLoginSession{"id": {ID: "id", Status: "authorizing", ApprovalClaim: "claim", ExpiresAt: time.Now().Add(-time.Second)}}
	r := httptest.NewRequest("POST", "/approve", nil)
	target := LoginRequest{Email: "user@example.test", DeviceID: "new"}
	snapshot := SubscriptionSnapshot{Email: "user@example.test", UUID: "business-user", DeviceLimit: intPtr(1)}
	_, _, err = s.approveQRDevice(r, target, snapshot, "business-test", "id", "claim")
	if !errors.Is(err, errQRExpired) || s.store.Devices[old.ID].Status != statusActive {
		t.Fatal("expired QR changed device admission")
	}
	s.qrSessions["id"].ExpiresAt = time.Now().Add(time.Minute)
	s.store.path = t.TempDir() // cannot replace a directory with the JSON file
	_, _, err = s.approveQRDevice(r, target, snapshot, "business-test", "id", "claim")
	if err == nil || s.store.Devices[old.ID].Status != statusActive || s.qrSessions["id"].Status != "authorizing" {
		t.Fatal("failed QR admission changed device or published credentials")
	}
}

func TestJSONQRExpiresWhileWaitingForStore(t *testing.T) {
	s := admissionServer(nil, policyKickOldest)
	s.store.path = filepath.Join(t.TempDir(), "devices.json")
	_, old, _, _, err := runAdmission(s, "old", nil)
	if err != nil {
		t.Fatal(err)
	}
	s.qrSessions = map[string]*QRLoginSession{"id": {ID: "id", Status: "authorizing", ApprovalClaim: "claim", ExpiresAt: time.Now().Add(100 * time.Millisecond)}}
	s.store.mu.Lock()
	done := make(chan error, 1)
	go func() {
		r := httptest.NewRequest("POST", "/approve", nil)
		_, _, err := s.approveQRDevice(r, LoginRequest{Email: "user@example.test", DeviceID: "new"}, SubscriptionSnapshot{Email: "user@example.test", UUID: "business-user", DeviceLimit: intPtr(1)}, "business-test", "id", "claim")
		done <- err
	}()
	time.Sleep(150 * time.Millisecond)
	s.store.mu.Unlock()
	if err := <-done; !errors.Is(err, errQRExpired) {
		t.Fatalf("wanted expiry after store wait, got %v", err)
	}
	if len(s.store.Devices) != 1 || s.store.Devices[old.ID].Status != statusActive || len(s.store.Sessions) != 1 || s.qrSessions["id"].Status != "authorizing" {
		t.Fatal("expired admission committed a new device or kicked the old one")
	}
}
