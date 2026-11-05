package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/lib/pq"
	_ "github.com/lib/pq"
)

type PostgresStore struct {
	db *sql.DB
}

type PostgresChanges struct {
	Users              map[string]*UserCache
	UserLimitOverrides map[string]time.Time
	Devices            map[string]*DeviceRecord
	LoginDevices       map[string]struct{}
	Sessions           map[string]*SessionRecord
	Audits             map[string]AuditLog
	DeletedDevices     []string
	DeletedSessions    []string
	DeletedAudits      []string
}

func (c PostgresChanges) Empty() bool {
	return len(c.Users) == 0 && len(c.Devices) == 0 && len(c.Sessions) == 0 &&
		len(c.Audits) == 0 && len(c.DeletedDevices) == 0 &&
		len(c.DeletedSessions) == 0 && len(c.DeletedAudits) == 0
}

func NewPostgresStore(ctx context.Context, dsn string) (*PostgresStore, error) {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("postgres open: %w", err)
	}
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(4)
	db.SetConnMaxLifetime(5 * time.Minute)
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("postgres ping: %w", err)
	}
	ps := &PostgresStore{db: db}
	if err := ps.migrate(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("postgres migrate: %w", err)
	}
	return ps, nil
}

func (ps *PostgresStore) Close() error { return ps.db.Close() }

func (ps *PostgresStore) migrate(ctx context.Context) error {
	tables := []string{
		`CREATE TABLE IF NOT EXISTS dg_qr_login_sessions (
			id TEXT PRIMARY KEY,
			expires_at TIMESTAMPTZ NOT NULL,
			payload_cipher TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS dg_users (
			id                   TEXT PRIMARY KEY,
			business_user_id     TEXT NOT NULL DEFAULT '',
			email                TEXT NOT NULL DEFAULT '',
			plan_id              INTEGER NOT NULL DEFAULT 0,
			plan_name            TEXT NOT NULL DEFAULT '',
			device_limit         INTEGER,
			device_limit_override INTEGER,
			last_synced_at       TIMESTAMPTZ NOT NULL,
			created_at           TIMESTAMPTZ NOT NULL,
			updated_at           TIMESTAMPTZ NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS dg_devices (
			id              TEXT PRIMARY KEY,
			user_id         TEXT NOT NULL,
			device_id_hash  TEXT NOT NULL DEFAULT '',
			device_name     TEXT NOT NULL DEFAULT '',
			platform        TEXT NOT NULL DEFAULT '',
			app_version     TEXT NOT NULL DEFAULT '',
			os_version      TEXT NOT NULL DEFAULT '',
			status          TEXT NOT NULL DEFAULT 'active',
			last_seen_at    TIMESTAMPTZ NOT NULL,
			created_at      TIMESTAMPTZ NOT NULL,
			revoked_at      TIMESTAMPTZ,
			revoked_by      TEXT NOT NULL DEFAULT '',
			last_ip         TEXT NOT NULL DEFAULT '',
			last_ip_region  TEXT NOT NULL DEFAULT '',
			last_ip_isp     TEXT NOT NULL DEFAULT '',
			user_agent      TEXT NOT NULL DEFAULT ''
		)`,
		`CREATE TABLE IF NOT EXISTS dg_sessions (
			id                      TEXT PRIMARY KEY,
			user_id                 TEXT NOT NULL,
			device_id               TEXT NOT NULL,
			token_hash              TEXT NOT NULL DEFAULT '',
			business_token_cipher   TEXT NOT NULL DEFAULT '',
			business_sub_url_cipher TEXT NOT NULL DEFAULT '',
			subscribe_token_hash    TEXT NOT NULL DEFAULT '',
			subscribe_token_cipher  TEXT NOT NULL DEFAULT '',
			status                  TEXT NOT NULL DEFAULT 'active',
			expires_at              TIMESTAMPTZ NOT NULL,
			created_at              TIMESTAMPTZ NOT NULL,
			last_seen_at            TIMESTAMPTZ NOT NULL,
			last_ip                 TEXT NOT NULL DEFAULT '',
			user_agent              TEXT NOT NULL DEFAULT ''
		)`,
		`CREATE TABLE IF NOT EXISTS dg_audit_logs (
			id         TEXT PRIMARY KEY,
			user_id    TEXT NOT NULL DEFAULT '',
			device_id  TEXT NOT NULL DEFAULT '',
			action     TEXT NOT NULL DEFAULT '',
			actor      TEXT NOT NULL DEFAULT '',
			ip         TEXT NOT NULL DEFAULT '',
			user_agent TEXT NOT NULL DEFAULT '',
			details    JSONB NOT NULL DEFAULT '{}',
			created_at TIMESTAMPTZ NOT NULL
		)`,
	}
	for _, ddl := range tables {
		if _, err := ps.db.ExecContext(ctx, ddl); err != nil {
			return fmt.Errorf("create table: %w", err)
		}
	}
	// Separate event clocks from heartbeat/ordinary profile timestamps. The
	// additive migrations preserve old rows and do not change API JSON models.
	for _, ddl := range []string{
		`ALTER TABLE dg_devices ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ NOT NULL DEFAULT 'epoch'`,
		`ALTER TABLE dg_users ADD COLUMN IF NOT EXISTS override_updated_at TIMESTAMPTZ NOT NULL DEFAULT 'epoch'`,
	} {
		if _, err := ps.db.ExecContext(ctx, ddl); err != nil {
			return fmt.Errorf("migrate event clocks: %w", err)
		}
	}

	idxs := []string{
		"CREATE INDEX IF NOT EXISTS idx_dg_users_business_id ON dg_users(business_user_id)",
		"CREATE INDEX IF NOT EXISTS idx_dg_users_email_lower ON dg_users(LOWER(email))",
		"CREATE INDEX IF NOT EXISTS idx_dg_qr_expiry ON dg_qr_login_sessions(expires_at)",
		"CREATE INDEX IF NOT EXISTS idx_dg_devices_user_id ON dg_devices(user_id)",
		"CREATE INDEX IF NOT EXISTS idx_dg_devices_user_hash ON dg_devices(user_id, device_id_hash)",
		"CREATE INDEX IF NOT EXISTS idx_dg_sessions_token_hash ON dg_sessions(token_hash)",
		"CREATE INDEX IF NOT EXISTS idx_dg_sessions_sub_token_hash ON dg_sessions(subscribe_token_hash)",
		"CREATE INDEX IF NOT EXISTS idx_dg_sessions_user_id ON dg_sessions(user_id)",
		"CREATE INDEX IF NOT EXISTS idx_dg_sessions_device_id ON dg_sessions(device_id)",
		"CREATE INDEX IF NOT EXISTS idx_dg_sessions_expiry ON dg_sessions(expires_at)",
		"CREATE INDEX IF NOT EXISTS idx_dg_audit_created ON dg_audit_logs(created_at DESC)",
	}
	for _, idx := range idxs {
		if _, err := ps.db.ExecContext(ctx, idx); err != nil {
			return err
		}
	}
	return nil
}

func (ps *PostgresStore) LoadAll(ctx context.Context, s *Store) error {
	if err := ps.loadUsers(ctx, s); err != nil {
		return err
	}
	if err := ps.loadDevices(ctx, s); err != nil {
		return err
	}
	if err := ps.loadSessions(ctx, s); err != nil {
		return err
	}
	return ps.loadAuditLogs(ctx, s)
}

func (ps *PostgresStore) loadUsers(ctx context.Context, s *Store) error {
	rows, err := ps.db.QueryContext(ctx, "SELECT id,business_user_id,email,plan_id,plan_name,device_limit,device_limit_override,last_synced_at,created_at,updated_at FROM dg_users")
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		u := &UserCache{}
		if err := rows.Scan(&u.ID, &u.BusinessUserID, &u.Email, &u.PlanID, &u.PlanName, &u.DeviceLimit, &u.DeviceLimitOverride, &u.LastSyncedAt, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return err
		}
		s.Users[u.ID] = u
	}
	return rows.Err()
}

func (ps *PostgresStore) loadDevices(ctx context.Context, s *Store) error {
	rows, err := ps.db.QueryContext(ctx, "SELECT id,user_id,device_id_hash,device_name,platform,app_version,os_version,status,last_seen_at,created_at,revoked_at,revoked_by,last_ip,last_ip_region,last_ip_isp,user_agent FROM dg_devices")
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		d := &DeviceRecord{}
		if err := rows.Scan(&d.ID, &d.UserID, &d.DeviceIDHash, &d.DeviceName, &d.Platform, &d.AppVersion, &d.OSVersion, &d.Status, &d.LastSeenAt, &d.CreatedAt, &d.RevokedAt, &d.RevokedBy, &d.LastIP, &d.LastIPRegion, &d.LastIPISP, &d.UserAgent); err != nil {
			return err
		}
		s.Devices[d.ID] = d
	}
	return rows.Err()
}

func (ps *PostgresStore) loadSessions(ctx context.Context, s *Store) error {
	rows, err := ps.db.QueryContext(ctx, "SELECT id,user_id,device_id,token_hash,business_token_cipher,business_sub_url_cipher,subscribe_token_hash,subscribe_token_cipher,status,expires_at,created_at,last_seen_at,last_ip,user_agent FROM dg_sessions")
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		ses := &SessionRecord{}
		if err := rows.Scan(&ses.ID, &ses.UserID, &ses.DeviceID, &ses.TokenHash, &ses.BusinessTokenCipher, &ses.BusinessSubURLCipher, &ses.SubscribeTokenHash, &ses.SubscribeTokenCipher, &ses.Status, &ses.ExpiresAt, &ses.CreatedAt, &ses.LastSeenAt, &ses.LastIP, &ses.UserAgent); err != nil {
			return err
		}
		s.Sessions[ses.ID] = ses
	}
	return rows.Err()
}

func (ps *PostgresStore) loadAuditLogs(ctx context.Context, s *Store) error {
	rows, err := ps.db.QueryContext(ctx, "SELECT id,user_id,device_id,action,actor,ip,user_agent,details,created_at FROM dg_audit_logs ORDER BY created_at ASC")
	if err != nil {
		return err
	}
	defer rows.Close()
	var audits []AuditLog
	for rows.Next() {
		a := AuditLog{}
		var raw []byte
		if err := rows.Scan(&a.ID, &a.UserID, &a.DeviceID, &a.Action, &a.Actor, &a.IP, &a.UserAgent, &raw, &a.CreatedAt); err != nil {
			return err
		}
		if len(raw) > 0 {
			_ = json.Unmarshal(raw, &a.Details)
		}
		audits = append(audits, a)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	s.Audits = audits
	return nil
}

func (ps *PostgresStore) SaveAll(ctx context.Context, s *Store) error {
	tx, err := ps.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()
	if err := ps.upsertUsers(ctx, tx, s, nil); err != nil {
		return err
	}
	if err := ps.deleteOrphanUsers(ctx, tx, s); err != nil {
		return err
	}
	if err := ps.upsertDevices(ctx, tx, s, nil); err != nil {
		return err
	}
	if err := ps.deleteOrphanDevices(ctx, tx, s); err != nil {
		return err
	}
	if err := ps.upsertSessions(ctx, tx, s); err != nil {
		return err
	}
	if err := ps.deleteOrphanSessions(ctx, tx, s); err != nil {
		return err
	}
	if err := ps.upsertAuditLogs(ctx, tx, s); err != nil {
		return err
	}
	return tx.Commit()
}

// SaveChanges persists only records changed by the current request. The old
// implementation rewrote every table for every heartbeat, which serialized all
// requests behind a long transaction once the store contained thousands of
// devices and sessions.
func (ps *PostgresStore) SaveChanges(ctx context.Context, c PostgresChanges) error {
	if c.Empty() {
		return nil
	}
	tx, err := ps.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin incremental tx: %w", err)
	}
	defer tx.Rollback()

	if len(c.DeletedSessions) > 0 {
		if _, err := tx.ExecContext(ctx, "DELETE FROM dg_sessions WHERE id = ANY($1)", pq.Array(c.DeletedSessions)); err != nil {
			return err
		}
	}
	if len(c.DeletedDevices) > 0 {
		if _, err := tx.ExecContext(ctx, "DELETE FROM dg_devices WHERE id = ANY($1)", pq.Array(c.DeletedDevices)); err != nil {
			return err
		}
	}
	if len(c.DeletedAudits) > 0 {
		if _, err := tx.ExecContext(ctx, "DELETE FROM dg_audit_logs WHERE id = ANY($1)", pq.Array(c.DeletedAudits)); err != nil {
			return err
		}
	}

	partial := &Store{
		Users:        c.Users,
		Devices:      c.Devices,
		Sessions:     c.Sessions,
		loginDevices: c.LoginDevices,
	}
	if err := ps.upsertUsers(ctx, tx, partial, c.UserLimitOverrides); err != nil {
		return err
	}
	if err := ps.upsertDevices(ctx, tx, partial, c.LoginDevices); err != nil {
		return err
	}
	if err := ps.writeSessions(ctx, tx, partial, false); err != nil {
		return err
	}
	if err := ps.upsertAuditRecords(ctx, tx, c.Audits); err != nil {
		return err
	}
	return tx.Commit()
}

// Subscription refreshes may carry a stale administrator override. Only the
// explicit administrator path may change it; business snapshots are monotonic.
const upsertUserSQL = `INSERT INTO dg_users(id,business_user_id,email,plan_id,plan_name,device_limit,device_limit_override,last_synced_at,created_at,updated_at,override_updated_at)
VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,CASE WHEN $11 THEN $12::timestamptz ELSE 'epoch'::timestamptz END)
ON CONFLICT(id) DO UPDATE SET
business_user_id=CASE WHEN EXCLUDED.last_synced_at>=dg_users.last_synced_at THEN EXCLUDED.business_user_id ELSE dg_users.business_user_id END,
email=CASE WHEN EXCLUDED.last_synced_at>=dg_users.last_synced_at THEN EXCLUDED.email ELSE dg_users.email END,
plan_id=CASE WHEN EXCLUDED.last_synced_at>=dg_users.last_synced_at THEN EXCLUDED.plan_id ELSE dg_users.plan_id END,
plan_name=CASE WHEN EXCLUDED.last_synced_at>=dg_users.last_synced_at THEN EXCLUDED.plan_name ELSE dg_users.plan_name END,
device_limit=CASE WHEN EXCLUDED.last_synced_at>=dg_users.last_synced_at THEN EXCLUDED.device_limit ELSE dg_users.device_limit END,
device_limit_override=CASE WHEN $11 AND EXCLUDED.override_updated_at>=dg_users.override_updated_at THEN EXCLUDED.device_limit_override ELSE dg_users.device_limit_override END,
override_updated_at=GREATEST(dg_users.override_updated_at,EXCLUDED.override_updated_at),
last_synced_at=GREATEST(dg_users.last_synced_at,EXCLUDED.last_synced_at),updated_at=GREATEST(dg_users.updated_at,EXCLUDED.updated_at)`

func (ps *PostgresStore) upsertUsers(ctx context.Context, tx *sql.Tx, s *Store, overrides map[string]time.Time) error {
	if len(s.Users) == 0 {
		return nil
	}
	stmt, err := tx.PrepareContext(ctx, upsertUserSQL)
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, u := range s.Users {
		overrideAt, override := overrides[u.ID]
		if _, err := stmt.ExecContext(ctx, u.ID, u.BusinessUserID, u.Email, u.PlanID, u.PlanName, u.DeviceLimit, u.DeviceLimitOverride, u.LastSyncedAt, u.CreatedAt, u.UpdatedAt, override, overrideAt); err != nil {
			return err
		}
	}
	return nil
}

func (ps *PostgresStore) deleteOrphanUsers(ctx context.Context, tx *sql.Tx, s *Store) error {
	if len(s.Users) == 0 {
		_, err := tx.ExecContext(ctx, "DELETE FROM dg_users")
		return err
	}
	ids := make([]string, 0, len(s.Users))
	for id := range s.Users {
		ids = append(ids, id)
	}
	_, err := tx.ExecContext(ctx, "DELETE FROM dg_users WHERE NOT (id = ANY($1))", pq.Array(ids))
	return err
}

// Heartbeats must not clear another instance's revocation. Only an explicit
// login newer than that revocation may reactivate a device.
const upsertDeviceSQL = `INSERT INTO dg_devices(id,user_id,device_id_hash,device_name,platform,app_version,os_version,status,last_seen_at,created_at,revoked_at,revoked_by,last_ip,last_ip_region,last_ip_isp,user_agent,last_login_at)
VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,CASE WHEN $17 THEN $9::timestamptz ELSE 'epoch'::timestamptz END)
ON CONFLICT(id) DO UPDATE SET user_id=EXCLUDED.user_id,device_id_hash=EXCLUDED.device_id_hash,device_name=EXCLUDED.device_name,platform=EXCLUDED.platform,app_version=EXCLUDED.app_version,os_version=EXCLUDED.os_version,status=EXCLUDED.status,last_seen_at=GREATEST(dg_devices.last_seen_at,EXCLUDED.last_seen_at),revoked_at=CASE WHEN EXCLUDED.status='revoked' THEN GREATEST(dg_devices.revoked_at,EXCLUDED.revoked_at) ELSE EXCLUDED.revoked_at END,revoked_by=CASE WHEN EXCLUDED.status='revoked' AND dg_devices.revoked_at > EXCLUDED.revoked_at THEN dg_devices.revoked_by ELSE EXCLUDED.revoked_by END,last_ip=EXCLUDED.last_ip,last_ip_region=EXCLUDED.last_ip_region,last_ip_isp=EXCLUDED.last_ip_isp,user_agent=EXCLUDED.user_agent,last_login_at=GREATEST(dg_devices.last_login_at,EXCLUDED.last_login_at)
WHERE (EXCLUDED.status='revoked' AND EXCLUDED.revoked_at>=dg_devices.last_login_at)
OR (EXCLUDED.status<>'revoked' AND NOT $17 AND dg_devices.status='active')
OR ($17 AND EXCLUDED.status='active' AND EXCLUDED.last_login_at>=dg_devices.last_login_at AND (dg_devices.revoked_at IS NULL OR dg_devices.revoked_at <= EXCLUDED.last_login_at))`

const revokeDeviceSessionsSQL = `UPDATE dg_sessions SET status='revoked',expires_at=LEAST(expires_at,$2) WHERE device_id=$1 AND status='active' AND created_at<=$2`

func (ps *PostgresStore) upsertDevices(ctx context.Context, tx *sql.Tx, s *Store, loginDevices map[string]struct{}) error {
	if len(s.Devices) == 0 {
		return nil
	}
	stmt, err := tx.PrepareContext(ctx, upsertDeviceSQL)
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, d := range s.Devices {
		_, login := loginDevices[d.ID]
		result, err := stmt.ExecContext(ctx, d.ID, d.UserID, d.DeviceIDHash, d.DeviceName, d.Platform, d.AppVersion, d.OSVersion, d.Status, d.LastSeenAt, d.CreatedAt, d.RevokedAt, d.RevokedBy, d.LastIP, d.LastIPRegion, d.LastIPISP, d.UserAgent, login)
		if err != nil {
			return err
		}
		count, err := result.RowsAffected()
		if err != nil {
			return err
		}
		if count == 0 {
			if login {
				return fmt.Errorf("device login was superseded; retry login")
			}
			continue // ignored stale revocation must not revoke newer sessions
		}
		if login || d.Status == statusRevoked {
			// The local cache may not contain sessions created by another instance.
			// Revoke those as well, before the new login session is inserted below.
			cutoff := d.LastSeenAt
			if !login {
				if d.RevokedAt == nil {
					continue
				}
				cutoff = *d.RevokedAt
			}
			if _, err := tx.ExecContext(ctx, revokeDeviceSessionsSQL, d.ID, cutoff); err != nil {
				return err
			}
		}
	}
	return nil
}

func (ps *PostgresStore) deleteOrphanDevices(ctx context.Context, tx *sql.Tx, s *Store) error {
	if len(s.Devices) == 0 {
		_, err := tx.ExecContext(ctx, "DELETE FROM dg_devices")
		return err
	}
	ids := make([]string, 0, len(s.Devices))
	for id := range s.Devices {
		ids = append(ids, id)
	}
	_, err := tx.ExecContext(ctx, "DELETE FROM dg_devices WHERE NOT (id = ANY($1))", pq.Array(ids))
	return err
}

// Session IDs are never reused for re-login, so inactive sessions are terminal.
// Revocation may supersede expiry, but neither can become active again.
const upsertSessionSQL = `INSERT INTO dg_sessions(id,user_id,device_id,token_hash,business_token_cipher,business_sub_url_cipher,subscribe_token_hash,subscribe_token_cipher,status,expires_at,created_at,last_seen_at,last_ip,user_agent)
SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14
WHERE $15::boolean OR EXISTS(SELECT 1 FROM dg_sessions WHERE id=$1)
ON CONFLICT(id) DO UPDATE SET business_sub_url_cipher=EXCLUDED.business_sub_url_cipher,status=EXCLUDED.status,expires_at=LEAST(dg_sessions.expires_at,EXCLUDED.expires_at),last_seen_at=GREATEST(dg_sessions.last_seen_at,EXCLUDED.last_seen_at),last_ip=EXCLUDED.last_ip,user_agent=EXCLUDED.user_agent
WHERE dg_sessions.status='active' OR EXCLUDED.status='revoked'`

func (ps *PostgresStore) upsertSessions(ctx context.Context, tx *sql.Tx, s *Store) error {
	return ps.writeSessions(ctx, tx, s, true)
}

// Only admission/migration can create a session ID. A delayed heartbeat or
// revocation from another instance must not resurrect a row after retention.
func (ps *PostgresStore) writeSessions(ctx context.Context, tx *sql.Tx, s *Store, allowInsert bool) error {
	if len(s.Sessions) == 0 {
		return nil
	}
	stmt, err := tx.PrepareContext(ctx, upsertSessionSQL)
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, ses := range s.Sessions {
		_, login := s.loginDevices[ses.DeviceID]
		if _, err := stmt.ExecContext(ctx, ses.ID, ses.UserID, ses.DeviceID, ses.TokenHash, ses.BusinessTokenCipher, ses.BusinessSubURLCipher, ses.SubscribeTokenHash, ses.SubscribeTokenCipher, ses.Status, ses.ExpiresAt, ses.CreatedAt, ses.LastSeenAt, ses.LastIP, ses.UserAgent, allowInsert || login); err != nil {
			return err
		}
	}
	return nil
}

func (ps *PostgresStore) deleteOrphanSessions(ctx context.Context, tx *sql.Tx, s *Store) error {
	if len(s.Sessions) == 0 {
		_, err := tx.ExecContext(ctx, "DELETE FROM dg_sessions")
		return err
	}
	ids := make([]string, 0, len(s.Sessions))
	for id := range s.Sessions {
		ids = append(ids, id)
	}
	_, err := tx.ExecContext(ctx, "DELETE FROM dg_sessions WHERE NOT (id = ANY($1))", pq.Array(ids))
	return err
}

func (ps *PostgresStore) upsertAuditLogs(ctx context.Context, tx *sql.Tx, s *Store) error {
	if len(s.Audits) == 0 {
		return nil
	}
	audits := make(map[string]AuditLog, len(s.Audits))
	for _, audit := range s.Audits {
		audits[audit.ID] = audit
	}
	return ps.upsertAuditRecords(ctx, tx, audits)
}

func (ps *PostgresStore) upsertAuditRecords(ctx context.Context, tx *sql.Tx, audits map[string]AuditLog) error {
	if len(audits) == 0 {
		return nil
	}
	stmt, err := tx.PrepareContext(ctx, "INSERT INTO dg_audit_logs(id,user_id,device_id,action,actor,ip,user_agent,details,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT(id) DO UPDATE SET user_id=EXCLUDED.user_id,device_id=EXCLUDED.device_id,action=EXCLUDED.action,actor=EXCLUDED.actor,ip=EXCLUDED.ip,user_agent=EXCLUDED.user_agent,details=EXCLUDED.details")
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, a := range audits {
		raw, _ := json.Marshal(a.Details)
		if raw == nil {
			raw = []byte("{}")
		}
		if _, err := stmt.ExecContext(ctx, a.ID, a.UserID, a.DeviceID, a.Action, a.Actor, a.IP, a.UserAgent, raw, a.CreatedAt); err != nil {
			return err
		}
	}
	return nil
}
