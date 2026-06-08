package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

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

	store, err := LoadStore(filepath.Join(t.TempDir(), "store.json"))
	if err != nil {
		t.Fatal(err)
	}
	server := &Server{
		cfg: Config{
			BusinessBaseURLs: []string{    business.URL,},
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

	store, err := LoadStore(filepath.Join(t.TempDir(), "store.json"))
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
			BusinessBaseURLs: []string{    business.URL,},
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

func stringFromNested(body []byte, first, second string) string {
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return ""
	}
	nested, _ := payload[first].(map[string]any)
	value, _ := nested[second].(string)
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
