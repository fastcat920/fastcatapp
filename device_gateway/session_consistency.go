package main

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"time"
)

var errSessionStoreUnavailable = errors.New("shared session store unavailable")

// Authorization checks use the shared DB even on an in-memory cache hit.
// Periodic full reloads are not a safe revocation propagation mechanism.
func (s *Server) verifySharedSession(ctx context.Context, tokenHash string, subscription bool) error {
	s.store.mu.RLock()
	pg := s.store.pg
	s.store.mu.RUnlock()
	if pg == nil {
		return nil
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	session, device, err := pg.sessionAuthorization(ctx, tokenHash, subscription)
	if errors.Is(err, sql.ErrNoRows) {
		return &sessionAuthorizationError{code: "DEVICE_SESSION_INVALID", message: "Device session is invalid"}
	}
	if err != nil {
		return fmt.Errorf("%w: %v", errSessionStoreUnavailable, err)
	}
	now := time.Now().UTC()
	if session.Status == statusActive && device.Status == statusActive && now.Before(session.ExpiresAt) {
		return nil
	}
	if device.Status == statusRevoked {
		session.Status = statusRevoked
	}
	return sessionAuthorizationFailure(session, device, now)
}

func (ps *PostgresStore) sessionAuthorization(ctx context.Context, tokenHash string, subscription bool) (*SessionRecord, *DeviceRecord, error) {
	column := "token_hash"
	if subscription {
		column = "subscribe_token_hash"
	}
	// column is selected solely from the fixed allowlist above, never user input.
	query := `SELECT s.status,s.expires_at,d.status,d.revoked_by FROM dg_sessions s
JOIN dg_devices d ON d.id=s.device_id AND d.user_id=s.user_id
JOIN dg_users u ON u.id=s.user_id WHERE s.` + column + `=$1`
	session, device := &SessionRecord{}, &DeviceRecord{}
	err := ps.db.QueryRowContext(ctx, query, tokenHash).Scan(&session.Status, &session.ExpiresAt, &device.Status, &device.RevokedBy)
	return session, device, err
}

func writeSessionStoreUnavailable(w http.ResponseWriter, err error) bool {
	if !errors.Is(err, errSessionStoreUnavailable) {
		return false
	}
	// Do not turn a transient DB outage into a 401 that logs clients out.
	writeError(w, http.StatusServiceUnavailable, "DEVICE_SESSION_CHECK_UNAVAILABLE", "Device session service is temporarily unavailable", nil)
	return true
}

func (s *Store) sessionCacheMissError() error {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.pg != nil {
		// Shared authorization already confirmed the token. A blocked/failed
		// cache reload must not falsely tell the client its session was revoked.
		return fmt.Errorf("%w: session cache is not ready", errSessionStoreUnavailable)
	}
	return errors.New("session not found")
}

// A gateway with a stale/empty local user cache must not replace another
// instance's verified plan limit with DefaultDeviceLimit after an upstream error.
func (s *Store) refreshLoginUser(ctx context.Context, email string) error {
	s.mu.RLock()
	pg := s.pg
	s.mu.RUnlock()
	if pg == nil {
		return nil
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	u := &UserCache{}
	err := pg.db.QueryRowContext(ctx, `SELECT id,business_user_id,email,plan_id,plan_name,device_limit,device_limit_override,last_synced_at,created_at,updated_at FROM dg_users WHERE LOWER(email)=LOWER($1) LIMIT 1`, email).
		Scan(&u.ID, &u.BusinessUserID, &u.Email, &u.PlanID, &u.PlanName, &u.DeviceLimit, &u.DeviceLimitOverride, &u.LastSyncedAt, &u.CreatedAt, &u.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, pending := s.dirtyUsers[u.ID]; pending {
		return errors.New("user limit has an unsaved update; retry login")
	}
	s.Users[u.ID] = u
	s.revision++
	return nil
}
