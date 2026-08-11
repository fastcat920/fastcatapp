package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestClientIPPrefersTrustedPublicForwardedHeaders(t *testing.T) {
	server := &Server{cfg: Config{TrustForwardedFor: true}}
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	req.RemoteAddr = "127.0.0.1:52318"
	req.Header.Set("X-Forwarded-For", "127.0.0.1, 10.0.0.4, 203.0.113.9")
	req.Header.Set("X-Real-IP", "198.51.100.7")

	if got := server.clientIP(req); got != "203.0.113.9" {
		t.Fatalf("clientIP() = %q, want first public forwarded IP", got)
	}
}

func TestClientIPPrefersCloudflareConnectingIP(t *testing.T) {
	server := &Server{cfg: Config{TrustForwardedFor: true}}
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	req.RemoteAddr = "127.0.0.1:52318"
	req.Header.Set("CF-Connecting-IP", "198.51.100.8")
	req.Header.Set("X-Forwarded-For", "203.0.113.9")

	if got := server.clientIP(req); got != "198.51.100.8" {
		t.Fatalf("clientIP() = %q, want CF-Connecting-IP", got)
	}
}

func TestClientIPFallsBackToRemoteAddrWhenUntrusted(t *testing.T) {
	server := &Server{cfg: Config{TrustForwardedFor: false}}
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	req.RemoteAddr = "127.0.0.1:52318"
	req.Header.Set("X-Forwarded-For", "203.0.113.9")

	if got := server.clientIP(req); got != "127.0.0.1" {
		t.Fatalf("clientIP() = %q, want remote addr", got)
	}
}

func TestSessionAuthorizationErrorDistinguishesTerminationReason(t *testing.T) {
	store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	server := &Server{store: store}

	tests := []struct {
		name      string
		status    string
		revokedBy string
		expiresAt time.Time
		wantCode  string
	}{
		{
			name:      "kicked by a newer device login",
			status:    statusRevoked,
			revokedBy: "system:kick_oldest",
			expiresAt: now,
			wantCode:  "DEVICE_KICKED_BY_NEW_LOGIN",
		},
		{
			name:      "removed by the user",
			status:    statusRevoked,
			revokedBy: "user",
			expiresAt: now,
			wantCode:  "DEVICE_REVOKED",
		},
		{
			name:      "session expired naturally",
			status:    statusExpired,
			expiresAt: now.Add(-time.Minute),
			wantCode:  "DEVICE_SESSION_EXPIRED",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store.Devices["dev_test"] = &DeviceRecord{
				ID:        "dev_test",
				Status:    tt.status,
				RevokedBy: tt.revokedBy,
			}
			session := &SessionRecord{
				DeviceID:  "dev_test",
				Status:    tt.status,
				ExpiresAt: tt.expiresAt,
			}
			got := server.sessionAuthorizationErrorLocked(session, now)
			var authErr *sessionAuthorizationError
			if !errors.As(got, &authErr) {
				t.Fatalf("error type = %T, want *sessionAuthorizationError", got)
			}
			if authErr.code != tt.wantCode {
				t.Fatalf("code = %q, want %q", authErr.code, tt.wantCode)
			}
		})
	}
}

func TestIPRegionResolverWithLocalDatabase(t *testing.T) {
	dbPath := filepath.Join("data", "ip2region.db")
	if _, err := os.Stat(dbPath); err != nil {
		t.Skip("ip2region database not available")
	}
	resolver, err := NewIPRegionResolver(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer resolver.Close()

	region, ok := resolver.Lookup("119.51.60.204")
	if !ok {
		t.Fatal("expected IP region lookup to succeed")
	}
	if !strings.Contains(region.Location, "中国") ||
		!strings.Contains(region.Location, "吉林") ||
		!strings.Contains(region.Location, "长春") {
		t.Fatalf("unexpected location: %#v", region)
	}
	if !strings.Contains(region.ISP, "联通") {
		t.Fatalf("unexpected ISP: %#v", region)
	}
}

func TestDeviceLimitAndSubscriptionRewrite(t *testing.T) {
	var business *httptest.Server
	business = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/v1/passport/auth/login":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"success": true,
				"data": map[string]any{
					"auth_data": "Bearer business-auth-token",
				},
			})
		case "/api/v1/user/getSubscribe":
			if r.Header.Get("Authorization") != "Bearer business-auth-token" {
				w.WriteHeader(http.StatusUnauthorized)
				_ = json.NewEncoder(w).Encode(map[string]any{"success": false})
				return
			}
			_ = json.NewEncoder(w).Encode(map[string]any{
				"success": true,
				"data": map[string]any{
					"email":           "user@example.com",
					"uuid":            "business-user-1",
					"plan_id":         10,
					"device_limit":    1,
					"subscribe_url":   business.URL + "/api/v1/client/subscribe?token=business-sub-token",
					"token":           "business-sub-token",
					"transfer_enable": 1024,
				},
			})
		case "/api/v1/client/subscribe":
			if r.URL.Query().Get("token") != "business-sub-token" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}
			w.Header().Set("Content-Type", "text/plain")
			_, _ = w.Write([]byte("proxy-subscription-data"))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer business.Close()

	store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	server := &Server{
		cfg: Config{
			BusinessBaseURLs:   []string{business.URL},
			APIPrefix:          "/api/v1",
			DataFile:           store.path,
			AdminToken:         "admin-token",
			TokenSecret:        "test-secret",
			SessionTTL:         time.Hour,
			DevicePolicy:       policyStrict,
			DefaultDeviceLimit: 1,
			HTTPTimeout:        3 * time.Second,
		},
		store:  store,
		client: business.Client(),
		key:    deriveKey("test-secret"),
	}
	gateway := httptest.NewServer(server.routes())
	defer gateway.Close()

	loginPayload := func(deviceID string) []byte {
		body, _ := json.Marshal(map[string]any{
			"email":       "user@example.com",
			"password":    "password",
			"device_id":   deviceID,
			"device_name": "Test Device",
			"platform":    "test",
		})
		return body
	}

	firstResp, firstBody := postJSON(t, gateway.URL+"/api/v1/passport/auth/login", loginPayload("device-a"), "")
	if firstResp.StatusCode != http.StatusOK {
		t.Fatalf("first login status = %d body=%s", firstResp.StatusCode, firstBody)
	}
	authToken := stringFromNested(firstBody, "data", "auth_data")
	if !strings.HasPrefix(authToken, "Bearer dg_") {
		t.Fatalf("expected gateway auth token, got %q", authToken)
	}
	if policy := stringFromNested(firstBody, "data", "device_policy"); policy != policyStrict {
		t.Fatalf("login device_policy = %q, want %q", policy, policyStrict)
	}

	heartbeatResp, heartbeatBody := postJSON(t, gateway.URL+"/api/v1/user/devices/heartbeat", []byte("{}"), authToken)
	if heartbeatResp.StatusCode != http.StatusOK {
		t.Fatalf("heartbeat status = %d body=%s", heartbeatResp.StatusCode, heartbeatBody)
	}
	if policy := stringFromNested(heartbeatBody, "data", "device_policy"); policy != policyStrict {
		t.Fatalf("heartbeat device_policy = %q, want %q", policy, policyStrict)
	}

	subResp, subBody := getJSON(t, gateway.URL+"/api/v1/user/getSubscribe", authToken)
	if subResp.StatusCode != http.StatusOK {
		t.Fatalf("getSubscribe status = %d body=%s", subResp.StatusCode, subBody)
	}
	subURL := stringFromNested(subBody, "data", "subscribe_url")
	subToken := stringFromNested(subBody, "data", "token")
	if !strings.HasPrefix(subURL, gateway.URL+"/api/v1/client/subscribe?") {
		t.Fatalf("subscribe_url was not rewritten: %s", subURL)
	}
	if !strings.HasPrefix(subToken, "sub_") {
		t.Fatalf("subscription token was not rewritten: %s", subToken)
	}

	proxyResp, proxyBody := getRaw(t, subURL, "")
	if proxyResp.StatusCode != http.StatusOK || string(proxyBody) != "proxy-subscription-data" {
		t.Fatalf("subscription proxy status=%d body=%s", proxyResp.StatusCode, proxyBody)
	}

	secondResp, secondBody := postJSON(t, gateway.URL+"/api/v1/passport/auth/login", loginPayload("device-b"), "")
	if secondResp.StatusCode != http.StatusConflict {
		t.Fatalf("second login status = %d body=%s", secondResp.StatusCode, secondBody)
	}
	if stringFromTop(secondBody, "code") != "DEVICE_LIMIT_EXCEEDED" {
		t.Fatalf("unexpected error body: %s", secondBody)
	}
}

func TestKickOldestRevokesUntilWithinLimit(t *testing.T) {
	var business *httptest.Server
	business = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/v1/passport/auth/login":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"success": true,
				"data": map[string]any{
					"auth_data": "Bearer business-auth-token",
				},
			})
		case "/api/v1/user/getSubscribe":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"success": true,
				"data": map[string]any{
					"email":        "user@example.com",
					"uuid":         "business-user-1",
					"plan_id":      10,
					"device_limit": 1,
				},
			})
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer business.Close()

	store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	store.Users["usr_test"] = &UserCache{
		ID:             "usr_test",
		BusinessUserID: "business-user-1",
		Email:          "user@example.com",
		DeviceLimit:    intPtr(1),
		CreatedAt:      now,
		UpdatedAt:      now,
	}
	store.Devices["dev_oldest"] = &DeviceRecord{
		ID:           "dev_oldest",
		UserID:       "usr_test",
		DeviceIDHash: "oldest",
		DeviceName:   "Oldest",
		Platform:     "test",
		Status:       statusActive,
		CreatedAt:    now.Add(-3 * time.Hour),
		LastSeenAt:   now.Add(-3 * time.Hour),
	}
	store.Devices["dev_middle"] = &DeviceRecord{
		ID:           "dev_middle",
		UserID:       "usr_test",
		DeviceIDHash: "middle",
		DeviceName:   "Middle",
		Platform:     "test",
		Status:       statusActive,
		CreatedAt:    now.Add(-2 * time.Hour),
		LastSeenAt:   now.Add(-2 * time.Hour),
	}
	if err := store.Save(); err != nil {
		t.Fatal(err)
	}

	server := &Server{
		cfg: Config{
			BusinessBaseURLs:   []string{business.URL},
			APIPrefix:          "/api/v1",
			DataFile:           store.path,
			AdminToken:         "admin-token",
			TokenSecret:        "test-secret",
			SessionTTL:         time.Hour,
			DevicePolicy:       policyKickOldest,
			DefaultDeviceLimit: 1,
			HTTPTimeout:        3 * time.Second,
		},
		store:  store,
		client: business.Client(),
		key:    deriveKey("test-secret"),
	}
	gateway := httptest.NewServer(server.routes())
	defer gateway.Close()

	body, _ := json.Marshal(map[string]any{
		"email":       "user@example.com",
		"password":    "password",
		"device_id":   "new-device",
		"device_name": "New Device",
		"platform":    "test",
	})
	resp, respBody := postJSON(t, gateway.URL+"/api/v1/passport/auth/login", body, "")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("login status = %d body=%s", resp.StatusCode, respBody)
	}

	store.mu.Lock()
	defer store.mu.Unlock()
	activeCount := len(server.activeDevicesLocked("usr_test"))
	if activeCount != 1 {
		t.Fatalf("active devices = %d, want 1", activeCount)
	}
	if store.Devices["dev_oldest"].Status != statusRevoked {
		t.Fatalf("oldest status = %s, want revoked", store.Devices["dev_oldest"].Status)
	}
	if store.Devices["dev_middle"].Status != statusRevoked {
		t.Fatalf("middle status = %s, want revoked", store.Devices["dev_middle"].Status)
	}
}

func TestProxyPassesThroughBusinessErrorBody(t *testing.T) {
	var business *httptest.Server
	business = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/v1/passport/auth/login":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"success": true,
				"data": map[string]any{
					"auth_data": "Bearer business-auth-token",
				},
			})
		case "/api/v1/user/getSubscribe":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"success": true,
				"data": map[string]any{
					"email":        "user@example.com",
					"uuid":         "business-user-1",
					"device_limit": 5,
				},
			})
		case "/api/v1/user/redeemgiftcard":
			if r.Header.Get("Authorization") != "Bearer business-auth-token" {
				w.WriteHeader(http.StatusUnauthorized)
				_ = json.NewEncoder(w).Encode(map[string]any{
					"message": "missing business token",
				})
				return
			}
			w.WriteHeader(http.StatusInternalServerError)
			_ = json.NewEncoder(w).Encode(map[string]any{
				"message": "The gift card does not exist",
			})
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer business.Close()

	store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	server := &Server{
		cfg: Config{
			BusinessBaseURLs:   []string{business.URL},
			APIPrefix:          "/api/v1",
			DataFile:           store.path,
			AdminToken:         "admin-token",
			TokenSecret:        "test-secret",
			SessionTTL:         time.Hour,
			DevicePolicy:       policyStrict,
			DefaultDeviceLimit: 5,
			HTTPTimeout:        3 * time.Second,
		},
		store:  store,
		client: business.Client(),
		key:    deriveKey("test-secret"),
	}
	gateway := httptest.NewServer(server.routes())
	defer gateway.Close()

	loginBody, _ := json.Marshal(map[string]any{
		"email":       "user@example.com",
		"password":    "password",
		"device_id":   "device-a",
		"device_name": "Test Device",
		"platform":    "test",
	})
	loginResp, loginRespBody := postJSON(t, gateway.URL+"/api/v1/passport/auth/login", loginBody, "")
	if loginResp.StatusCode != http.StatusOK {
		t.Fatalf("login status = %d body=%s", loginResp.StatusCode, loginRespBody)
	}
	authToken := stringFromNested(loginRespBody, "data", "auth_data")
	if authToken == "" {
		t.Fatalf("missing gateway auth token: %s", loginRespBody)
	}

	redeemBody, _ := json.Marshal(map[string]any{
		"giftcard": "bad-card",
	})
	redeemResp, redeemRespBody := postJSON(t, gateway.URL+"/api/v1/user/redeemgiftcard", redeemBody, authToken)
	if redeemResp.StatusCode != http.StatusInternalServerError {
		t.Fatalf("redeem status = %d body=%s", redeemResp.StatusCode, redeemRespBody)
	}
	if got := stringFromTop(redeemRespBody, "message"); got != "The gift card does not exist" {
		t.Fatalf("redeem message = %q body=%s", got, redeemRespBody)
	}
	if got := stringFromTop(redeemRespBody, "code"); got == "BUSINESS_PROXY_FAILED" {
		t.Fatalf("gateway wrapped backend error instead of passing it through: %s", redeemRespBody)
	}
}

func TestAdminDashboardTreatsReachableBusiness4xxAsOnline(t *testing.T) {
	business := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path != "/api/v1/passport/auth/login" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"message": "credentials required",
		})
	}))
	defer business.Close()

	store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	server := &Server{
		cfg: Config{
			BusinessBaseURLs:   []string{business.URL},
			APIPrefix:          "/api/v1",
			DataFile:           store.path,
			AdminToken:         "admin-token",
			TokenSecret:        "test-secret",
			SessionTTL:         time.Hour,
			DevicePolicy:       policyStrict,
			DefaultDeviceLimit: 1,
			HTTPTimeout:        3 * time.Second,
		},
		store:  store,
		client: business.Client(),
		key:    deriveKey("test-secret"),
	}
	gateway := httptest.NewServer(server.routes())
	defer gateway.Close()

	resp, body := getAdminJSON(t, gateway.URL+"/api/v1/admin/dashboard", "admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("dashboard status = %d body=%s", resp.StatusCode, body)
	}
	if got := stringFromNested(body, "data", "business", "status"); got != "online" {
		t.Fatalf("business status = %q body=%s", got, body)
	}
}

func TestAdminUsersPaginationFilteringAndSorting(t *testing.T) {
	store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 6, 26, 10, 0, 0, 0, time.UTC)
	for i := 0; i < 35; i++ {
		id := fmt.Sprintf("usr_%02d", i)
		user := &UserCache{
			ID:             id,
			BusinessUserID: fmt.Sprintf("business-%02d", i),
			Email:          fmt.Sprintf("user%02d@example.com", i),
			PlanID:         i % 3,
			PlanName:       []string{"Basic", "Pro", "Team"}[i%3],
			DeviceLimit:    intPtr(3),
			LastSyncedAt:   now.Add(time.Duration(i) * time.Minute),
			CreatedAt:      now.Add(time.Duration(i) * time.Minute),
			UpdatedAt:      now.Add(time.Duration(i) * time.Minute),
		}
		if i == 10 {
			user.DeviceLimitOverride = intPtr(5)
		}
		store.Users[id] = user
		if i%2 == 0 {
			store.Devices[fmt.Sprintf("dev_%02d", i)] = &DeviceRecord{
				ID:         fmt.Sprintf("dev_%02d", i),
				UserID:     id,
				Status:     statusActive,
				LastSeenAt: now,
				CreatedAt:  now,
			}
		}
	}
	server := &Server{
		cfg: Config{
			APIPrefix:  "/api/v1",
			AdminToken: "admin-token",
		},
		store: store,
	}
	gateway := httptest.NewServer(server.routes())
	defer gateway.Close()

	resp, body := getAdminJSON(t, gateway.URL+"/api/v1/admin/users?page=2&sort=email&order=asc", "admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("users status = %d body=%s", resp.StatusCode, body)
	}
	payload := mapFromJSON(t, body)
	data := payload["data"].(map[string]any)
	users := data["users"].([]any)
	pagination := data["pagination"].(map[string]any)
	if len(users) != 5 {
		t.Fatalf("page 2 users length = %d, want 5", len(users))
	}
	if got := users[0].(map[string]any)["id"]; got != "usr_30" {
		t.Fatalf("first page 2 user = %v, want usr_30", got)
	}
	if pagination["total"].(float64) != 35 ||
		pagination["page"].(float64) != 2 ||
		pagination["page_size"].(float64) != 30 ||
		pagination["total_pages"].(float64) != 2 {
		t.Fatalf("unexpected pagination: %#v", pagination)
	}

	resp, body = getAdminJSON(t, gateway.URL+"/api/v1/admin/users?page_size=100&device_status=active&limit_mode=overridden", "admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("filtered users status = %d body=%s", resp.StatusCode, body)
	}
	payload = mapFromJSON(t, body)
	data = payload["data"].(map[string]any)
	users = data["users"].([]any)
	pagination = data["pagination"].(map[string]any)
	if len(users) != 1 || users[0].(map[string]any)["id"] != "usr_10" {
		t.Fatalf("filtered users = %#v, want only usr_10", users)
	}
	if pagination["total"].(float64) != 1 {
		t.Fatalf("filtered total = %v, want 1", pagination["total"])
	}
}

func TestAdminAuditLogsPagination(t *testing.T) {
	store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 6, 26, 10, 0, 0, 0, time.UTC)
	for i := 0; i < 65; i++ {
		store.Audits = append(store.Audits, AuditLog{
			ID:        fmt.Sprintf("audit_%02d", i),
			Action:    fmt.Sprintf("action_%02d", i),
			UserID:    fmt.Sprintf("usr_%02d", i),
			CreatedAt: now.Add(time.Duration(i) * time.Minute),
		})
	}
	server := &Server{
		cfg: Config{
			APIPrefix:  "/api/v1",
			AdminToken: "admin-token",
		},
		store: store,
	}
	gateway := httptest.NewServer(server.routes())
	defer gateway.Close()

	resp, body := getAdminJSON(t, gateway.URL+"/api/v1/admin/audit-logs?page=3", "admin-token")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("audit status = %d body=%s", resp.StatusCode, body)
	}
	payload := mapFromJSON(t, body)
	data := payload["data"].(map[string]any)
	logs := data["audit_logs"].([]any)
	pagination := data["pagination"].(map[string]any)
	if len(logs) != 5 {
		t.Fatalf("page 3 audit length = %d, want 5", len(logs))
	}
	if got := logs[0].(map[string]any)["action"]; got != "action_04" {
		t.Fatalf("first page 3 audit = %v, want action_04", got)
	}
	if pagination["total"].(float64) != 65 ||
		pagination["page"].(float64) != 3 ||
		pagination["page_size"].(float64) != 30 ||
		pagination["total_pages"].(float64) != 3 {
		t.Fatalf("unexpected audit pagination: %#v", pagination)
	}
}

func TestBusinessFailoverRetriesSafeRequestOnServerError(t *testing.T) {
	firstCalls := 0
	first := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		firstCalls++
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer first.Close()

	secondCalls := 0
	second := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		secondCalls++
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))
	defer second.Close()

	server := &Server{
		cfg:    Config{BusinessBaseURLs: []string{first.URL, second.URL}},
		client: &http.Client{Timeout: time.Second},
		log:    log.New(io.Discard, "", 0),
	}
	resp, err := server.tryBusinessURLs(context.Background(), func(baseURL string) (*http.Request, error) {
		return http.NewRequest(http.MethodGet, baseURL+"/api/v1/user/info", nil)
	})
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK || firstCalls != 1 || secondCalls != 1 {
		t.Fatalf("status=%d firstCalls=%d secondCalls=%d", resp.StatusCode, firstCalls, secondCalls)
	}
}

func TestBusinessFailoverDoesNotRetryUnsafeRequestOnServerError(t *testing.T) {
	first := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer first.Close()

	secondCalls := 0
	second := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		secondCalls++
		w.WriteHeader(http.StatusOK)
	}))
	defer second.Close()

	server := &Server{
		cfg:    Config{BusinessBaseURLs: []string{first.URL, second.URL}},
		client: &http.Client{Timeout: time.Second},
		log:    log.New(io.Discard, "", 0),
	}
	resp, err := server.tryBusinessURLs(context.Background(), func(baseURL string) (*http.Request, error) {
		return http.NewRequest(http.MethodPost, baseURL+"/api/v1/user/order/save", strings.NewReader("{}"))
	})
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusInternalServerError || secondCalls != 0 {
		t.Fatalf("status=%d secondCalls=%d", resp.StatusCode, secondCalls)
	}
}

func TestBusinessFailoverPromotesSuccessfulBackup(t *testing.T) {
	firstCalls := 0
	first := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		firstCalls++
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer first.Close()

	secondCalls := 0
	second := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		secondCalls++
		w.WriteHeader(http.StatusOK)
	}))
	defer second.Close()

	server := &Server{
		cfg: Config{
			BusinessBaseURLs:         []string{first.URL, second.URL},
			BusinessFailureThreshold: 2,
			BusinessCircuitBreak:     time.Minute,
		},
		client:        &http.Client{Timeout: time.Second},
		log:           log.New(io.Discard, "", 0),
		backendStates: make(map[string]*BusinessBackendState),
	}
	server.syncBusinessBackends(server.cfg.BusinessBaseURLs)

	for range 2 {
		resp, err := server.tryBusinessURLs(context.Background(), func(baseURL string) (*http.Request, error) {
			return http.NewRequest(http.MethodGet, baseURL+"/api/v1/user/info", nil)
		})
		if err != nil {
			t.Fatal(err)
		}
		_ = resp.Body.Close()
	}

	if firstCalls != 1 || secondCalls != 2 {
		t.Fatalf("firstCalls=%d secondCalls=%d, want 1 and 2", firstCalls, secondCalls)
	}
}

func TestBusinessFailoverSkipsBackendWhileCircuitIsOpen(t *testing.T) {
	server := &Server{
		cfg: Config{
			BusinessBaseURLs:         []string{"https://primary.example", "https://backup.example"},
			BusinessFailureThreshold: 2,
			BusinessCircuitBreak:     time.Minute,
		},
		log:           log.New(io.Discard, "", 0),
		backendStates: make(map[string]*BusinessBackendState),
	}
	server.syncBusinessBackends(server.cfg.BusinessBaseURLs)
	server.markBusinessFailure("https://primary.example")
	server.markBusinessFailure("https://primary.example")

	urls := server.businessURLs()
	if len(urls) != 1 || urls[0] != "https://backup.example" {
		t.Fatalf("businessURLs() = %v, want only backup", urls)
	}
}

func TestBusinessRecoveryFailsBackAfterConsecutiveHealthyProbes(t *testing.T) {
	primary := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer primary.Close()
	backup := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer backup.Close()

	server := &Server{
		cfg: Config{
			BusinessBaseURLs:        []string{primary.URL, backup.URL},
			APIPrefix:               "/api/v1",
			BusinessRecoverySuccess: 3,
			BusinessBackupMinHold:   time.Minute,
		},
		client:        &http.Client{Timeout: time.Second},
		log:           log.New(io.Discard, "", 0),
		backendStates: make(map[string]*BusinessBackendState),
	}
	server.syncBusinessBackends(server.cfg.BusinessBaseURLs)
	server.markBusinessSuccess(backup.URL)
	server.backendMu.Lock()
	server.activeBusinessSince = time.Now().Add(-2 * time.Minute)
	server.backendMu.Unlock()

	server.checkBusinessRecovery(context.Background())
	server.checkBusinessRecovery(context.Background())
	if got := server.businessURLs()[0]; got != backup.URL {
		t.Fatalf("active backend changed before threshold: %s", got)
	}
	server.checkBusinessRecovery(context.Background())
	if got := server.businessURLs()[0]; got != primary.URL {
		t.Fatalf("active backend = %s, want recovered primary", got)
	}
}

func TestBusinessRecoveryHonorsBackupMinimumHold(t *testing.T) {
	primary := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer primary.Close()
	backup := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer backup.Close()

	server := &Server{
		cfg: Config{
			BusinessBaseURLs:        []string{primary.URL, backup.URL},
			APIPrefix:               "/api/v1",
			BusinessRecoverySuccess: 1,
			BusinessBackupMinHold:   time.Hour,
		},
		client:        &http.Client{Timeout: time.Second},
		log:           log.New(io.Discard, "", 0),
		backendStates: make(map[string]*BusinessBackendState),
	}
	server.syncBusinessBackends(server.cfg.BusinessBaseURLs)
	server.markBusinessSuccess(backup.URL)
	server.checkBusinessRecovery(context.Background())

	if got := server.businessURLs()[0]; got != backup.URL {
		t.Fatalf("active backend = %s, want backup during minimum hold", got)
	}
}

func TestConcurrentAdminReadsDoNotBlockDeviceUpdates(t *testing.T) {
	store, _, err := LoadStore(filepath.Join(t.TempDir(), "store.json"), "")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	for i := 0; i < 50; i++ {
		userID := fmt.Sprintf("usr_%d", i)
		deviceID := fmt.Sprintf("dev_%d", i)
		store.Users[userID] = &UserCache{ID: userID, Email: fmt.Sprintf("user%d@example.com", i), CreatedAt: now, UpdatedAt: now}
		store.Devices[deviceID] = &DeviceRecord{ID: deviceID, UserID: userID, Status: statusActive, CreatedAt: now, LastSeenAt: now}
	}
	server := &Server{
		cfg:   Config{APIPrefix: "/api/v1", AdminToken: "admin-token", DefaultDeviceLimit: 1},
		store: store,
		log:   log.New(io.Discard, "", 0),
	}
	gateway := httptest.NewServer(server.routes())
	defer gateway.Close()

	const readers = 12
	const requestsPerReader = 20
	errs := make(chan error, readers+1)
	var wg sync.WaitGroup
	for i := 0; i < readers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < requestsPerReader; j++ {
				req, err := http.NewRequest(http.MethodGet, gateway.URL+"/api/v1/admin/users?page=1&page_size=30", nil)
				if err != nil {
					errs <- err
					return
				}
				req.Header.Set("X-Admin-Token", "admin-token")
				resp, err := http.DefaultClient.Do(req)
				if err != nil {
					errs <- err
					return
				}
				_, _ = io.Copy(io.Discard, resp.Body)
				_ = resp.Body.Close()
				if resp.StatusCode != http.StatusOK {
					errs <- fmt.Errorf("admin status %d", resp.StatusCode)
					return
				}
			}
		}()
	}
	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < readers*requestsPerReader; i++ {
			store.mu.Lock()
			store.Devices["dev_0"].LastSeenAt = time.Now().UTC()
			store.mu.Unlock()
		}
	}()
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Fatal(err)
		}
	}
}

func postJSON(t *testing.T, url string, body []byte, auth string) (*http.Response, []byte) {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	return doRead(t, req)
}

func getJSON(t *testing.T, url string, auth string) (*http.Response, []byte) {
	t.Helper()
	return getRaw(t, url, auth)
}

func getRaw(t *testing.T, url string, auth string) (*http.Response, []byte) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	return doRead(t, req)
}

func getAdminJSON(t *testing.T, url string, token string) (*http.Response, []byte) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("X-Admin-Token", token)
	return doRead(t, req)
}

func doRead(t *testing.T, req *http.Request) (*http.Response, []byte) {
	t.Helper()
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return resp, body
}

func mapFromJSON(t *testing.T, body []byte) map[string]any {
	t.Helper()
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatal(err)
	}
	return payload
}

func stringFromNested(body []byte, keys ...string) string {
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return ""
	}
	var current any = payload
	for _, key := range keys {
		nested, _ := current.(map[string]any)
		if nested == nil {
			return ""
		}
		current = nested[key]
	}
	value, _ := current.(string)
	return value
}

func stringFromTop(body []byte, key string) string {
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return ""
	}
	value, _ := payload[key].(string)
	return value
}
