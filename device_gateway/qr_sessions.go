package main

import (
	"context"
	"crypto/hmac"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"
)

func writeQRError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, errQRCapacity):
		w.Header().Set("Retry-After", "60")
		writeError(w, http.StatusTooManyRequests, "QR_CAPACITY_REACHED", "QR login is busy, please retry shortly", nil)
	case errors.Is(err, errQRNotFound):
		writeError(w, http.StatusNotFound, "QR_SESSION_NOT_FOUND", "QR login session not found", nil)
	case errors.Is(err, errQRExpired):
		writeError(w, http.StatusGone, "QR_SESSION_EXPIRED", "二维码已过期，请刷新后重试", nil)
	case errors.Is(err, errQRUsed):
		writeError(w, http.StatusConflict, "QR_SESSION_USED", "二维码已被使用", nil)
	default:
		writeError(w, http.StatusServiceUnavailable, "QR_SESSION_STORE_UNAVAILABLE", "QR login service is temporarily unavailable", nil)
	}
}

func validQRPollToken(item *QRLoginSession, token string) bool {
	return token != "" && hmac.Equal([]byte(item.PollToken), []byte(token))
}

// Only the target receives the polling secret; the QR contains a public ID.
func (s *Server) handleQRSession(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
		return
	}
	var req struct {
		LoginRequest
		DeliveryACK bool `json:"delivery_ack"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_JSON", "Invalid JSON body", nil)
		return
	}
	req.DeviceID, req.DeviceName = strings.TrimSpace(req.DeviceID), strings.TrimSpace(req.DeviceName)
	req.Platform = strings.TrimSpace(req.Platform)
	if req.DeviceID == "" || req.DeviceName == "" {
		writeError(w, http.StatusBadRequest, "DEVICE_INFO_REQUIRED", "device_id and device_name are required", nil)
		return
	}
	if req.Platform == "" {
		req.Platform = "unknown"
	}
	req.Email, req.Password = "", "" // a QR target never supplies account credentials
	now := time.Now().UTC()
	item := &QRLoginSession{
		ID: "qrl_" + randomHex(16), PollToken: "qpt_" + randomHex(24),
		Device: req.LoginRequest, TargetIP: s.clientIP(r), TargetUA: r.UserAgent(),
		Status: "pending", CreatedAt: now, ExpiresAt: now.Add(2 * time.Minute), DeliveryACK: req.DeliveryACK,
	}
	if err := s.createQRSession(r.Context(), item); err != nil {
		writeQRError(w, err)
		return
	}
	data := map[string]any{"id": item.ID, "poll_token": item.PollToken,
		"qr_data": "fastcat://login/qr?challenge=" + item.ID, "expires_at": item.ExpiresAt.Format(time.RFC3339)}
	if item.DeliveryACK {
		data["delivery_ack"] = true
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "data": data})
}

func (s *Server) handleQRSessionByID(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	id := strings.TrimPrefix(r.URL.Path, s.cfg.APIPrefix+"/auth/qr/sessions/")
	ack := strings.HasSuffix(id, "/ack")
	if ack {
		id = strings.TrimSuffix(id, "/ack")
	}
	if id == "" || strings.Contains(id, "/") {
		writeQRError(w, errQRNotFound)
		return
	}
	if ack {
		if r.Method == http.MethodPost {
			s.handleQRAcknowledge(w, r, id)
		} else {
			writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
		}
		return
	}
	switch r.Method {
	case http.MethodGet:
		s.handleQRPoll(w, r, id)
	case http.MethodPost:
		s.handleQRApprove(w, r, id)
	case http.MethodDelete:
		s.handleQRCancel(w, r, id)
	default:
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
	}
}

func (s *Server) handleQRCancel(w http.ResponseWriter, r *http.Request, id string) {
	token := strings.TrimSpace(r.URL.Query().Get("poll_token"))
	// Distinguish a missing row (idempotent cancel) from an invalid secret.
	invalidSecret := false
	err := s.mutateQRSession(r.Context(), nil, id, func(item *QRLoginSession) (bool, error) {
		if !validQRPollToken(item, token) {
			invalidSecret = true
			return false, errQRNotFound
		}
		if item.Status != "pending" {
			return false, errQRUsed
		}
		return true, nil
	})
	if err != nil && (!errors.Is(err, errQRNotFound) || invalidSecret) {
		writeQRError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "data": map[string]any{"status": "cancelled"}})
}

func (s *Server) handleQRPoll(w http.ResponseWriter, r *http.Request, id string) {
	token := strings.TrimSpace(r.URL.Query().Get("poll_token"))
	var data map[string]any
	err := s.mutateQRSession(r.Context(), nil, id, func(item *QRLoginSession) (bool, error) {
		if !validQRPollToken(item, token) {
			return false, errQRNotFound
		}
		if !time.Now().Before(item.ExpiresAt) {
			data = map[string]any{"status": "expired"}
			return true, nil
		}
		data = map[string]any{"status": item.Status, "expires_at": item.ExpiresAt.Format(time.RFC3339)}
		if item.Status == "approved" && item.Response != nil {
			data["login"] = item.Response
			if item.DeliveryACK {
				data["delivery_id"] = item.DeliveryID
			} else {
				// Legacy clients (including tvOS) never send ACK.
				item.Status, item.Response = "consumed", nil
			}
		}
		return false, nil
	})
	if err != nil {
		writeQRError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "data": data})
}

func (s *Server) handleQRAcknowledge(w http.ResponseWriter, r *http.Request, id string) {
	var req struct {
		PollToken  string `json:"poll_token"`
		DeliveryID string `json:"delivery_id"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 4096)).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_JSON", "Invalid JSON body", nil)
		return
	}
	err := s.mutateQRSession(r.Context(), nil, id, func(item *QRLoginSession) (bool, error) {
		if !item.DeliveryACK || !validQRPollToken(item, req.PollToken) || req.DeliveryID == "" ||
			!hmac.Equal([]byte(item.DeliveryID), []byte(req.DeliveryID)) {
			return false, errQRNotFound
		}
		if !time.Now().Before(item.ExpiresAt) {
			return false, errQRExpired
		}
		if item.Status != "approved" && item.Status != "consumed" {
			return false, errQRUsed
		}
		item.Status, item.Response = "consumed", nil
		return false, nil
	})
	if err != nil {
		writeQRError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "data": map[string]any{"status": "consumed"}})
}

func (s *Server) handleQRApprove(w http.ResponseWriter, r *http.Request, id string) {
	session, ok := s.requireSession(w, r)
	if !ok {
		return
	}
	claim := randomHex(24)
	var target LoginRequest
	var targetIP, targetUA string
	err := s.mutateQRSession(r.Context(), nil, id, func(item *QRLoginSession) (bool, error) {
		if !time.Now().Before(item.ExpiresAt) {
			return false, errQRExpired
		}
		if item.Status != "pending" {
			return false, errQRUsed
		}
		item.Status, item.ApprovedBy, item.ApprovalClaim = "authorizing", session.User.ID, claim
		target, targetIP, targetUA = item.Device, item.TargetIP, item.TargetUA
		return false, nil
	})
	if err != nil {
		writeQRError(w, err)
		return
	}
	snapshot, err := s.fetchSubscriptionSnapshot(r.Context(), session.BusinessToken)
	if err != nil {
		s.failQRClaim(id, claim)
		writeError(w, http.StatusBadGateway, "QR_SUBSCRIPTION_UNAVAILABLE", "无法验证账户订阅，请稍后重试", nil)
		return
	}
	if snapshot.Email == "" {
		snapshot.Email = session.User.Email
	}
	request := r.Clone(r.Context())
	request.RemoteAddr = targetIP
	request.Header.Set("User-Agent", targetUA)
	request.Header.Del("X-Forwarded-For")
	request.Header.Del("X-Real-IP")
	request.Header.Del("CF-Connecting-IP")
	limit, active, err := s.approveQRDevice(request, target, snapshot, session.BusinessToken, id, claim)
	if err != nil {
		s.failQRClaim(id, claim)
		if errors.Is(err, errDeviceLimitExceeded) {
			writeError(w, http.StatusConflict, "DEVICE_LIMIT_EXCEEDED", "设备数量已达上限", map[string]any{"device_limit": limit, "active_count": active})
		} else {
			writeQRError(w, err)
		}
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"success": true, "data": map[string]any{"device_name": target.DeviceName, "platform": target.Platform}})
}

func validateQRClaim(item *QRLoginSession, claim string) error {
	if item == nil {
		return errQRNotFound
	}
	if item.Status != "authorizing" || item.ApprovalClaim != claim {
		return errQRUsed
	}
	if !time.Now().Before(item.ExpiresAt) {
		return errQRExpired
	}
	return nil
}

func (s *Server) completeQRResponse(item *QRLoginSession, token string, device *DeviceRecord, email string, limit int) {
	item.Response = map[string]any{"token": "Bearer " + token, "auth_data": "Bearer " + token,
		"email": email, "device": publicDevice(device, device.ID),
		"device_limit": nullableLimit(limit), "device_policy": s.cfg.DevicePolicy}
	if urls := s.ossGatewayURLs(); len(urls) > 0 {
		item.Response["gateway_urls"] = urls
	}
	item.Status = "approved"
	if item.DeliveryACK {
		item.DeliveryID = randomHex(24)
	}
}

func (s *Server) approveQRDevice(r *http.Request, target LoginRequest, snapshot SubscriptionSnapshot, businessToken, id, claim string) (int, int, error) {
	if s.qrPostgres() == nil {
		// JSON mode is single-process: reserve the challenge across the file
		// save, so expiry cleanup/cancellation cannot remove it after admission.
		// Never run a fallible QR callback after committing the device file.
		s.qrMu.Lock()
		defer s.qrMu.Unlock()
		item := s.qrSessions[id]
		if err := validateQRClaim(item, claim); err != nil {
			return 0, 0, err
		}
		token, device, limit, active, err := s.admitDeviceWithCompletion(r, target, snapshot, businessToken,
			func(ctx context.Context, _ *sql.Tx, _ string, _ *DeviceRecord, _, _ int) error {
				if err := ctx.Err(); err != nil {
					return err
				}
				// Store.mu may have been held by a concurrent file save. Recheck
				// after acquiring it, immediately before persisting admission.
				return validateQRClaim(item, claim)
			})
		if err != nil {
			return limit, active, err
		}
		s.completeQRResponse(item, token, device, snapshot.Email, limit)
		return limit, active, nil
	}
	_, _, limit, active, err := s.admitDeviceWithCompletion(r, target, snapshot, businessToken,
		func(ctx context.Context, tx *sql.Tx, token string, device *DeviceRecord, limit, _ int) error {
			return s.mutateQRSession(ctx, tx, id, func(item *QRLoginSession) (bool, error) {
				if err := validateQRClaim(item, claim); err != nil {
					return false, err
				}
				s.completeQRResponse(item, token, device, snapshot.Email, limit)
				return false, nil
			})
		})
	return limit, active, err
}

func (s *Server) failQRClaim(id, claim string) {
	// The request may have been cancelled while querying the business service.
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_ = s.mutateQRSession(ctx, nil, id, func(item *QRLoginSession) (bool, error) {
		if item.Status == "authorizing" && item.ApprovalClaim == claim {
			item.Status, item.Response = "failed", nil
		}
		return false, nil
	})
}
