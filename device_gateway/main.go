package main

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"encoding/base64"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	statusActive  = "active"
	statusRevoked = "revoked"
	statusExpired = "expired"

	policyStrict     = "strict"
	policyKickOldest = "kick_oldest"
)

type Config struct {
	ListenAddr         string
	BusinessBaseURLs   []string
	PublicBaseURL      string
	GatewayURLs        []string
	APIPrefix          string
	DataFile           string
	AdminToken         string
	TokenSecret        string
	SessionTTL         time.Duration
	DevicePolicy       string
	DefaultDeviceLimit int
	HTTPTimeout        time.Duration
	TrustForwardedFor  bool
}

type Server struct {
	cfg    Config
	store  *Store
	client *http.Client
	key    []byte
	log    *log.Logger
	ossMu  sync.RWMutex
}

type Store struct {
	mu       sync.Mutex                `json:"-"`
	path     string                    `json:"-"`
	Users    map[string]*UserCache     `json:"users"`
	Devices  map[string]*DeviceRecord  `json:"devices"`
	Sessions map[string]*SessionRecord `json:"sessions"`
	Audits   []AuditLog                `json:"audits"`
}

type UserCache struct {
	ID                  string    `json:"id"`
	BusinessUserID      string    `json:"business_user_id,omitempty"`
	Email               string    `json:"email"`
	PlanID              int       `json:"plan_id,omitempty"`
	PlanName            string    `json:"plan_name,omitempty"`
	DeviceLimit         *int      `json:"device_limit,omitempty"`
	DeviceLimitOverride *int      `json:"device_limit_override,omitempty"`
	LastSyncedAt        time.Time `json:"last_synced_at"`
	CreatedAt           time.Time `json:"created_at"`
	UpdatedAt           time.Time `json:"updated_at"`
}

type DeviceRecord struct {
	ID           string     `json:"id"`
	UserID       string     `json:"user_id"`
	DeviceIDHash string     `json:"device_id_hash"`
	DeviceName   string     `json:"device_name"`
	Platform     string     `json:"platform"`
	AppVersion   string     `json:"app_version,omitempty"`
	OSVersion    string     `json:"os_version,omitempty"`
	Status       string     `json:"status"`
	LastSeenAt   time.Time  `json:"last_seen_at"`
	CreatedAt    time.Time  `json:"created_at"`
	RevokedAt    *time.Time `json:"revoked_at,omitempty"`
	RevokedBy    string     `json:"revoked_by,omitempty"`
	LastIP       string     `json:"last_ip,omitempty"`
	UserAgent    string     `json:"user_agent,omitempty"`
}

type SessionRecord struct {
	ID                   string    `json:"id"`
	UserID               string    `json:"user_id"`
	DeviceID             string    `json:"device_id"`
	TokenHash            string    `json:"token_hash"`
	BusinessTokenCipher  string    `json:"business_token_cipher"`
	BusinessSubURLCipher string    `json:"business_sub_url_cipher,omitempty"`
	SubscribeTokenHash   string    `json:"subscribe_token_hash"`
	SubscribeTokenCipher string    `json:"subscribe_token_cipher"`
	Status               string    `json:"status"`
	ExpiresAt            time.Time `json:"expires_at"`
	CreatedAt            time.Time `json:"created_at"`
	LastSeenAt           time.Time `json:"last_seen_at"`
	LastIP               string    `json:"last_ip,omitempty"`
	UserAgent            string    `json:"user_agent,omitempty"`
}

type AuditLog struct {
	ID        string         `json:"id"`
	UserID    string         `json:"user_id,omitempty"`
	DeviceID  string         `json:"device_id,omitempty"`
	Action    string         `json:"action"`
	Actor     string         `json:"actor"`
	IP        string         `json:"ip,omitempty"`
	UserAgent string         `json:"user_agent,omitempty"`
	Details   map[string]any `json:"details,omitempty"`
	CreatedAt time.Time      `json:"created_at"`
}

type LoginRequest struct {
	Email      string         `json:"email"`
	Password   string         `json:"password"`
	DeviceID   string         `json:"device_id"`
	DeviceName string         `json:"device_name"`
	Platform   string         `json:"platform"`
	AppVersion string         `json:"app_version"`
	OSVersion  string         `json:"os_version"`
	DeviceInfo map[string]any `json:"device_info"`
}

type SubscriptionSnapshot struct {
	Email          string
	UUID           string
	PlanID         int
	PlanName       string
	DeviceLimit    *int
	SubscribeURL   string
	SubscribeToken string
}

type SessionContext struct {
	User           *UserCache
	Device         *DeviceRecord
	Session        *SessionRecord
	BusinessToken  string
	SubscribeToken string
}

type businessHTTPError struct {
	status      int
	body        []byte
	contentType string
}

func (e *businessHTTPError) Error() string {
	return fmt.Sprintf("business API returned status %d", e.status)
}

//go:embed static/*
var adminStatic embed.FS

func main() {
	logger := log.New(os.Stdout, "[device-gateway] ", log.LstdFlags|log.Lmicroseconds)

	cfg, err := loadConfig(logger)
	if err != nil {
		logger.Fatal(err)
	}

	store, err := LoadStore(cfg.DataFile)
	if err != nil {
		logger.Fatal(err)
	}

	server := &Server{
		cfg:   cfg,
		store: store,
		client: &http.Client{
			Timeout: cfg.HTTPTimeout,
		},
		key: deriveKey(cfg.TokenSecret),
		log: logger,
	}

	logger.Printf("listening on %s, business=%s, api_prefix=%s, data=%s",
		cfg.ListenAddr, cfg.BusinessBaseURLs, cfg.APIPrefix, cfg.DataFile)

	go server.periodicCleanup()

	server.startOSSRefresher(envInt("DG_OSS_REFRESH_MINUTES", 30))
	if err := http.ListenAndServe(cfg.ListenAddr, server.routes()); err != nil {
		logger.Fatal(err)
	}
}

// fetchBusinessBaseURLs tries to load business backend URLs from OSS remote
// config. It iterates through the comma-separated DG_OSS_CONFIG_URLS, downloads
// each, XOR-decrypts the body, and extracts all domains.
// Returns nil if all sources fail or are not configured.
func fetchBusinessBaseURLs(logger *log.Logger) (domains, gatewayURLs []string) {
	ossURLs := env("DG_OSS_CONFIG_URLS", "")
	if ossURLs == "" {
		return nil, nil
	}
	xorKey := env("DG_OSS_XOR_KEY", "")
	if xorKey == "" {
		logger.Printf("DG_OSS_XOR_KEY not set, skipping OSS fetch")
		return nil, nil
	}
	timeout := envInt("DG_OSS_FETCH_TIMEOUT", 15)
	urls := strings.Split(ossURLs, ",")

	client := &http.Client{
		Timeout: time.Duration(timeout) * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}

	for i, rawURL := range urls {
		rawURL = strings.TrimSpace(rawURL)
		if rawURL == "" {
			continue
		}
		logger.Printf("OSS fetch [%d/%d]: %s", i+1, len(urls), rawURL)

		body, err := downloadOSS(client, rawURL)
		if err != nil {
			logger.Printf("OSS fetch failed: %v", err)
			continue
		}

		decrypted, err := xorDecrypt(body, xorKey)
		if err != nil {
			logger.Printf("OSS decrypt failed: %v", err)
			continue
		}

		domains, gatewayURLs, err := extractOSSConfig(decrypted)
		if err != nil {
			logger.Printf("OSS parse failed: %v", err)
			continue
		}

		logger.Printf("OSS resolved business URLs: %v, gateway URLs: %v", domains, gatewayURLs)
		return domains, gatewayURLs
	}
	return nil, nil
}

func downloadOSS(client *http.Client, rawURL string) ([]byte, error) {
	req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return io.ReadAll(io.LimitReader(resp.Body, 1<<20))
}

// xorDecrypt decrypts a base64-encoded XOR ciphertext using the given key.
// Returns JSON plaintext if the input is already valid JSON (unencrypted).
func xorDecrypt(body []byte, key string) ([]byte, error) {
	trimmed := bytes.TrimSpace(body)
	if len(trimmed) == 0 {
		return nil, errors.New("empty body")
	}
	// Already plain JSON?
	if trimmed[0] == '{' || trimmed[0] == '[' {
		if json.Valid(trimmed) {
			return trimmed, nil
		}
	}
	// XOR + Base64 decrypt
	encBytes, err := base64.StdEncoding.DecodeString(string(trimmed))
	if err != nil {
		return nil, fmt.Errorf("base64 decode: %w", err)
	}
	keyBytes := []byte(key)
	decBytes := make([]byte, len(encBytes))
	for i := range encBytes {
		decBytes[i] = encBytes[i] ^ keyBytes[i%len(keyBytes)]
	}
	return decBytes, nil
}

var (
	ossDomainsRE     = regexp.MustCompile(`"domains"\s*:\s*(\[[^\]]*\])`)
	ossGatewayURLsRE = regexp.MustCompile(`"gateway_urls"\s*:\s*(\[[^\]]*\])`)
)

// extractOSSConfig extracts business domains and gateway URLs from the
// OSS remote config. The OSS data is non-standard JSON (anonymous nested
// object), so we use regex to pull out the two arrays directly.
func extractOSSConfig(data []byte) (domains, gatewayURLs []string, err error) {
	// Extract domains
	if m := ossDomainsRE.FindSubmatch(data); len(m) >= 2 {
		var arr []string
		if err := json.Unmarshal(m[1], &arr); err == nil {
			for _, d := range arr {
				d = strings.TrimRight(d, "/")
				if d == "" {
					continue
				}
				if _, e := url.ParseRequestURI(d); e != nil {
					continue
				}
				domains = append(domains, d)
			}
		}
	}

	// Extract gateway URLs
	if m := ossGatewayURLsRE.FindSubmatch(data); len(m) >= 2 {
		var arr []string
		if err := json.Unmarshal(m[1], &arr); err == nil {
			for _, u := range arr {
				u = strings.TrimRight(u, "/")
				if u == "" {
					continue
				}
				if _, e := url.ParseRequestURI(u); e != nil {
					continue
				}
				gatewayURLs = append(gatewayURLs, u)
			}
		}
	}

	return domains, gatewayURLs, nil
}



func loadConfig(logger *log.Logger) (Config, error) {
	sessionHours := envInt("DG_SESSION_TTL_HOURS", 720)
	timeoutSeconds := envInt("DG_HTTP_TIMEOUT_SECONDS", 20)
	apiPrefix := strings.TrimRight(env("DG_API_PREFIX", "/api/v1"), "/")
	if apiPrefix == "" {
		apiPrefix = "/api/v1"
	}

	policy := env("DG_DEVICE_POLICY", policyStrict)
	if policy != policyStrict && policy != policyKickOldest {
		return Config{}, fmt.Errorf("unsupported DG_DEVICE_POLICY: %s", policy)
	}

	publicBaseURL := strings.TrimRight(env("DG_PUBLIC_BASE_URL", ""), "/")
	var ossGatewayURLs []string

	var baseURLs []string
	if envURL := strings.TrimRight(env("DG_BUSINESS_BASE_URL", ""), "/"); envURL != "" {
		baseURLs = []string{envURL}
	} else {
		logger.Printf("DG_BUSINESS_BASE_URL not set, fetching from OSS remote config...")
		baseURLs, ossGatewayURLs = fetchBusinessBaseURLs(logger)
		if len(baseURLs) == 0 {
			return Config{}, errors.New("DG_BUSINESS_BASE_URL is required (env not set and all OSS sources failed)")
		}
		// Use OSS gateway_urls as fallback for DG_PUBLIC_BASE_URL
		if publicBaseURL == "" && len(ossGatewayURLs) > 0 {
			publicBaseURL = ossGatewayURLs[0]
			logger.Printf("using OSS gateway_url as public base: %s", publicBaseURL)
		}
	}
	for _, u := range baseURLs {
		if _, err := url.ParseRequestURI(u); err != nil {
			return Config{}, fmt.Errorf("invalid business URL %q: %w", u, err)
		}
	}

	adminToken := env("DG_ADMIN_TOKEN", "")
	tokenSecret := env("DG_TOKEN_SECRET", "")
	if tokenSecret == "" {
		tokenSecret = adminToken
	}
	if tokenSecret == "" {
		tokenSecret = "dev-insecure-token-secret"
	}

	return Config{
		ListenAddr:         env("DG_LISTEN_ADDR", ":8787"),
		BusinessBaseURLs:   baseURLs,
		PublicBaseURL:      publicBaseURL,
		GatewayURLs:        ossGatewayURLs,
		APIPrefix:          apiPrefix,
		DataFile:           env("DG_DATA_FILE", "./data/device-gateway.json"),
		AdminToken:         adminToken,
		TokenSecret:        tokenSecret,
		SessionTTL:         time.Duration(sessionHours) * time.Hour,
		DevicePolicy:       policy,
		DefaultDeviceLimit: envInt("DG_DEFAULT_DEVICE_LIMIT", 1),
		HTTPTimeout:        time.Duration(timeoutSeconds) * time.Second,
		TrustForwardedFor:  envBool("DG_TRUST_FORWARDED_FOR", false),
	}, nil
}

func (s *Server) routes() http.Handler {
	mux := http.NewServeMux()
	prefix := s.cfg.APIPrefix

	mux.HandleFunc("/admin", s.handleAdminPage)
	mux.HandleFunc("/admin/", s.handleAdminPage)
	mux.HandleFunc("/admin/static/", s.handleAdminStatic)
	mux.HandleFunc("/healthz", s.handleHealth)
	mux.HandleFunc(prefix+"/passport/auth/login", s.handleLogin)
	mux.HandleFunc(prefix+"/client/subscribe", s.handleSubscribe)
	mux.HandleFunc(prefix+"/user/devices/heartbeat", s.handleHeartbeat)
	mux.HandleFunc(prefix+"/user/devices", s.handleUserDevices)
	mux.HandleFunc(prefix+"/user/devices/", s.handleUserDeviceByID)
	mux.HandleFunc(prefix+"/admin/", s.handleAdmin)
	mux.HandleFunc("/", s.handleProxy)

	return withCORS(mux)
}

// startOSSRefresher periodically re-fetches OSS remote config so domain
// changes take effect without a restart.
func (s *Server) startOSSRefresher(intervalMinutes int) {
	if intervalMinutes <= 0 {
		return
	}
	go func() {
		ticker := time.NewTicker(time.Duration(intervalMinutes) * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			s.refreshOSSConfig()
		}
	}()
}

func (s *Server) refreshOSSConfig() {
	if env("DG_OSS_CONFIG_URLS", "") == "" || env("DG_OSS_XOR_KEY", "") == "" {
		return
	}
	domains, gatewayURLs := fetchBusinessBaseURLs(s.log)
	if len(domains) == 0 {
		s.log.Printf("OSS refresh: no domains returned, keeping current config")
		return
	}
	s.ossMu.Lock()
	s.cfg.BusinessBaseURLs = domains
	if len(gatewayURLs) > 0 {
		s.cfg.GatewayURLs = gatewayURLs
	}
	s.ossMu.Unlock()
	s.log.Printf("OSS refreshed: business URLs=%v, gateway URLs=%v", domains, gatewayURLs)
}

func (s *Server) handleAdminPage(w http.ResponseWriter, r *http.Request) {
	data, err := adminStatic.ReadFile("static/admin.html")
	if err != nil {
		http.Error(w, "Not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(data)
}

func (s *Server) handleAdminStatic(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/admin/static/")
	data, err := adminStatic.ReadFile("static/" + path)
	if err != nil {
		http.Error(w, "Not found", http.StatusNotFound)
		return
	}
	if strings.HasSuffix(path, ".css") {
		w.Header().Set("Content-Type", "text/css; charset=utf-8")
	} else if strings.HasSuffix(path, ".js") {
		w.Header().Set("Content-Type", "application/javascript; charset=utf-8")
	}
	w.Write(data)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"status": "ok",
			"time":   time.Now().UTC().Format(time.RFC3339),
		},
	})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
		return
	}

	var req LoginRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_JSON", "Invalid JSON body", nil)
		return
	}
	req.Email = strings.TrimSpace(req.Email)
	req.DeviceID = strings.TrimSpace(req.DeviceID)
	req.DeviceName = strings.TrimSpace(req.DeviceName)
	req.Platform = strings.TrimSpace(req.Platform)

	if req.Email == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "CREDENTIALS_REQUIRED", "Email and password are required", nil)
		return
	}
	if req.DeviceID == "" {
		writeError(w, http.StatusBadRequest, "DEVICE_ID_REQUIRED", "device_id is required", nil)
		return
	}
	if req.DeviceName == "" {
		req.DeviceName = "Unknown device"
	}
	if req.Platform == "" {
		req.Platform = "unknown"
	}

	businessToken, businessPayload, err := s.businessLogin(r.Context(), req.Email, req.Password)
	if err != nil {
		var apiErr *businessHTTPError
		if errors.As(err, &apiErr) {
			writeRaw(w, apiErr.status, apiErr.contentType, apiErr.body)
			return
		}
		s.log.Printf("business login failed: %v", err)
		writeError(w, http.StatusBadGateway, "BACKEND_UNREACHABLE", "Business backend unreachable", nil)
		return
	}

	snapshot, err := s.fetchSubscriptionSnapshot(r.Context(), businessToken)
	if err != nil {
		s.log.Printf("subscription sync failed after login, using fallback limit: %v", err)
		snapshot = SubscriptionSnapshot{
			Email:       req.Email,
			DeviceLimit: intPtr(s.cfg.DefaultDeviceLimit),
		}
	}
	if snapshot.Email == "" {
		snapshot.Email = req.Email
	}

	sessionToken, device, effectiveLimit, activeCount, err := s.admitDevice(r, req, snapshot, businessToken)
	if err != nil {
		if errors.Is(err, errDeviceLimitExceeded) {
			writeError(w, http.StatusConflict, "DEVICE_LIMIT_EXCEEDED", "Device limit exceeded", map[string]any{
				"device_limit": effectiveLimit,
				"active_count": activeCount,
			})
			return
		}
		s.log.Printf("device admission failed: %v", err)
		writeError(w, http.StatusInternalServerError, "DEVICE_ADMISSION_FAILED", "Device admission failed", nil)
		return
	}

	data := mapFromAny(businessPayload["data"])
	if data == nil {
		data = map[string]any{}
	}
	gatewayToken := "Bearer " + sessionToken
	data["auth_data"] = gatewayToken
	data["token"] = gatewayToken
	data["device"] = publicDevice(device, device.ID)
	data["device_limit"] = nullableLimit(effectiveLimit)
	if len(s.ossGatewayURLs()) > 0 {
		data["gateway_urls"] = s.ossGatewayURLs()
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Login successful",
		"data":    data,
	})
}

func (s *Server) handleSubscribe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
		return
	}

	token := r.URL.Query().Get("token")
	if token == "" {
		token = r.URL.Query().Get("device_session")
	}
	if token == "" {
		token = r.URL.Query().Get("session")
	}
	if token == "" {
		token = bearerToken(r.Header.Get("Authorization"))
	}
	if token == "" {
		writeError(w, http.StatusUnauthorized, "SUBSCRIBE_TOKEN_REQUIRED", "Subscription token is required", nil)
		return
	}

	sessionCtx, err := s.authorizeSubscribeToken(r, token)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "SUBSCRIBE_SESSION_INVALID", "Subscription session is invalid or expired", nil)
		return
	}

	targetURL, err := s.businessSubscribeURL(r.Context(), sessionCtx)
	if err != nil {
		s.log.Printf("subscription URL lookup failed: %v", err)
		writeError(w, http.StatusBadGateway, "SUBSCRIBE_URL_UNAVAILABLE", "Subscription URL is unavailable", nil)
		return
	}
	targetURL, err = mergeSubscribeQuery(targetURL, r.URL.Query())
	if err != nil {
		writeError(w, http.StatusBadGateway, "BAD_SUBSCRIBE_URL", "Bad subscription URL", nil)
		return
	}

	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, targetURL, nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "REQUEST_CREATE_FAILED", "Failed to create proxy request", nil)
		return
	}
	copyProxyHeaders(req.Header, r.Header)
	req.Header.Del("Authorization")

	resp, err := s.client.Do(req)
	if err != nil {
		s.log.Printf("subscription proxy failed: %v", err)
		writeError(w, http.StatusBadGateway, "SUBSCRIBE_PROXY_FAILED", "Subscription proxy failed", nil)
		return
	}
	defer resp.Body.Close()

	copyResponseHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

var errDeviceLimitExceeded = errors.New("device limit exceeded")

func (s *Server) admitDevice(r *http.Request, req LoginRequest, snapshot SubscriptionSnapshot, businessToken string) (string, *DeviceRecord, int, int, error) {
	now := time.Now().UTC()
	clientIP := s.clientIP(r)
	userAgent := r.UserAgent()
	deviceHash := s.hashValue("device", req.DeviceID)

	encryptedBusinessToken, err := encryptString(s.key, businessToken)
	if err != nil {
		return "", nil, 0, 0, err
	}

	sessionToken := "dg_" + randomHex(32)
	sessionHash := s.hashValue("session", sessionToken)
	subscribeToken := "sub_" + randomHex(32)
	subscribeHash := s.hashValue("subscribe", subscribeToken)
	encryptedSubscribeToken, err := encryptString(s.key, subscribeToken)
	if err != nil {
		return "", nil, 0, 0, err
	}
	var encryptedSubURL string
	if snapshot.SubscribeURL != "" {
		encryptedSubURL, err = encryptString(s.key, snapshot.SubscribeURL)
		if err != nil {
			return "", nil, 0, 0, err
		}
	}

	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	user := s.upsertUserLocked(snapshot, req.Email, now)
	effectiveLimit := s.effectiveLimitLocked(user)
	activeDevices := s.activeDevicesLocked(user.ID)
	activeCount := len(activeDevices)

	device := s.findDeviceByHashLocked(user.ID, deviceHash)
	isNewActiveDevice := device == nil || device.Status != statusActive
	if isNewActiveDevice && effectiveLimit > 0 && activeCount >= effectiveLimit {
		if s.cfg.DevicePolicy != policyKickOldest {
			return "", nil, effectiveLimit, activeCount, errDeviceLimitExceeded
		}
		for activeCount >= effectiveLimit {
			oldest := oldestDevice(activeDevices)
			if oldest == nil {
				return "", nil, effectiveLimit, activeCount, errDeviceLimitExceeded
			}
			s.revokeDeviceLocked(oldest, "system:kick_oldest", now)
			s.revokeDeviceSessionsLocked(oldest.ID, now)
			s.addAuditLocked("device.revoked", user.ID, oldest.ID, "system:kick_oldest", clientIP, userAgent, map[string]any{
				"reason": "device policy kick_oldest",
			}, now)
			activeCount--
			activeDevices = removeDeviceByID(activeDevices, oldest.ID)
		}
	}

	if device == nil {
		device = &DeviceRecord{
			ID:           "dev_" + randomHex(12),
			UserID:       user.ID,
			DeviceIDHash: deviceHash,
			CreatedAt:    now,
		}
		s.store.Devices[device.ID] = device
	}

	device.DeviceName = req.DeviceName
	device.Platform = req.Platform
	device.AppVersion = req.AppVersion
	device.OSVersion = req.OSVersion
	device.Status = statusActive
	device.LastSeenAt = now
	device.LastIP = clientIP
	device.UserAgent = userAgent
	device.RevokedAt = nil
	device.RevokedBy = ""

	s.revokeDeviceSessionsLocked(device.ID, now)

	session := &SessionRecord{
		ID:                   "ses_" + randomHex(12),
		UserID:               user.ID,
		DeviceID:             device.ID,
		TokenHash:            sessionHash,
		BusinessTokenCipher:  encryptedBusinessToken,
		BusinessSubURLCipher: encryptedSubURL,
		SubscribeTokenHash:   subscribeHash,
		SubscribeTokenCipher: encryptedSubscribeToken,
		Status:               statusActive,
		ExpiresAt:            now.Add(s.cfg.SessionTTL),
		CreatedAt:            now,
		LastSeenAt:           now,
		LastIP:               clientIP,
		UserAgent:            userAgent,
	}
	s.store.Sessions[session.ID] = session
	s.addAuditLocked("session.created", user.ID, device.ID, "user", clientIP, userAgent, map[string]any{
		"platform": req.Platform,
	}, now)

	if err := s.store.saveLocked(); err != nil {
		return "", nil, effectiveLimit, activeCount, err
	}
	return sessionToken, cloneDevice(device), effectiveLimit, activeCount + boolToInt(isNewActiveDevice), nil
}

func (s *Server) handleUserDevices(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != s.cfg.APIPrefix+"/user/devices" {
		s.handleProxy(w, r)
		return
	}

	ctx, ok := s.requireSession(w, r)
	if !ok {
		return
	}

	switch r.Method {
	case http.MethodGet:
		s.writeUserDevices(w, ctx)
	default:
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
	}
}

func (s *Server) handleUserDeviceByID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
		return
	}

	ctx, ok := s.requireSession(w, r)
	if !ok {
		return
	}

	deviceID := strings.TrimPrefix(r.URL.Path, s.cfg.APIPrefix+"/user/devices/")
	deviceID, _ = url.PathUnescape(strings.Trim(deviceID, "/"))
	if deviceID == "" {
		writeError(w, http.StatusBadRequest, "DEVICE_ID_REQUIRED", "Device id is required", nil)
		return
	}

	now := time.Now().UTC()
	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	device := s.store.Devices[deviceID]
	if device == nil || device.UserID != ctx.User.ID {
		writeError(w, http.StatusNotFound, "DEVICE_NOT_FOUND", "Device not found", nil)
		return
	}

	s.revokeDeviceLocked(device, "user", now)
	s.revokeDeviceSessionsLocked(device.ID, now)
	s.addAuditLocked("device.revoked", ctx.User.ID, device.ID, "user", s.clientIP(r), r.UserAgent(), nil, now)

	if err := s.store.saveLocked(); err != nil {
		writeError(w, http.StatusInternalServerError, "STORE_SAVE_FAILED", "Failed to save store", nil)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Device revoked",
	})
}

func (s *Server) handleHeartbeat(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
		return
	}
	ctx, ok := s.requireSession(w, r)
	if !ok {
		return
	}

	now := time.Now().UTC()
	s.store.mu.Lock()
	// ctx.Device / ctx.Session are copies from authorize(); look up
	// the real store entries by ID so the update actually persists.
	if dev, ok := s.store.Devices[ctx.Device.ID]; ok {
		dev.LastSeenAt = now
	}
	if ses, ok := s.store.Sessions[ctx.Session.ID]; ok {
		ses.LastSeenAt = now
	}
	_ = s.store.saveLocked()
	s.store.mu.Unlock()

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"device": publicDevice(ctx.Device, ctx.Device.ID),
		},
	})
}

func (s *Server) writeUserDevices(w http.ResponseWriter, ctx *SessionContext) {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	devices := s.devicesForUserLocked(ctx.User.ID)
	activeCount := 0
	items := make([]map[string]any, 0, len(devices))
	for _, device := range devices {
		if device.Status == statusActive {
			activeCount++
		}
		pd := publicDevice(device, ctx.Device.ID)
		s.log.Printf("device %s status=%s last_seen=%s is_online=%v age=%v",
			device.ID, device.Status,
			device.LastSeenAt.Format(time.RFC3339),
			pd["is_online"], time.Since(device.LastSeenAt))
		items = append(items, pd)
	}

	sort.Slice(items, func(i, j int) bool {
		return fmt.Sprint(items[i]["last_seen_at"]) > fmt.Sprint(items[j]["last_seen_at"])
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"devices":      items,
			"active_count": activeCount,
			"device_limit": nullableLimit(s.effectiveLimitLocked(ctx.User)),
		},
	})
}

func (s *Server) handleAdmin(w http.ResponseWriter, r *http.Request) {
	if !s.requireAdmin(w, r) {
		return
	}

	adminPrefix := s.cfg.APIPrefix + "/admin"
	path := strings.TrimPrefix(r.URL.Path, adminPrefix)
	path = strings.Trim(path, "/")

	if path == "users" && r.Method == http.MethodGet {
		s.handleAdminListUsers(w, r)
		return
	}
	if path == "audit-logs" && r.Method == http.MethodGet {
		s.handleAdminAuditLogs(w, r)
		return
	}

	parts := strings.Split(path, "/")
	if len(parts) >= 3 && parts[0] == "users" && parts[2] == "devices" {
		userKey, _ := url.PathUnescape(parts[1])
		if len(parts) == 3 && r.Method == http.MethodGet {
			s.handleAdminUserDevices(w, r, userKey)
			return
		}
		if len(parts) == 4 && r.Method == http.MethodDelete {
			deviceID, _ := url.PathUnescape(parts[3])
			s.handleAdminRevokeDevice(w, r, userKey, deviceID)
			return
		}
	}
	if len(parts) == 3 && parts[0] == "users" && parts[2] == "device-limit" && r.Method == http.MethodPatch {
		userKey, _ := url.PathUnescape(parts[1])
		s.handleAdminPatchDeviceLimit(w, r, userKey)
		return
	}

	writeError(w, http.StatusNotFound, "NOT_FOUND", "Admin endpoint not found", nil)
}

func (s *Server) handleAdminListUsers(w http.ResponseWriter, r *http.Request) {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	users := make([]map[string]any, 0, len(s.store.Users))
	for _, user := range s.store.Users {
		activeCount := len(s.activeDevicesLocked(user.ID))
		users = append(users, publicUser(user, s.effectiveLimitLocked(user), activeCount))
	}
	sort.Slice(users, func(i, j int) bool {
		return fmt.Sprint(users[i]["updated_at"]) > fmt.Sprint(users[j]["updated_at"])
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"users": users,
		},
	})
}

func (s *Server) handleAdminUserDevices(w http.ResponseWriter, r *http.Request, userKey string) {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	user := s.findUserLocked(userKey)
	if user == nil {
		writeError(w, http.StatusNotFound, "USER_NOT_FOUND", "User not found", nil)
		return
	}
	devices := s.devicesForUserLocked(user.ID)
	items := make([]map[string]any, 0, len(devices))
	for _, device := range devices {
		items = append(items, publicDevice(device, ""))
	}
	sort.Slice(items, func(i, j int) bool {
		return fmt.Sprint(items[i]["last_seen_at"]) > fmt.Sprint(items[j]["last_seen_at"])
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"user":    publicUser(user, s.effectiveLimitLocked(user), len(s.activeDevicesLocked(user.ID))),
			"devices": items,
		},
	})
}

func (s *Server) handleAdminRevokeDevice(w http.ResponseWriter, r *http.Request, userKey, deviceID string) {
	now := time.Now().UTC()
	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	user := s.findUserLocked(userKey)
	if user == nil {
		writeError(w, http.StatusNotFound, "USER_NOT_FOUND", "User not found", nil)
		return
	}
	device := s.store.Devices[deviceID]
	if device == nil || device.UserID != user.ID {
		writeError(w, http.StatusNotFound, "DEVICE_NOT_FOUND", "Device not found", nil)
		return
	}

	s.revokeDeviceLocked(device, "admin", now)
	s.revokeDeviceSessionsLocked(device.ID, now)
	s.addAuditLocked("device.revoked", user.ID, device.ID, "admin", s.clientIP(r), r.UserAgent(), nil, now)

	if err := s.store.saveLocked(); err != nil {
		writeError(w, http.StatusInternalServerError, "STORE_SAVE_FAILED", "Failed to save store", nil)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "Device revoked",
	})
}

func (s *Server) handleAdminPatchDeviceLimit(w http.ResponseWriter, r *http.Request, userKey string) {
	var payload map[string]json.RawMessage
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_JSON", "Invalid JSON body", nil)
		return
	}

	limit, clear, err := parseDeviceLimitPatch(payload)
	if err != nil {
		writeError(w, http.StatusBadRequest, "BAD_DEVICE_LIMIT", err.Error(), nil)
		return
	}

	now := time.Now().UTC()
	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	user := s.findUserLocked(userKey)
	if user == nil {
		writeError(w, http.StatusNotFound, "USER_NOT_FOUND", "User not found", nil)
		return
	}

	if clear {
		user.DeviceLimitOverride = nil
	} else {
		user.DeviceLimitOverride = &limit
	}
	user.UpdatedAt = now
	s.addAuditLocked("user.device_limit_override.updated", user.ID, "", "admin", s.clientIP(r), r.UserAgent(), map[string]any{
		"device_limit_override": user.DeviceLimitOverride,
	}, now)

	if err := s.store.saveLocked(); err != nil {
		writeError(w, http.StatusInternalServerError, "STORE_SAVE_FAILED", "Failed to save store", nil)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"user": publicUser(user, s.effectiveLimitLocked(user), len(s.activeDevicesLocked(user.ID))),
		},
	})
}

func (s *Server) handleAdminAuditLogs(w http.ResponseWriter, r *http.Request) {
	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	limit := queryInt(r, "limit", 100)
	if limit < 1 || limit > 500 {
		limit = 100
	}
	start := len(s.store.Audits) - limit
	if start < 0 {
		start = 0
	}
	items := append([]AuditLog(nil), s.store.Audits[start:]...)
	sort.Slice(items, func(i, j int) bool {
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"audit_logs": items,
		},
	})
}

func (s *Server) handleProxy(w http.ResponseWriter, r *http.Request) {
	if !strings.HasPrefix(r.URL.Path, s.cfg.APIPrefix+"/") {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "Endpoint not found", nil)
		return
	}
	if r.URL.Path == s.cfg.APIPrefix+"/passport/auth/login" {
		s.handleLogin(w, r)
		return
	}

	if isPublicEndpoint(s.cfg.APIPrefix, r.URL.Path) {
		s.proxyToBusiness(w, r, nil)
		return
	}

	ctx, ok := s.requireSession(w, r)
	if !ok {
		return
	}
	s.proxyToBusiness(w, r, ctx)
}

func (s *Server) proxyToBusiness(w http.ResponseWriter, r *http.Request, sessionCtx *SessionContext) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 32<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, "BODY_READ_FAILED", "Failed to read request body", nil)
		return
	}

	resp, err := s.tryBusinessURLs(r.Context(), func(baseURL string) (*http.Request, error) {
		targetURL, err := s.businessURLFor(baseURL, r.URL.Path, r.URL.RawQuery)
		if err != nil {
			return nil, err
		}
		req, err := http.NewRequestWithContext(r.Context(), r.Method, targetURL, bytes.NewReader(body))
		if err != nil {
			return nil, err
		}
		copyProxyHeaders(req.Header, r.Header)
		if sessionCtx != nil {
			req.Header.Set("Authorization", sessionCtx.BusinessToken)
		} else {
			req.Header.Del("Authorization")
		}
		return req, nil
	})
	if err != nil {
		s.log.Printf("proxy request failed: %v", err)
		writeError(w, http.StatusBadGateway, "BUSINESS_PROXY_FAILED", "Business proxy failed", nil)
		return
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		writeError(w, http.StatusBadGateway, "BUSINESS_BODY_READ_FAILED", "Failed to read business response", nil)
		return
	}

	if sessionCtx != nil && resp.StatusCode >= 200 && resp.StatusCode < 300 && strings.HasSuffix(r.URL.Path, "/user/getSubscribe") {
		respBody = s.rewriteSubscriptionResponse(r, sessionCtx, respBody)
	}

	copyResponseHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(respBody)
}

func (s *Server) requireSession(w http.ResponseWriter, r *http.Request) (*SessionContext, bool) {
	ctx, err := s.authorize(r)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "DEVICE_SESSION_INVALID", "Device session is invalid or expired", nil)
		return nil, false
	}
	return ctx, true
}

func (s *Server) authorize(r *http.Request) (*SessionContext, error) {
	token := bearerToken(r.Header.Get("Authorization"))
	if token == "" {
		return nil, errors.New("missing authorization")
	}
	tokenHash := s.hashValue("session", token)
	now := time.Now().UTC()
	clientIP := s.clientIP(r)
	userAgent := r.UserAgent()

	var sessionCopy SessionRecord
	var deviceCopy DeviceRecord
	var userCopy UserCache
	shouldSave := false

	s.store.mu.Lock()
	for _, session := range s.store.Sessions {
		if session.TokenHash != tokenHash {
			continue
		}
		if session.Status != statusActive || now.After(session.ExpiresAt) {
			if session.Status == statusActive {
				session.Status = statusExpired
				shouldSave = true
			}
			s.store.mu.Unlock()
			if shouldSave {
				_ = s.store.Save()
			}
			return nil, errors.New("session inactive")
		}
		device := s.store.Devices[session.DeviceID]
		user := s.store.Users[session.UserID]
		if device == nil || user == nil || device.Status != statusActive {
			s.store.mu.Unlock()
			return nil, errors.New("device inactive")
		}
		if now.Sub(session.LastSeenAt) > time.Minute {
			session.LastSeenAt = now
			session.LastIP = clientIP
			session.UserAgent = userAgent
			device.LastSeenAt = now
			device.LastIP = clientIP
			device.UserAgent = userAgent
			shouldSave = true
		}
		sessionCopy = *session
		deviceCopy = *device
		userCopy = *user
		break
	}
	if sessionCopy.ID == "" {
		s.store.mu.Unlock()
		return nil, errors.New("session not found")
	}
	if shouldSave {
		if err := s.store.saveLocked(); err != nil {
			s.store.mu.Unlock()
			return nil, err
		}
	}
	s.store.mu.Unlock()

	businessToken, err := decryptString(s.key, sessionCopy.BusinessTokenCipher)
	if err != nil {
		return nil, err
	}
	subscribeToken, err := decryptString(s.key, sessionCopy.SubscribeTokenCipher)
	if err != nil {
		return nil, err
	}

	return &SessionContext{
		User:           &userCopy,
		Device:         &deviceCopy,
		Session:        &sessionCopy,
		BusinessToken:  businessToken,
		SubscribeToken: subscribeToken,
	}, nil
}

func (s *Server) authorizeSubscribeToken(r *http.Request, token string) (*SessionContext, error) {
	tokenHash := s.hashValue("subscribe", token)
	now := time.Now().UTC()
	clientIP := s.clientIP(r)
	userAgent := r.UserAgent()

	var sessionCopy SessionRecord
	var deviceCopy DeviceRecord
	var userCopy UserCache
	shouldSave := false

	s.store.mu.Lock()
	for _, session := range s.store.Sessions {
		if session.SubscribeTokenHash != tokenHash {
			continue
		}
		if session.Status != statusActive || now.After(session.ExpiresAt) {
			if session.Status == statusActive {
				session.Status = statusExpired
				shouldSave = true
			}
			s.store.mu.Unlock()
			if shouldSave {
				_ = s.store.Save()
			}
			return nil, errors.New("session inactive")
		}
		device := s.store.Devices[session.DeviceID]
		user := s.store.Users[session.UserID]
		if device == nil || user == nil || device.Status != statusActive {
			s.store.mu.Unlock()
			return nil, errors.New("device inactive")
		}
		if now.Sub(session.LastSeenAt) > time.Minute {
			session.LastSeenAt = now
			session.LastIP = clientIP
			session.UserAgent = userAgent
			device.LastSeenAt = now
			device.LastIP = clientIP
			device.UserAgent = userAgent
			shouldSave = true
		}
		sessionCopy = *session
		deviceCopy = *device
		userCopy = *user
		break
	}
	if sessionCopy.ID == "" {
		s.store.mu.Unlock()
		return nil, errors.New("session not found")
	}
	if shouldSave {
		if err := s.store.saveLocked(); err != nil {
			s.store.mu.Unlock()
			return nil, err
		}
	}
	s.store.mu.Unlock()

	businessToken, err := decryptString(s.key, sessionCopy.BusinessTokenCipher)
	if err != nil {
		return nil, err
	}

	return &SessionContext{
		User:           &userCopy,
		Device:         &deviceCopy,
		Session:        &sessionCopy,
		BusinessToken:  businessToken,
		SubscribeToken: token,
	}, nil
}

func (s *Server) requireAdmin(w http.ResponseWriter, r *http.Request) bool {
	if s.cfg.AdminToken == "" {
		writeError(w, http.StatusServiceUnavailable, "ADMIN_DISABLED", "Admin API is disabled", nil)
		return false
	}

	token := r.Header.Get("X-Admin-Token")
	if token == "" {
		token = bearerToken(r.Header.Get("Authorization"))
	}
	if !constantTimeEqual(token, s.cfg.AdminToken) {
		writeError(w, http.StatusForbidden, "ADMIN_FORBIDDEN", "Invalid admin token", nil)
		return false
	}
	return true
}

func (s *Server) businessLogin(ctx context.Context, email, password string) (string, map[string]any, error) {
	loginBody := map[string]any{
		"email":    email,
		"password": password,
	}
	raw, _ := json.Marshal(loginBody)
	loginPath := s.cfg.APIPrefix + "/passport/auth/login"

	resp, err := s.tryBusinessURLs(ctx, func(baseURL string) (*http.Request, error) {
		targetURL, err := s.businessURLFor(baseURL, loginPath, "")
		if err != nil {
			return nil, err
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, targetURL, bytes.NewReader(raw))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json")
		return req, nil
	})
	if err != nil {
		return "", nil, err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", nil, err
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", nil, &businessHTTPError{
			status:      resp.StatusCode,
			body:        respBody,
			contentType: resp.Header.Get("Content-Type"),
		}
	}

	var payload map[string]any
	if err := json.Unmarshal(respBody, &payload); err != nil {
		return "", nil, fmt.Errorf("business login response is not JSON: %w", err)
	}

	if success, ok := payload["success"].(bool); ok && !success {
		return "", nil, &businessHTTPError{
			status:      resp.StatusCode,
			body:        respBody,
			contentType: resp.Header.Get("Content-Type"),
		}
	}

	token := extractBusinessToken(payload)
	if token == "" {
		return "", nil, errors.New("business token not found in login response")
	}
	return token, payload, nil
}

func (s *Server) fetchSubscriptionSnapshot(ctx context.Context, businessToken string) (SubscriptionSnapshot, error) {
	subPath := s.cfg.APIPrefix + "/user/getSubscribe"

	resp, err := s.tryBusinessURLs(ctx, func(baseURL string) (*http.Request, error) {
		targetURL, err := s.businessURLFor(baseURL, subPath, "")
		if err != nil {
			return nil, err
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, targetURL, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("Accept", "application/json")
		req.Header.Set("Authorization", businessToken)
		return req, nil
	})
	if err != nil {
		return SubscriptionSnapshot{}, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return SubscriptionSnapshot{}, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return SubscriptionSnapshot{}, fmt.Errorf("business subscription status %d", resp.StatusCode)
	}
	return parseSubscriptionSnapshot(body)
}

func (s *Server) rewriteSubscriptionResponse(r *http.Request, sessionCtx *SessionContext, body []byte) []byte {
	snapshot, err := parseSubscriptionSnapshot(body)
	if err != nil {
		return body
	}

	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return body
	}
	data := mapFromAny(payload["data"])
	if data == nil {
		return body
	}

	now := time.Now().UTC()
	var encryptedSubURL string
	if snapshot.SubscribeURL != "" {
		encryptedSubURL, err = encryptString(s.key, snapshot.SubscribeURL)
		if err != nil {
			return body
		}
	}

	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	user := s.store.Users[sessionCtx.User.ID]
	if user == nil {
		return body
	}
	if snapshot.Email != "" {
		user.Email = snapshot.Email
	}
	if snapshot.UUID != "" {
		user.BusinessUserID = snapshot.UUID
	}
	if snapshot.PlanID > 0 {
		user.PlanID = snapshot.PlanID
	}
	if snapshot.PlanName != "" {
		user.PlanName = snapshot.PlanName
	}
	if snapshot.DeviceLimit != nil {
		user.DeviceLimit = snapshot.DeviceLimit
	}
	user.LastSyncedAt = now
	user.UpdatedAt = now

	if encryptedSubURL != "" {
		if session := s.store.Sessions[sessionCtx.Session.ID]; session != nil {
			session.BusinessSubURLCipher = encryptedSubURL
		}
	}
	_ = s.store.saveLocked()

	if sessionCtx.SubscribeToken != "" {
		data["subscribe_url"] = s.gatewaySubscribeURL(r, sessionCtx.SubscribeToken)
		data["token"] = sessionCtx.SubscribeToken
	}
	if len(s.ossGatewayURLs()) > 0 {
		data["gateway_urls"] = s.ossGatewayURLs()
	}
	rewritten, err := json.Marshal(payload)
	if err != nil {
		return body
	}
	return rewritten
}

func parseSubscriptionSnapshot(body []byte) (SubscriptionSnapshot, error) {
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return SubscriptionSnapshot{}, err
	}
	data := mapFromAny(payload["data"])
	if data == nil {
		return SubscriptionSnapshot{}, errors.New("subscription data not found")
	}

	plan := mapFromAny(data["plan"])
	limit := intPtrFromAny(data["device_limit"])
	if limit == nil && plan != nil {
		limit = intPtrFromAny(plan["device_limit"])
	}

	snapshot := SubscriptionSnapshot{
		Email:          stringFromAny(data["email"]),
		UUID:           stringFromAny(data["uuid"]),
		PlanID:         intFromAny(data["plan_id"]),
		DeviceLimit:    limit,
		SubscribeURL:   stringFromAny(data["subscribe_url"]),
		SubscribeToken: stringFromAny(data["token"]),
	}
	if plan != nil {
		if snapshot.PlanID == 0 {
			snapshot.PlanID = intFromAny(plan["id"])
		}
		snapshot.PlanName = stringFromAny(plan["name"])
	}
	return snapshot, nil
}

func (s *Server) upsertUserLocked(snapshot SubscriptionSnapshot, fallbackEmail string, now time.Time) *UserCache {
	email := snapshot.Email
	if email == "" {
		email = fallbackEmail
	}
	businessID := snapshot.UUID
	if businessID == "" {
		businessID = email
	}

	user := s.findUserLocked(businessID)
	if user == nil && email != "" {
		user = s.findUserLocked(email)
	}
	if user == nil {
		user = &UserCache{
			ID:        "usr_" + stableShortID(s.hashValue("user", strings.ToLower(email))),
			Email:     email,
			CreatedAt: now,
		}
		if user.ID == "usr_" {
			user.ID = "usr_" + randomHex(10)
		}
		s.store.Users[user.ID] = user
	}

	user.Email = email
	user.BusinessUserID = businessID
	user.PlanID = snapshot.PlanID
	user.PlanName = snapshot.PlanName
	if snapshot.DeviceLimit != nil {
		user.DeviceLimit = snapshot.DeviceLimit
	}
	if user.DeviceLimit == nil {
		user.DeviceLimit = intPtr(s.cfg.DefaultDeviceLimit)
	}
	user.LastSyncedAt = now
	user.UpdatedAt = now
	return user
}

func (s *Server) effectiveLimitLocked(user *UserCache) int {
	if user.DeviceLimitOverride != nil {
		return *user.DeviceLimitOverride
	}
	if user.DeviceLimit != nil {
		return *user.DeviceLimit
	}
	return s.cfg.DefaultDeviceLimit
}

func (s *Server) activeDevicesLocked(userID string) []*DeviceRecord {
	devices := make([]*DeviceRecord, 0)
	for _, device := range s.store.Devices {
		if device.UserID == userID && device.Status == statusActive {
			devices = append(devices, device)
		}
	}
	return devices
}

func (s *Server) devicesForUserLocked(userID string) []*DeviceRecord {
	devices := make([]*DeviceRecord, 0)
	for _, device := range s.store.Devices {
		if device.UserID == userID {
			devices = append(devices, device)
		}
	}
	return devices
}

func (s *Server) findDeviceByHashLocked(userID, deviceHash string) *DeviceRecord {
	for _, device := range s.store.Devices {
		if device.UserID == userID && device.DeviceIDHash == deviceHash {
			return device
		}
	}
	return nil
}

func (s *Server) findUserLocked(key string) *UserCache {
	key = strings.TrimSpace(key)
	if key == "" {
		return nil
	}
	if user := s.store.Users[key]; user != nil {
		return user
	}
	lowerKey := strings.ToLower(key)
	for _, user := range s.store.Users {
		if strings.ToLower(user.Email) == lowerKey || user.BusinessUserID == key {
			return user
		}
	}
	return nil
}

func (s *Server) revokeDeviceLocked(device *DeviceRecord, actor string, now time.Time) {
	device.Status = statusRevoked
	device.RevokedAt = &now
	device.RevokedBy = actor
}

func (s *Server) revokeDeviceSessionsLocked(deviceID string, now time.Time) {
	for _, session := range s.store.Sessions {
		if session.DeviceID == deviceID && session.Status == statusActive {
			session.Status = statusRevoked
			session.ExpiresAt = now
		}
	}
}

func (s *Server) addAuditLocked(action, userID, deviceID, actor, ip, userAgent string, details map[string]any, now time.Time) {
	s.store.Audits = append(s.store.Audits, AuditLog{
		ID:        "aud_" + randomHex(12),
		UserID:    userID,
		DeviceID:  deviceID,
		Action:    action,
		Actor:     actor,
		IP:        ip,
		UserAgent: userAgent,
		Details:   details,
		CreatedAt: now,
	})
	if len(s.store.Audits) > 5000 {
		s.store.Audits = s.store.Audits[len(s.store.Audits)-5000:]
	}
}

func (s *Server) businessURLs() []string {
	s.ossMu.RLock()
	defer s.ossMu.RUnlock()
	return s.cfg.BusinessBaseURLs
}

func (s *Server) ossGatewayURLs() []string {
	s.ossMu.RLock()
	defer s.ossMu.RUnlock()
	return s.cfg.GatewayURLs
}

func (s *Server) businessBaseURL() string {
	if urls := s.businessURLs(); len(urls) > 0 {
		return urls[0]
	}
	return ""
}


func (s *Server) businessURLFor(baseURL, path, rawQuery string) (string, error) {
	base, err := url.Parse(baseURL)
	if err != nil {
		return "", err
	}
	base.Path = joinURLPath(base.Path, path)
	base.RawQuery = rawQuery
	return base.String(), nil
}

func (s *Server) businessURL(path, rawQuery string) (string, error) {
	base, err := url.Parse(s.businessBaseURL())
	if err != nil {
		return "", err
	}
	base.Path = joinURLPath(base.Path, path)
	base.RawQuery = rawQuery
	return base.String(), nil
}
// tryBusinessURLs executes a request against every business URL in order
// until one succeeds. makeReq is called with each base URL to construct the
// request; if makeReq returns an error for a given URL, that URL is skipped.
func (s *Server) tryBusinessURLs(ctx context.Context, makeReq func(baseURL string) (*http.Request, error)) (*http.Response, error) {
	const perURLTimeout = 5 * time.Second
	var lastErr error
	urls := s.businessURLs()
	for i, baseURL := range urls {
		req, err := makeReq(baseURL)
		if err != nil {
			lastErr = err
			continue
		}
		urlCtx, cancel := context.WithTimeout(ctx, perURLTimeout)
		req = req.WithContext(urlCtx)
		resp, err := s.client.Do(req)
		cancel()
		if err != nil {
			s.log.Printf("business request to %s failed (%d/%d): %v", baseURL, i+1, len(urls), err)
			lastErr = err
			continue
		}
		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			s.log.Printf("business request to %s returned %d (%d/%d), trying next", baseURL, resp.StatusCode, i+1, len(urls))
			lastErr = &businessHTTPError{
				status:      resp.StatusCode,
				body:        body,
				contentType: resp.Header.Get("Content-Type"),
			}
			continue
		}
		return resp, nil
	}
	if lastErr != nil {
		return nil, lastErr
	}
	return nil, errors.New("no business URLs configured")
}


func (s *Server) businessSubscribeURL(ctx context.Context, sessionCtx *SessionContext) (string, error) {
	if sessionCtx.Session.BusinessSubURLCipher != "" {
		rawURL, err := decryptString(s.key, sessionCtx.Session.BusinessSubURLCipher)
		if err == nil && rawURL != "" {
			return s.absoluteBusinessURL(rawURL)
		}
	}

	snapshot, err := s.fetchSubscriptionSnapshot(ctx, sessionCtx.BusinessToken)
	if err != nil {
		return "", err
	}
	if snapshot.SubscribeURL == "" {
		return "", errors.New("business subscribe_url is empty")
	}

	encryptedSubURL, err := encryptString(s.key, snapshot.SubscribeURL)
	if err == nil {
		s.store.mu.Lock()
		if session := s.store.Sessions[sessionCtx.Session.ID]; session != nil {
			session.BusinessSubURLCipher = encryptedSubURL
			_ = s.store.saveLocked()
		}
		s.store.mu.Unlock()
	}

	return s.absoluteBusinessURL(snapshot.SubscribeURL)
}

func (s *Server) absoluteBusinessURL(rawURL string) (string, error) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	if parsed.IsAbs() {
		return parsed.String(), nil
	}
	base, err := url.Parse(s.businessBaseURL())
	if err != nil {
		return "", err
	}
	base.Path = joinURLPath(base.Path, parsed.Path)
	base.RawQuery = parsed.RawQuery
	return base.String(), nil
}

func (s *Server) gatewaySubscribeURL(r *http.Request, subscribeToken string) string {
	baseURL := s.publicBaseURL(r)
	parsed, err := url.Parse(baseURL)
	if err != nil {
		return ""
	}
	parsed.Path = joinURLPath(parsed.Path, s.cfg.APIPrefix+"/client/subscribe")
	query := parsed.Query()
	query.Set("token", subscribeToken)
	parsed.RawQuery = query.Encode()
	return parsed.String()
}

func (s *Server) publicBaseURL(r *http.Request) string {
	if s.cfg.PublicBaseURL != "" {
		return s.cfg.PublicBaseURL
	}
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	if forwardedProto := r.Header.Get("X-Forwarded-Proto"); forwardedProto != "" {
		scheme = strings.TrimSpace(strings.Split(forwardedProto, ",")[0])
	}
	host := r.Host
	if forwardedHost := r.Header.Get("X-Forwarded-Host"); forwardedHost != "" {
		host = strings.TrimSpace(strings.Split(forwardedHost, ",")[0])
	}
	return scheme + "://" + host
}

func (s *Server) hashValue(scope, value string) string {
	mac := hmac.New(sha256.New, []byte(s.cfg.TokenSecret))
	_, _ = mac.Write([]byte(scope))
	_, _ = mac.Write([]byte{0})
	_, _ = mac.Write([]byte(value))
	return hex.EncodeToString(mac.Sum(nil))
}

func (s *Server) clientIP(r *http.Request) string {
	if s.cfg.TrustForwardedFor {
		if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
			parts := strings.Split(forwarded, ",")
			return strings.TrimSpace(parts[0])
		}
		if realIP := r.Header.Get("X-Real-IP"); realIP != "" {
			return strings.TrimSpace(realIP)
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func LoadStore(path string) (*Store, error) {
	store := &Store{
		path:     path,
		Users:    map[string]*UserCache{},
		Devices:  map[string]*DeviceRecord{},
		Sessions: map[string]*SessionRecord{},
		Audits:   []AuditLog{},
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}

	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		if err := store.Save(); err != nil {
			return nil, err
		}
		return store, nil
	}
	if err != nil {
		return nil, err
	}
	if len(bytes.TrimSpace(data)) == 0 {
		return store, nil
	}
	if err := json.Unmarshal(data, store); err != nil {
		return nil, err
	}
	store.path = path
	if store.Users == nil {
		store.Users = map[string]*UserCache{}
	}
	if store.Devices == nil {
		store.Devices = map[string]*DeviceRecord{}
	}
	if store.Sessions == nil {
		store.Sessions = map[string]*SessionRecord{}
	}
	if store.Audits == nil {
		store.Audits = []AuditLog{}
	}
	return store, nil
}

func (s *Store) Save() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.saveLocked()
}

func (s *Store) saveLocked() error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}

func extractBusinessToken(payload map[string]any) string {
	data := mapFromAny(payload["data"])
	if data != nil {
		if token := stringFromAny(data["auth_data"]); token != "" {
			return token
		}
		if token := stringFromAny(data["token"]); token != "" {
			return token
		}
	}
	if token := stringFromAny(payload["auth_data"]); token != "" {
		return token
	}
	return stringFromAny(payload["token"])
}

func parseDeviceLimitPatch(payload map[string]json.RawMessage) (int, bool, error) {
	raw, ok := payload["device_limit_override"]
	if !ok {
		raw, ok = payload["device_limit"]
	}
	if !ok {
		return 0, false, errors.New("device_limit_override is required")
	}
	if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return 0, true, nil
	}
	var limit int
	if err := json.Unmarshal(raw, &limit); err != nil {
		return 0, false, errors.New("device limit must be an integer or null")
	}
	if limit < 0 {
		return 0, false, errors.New("device limit cannot be negative")
	}
	return limit, false, nil
}

func publicUser(user *UserCache, effectiveLimit, activeCount int) map[string]any {
	return map[string]any{
		"id":                     user.ID,
		"business_user_id":       user.BusinessUserID,
		"email":                  user.Email,
		"plan_id":                user.PlanID,
		"plan_name":              user.PlanName,
		"device_limit":           nullableLimit(valueOrZero(user.DeviceLimit)),
		"device_limit_override":  nullableLimit(valueOrZero(user.DeviceLimitOverride)),
		"effective_device_limit": nullableLimit(effectiveLimit),
		"active_device_count":    activeCount,
		"last_synced_at":         user.LastSyncedAt.Format(time.RFC3339),
		"created_at":             user.CreatedAt.Format(time.RFC3339),
		"updated_at":             user.UpdatedAt.Format(time.RFC3339),
	}
}

func publicDevice(device *DeviceRecord, currentDeviceID string) map[string]any {
	return map[string]any{
		"id":           device.ID,
		"device_name":  device.DeviceName,
		"platform":     device.Platform,
		"app_version":  device.AppVersion,
		"os_version":   device.OSVersion,
		"status":       device.Status,
		"last_seen_at": device.LastSeenAt.Format(time.RFC3339),
		"created_at":   device.CreatedAt.Format(time.RFC3339),
		"revoked_at":   timePtrString(device.RevokedAt),
		"revoked_by":   device.RevokedBy,
		"last_ip":      device.LastIP,
		"is_online":   device.Status == statusActive && time.Since(device.LastSeenAt) < 5*time.Minute,
		"is_current":   currentDeviceID != "" && device.ID == currentDeviceID,
	}
}

func cloneDevice(device *DeviceRecord) *DeviceRecord {
	if device == nil {
		return nil
	}
	copy := *device
	return &copy
}

func oldestDevice(devices []*DeviceRecord) *DeviceRecord {
	if len(devices) == 0 {
		return nil
	}
	oldest := devices[0]
	for _, device := range devices[1:] {
		if device.LastSeenAt.Before(oldest.LastSeenAt) {
			oldest = device
		}
	}
	return oldest
}

func removeDeviceByID(devices []*DeviceRecord, deviceID string) []*DeviceRecord {
	out := devices[:0]
	for _, device := range devices {
		if device.ID != deviceID {
			out = append(out, device)
		}
	}
	return out
}

func isPublicEndpoint(apiPrefix, path string) bool {
	public := []string{
		"/passport/auth/register",
		"/passport/comm/sendEmailVerify",
		"/passport/auth/forget",
		"/guest/comm/config",
	}
	trimmed := strings.TrimPrefix(path, apiPrefix)
	for _, endpoint := range public {
		if trimmed == endpoint {
			return true
		}
	}
	return false
}

func copyProxyHeaders(dst, src http.Header) {
	for name, values := range src {
		canonical := http.CanonicalHeaderKey(name)
		switch canonical {
		case "Host", "Connection", "Content-Length", "Authorization":
			continue
		}
		for _, value := range values {
			dst.Add(name, value)
		}
	}
	if dst.Get("Accept") == "" {
		dst.Set("Accept", "application/json")
	}
}

func copyResponseHeaders(dst, src http.Header) {
	for name, values := range src {
		canonical := http.CanonicalHeaderKey(name)
		switch canonical {
		case "Connection", "Content-Length", "Transfer-Encoding":
			continue
		}
		for _, value := range values {
			dst.Add(name, value)
		}
	}
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeRaw(w http.ResponseWriter, status int, contentType string, body []byte) {
	if contentType == "" {
		contentType = "application/json; charset=utf-8"
	}
	w.Header().Set("Content-Type", contentType)
	w.WriteHeader(status)
	_, _ = w.Write(body)
}

func writeError(w http.ResponseWriter, status int, code, message string, data map[string]any) {
	payload := map[string]any{
		"success": false,
		"code":    code,
		"message": message,
	}
	if data != nil {
		payload["data"] = data
	}
	writeJSON(w, status, payload)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Admin-Token")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func encryptString(key []byte, plaintext string) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	ciphertext := gcm.Seal(nil, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(append(nonce, ciphertext...)), nil
}

func decryptString(key []byte, encoded string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(raw) < gcm.NonceSize() {
		return "", errors.New("ciphertext too short")
	}
	nonce := raw[:gcm.NonceSize()]
	ciphertext := raw[gcm.NonceSize():]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}
	return string(plaintext), nil
}

func deriveKey(secret string) []byte {
	sum := sha256.Sum256([]byte(secret))
	return sum[:]
}

func bearerToken(header string) string {
	header = strings.TrimSpace(header)
	if header == "" {
		return ""
	}
	if strings.HasPrefix(strings.ToLower(header), "bearer ") {
		return strings.TrimSpace(header[7:])
	}
	return header
}

func joinURLPath(basePath, requestPath string) string {
	basePath = strings.TrimRight(basePath, "/")
	requestPath = "/" + strings.TrimLeft(requestPath, "/")
	if basePath == "" {
		return requestPath
	}
	return basePath + requestPath
}

func mergeSubscribeQuery(rawURL string, incoming url.Values) (string, error) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	query := parsed.Query()
	for key, values := range incoming {
		if key == "token" || key == "device_session" || key == "session" {
			continue
		}
		for _, value := range values {
			query.Add(key, value)
		}
	}
	parsed.RawQuery = query.Encode()
	return parsed.String(), nil
}

func mapFromAny(value any) map[string]any {
	if value == nil {
		return nil
	}
	if out, ok := value.(map[string]any); ok {
		return out
	}
	return nil
}

func stringFromAny(value any) string {
	switch v := value.(type) {
	case string:
		return v
	case fmt.Stringer:
		return v.String()
	default:
		return ""
	}
}

func intFromAny(value any) int {
	switch v := value.(type) {
	case int:
		return v
	case int64:
		return int(v)
	case float64:
		return int(v)
	case json.Number:
		i, _ := v.Int64()
		return int(i)
	case string:
		i, _ := strconv.Atoi(v)
		return i
	default:
		return 0
	}
}

func intPtrFromAny(value any) *int {
	if value == nil {
		return nil
	}
	i := intFromAny(value)
	return &i
}

func intPtr(value int) *int {
	return &value
}

func valueOrZero(ptr *int) int {
	if ptr == nil {
		return 0
	}
	return *ptr
}

func nullableLimit(value int) any {
	if value <= 0 {
		return nil
	}
	return value
}

func timePtrString(value *time.Time) any {
	if value == nil {
		return nil
	}
	return value.Format(time.RFC3339)
}

func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func stableShortID(hash string) string {
	if len(hash) <= 20 {
		return hash
	}
	return hash[:20]
}

func randomHex(size int) string {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		panic(err)
	}
	return hex.EncodeToString(buf)
}

func constantTimeEqual(a, b string) bool {
	return hmac.Equal([]byte(a), []byte(b))
}

func queryInt(r *http.Request, key string, fallback int) int {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return value
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func envInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func envBool(key string, fallback bool) bool {
	value := strings.ToLower(strings.TrimSpace(os.Getenv(key)))
	if value == "" {
		return fallback
	}
	return value == "1" || value == "true" || value == "yes"
}

func (s *Server) periodicCleanup() {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()
	for range ticker.C {
		s.cleanupRevokedDevices()
	}
}

func (s *Server) cleanupRevokedDevices() {
	cutoff90 := time.Now().UTC().Add(-90 * 24 * time.Hour)
	cutoff30 := time.Now().UTC().Add(-30 * 24 * time.Hour)
	s.store.mu.Lock()
	defer s.store.mu.Unlock()

	autoRevoked := 0
	now := time.Now().UTC()

	// Auto-revoke active devices offline for more than 30 days
	for _, device := range s.store.Devices {
		if device.Status == statusActive && device.LastSeenAt.Before(cutoff30) {
			s.revokeDeviceLocked(device, "system:auto_offline", now)
			s.revokeDeviceSessionsLocked(device.ID, now)
			s.addAuditLocked("device.revoked", device.UserID, device.ID, "system:auto_offline", "", "", map[string]any{
				"reason": "offline more than 30 days",
			}, now)
			autoRevoked++
		}
	}

	// Physical delete revoked devices older than 90 days
	removed := 0
	for id, device := range s.store.Devices {
		if device.Status == statusRevoked && device.RevokedAt != nil && device.RevokedAt.Before(cutoff90) {
			for sid, session := range s.store.Sessions {
				if session.DeviceID == id {
					delete(s.store.Sessions, sid)
				}
			}
			delete(s.store.Devices, id)
			removed++
		}
	}
	if autoRevoked > 0 || removed > 0 {
		s.log.Printf("cleanup: auto-revoked %d offline devices (>30d), removed %d expired revoked devices (>90d)", autoRevoked, removed)
		_ = s.store.saveLocked()
	}
}
