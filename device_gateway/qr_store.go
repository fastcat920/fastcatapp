package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

var (
	errQRNotFound = errors.New("QR session not found")
	errQRExpired  = errors.New("QR session expired")
	errQRUsed     = errors.New("QR session already used")
	errQRCapacity = errors.New("QR session capacity reached")
)

const qrInsertSQL = `INSERT INTO dg_qr_login_sessions(id,expires_at,payload_cipher) VALUES($1,$2,$3)`
const qrSelectSQL = `SELECT payload_cipher FROM dg_qr_login_sessions WHERE id=$1 FOR UPDATE`
const qrUpdateSQL = `UPDATE dg_qr_login_sessions SET payload_cipher=$2 WHERE id=$1`
const qrDeleteSQL = `DELETE FROM dg_qr_login_sessions WHERE id=$1`
const qrCapacityLockSQL = `SELECT pg_advisory_xact_lock(hashtext('fastcat:qr:capacity')::bigint)`
const qrCountSQL = `SELECT COUNT(*) FROM dg_qr_login_sessions WHERE expires_at > $1`

// store.pg is immutable after startup. Do not take Store.mu here: an approval
// completion already holds it while committing the admission transaction.
func (s *Server) qrPostgres() *PostgresStore {
	if s.store == nil {
		return nil
	}
	return s.store.pg
}

func (s *Server) encodeQR(item *QRLoginSession) (string, error) {
	payload, err := json.Marshal(item)
	if err != nil {
		return "", err
	}
	return encryptString(s.key, string(payload))
}

func (s *Server) decodeQR(id, ciphertext string) (*QRLoginSession, error) {
	payload, err := decryptString(s.key, ciphertext)
	if err != nil {
		return nil, errors.New("cannot decrypt QR session")
	}
	item := &QRLoginSession{}
	if err := json.Unmarshal([]byte(payload), item); err != nil || item.ID != id {
		return nil, errors.New("invalid QR session payload")
	}
	return item, nil
}

func (s *Server) createQRSession(ctx context.Context, item *QRLoginSession) error {
	capacity := positiveEnvInt("DG_QR_MAX_ACTIVE_SESSIONS", 10000)
	pg := s.qrPostgres()
	if pg == nil {
		s.qrMu.Lock()
		defer s.qrMu.Unlock()
		if s.qrSessions == nil {
			s.qrSessions = map[string]*QRLoginSession{}
		}
		for id, old := range s.qrSessions {
			if !time.Now().Before(old.ExpiresAt) {
				delete(s.qrSessions, id)
			}
		}
		if len(s.qrSessions) >= capacity {
			return errQRCapacity
		}
		s.qrSessions[item.ID] = item
		return nil
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	ciphertext, err := s.encodeQR(item)
	if err != nil {
		return err
	}
	tx, err := pg.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	// Count and insert share a cluster-wide transaction lock. Separate gateways
	// cannot each observe the last free slot and over-admit challenges.
	if _, err := tx.ExecContext(ctx, qrCapacityLockSQL); err != nil {
		return err
	}
	now := time.Now().UTC()
	if _, err := tx.ExecContext(ctx, cleanupQRSQL, now); err != nil {
		return err
	}
	var count int
	if err := tx.QueryRowContext(ctx, qrCountSQL, now).Scan(&count); err != nil {
		return err
	}
	if count >= capacity {
		return errQRCapacity
	}
	if _, err := tx.ExecContext(ctx, qrInsertSQL, item.ID, item.ExpiresAt, ciphertext); err != nil {
		return err
	}
	return tx.Commit()
}

// The callback runs under a row lock (or qrMu for single-process JSON mode).
// Returning true deletes the challenge. Failed callbacks never publish edits.
// A supplied transaction makes QR delivery atomic with device admission.
func (s *Server) mutateQRSession(ctx context.Context, tx *sql.Tx, id string, mutate func(*QRLoginSession) (bool, error)) error {
	pg := s.qrPostgres()
	if pg == nil {
		s.qrMu.Lock()
		defer s.qrMu.Unlock()
		old := s.qrSessions[id]
		if old == nil {
			return errQRNotFound
		}
		// JSON cloning includes the nested credential response map.
		payload, err := json.Marshal(old)
		if err != nil {
			return err
		}
		item := &QRLoginSession{}
		if err := json.Unmarshal(payload, item); err != nil {
			return err
		}
		remove, err := mutate(item)
		if err != nil {
			return err
		}
		if remove {
			delete(s.qrSessions, id)
		} else {
			s.qrSessions[id] = item
		}
		return nil
	}
	if tx != nil {
		return s.mutateQRTransaction(ctx, tx, id, mutate)
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := pg.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := s.mutateQRTransaction(ctx, tx, id, mutate); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Server) mutateQRTransaction(ctx context.Context, tx *sql.Tx, id string, mutate func(*QRLoginSession) (bool, error)) error {
	var ciphertext string
	if err := tx.QueryRowContext(ctx, qrSelectSQL, id).Scan(&ciphertext); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return errQRNotFound
		}
		return err
	}
	item, err := s.decodeQR(id, ciphertext)
	if err != nil {
		return err
	}
	before, _ := json.Marshal(item)
	remove, err := mutate(item)
	if err != nil {
		return err
	}
	if remove {
		_, err = tx.ExecContext(ctx, qrDeleteSQL, id)
		return err
	}
	after, err := json.Marshal(item)
	if err != nil {
		return err
	}
	if string(before) == string(after) {
		return nil // polling must not re-encrypt/write unchanged pending results
	}
	ciphertext, err = s.encodeQR(item)
	if err != nil {
		return fmt.Errorf("encode QR update: %w", err)
	}
	_, err = tx.ExecContext(ctx, qrUpdateSQL, id, ciphertext)
	return err
}
