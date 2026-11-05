package main

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"
)

// PostgreSQL completions join the same transaction as device admission. In JSON
// mode completion runs before the file save, with tx=nil: it must only validate
// and must not publish external state, because persistence can still fail.
type admissionCompletion func(context.Context, *sql.Tx, string, *DeviceRecord, int, int) error

const admissionLockSQL = `SELECT pg_advisory_xact_lock(hashtext($1)::bigint)`
const admissionUserSQL = `SELECT id,business_user_id,email,plan_id,plan_name,device_limit,device_limit_override,last_synced_at,created_at,updated_at FROM dg_users
WHERE ($1<>'' AND business_user_id=$1) OR LOWER(email)=$2
ORDER BY CASE WHEN $1<>'' AND business_user_id=$1 THEN 0 ELSE 1 END,id LIMIT 1 FOR UPDATE`
const admissionDevicesSQL = `SELECT id,user_id,device_id_hash,device_name,platform,app_version,os_version,status,last_seen_at,created_at,revoked_at,revoked_by,last_ip,last_ip_region,last_ip_isp,user_agent
FROM dg_devices WHERE user_id=$1 ORDER BY id FOR UPDATE`

func (s *Server) admitDeviceWithCompletion(r *http.Request, req LoginRequest, snapshot SubscriptionSnapshot, businessToken string, complete admissionCompletion) (string, *DeviceRecord, int, int, error) {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	if s.store.pg != nil {
		return s.admitDevicePostgresLocked(r, req, snapshot, businessToken, complete)
	}

	// A failed file write must not leave a phantom login or kick in memory.
	staged := cloneAdmissionStore(s.store)
	staged.path = s.store.path
	worker := s.admissionWorker(staged)
	token, device, limit, active, err := worker.prepareDeviceAdmission(r, req, snapshot, businessToken)
	if err != nil {
		return "", nil, limit, active, err
	}
	if complete != nil {
		if err := complete(r.Context(), nil, token, device, limit, active); err != nil {
			return "", nil, limit, active, err
		}
	}
	if err := staged.saveLocked(); err != nil {
		return "", nil, limit, active, err
	}
	s.store.Users, s.store.Devices, s.store.Sessions, s.store.Audits = staged.Users, staged.Devices, staged.Sessions, staged.Audits
	s.store.rebuildSessionIndexesLocked()
	s.store.clearDirtyLocked()
	s.store.revision++
	return token, device, limit, active, nil
}

func (s *Server) admissionWorker(staged *Store) *Server {
	// Do not copy Server's mutexes or the QR state into a transaction worker.
	return &Server{cfg: s.cfg, key: s.key, store: staged, ipGeo: s.ipGeo}
}

func emptyAdmissionStore() *Store {
	return &Store{Users: map[string]*UserCache{}, Devices: map[string]*DeviceRecord{}, Sessions: map[string]*SessionRecord{}}
}

func cloneAdmissionStore(source *Store) *Store {
	copy := emptyAdmissionStore()
	for id, user := range source.Users {
		value := *user
		copy.Users[id] = &value
	}
	for id, device := range source.Devices {
		copy.Devices[id] = cloneDevice(device)
	}
	for id, session := range source.Sessions {
		value := *session
		copy.Sessions[id] = &value
	}
	copy.Audits = append([]AuditLog(nil), source.Audits...)
	return copy
}

func admissionLockKeys(snapshot SubscriptionSnapshot, fallbackEmail string) []string {
	email := snapshot.Email
	if email == "" {
		email = fallbackEmail
	}
	keys := []string{"fastcat:admit:email:" + strings.ToLower(strings.TrimSpace(email))}
	if snapshot.UUID != "" {
		keys = append(keys, "fastcat:admit:uuid:"+snapshot.UUID)
	}
	// Every caller acquires multiple identity locks in the same order. The
	// email lock also covers fallback logins with no subscription/UUID response.
	sort.Strings(keys)
	return keys
}

func (s *Server) admitDevicePostgresLocked(r *http.Request, req LoginRequest, snapshot SubscriptionSnapshot, businessToken string, complete admissionCompletion) (string, *DeviceRecord, int, int, error) {
	// Preserve pending local writes; do not silently discard a failed revocation
	// or administrator change when replacing this account with the DB snapshot.
	if s.store.hasPendingChangesLocked() {
		if err := s.store.saveLocked(); err != nil {
			return "", nil, 0, 0, fmt.Errorf("flush pending changes before admission: %w", err)
		}
	}
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	pg := s.store.pg
	tx, err := pg.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return "", nil, 0, 0, err
	}
	defer tx.Rollback()
	for _, key := range admissionLockKeys(snapshot, req.Email) {
		if _, err := tx.ExecContext(ctx, admissionLockSQL, key); err != nil {
			return "", nil, 0, 0, err
		}
	}
	staged, err := loadAdmissionStore(ctx, tx, snapshot, req.Email)
	if err != nil {
		return "", nil, 0, 0, err
	}
	worker := s.admissionWorker(staged)
	token, device, limit, active, err := worker.prepareDeviceAdmission(r, req, snapshot, businessToken)
	if err != nil {
		return "", nil, limit, active, err
	}
	changes := staged.postgresChangesLocked()
	partial := &Store{Users: changes.Users, Devices: changes.Devices, Sessions: changes.Sessions}
	if err := pg.upsertUsers(ctx, tx, partial, nil); err != nil {
		return "", nil, limit, active, err
	}
	if err := pg.upsertDevices(ctx, tx, partial, changes.LoginDevices); err != nil {
		return "", nil, limit, active, err
	}
	if err := pg.upsertSessions(ctx, tx, partial); err != nil {
		return "", nil, limit, active, err
	}
	if err := pg.upsertAuditRecords(ctx, tx, changes.Audits); err != nil {
		return "", nil, limit, active, err
	}
	if complete != nil {
		if err := complete(ctx, tx, token, device, limit, active); err != nil {
			return "", nil, limit, active, err
		}
	}
	if err := tx.Commit(); err != nil {
		return "", nil, limit, active, err
	}
	s.store.mergeAdmissionLocked(staged, changes)
	return token, device, limit, active, nil
}

func loadAdmissionStore(ctx context.Context, tx *sql.Tx, snapshot SubscriptionSnapshot, fallbackEmail string) (*Store, error) {
	staged := emptyAdmissionStore()
	email := snapshot.Email
	if email == "" {
		email = fallbackEmail
	}
	u := &UserCache{}
	err := tx.QueryRowContext(ctx, admissionUserSQL, snapshot.UUID, strings.ToLower(strings.TrimSpace(email))).Scan(
		&u.ID, &u.BusinessUserID, &u.Email, &u.PlanID, &u.PlanName, &u.DeviceLimit, &u.DeviceLimitOverride, &u.LastSyncedAt, &u.CreatedAt, &u.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return staged, nil
	}
	if err != nil {
		return nil, err
	}
	staged.Users[u.ID] = u
	rows, err := tx.QueryContext(ctx, admissionDevicesSQL, u.ID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		d := &DeviceRecord{}
		if err := rows.Scan(&d.ID, &d.UserID, &d.DeviceIDHash, &d.DeviceName, &d.Platform, &d.AppVersion, &d.OSVersion, &d.Status, &d.LastSeenAt, &d.CreatedAt, &d.RevokedAt, &d.RevokedBy, &d.LastIP, &d.LastIPRegion, &d.LastIPISP, &d.UserAgent); err != nil {
			return nil, err
		}
		staged.Devices[d.ID] = d
	}
	return staged, rows.Err()
}

// Only committed admission state is published. Old cached sessions for affected
// devices are terminal locally as well as in the shared transaction; unrelated
// accounts and caches are left untouched.
func (s *Store) mergeAdmissionLocked(staged *Store, changes PostgresChanges) {
	for id, user := range staged.Users {
		s.Users[id] = user
	}
	for id, device := range staged.Devices {
		s.Devices[id] = device
	}
	for _, session := range s.Sessions {
		device := changes.Devices[session.DeviceID]
		_, login := changes.LoginDevices[session.DeviceID]
		if device != nil && (login || device.Status == statusRevoked) && session.Status == statusActive {
			cutoff := device.LastSeenAt
			if !login && device.RevokedAt != nil {
				cutoff = *device.RevokedAt
			}
			if session.CreatedAt.After(cutoff) {
				continue
			}
			session.Status = statusRevoked
			if session.ExpiresAt.After(cutoff) {
				session.ExpiresAt = cutoff
			}
		}
	}
	for id, session := range staged.Sessions {
		s.Sessions[id] = session
		s.indexSessionLocked(session)
	}
	s.Audits = append(s.Audits, staged.Audits...)
	if len(s.Audits) > 5000 {
		s.Audits = s.Audits[len(s.Audits)-5000:]
	}
	s.revision++
}
