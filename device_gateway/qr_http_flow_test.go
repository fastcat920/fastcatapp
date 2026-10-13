package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// Exercise real QR handlers and JSON persistence without fixtures that directly
// manufacture an approved challenge or a target device session.
func TestJSONQRHTTPApprovalDeliveryAndAcknowledgement(t *testing.T) {
	const (
		businessToken = "isolated-qr-business-token"
		accountEmail  = "qr-user@example.test"
		businessUser  = "isolated-qr-business-user"
		targetIP      = "203.0.113.27"
		targetUA      = "FastCat test TV"
		phoneIP       = "198.51.100.38"
	)
	var subscriptionRequests atomic.Int32
	business := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/api/v1/user/getSubscribe" || r.Header.Get("Authorization") != businessToken {
			t.Error("unexpected request or account credential at isolated business service")
			http.Error(w, "unexpected test request", http.StatusBadRequest)
			return
		}
		subscriptionRequests.Add(1)
		writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{
			"email": accountEmail, "uuid": businessUser, "device_limit": 3,
			"plan": map[string]any{"id": 1, "name": "Isolated test plan"},
		}})
	}))
	t.Cleanup(business.Close)

	s := admissionServer(nil, policyStrict)
	s.cfg.APIPrefix = "/api/v1"
	s.cfg.TrustForwardedFor = true
	s.cfg.BusinessBaseURLs = []string{business.URL}
	s.store.path = filepath.Join(t.TempDir(), "qr-http-store.json")
	s.qrSessions = make(map[string]*QRLoginSession)
	s.client = business.Client()
	s.client.Timeout = 2 * time.Second
	s.log = log.New(io.Discard, "", 0)

	phoneRequest := httptest.NewRequest(http.MethodPost, "/api/v1/passport/auth/login", nil)
	phoneRequest.Header.Set("X-Forwarded-For", phoneIP)
	phoneRequest.Header.Set("User-Agent", "FastCat test phone")
	phoneToken, phoneDevice, _, _, err := s.admitDevice(phoneRequest, LoginRequest{
		Email: accountEmail, DeviceID: "test-phone-device", DeviceName: "Test phone", Platform: "android",
	}, SubscriptionSnapshot{Email: accountEmail, UUID: businessUser, DeviceLimit: intPtr(3)}, businessToken)
	if err != nil {
		t.Fatalf("admit phone session: %v", err)
	}
	if s.store.pg != nil {
		t.Fatal("HTTP flow must use only isolated JSON persistence")
	}

	gateway := httptest.NewServer(s.routes())
	t.Cleanup(gateway.Close)
	client := gateway.Client()
	client.Timeout = 3 * time.Second
	requestQR := func(method, suffix string, body map[string]any, authorization string, headers map[string]string) (int, map[string]any) {
		t.Helper()
		var encoded []byte
		if body != nil {
			var marshalErr error
			encoded, marshalErr = json.Marshal(body)
			if marshalErr != nil {
				t.Fatal(marshalErr)
			}
		}
		r, requestErr := http.NewRequest(method, gateway.URL+"/api/v1/auth/qr/sessions"+suffix, bytes.NewReader(encoded))
		if requestErr != nil {
			t.Fatal(requestErr)
		}
		r.Header.Set("Content-Type", "application/json")
		if authorization != "" {
			r.Header.Set("Authorization", authorization)
		}
		for name, value := range headers {
			r.Header.Set(name, value)
		}
		response, requestErr := client.Do(r)
		if requestErr != nil {
			t.Fatal(requestErr)
		}
		defer response.Body.Close()
		if response.Header.Get("Cache-Control") != "no-store" {
			t.Fatal("QR HTTP responses must not be cached")
		}
		var result map[string]any
		if err := json.NewDecoder(response.Body).Decode(&result); err != nil {
			t.Fatal(err)
		}
		return response.StatusCode, result
	}
	dataOf := func(response map[string]any) map[string]any {
		t.Helper()
		data, ok := response["data"].(map[string]any)
		if !ok {
			t.Fatal("successful QR response lacks data")
		}
		return data
	}
	textOf := func(data map[string]any, key string) string {
		t.Helper()
		value, ok := data[key].(string)
		if !ok || value == "" {
			t.Fatalf("QR response lacks non-empty %s", key)
		}
		return value
	}
	assertCounts := func(want int) {
		t.Helper()
		s.store.mu.RLock()
		defer s.store.mu.RUnlock()
		if len(s.store.Users) != 1 || len(s.store.Devices) != want || len(s.store.Sessions) != want {
			t.Fatalf("unexpected admitted rows: users=%d devices=%d sessions=%d; want 1/%d/%d", len(s.store.Users), len(s.store.Devices), len(s.store.Sessions), want, want)
		}
		for _, session := range s.store.Sessions {
			if session.Status != statusActive {
				t.Fatal("QR retry revoked a valid session")
			}
		}
	}

	status, response := requestQR(http.MethodPost, "", map[string]any{
		"device_id": "test-tv-device", "device_name": "Test TV", "platform": "android_tv", "delivery_ack": true,
	}, "", map[string]string{"X-Forwarded-For": targetIP, "User-Agent": targetUA})
	if status != http.StatusOK {
		t.Fatalf("create QR status: %d", status)
	}
	created := dataOf(response)
	id, secret := textOf(created, "id"), textOf(created, "poll_token")
	if created["delivery_ack"] != true || created["qr_data"] != "fastcat://login/qr?challenge="+id {
		t.Fatal("ACK negotiation or public QR payload changed")
	}
	pollSuffix := "/" + id + "?" + url.Values{"poll_token": {secret}}.Encode()
	assertCounts(1)

	status, _ = requestQR(http.MethodPost, "/"+id, map[string]any{}, "", nil)
	if status != http.StatusUnauthorized {
		t.Fatalf("anonymous approval status = %d, want 401", status)
	}
	assertCounts(1)
	if subscriptionRequests.Load() != 0 {
		t.Fatal("anonymous approval reached authenticated business service")
	}
	status, response = requestQR(http.MethodGet, pollSuffix, nil, "", nil)
	if status != http.StatusOK || dataOf(response)["status"] != "pending" {
		t.Fatal("rejected anonymous approval changed pending challenge")
	}

	phoneHeaders := map[string]string{
		"X-Forwarded-For": phoneIP, "X-Real-IP": "198.51.100.39", "CF-Connecting-IP": "198.51.100.40",
		"User-Agent": "FastCat approving phone",
	}
	status, response = requestQR(http.MethodPost, "/"+id, map[string]any{}, "Bearer "+phoneToken, phoneHeaders)
	if status != http.StatusOK || dataOf(response)["device_name"] != "Test TV" {
		t.Fatalf("authenticated phone approval status: %d", status)
	}
	if data := dataOf(response); data["login"] != nil || data["auth_data"] != nil || data["delivery_id"] != nil {
		t.Fatal("phone approval response exposed target login credentials")
	}
	assertCounts(2)
	if subscriptionRequests.Load() != 1 {
		t.Fatal("phone approval did not fetch exactly one account subscription")
	}

	assertDuplicateApproval := func() {
		t.Helper()
		status, response := requestQR(http.MethodPost, "/"+id, map[string]any{}, "Bearer "+phoneToken, phoneHeaders)
		if status != http.StatusConflict || response["code"] != "QR_SESSION_USED" {
			t.Fatalf("repeat approval status = %d, want 409/QR_SESSION_USED", status)
		}
		assertCounts(2)
		if subscriptionRequests.Load() != 1 {
			t.Fatal("repeat approval called business service again")
		}
	}
	assertDuplicateApproval()

	var deliveredToken, deliveryID, targetDeviceID string
	for i := 0; i < 2; i++ {
		status, response = requestQR(http.MethodGet, pollSuffix, nil, "", nil)
		data := dataOf(response)
		if status != http.StatusOK || data["status"] != "approved" {
			t.Fatalf("poll %d did not retain approved delivery: status=%d", i+1, status)
		}
		login, ok := data["login"].(map[string]any)
		if !ok {
			t.Fatal("approved delivery lacks login response")
		}
		if i == 0 {
			deliveredToken, deliveryID = textOf(login, "auth_data"), textOf(data, "delivery_id")
			device, ok := login["device"].(map[string]any)
			if !ok {
				t.Fatal("approved login lacks admitted target device")
			}
			targetDeviceID = textOf(device, "id")
			if deliveredToken == "Bearer "+phoneToken || targetDeviceID == phoneDevice.ID {
				t.Fatal("target incorrectly reused approving phone identity")
			}
		} else if login["auth_data"] != deliveredToken || data["delivery_id"] != deliveryID {
			t.Fatal("repeat poll rotated credentials instead of returning same delivery")
		}
	}

	s.store.mu.RLock()
	targetDevice := cloneDevice(s.store.Devices[targetDeviceID])
	var targetSession *SessionRecord
	for _, session := range s.store.Sessions {
		if session.DeviceID == targetDeviceID {
			copy := *session
			targetSession = &copy
		}
	}
	s.store.mu.RUnlock()
	if targetDevice == nil || targetSession == nil || targetDevice.LastIP != targetIP || targetSession.LastIP != targetIP || targetDevice.UserAgent != targetUA || targetSession.UserAgent != targetUA {
		t.Fatal("phone forwarded IP/UA replaced original target metadata")
	}
	targetRequest := httptest.NewRequest(http.MethodGet, "/api/v1/user/devices", nil)
	targetRequest.Header.Set("Authorization", deliveredToken)
	if authorized, err := s.authorize(targetRequest); err != nil || authorized.Device.ID != targetDeviceID {
		t.Fatalf("delivered target token cannot authenticate: %v", err)
	}

	for i := 0; i < 2; i++ {
		status, response = requestQR(http.MethodPost, "/"+id+"/ack", map[string]any{
			"poll_token": secret, "delivery_id": deliveryID,
		}, "", nil)
		if status != http.StatusOK || dataOf(response)["status"] != "consumed" {
			t.Fatalf("ACK %d status = %d, want idempotent consumption", i+1, status)
		}
	}
	status, response = requestQR(http.MethodGet, pollSuffix, nil, "", nil)
	if status != http.StatusOK || dataOf(response)["status"] != "consumed" || dataOf(response)["login"] != nil {
		t.Fatal("acknowledged QR exposed credentials again")
	}
	assertDuplicateApproval()
	if authorized, err := s.authorize(targetRequest); err != nil || authorized.Device.ID != targetDeviceID {
		t.Fatalf("ACK or duplicate approval invalidated successful target login: %v", err)
	}

	persisted, err := os.ReadFile(s.store.path)
	if err != nil {
		t.Fatal(err)
	}
	var saved Store
	if err := json.Unmarshal(persisted, &saved); err != nil || len(saved.Devices) != 2 || len(saved.Sessions) != 2 {
		t.Fatal("normal device admission was not persisted to the isolated JSON file")
	}
	if strings.Contains(string(persisted), businessToken) || strings.Contains(string(persisted), bearerToken(deliveredToken)) {
		t.Fatal("JSON persistence contains plaintext business or delivered login token")
	}
}
