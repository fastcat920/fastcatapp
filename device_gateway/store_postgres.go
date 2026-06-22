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

	idxs := []string{
		"CREATE INDEX IF NOT EXISTS idx_dg_devices_user_id ON dg_devices(user_id)",
		"CREATE INDEX IF NOT EXISTS idx_dg_devices_user_hash ON dg_devices(user_id, device_id_hash)",
		"CREATE INDEX IF NOT EXISTS idx_dg_sessions_token_hash ON dg_sessions(token_hash)",
		"CREATE INDEX IF NOT EXISTS idx_dg_sessions_sub_token_hash ON dg_sessions(subscribe_token_hash)",
		"CREATE INDEX IF NOT EXISTS idx_dg_sessions_user_id ON dg_sessions(user_id)",
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
	if err := ps.upsertUsers(ctx, tx, s); err != nil {
		return err
	}
	if err := ps.deleteOrphanUsers(ctx, tx, s); err != nil {
		return err
	}
	if err := ps.upsertDevices(ctx, tx, s); err != nil {
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

func (ps *PostgresStore) upsertUsers(ctx context.Context, tx *sql.Tx, s *Store) error {
	if len(s.Users) == 0 {
		return nil
	}
	stmt, err := tx.PrepareContext(ctx, "INSERT INTO dg_users(id,business_user_id,email,plan_id,plan_name,device_limit,device_limit_override,last_synced_at,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) ON CONFLICT(id) DO UPDATE SET business_user_id=EXCLUDED.business_user_id,email=EXCLUDED.email,plan_id=EXCLUDED.plan_id,plan_name=EXCLUDED.plan_name,device_limit=EXCLUDED.device_limit,device_limit_override=EXCLUDED.device_limit_override,last_synced_at=EXCLUDED.last_synced_at,updated_at=EXCLUDED.updated_at")
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, u := range s.Users {
		if _, err := stmt.ExecContext(ctx, u.ID, u.BusinessUserID, u.Email, u.PlanID, u.PlanName, u.DeviceLimit, u.DeviceLimitOverride, u.LastSyncedAt, u.CreatedAt, u.UpdatedAt); err != nil {
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

func (ps *PostgresStore) upsertDevices(ctx context.Context, tx *sql.Tx, s *Store) error {
	if len(s.Devices) == 0 {
		return nil
	}
	stmt, err := tx.PrepareContext(ctx, "INSERT INTO dg_devices(id,user_id,device_id_hash,device_name,platform,app_version,os_version,status,last_seen_at,created_at,revoked_at,revoked_by,last_ip,last_ip_region,last_ip_isp,user_agent) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16) ON CONFLICT(id) DO UPDATE SET user_id=EXCLUDED.user_id,device_id_hash=EXCLUDED.device_id_hash,device_name=EXCLUDED.device_name,platform=EXCLUDED.platform,app_version=EXCLUDED.app_version,os_version=EXCLUDED.os_version,status=EXCLUDED.status,last_seen_at=EXCLUDED.last_seen_at,revoked_at=EXCLUDED.revoked_at,revoked_by=EXCLUDED.revoked_by,last_ip=EXCLUDED.last_ip,last_ip_region=EXCLUDED.last_ip_region,last_ip_isp=EXCLUDED.last_ip_isp,user_agent=EXCLUDED.user_agent")
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, d := range s.Devices {
		if _, err := stmt.ExecContext(ctx, d.ID, d.UserID, d.DeviceIDHash, d.DeviceName, d.Platform, d.AppVersion, d.OSVersion, d.Status, d.LastSeenAt, d.CreatedAt, d.RevokedAt, d.RevokedBy, d.LastIP, d.LastIPRegion, d.LastIPISP, d.UserAgent); err != nil {
			return err
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

func (ps *PostgresStore) upsertSessions(ctx context.Context, tx *sql.Tx, s *Store) error {
	if len(s.Sessions) == 0 {
		return nil
	}
	stmt, err := tx.PrepareContext(ctx, "INSERT INTO dg_sessions(id,user_id,device_id,token_hash,business_token_cipher,business_sub_url_cipher,subscribe_token_hash,subscribe_token_cipher,status,expires_at,created_at,last_seen_at,last_ip,user_agent) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) ON CONFLICT(id) DO UPDATE SET user_id=EXCLUDED.user_id,device_id=EXCLUDED.device_id,token_hash=EXCLUDED.token_hash,business_token_cipher=EXCLUDED.business_token_cipher,business_sub_url_cipher=EXCLUDED.business_sub_url_cipher,subscribe_token_hash=EXCLUDED.subscribe_token_hash,subscribe_token_cipher=EXCLUDED.subscribe_token_cipher,status=EXCLUDED.status,expires_at=EXCLUDED.expires_at,last_seen_at=EXCLUDED.last_seen_at,last_ip=EXCLUDED.last_ip,user_agent=EXCLUDED.user_agent")
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, ses := range s.Sessions {
		if _, err := stmt.ExecContext(ctx, ses.ID, ses.UserID, ses.DeviceID, ses.TokenHash, ses.BusinessTokenCipher, ses.BusinessSubURLCipher, ses.SubscribeTokenHash, ses.SubscribeTokenCipher, ses.Status, ses.ExpiresAt, ses.CreatedAt, ses.LastSeenAt, ses.LastIP, ses.UserAgent); err != nil {
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
	stmt, err := tx.PrepareContext(ctx, "INSERT INTO dg_audit_logs(id,user_id,device_id,action,actor,ip,user_agent,details,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT(id) DO UPDATE SET user_id=EXCLUDED.user_id,device_id=EXCLUDED.device_id,action=EXCLUDED.action,actor=EXCLUDED.actor,ip=EXCLUDED.ip,user_agent=EXCLUDED.user_agent,details=EXCLUDED.details")
	if err != nil {
		return err
	}
	defer stmt.Close()
	for _, a := range s.Audits {
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

