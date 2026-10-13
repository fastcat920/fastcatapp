package main

import (
	"context"
	"time"
)

// Expiration is immutable/monotonically decreasing for a session ID. Using it
// rather than stale in-memory device state cannot delete another instance's
// new login. Revocations already shorten expires_at to their event timestamp.
const cleanupSessionsSQL = `DELETE FROM dg_sessions WHERE expires_at < $1 RETURNING id`
const cleanupQRSQL = `DELETE FROM dg_qr_login_sessions WHERE expires_at <= $1`

// Cleanup may run on a lagging instance. All decisions must use locked database
// rows, not its local view of a device that may already have logged in elsewhere.
const revokeOfflineDevicesSQL = `UPDATE dg_devices SET status='revoked',revoked_at=$1,revoked_by='system:auto_offline'
WHERE status='active' AND last_seen_at<$2 AND last_login_at<$2 RETURNING id`
const removeOldDevicesSQL = `DELETE FROM dg_devices d WHERE d.status='revoked' AND d.revoked_at<$1
AND NOT EXISTS(SELECT 1 FROM dg_sessions s WHERE s.device_id=d.id AND s.status='active' AND s.expires_at>$2) RETURNING d.id`
const removeRetiredDeviceSessionsSQL = `DELETE FROM dg_sessions WHERE device_id=$1 AND (status<>'active' OR expires_at<=$2)`

func (s *Server) cleanupPostgresDevices(ctx context.Context, now time.Time) error {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	if s.store.hasPendingChangesLocked() {
		if err := s.store.saveLocked(); err != nil {
			return err
		}
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.store.pg.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	rows, err := tx.QueryContext(ctx, revokeOfflineDevicesSQL, now, now.Add(-30*24*time.Hour))
	if err != nil {
		return err
	}
	var revoked []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		revoked = append(revoked, id)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	for _, id := range revoked {
		if _, err := tx.ExecContext(ctx, revokeDeviceSessionsSQL, id, now); err != nil {
			return err
		}
	}
	rows, err = tx.QueryContext(ctx, removeOldDevicesSQL, now.Add(-90*24*time.Hour), now)
	if err != nil {
		return err
	}
	var removed []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		removed = append(removed, id)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	for _, id := range removed {
		if _, err := tx.ExecContext(ctx, removeRetiredDeviceSessionsSQL, id, now); err != nil {
			return err
		}
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	// Do not dirty a stale snapshot: the next shared reload obtains complete
	// authoritative rows; only invalidate local records known to be removed.
	for _, id := range revoked {
		if device := s.store.Devices[id]; device != nil {
			device.Status, device.RevokedBy, device.RevokedAt = statusRevoked, "system:auto_offline", &now
		}
	}
	for _, id := range removed {
		delete(s.store.Devices, id)
	}
	if len(removed)+len(revoked) > 0 {
		s.store.revision++
	}
	return nil
}

func (s *Server) cleanupOldSessions(ctx context.Context, now time.Time) (int, error) {
	cutoff := now.Add(-time.Duration(positiveEnvInt("DG_SESSION_RETENTION_DAYS", 30)) * 24 * time.Hour)
	s.store.mu.Lock()
	defer s.store.mu.Unlock()
	if s.store.pg == nil {
		staged := cloneAdmissionStore(s.store)
		staged.path = s.store.path
		removed := 0
		for id, session := range staged.Sessions {
			if session.ExpiresAt.Before(cutoff) {
				delete(staged.Sessions, id)
				removed++
			}
		}
		if removed == 0 {
			return 0, nil
		}
		if err := staged.saveLocked(); err != nil {
			return 0, err
		}
		s.store.Sessions = staged.Sessions
		s.store.clearDirtyLocked()
		s.store.rebuildSessionIndexesLocked()
		s.store.revision++
		return removed, nil
	}
	if s.store.hasPendingChangesLocked() {
		if err := s.store.saveLocked(); err != nil {
			return 0, err
		}
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	rows, err := s.store.pg.db.QueryContext(ctx, cleanupSessionsSQL, cutoff)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	var deleted []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return 0, err
		}
		deleted = append(deleted, id)
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}
	for _, id := range deleted {
		delete(s.store.Sessions, id)
	}
	if len(deleted) > 0 {
		s.store.rebuildSessionIndexesLocked()
		s.store.revision++
	}
	return len(deleted), nil
}

func (s *Server) cleanupExpiredQR(ctx context.Context, now time.Time) error {
	if pg := s.qrPostgres(); pg != nil {
		ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
		defer cancel()
		_, err := pg.db.ExecContext(ctx, cleanupQRSQL, now)
		return err
	}
	s.qrMu.Lock()
	defer s.qrMu.Unlock()
	for id, item := range s.qrSessions {
		if !now.Before(item.ExpiresAt) {
			delete(s.qrSessions, id)
		}
	}
	return nil
}
