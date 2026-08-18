package main

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"embed"
	"encoding/base64"
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

	ip2region "github.com/lionsoul2014/ip2region/v1.0/binding/golang/ip2region"
)

const (
	statusActive  = "active"
	statusRevoked = "revoked"
	statusExpired = "expired"

	policyStrict     = "strict"
	policyKickOldest = "kick_oldest"

	adminDefaultPageSize = 30
	adminMaxPageSize     = 100
)

type Config struct {
	ListenAddr               string
	BusinessBaseURLs         []string
	PublicBaseURL            string
	GatewayURLs              []string
	APIPrefix                string
	DataFile                 string
	AdminToken               string
	TokenSecret              string
	SessionTTL               time.Duration
	DevicePolicy             string
	DefaultDeviceLimit       int
	HTTPTimeout              time.Duration
	BusinessFailureThreshold int
	BusinessCircuitBreak     time.Duration
	BusinessHealthInterval   time.Duration
	BusinessRecoverySuccess  int
	BusinessBackupMinHold    time.Duration
	TrustForwardedFor        bool
	IPRegionDB               string
	PostgresDSN              string
}

type Server struct {
	cfg                 Config
	store               *Store
	client              *http.Client
	key                 []byte
	log                 *log.Logger
	ossMu               sync.RWMutex
	backendMu           sync.Mutex
	backendStates       map[string]*BusinessBackendState
	activeBusinessURL   string
	activeBusinessSince time.Time
	ipGeo               *IPRegionResolver
}

type BusinessBackendState struct {
	FailureCount         int
	DisabledUntil        time.Time
	LastSuccessAt        time.Time
	LastFailureAt        time.Time
	RecoverySuccessCount int
}

type BusinessServiceStatus struct {
	Index                   int    `json:"index"`
	Role                    string `json:"role"`
	Address                 string `json:"address"`
	Active                  bool   `json:"active"`
	Status                  string `json:"status"`
	LatencyMS               int64  `json:"latency_ms"`
	StatusCode              int    `json:"status_code,omitempty"`
	FailureReason           string `json:"failure_reason,omitempty"`
	FailureCount            int    `json:"failure_count"`
	RecoverySuccessCount    int    `json:"recovery_success_count"`
	RecoveryRequired        int    `json:"recovery_required"`
	CircuitRemainingSeconds int64  `json:"circuit_remaining_seconds,omitempty"`
	LastSuccessAt           string `json:"last_success_at,omitempty"`
	LastFailureAt           string `json:"last_failure_at,omitempty"`
	CheckedAt               string `json:"checked_at"`
}

type Store struct {
	mu                     sync.RWMutex              `json:"-"`
	path                   string                    `json:"-"`
	pg                     *PostgresStore            `json:"-"`
	sessionByTokenHash     map[string]string         `json:"-"`
	sessionBySubscribeHash map[string]string         `json:"-"`
	dirtyUsers             map[string]struct{}       `json:"-"`
	dirtyDevices           map[string]struct{}       `json:"-"`
	dirtySessions          map[string]struct{}       `json:"-"`
	dirtyAudits            map[string]AuditLog       `json:"-"`
	deletedDevices         map[string]struct{}       `json:"-"`
	deletedSessions        map[string]struct{}       `json:"-"`
	deletedAudits          map[string]struct{}       `json:"-"`
	revision               uint64                    `json:"-"`
	Users                  map[string]*UserCache     `json:"users"`
	Devices                map[string]*DeviceRecord  `json:"devices"`
	Sessions               map[string]*SessionRecord `json:"sessions"`
	Audits                 []AuditLog                `json:"audits"`
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
	LastIPRegion string     `json:"last_ip_region,omitempty"`
	LastIPISP    string     `json:"last_ip_isp,omitempty"`
	UserAgent    string     `json:"user_agent,omitempty"`
}

type IPRegionInfo struct {
	Location string
	ISP      string
}

type IPRegionResolver struct {
	mu sync.Mutex
	db *ip2region.Ip2Region
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
	DeviceLimitSet bool
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

	store, pgClose, err := LoadStore(cfg.DataFile, cfg.PostgresDSN)
	if err != nil {
		logger.Fatal(err)
	}

	server := &Server{
		cfg:   cfg,
		store: store,
		client: &http.Client{
			Timeout: cfg.HTTPTimeout,
			Transport: &http.Transport{
				MaxIdleConns:          256,
				MaxIdleConnsPerHost:   64,
				MaxConnsPerHost:       128,
				IdleConnTimeout:       90 * time.Second,
				TLSHandshakeTimeout:   5 * time.Second,
				ExpectContinueTimeout: time.Second,
				ResponseHeaderTimeout: 5 * time.Second,
			},
		},
		key:           deriveKey(cfg.TokenSecret),
		log:           logger,
		backendStates: make(map[string]*BusinessBackendState),
	}
	server.syncBusinessBackends(cfg.BusinessBaseURLs)
	if cfg.IPRegionDB != "" {
		if resolver, err := NewIPRegionResolver(cfg.IPRegionDB); err != nil {
			logger.Printf("IP region database unavailable (%s): %v", cfg.IPRegionDB, err)
		} else {
			server.ipGeo = resolver
			defer resolver.Close()
			logger.Printf("IP region database loaded: %s", cfg.IPRegionDB)
		}
	}

	logger.Printf("listening on %s, business=%s, api_prefix=%s, data=%s",
		cfg.ListenAddr, cfg.BusinessBaseURLs, cfg.APIPrefix, cfg.DataFile)

	if store.pg != nil {
		defer pgClose()
		syncInterval := envInt("DG_DB_SYNC_SECONDS", 30)
		if syncInterval < 1 {
			syncInterval = 30
		}
		go syncPostgresLoop(store, time.Duration(syncInterval)*time.Second, logger)
	}
	go server.periodicCleanup()
	server.startBusinessRecoveryChecker()

	server.startOSSRefresher(envInt("DG_OSS_REFRESH_MINUTES", 30))
	if err := http.ListenAndServe(cfg.ListenAddr, server.routes()); err != nil {
		logger.Fatal(err)
	}
}

const defaultEmergencyOSSConfigURL = "https://gdhwag-1251796499.cos.ap-guangzhou.myqcloud.com/cat.json"

type ossFetchResult struct {
	domains       []string
	gatewayURLs   []string
	configVersion string
	decrypted     []byte
	source        string
	index         int
	err           error
}

// fetchBusinessBaseURLs resolves the dynamic route bundle using the same
// order as the client: concurrent normal OSS sources, the emergency OSS, then
// the last complete server-side cache.
func fetchBusinessBaseURLs(logger *log.Logger) (domains, gatewayURLs []string) {
	ossURLs := env("DG_OSS_CONFIG_URLS", "")
	xorKey := env("DG_OSS_XOR_KEY", "")
	timeout := envInt("DG_OSS_FETCH_TIMEOUT", 15)
	if timeout < 1 {
		timeout = 5
	}
	client := &http.Client{
		Timeout: time.Duration(timeout) * time.Second,
	}
	cached := loadCachedOSSResult(logger)
	var cachedHealthChannel chan bool
	if cached != nil {
		cachedHealthChannel = make(chan bool, 1)
		go func() {
			cachedHealthChannel <- anyOSSBusinessRouteHealthy(client, cached.domains)
		}()
	}
	cachedHealthKnown := false
	cachedHealthy := false
	waitForCachedHealth := func(wait time.Duration) bool {
		if cached == nil {
			return false
		}
		if cachedHealthKnown {
			return cachedHealthy
		}
		select {
		case cachedHealthy = <-cachedHealthChannel:
			cachedHealthKnown = true
		case <-time.After(wait):
			return false
		}
		return cachedHealthy
	}
	if xorKey == "" {
		logger.Printf("DG_OSS_XOR_KEY not set, skipping OSS fetch")
		if !waitForCachedHealth(5 * time.Second) {
			return nil, nil
		}
		return cached.domains, cached.gatewayURLs
	}

	normalURLs := splitAndNormalizeURLs(ossURLs)
	result := fetchOSSGroup(logger, client, normalURLs, xorKey)
	if result == nil {
		emergencyURL := strings.TrimSpace(env("DG_EMERGENCY_OSS_CONFIG_URL", defaultEmergencyOSSConfigURL))
		if emergencyURL != "" && !containsString(normalURLs, emergencyURL) {
			logger.Printf("normal OSS sources unavailable, trying emergency OSS")
			result = fetchOSSGroup(logger, client, []string{emergencyURL}, xorKey)
		}
	}
	if result == nil {
		if !waitForCachedHealth(5 * time.Second) {
			return nil, nil
		}
		logger.Printf("using complete OSS cache config_version=%s", cached.configVersion)
		return cached.domains, cached.gatewayURLs
	}
	if !anyOSSBusinessRouteHealthy(client, result.domains) {
		logger.Printf("OSS source %s has no reachable business route, keeping complete cache", result.source)
		if !waitForCachedHealth(5 * time.Second) {
			return nil, nil
		}
		return cached.domains, cached.gatewayURLs
	}
	if cached != nil &&
		compareConfigVersions(cached.configVersion, result.configVersion) >= 0 &&
		waitForCachedHealth(time.Second) {
		logger.Printf(
			"OSS config_version=%s is not newer than complete cache=%s, keeping cache",
			result.configVersion,
			cached.configVersion,
		)
		return cached.domains, cached.gatewayURLs
	}
	if cached != nil &&
		compareConfigVersions(cached.configVersion, result.configVersion) >= 0 {
		// Availability wins temporarily when the newer cache route is down, but
		// do not overwrite it with an older/equal version. A later recovery can
		// still restore the intended higher-version route.
		logger.Printf("complete OSS cache is unreachable, temporarily using healthy source=%s without replacing cache", result.source)
		return result.domains, result.gatewayURLs
	}
	persistOSSConfigCache(logger, result.decrypted)
	logger.Printf("OSS resolved source=%s config_version=%s business URLs=%v gateway URLs=%v", result.source, result.configVersion, result.domains, result.gatewayURLs)
	return result.domains, result.gatewayURLs
}

func anyOSSBusinessRouteHealthy(client *http.Client, domains []string) bool {
	if len(domains) == 0 {
		return false
	}
	results := make(chan bool, len(domains))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	prefix := strings.TrimRight(env("DG_API_PREFIX", "/api/v1"), "/")
	for _, domain := range domains {
		go func(baseURL string) {
			target, err := url.Parse(baseURL)
			if err != nil {
				results <- false
				return
			}
			target.Path = joinURLPath(target.Path, prefix+"/guest/comm/config")
			probeCtx, probeCancel := context.WithTimeout(ctx, 5*time.Second)
			defer probeCancel()
			req, err := http.NewRequestWithContext(probeCtx, http.MethodGet, target.String(), nil)
			if err != nil {
				results <- false
				return
			}
			resp, err := client.Do(req)
			if err != nil {
				results <- false
				return
			}
			_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
			_ = resp.Body.Close()
			results <- resp.StatusCode >= 200 && resp.StatusCode < 300
		}(domain)
	}
	for range domains {
		if <-results {
			cancel()
			return true
		}
	}
	return false
}

func fetchOSSGroup(logger *log.Logger, client *http.Client, urls []string, xorKey string) *ossFetchResult {
	if len(urls) == 0 {
		return nil
	}
	results := make(chan ossFetchResult, len(urls))
	for i, rawURL := range urls {
		go func(index int, source string) {
			logger.Printf("OSS fetch [%d/%d]: %s", index+1, len(urls), source)
			body, err := downloadOSS(client, source)
			if err != nil {
				results <- ossFetchResult{source: source, index: index, err: err}
				return
			}
			decrypted, err := xorDecrypt(body, xorKey)
			if err != nil {
				results <- ossFetchResult{source: source, index: index, err: err}
				return
			}
			domains, gatewayURLs, version, err := extractOSSConfig(decrypted)
			results <- ossFetchResult{
				domains: domains, gatewayURLs: gatewayURLs, configVersion: version,
				decrypted: decrypted, source: source, index: index, err: err,
			}
		}(i, rawURL)
	}

	var best *ossFetchResult
	var settlement <-chan time.Time
	for received := 0; received < len(urls); {
		select {
		case result := <-results:
			received++
			if result.err != nil {
				logger.Printf("OSS source %s rejected: %v", result.source, result.err)
				continue
			}
			comparison := 1
			if best != nil {
				comparison = compareConfigVersions(result.configVersion, best.configVersion)
			}
			if best == nil || comparison > 0 || (comparison == 0 && result.index < best.index) {
				copy := result
				best = &copy
			}
			if settlement == nil {
				// Give other healthy mirrors a short window to return a newer
				// config_version, but never wait for every dead source timeout.
				settlement = time.After(500 * time.Millisecond)
			}
		case <-settlement:
			return best
		}
	}
	return best
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
	ossDomainsRE       = regexp.MustCompile(`"domains"\s*:\s*(\[[^\]]*\])`)
	ossGatewayURLsRE   = regexp.MustCompile(`"gateway_urls"\s*:\s*(\[[^\]]*\])`)
	ossConfigVersionRE = regexp.MustCompile(`"config_version"\s*:\s*"?([0-9]+(?:\.[0-9]+)*)"?`)
)

// extractOSSConfig extracts business domains and gateway URLs from the
// OSS remote config. The OSS data is non-standard JSON (anonymous nested
// object), so we use regex to pull out the two arrays directly.
func extractOSSConfig(data []byte) (domains, gatewayURLs []string, configVersion string, err error) {
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
	if m := ossConfigVersionRE.FindSubmatch(data); len(m) >= 2 {
		configVersion = string(m[1])
	}
	if len(domains) == 0 {
		return nil, nil, configVersion, errors.New("OSS config has no valid domains")
	}
	return domains, gatewayURLs, configVersion, nil
}

func compareConfigVersions(left, right string) int {
	if left == right {
		return 0
	}
	if left == "" {
		return -1
	}
	if right == "" {
		return 1
	}
	a := strings.Split(left, ".")
	b := strings.Split(right, ".")
	length := len(a)
	if len(b) > length {
		length = len(b)
	}
	for i := 0; i < length; i++ {
		av, bv := 0, 0
		if i < len(a) {
			av, _ = strconv.Atoi(a[i])
		}
		if i < len(b) {
			bv, _ = strconv.Atoi(b[i])
		}
		if av < bv {
			return -1
		}
		if av > bv {
			return 1
		}
	}
	return 0
}

func ossConfigCachePath() string {
	return env("DG_OSS_CACHE_FILE", "./data/device-gateway-remote-config.json")
}

func persistOSSConfigCache(logger *log.Logger, data []byte) {
	if len(data) == 0 {
		return
	}
	path := ossConfigCachePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		logger.Printf("OSS cache mkdir failed: %v", err)
		return
	}
	temp := path + ".tmp"
	if err := os.WriteFile(temp, data, 0o600); err != nil {
		logger.Printf("OSS cache write failed: %v", err)
		return
	}
	if err := os.Rename(temp, path); err != nil {
		logger.Printf("OSS cache replace failed: %v", err)
	}
}

func loadCachedOSSResult(logger *log.Logger) *ossFetchResult {
	data, err := os.ReadFile(ossConfigCachePath())
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			logger.Printf("OSS cache read failed: %v", err)
		}
		return nil
	}
	domains, gatewayURLs, version, err := extractOSSConfig(data)
	if err != nil {
		logger.Printf("OSS cache invalid: %v", err)
		return nil
	}
	return &ossFetchResult{
		domains:       domains,
		gatewayURLs:   gatewayURLs,
		configVersion: version,
		decrypted:     data,
		source:        "local_cache",
	}
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

	// OSS is the authoritative dynamic route. The environment values are only
	// startup seeds for a brand-new server when both OSS and its complete cache
	// are unavailable.
	baseURLs, ossGatewayURLs := fetchBusinessBaseURLs(logger)
	if len(baseURLs) == 0 {
		if envURLs := env("DG_BUSINESS_BASE_URLS", ""); envURLs != "" {
			baseURLs = splitAndNormalizeURLs(envURLs)
		} else if envURL := strings.TrimRight(env("DG_BUSINESS_BASE_URL", ""), "/"); envURL != "" {
			baseURLs = []string{envURL}
		}
		if len(baseURLs) > 0 {
			logger.Printf("OSS route unavailable, using environment business seed: %v", baseURLs)
		}
	}
	if len(baseURLs) == 0 {
		return Config{}, errors.New("no usable business route from OSS, cache, or environment seed")
	}
	// A gateway should normally set its own public URL. This is only a fallback
	// for deployments which intentionally infer it from the shared OSS bundle.
	if publicBaseURL == "" && len(ossGatewayURLs) > 0 {
		publicBaseURL = ossGatewayURLs[0]
		logger.Printf("using OSS gateway_url as public base: %s", publicBaseURL)
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
		ListenAddr:               env("DG_LISTEN_ADDR", ":8787"),
		BusinessBaseURLs:         baseURLs,
		PublicBaseURL:            publicBaseURL,
		GatewayURLs:              ossGatewayURLs,
		APIPrefix:                apiPrefix,
		DataFile:                 env("DG_DATA_FILE", "./data/device-gateway.json"),
		AdminToken:               adminToken,
		TokenSecret:              tokenSecret,
		SessionTTL:               time.Duration(sessionHours) * time.Hour,
		DevicePolicy:             policy,
		DefaultDeviceLimit:       envInt("DG_DEFAULT_DEVICE_LIMIT", 1),
		HTTPTimeout:              time.Duration(timeoutSeconds) * time.Second,
		BusinessFailureThreshold: envInt("DG_BUSINESS_FAILURE_THRESHOLD", 2),
		BusinessCircuitBreak:     time.Duration(envInt("DG_BUSINESS_CIRCUIT_SECONDS", 90)) * time.Second,
		BusinessHealthInterval:   time.Duration(envInt("DG_BUSINESS_HEALTH_INTERVAL_SECONDS", 30)) * time.Second,
		BusinessRecoverySuccess:  envInt("DG_BUSINESS_RECOVERY_SUCCESSES", 3),
		BusinessBackupMinHold:    time.Duration(envInt("DG_BUSINESS_BACKUP_MIN_HOLD_SECONDS", 180)) * time.Second,
		TrustForwardedFor:        envBool("DG_TRUST_FORWARDED_FOR", false),
		IPRegionDB:               env("DG_IP_REGION_DB", "./data/ip2region.db"),
		PostgresDSN:              env("DG_POSTGRES_DSN", ""),
	}, nil
}

func splitAndNormalizeURLs(raw string) []string {
	result := make([]string, 0)
	seen := make(map[string]struct{})
	for _, item := range strings.Split(raw, ",") {
		item = strings.TrimRight(strings.TrimSpace(item), "/")
		if item == "" {
			continue
		}
		if _, exists := seen[item]; exists {
			continue
		}
		seen[item] = struct{}{}
		result = append(result, item)
	}
	return result
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
	mux.HandleFunc(prefix+"/user/service-status", s.handleServiceStatus)
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
	if env("DG_OSS_XOR_KEY", "") == "" {
		return
	}
	domains, gatewayURLs := fetchBusinessBaseURLs(s.log)
	if len(domains) == 0 {
		s.log.Printf("OSS refresh: no domains returned, keeping current config")
		return
	}
	if !s.anyBusinessBackendHealthy(domains) {
		s.log.Printf("OSS refresh: candidate business routes are unreachable, keeping current config")
		return
	}
	s.ossMu.Lock()
	s.cfg.BusinessBaseURLs = domains
	if len(gatewayURLs) > 0 {
		s.cfg.GatewayURLs = gatewayURLs
	}
	s.ossMu.Unlock()
	s.syncBusinessBackends(domains)
	s.log.Printf("OSS refreshed: business URLs=%v, gateway URLs=%v", domains, gatewayURLs)
}

func (s *Server) anyBusinessBackendHealthy(domains []string) bool {
	if len(domains) == 0 {
		return false
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	results := make(chan bool, len(domains))
	for _, domain := range domains {
		go func(baseURL string) {
			results <- s.probeBusinessBackend(ctx, baseURL)
		}(domain)
	}
	for range domains {
		if <-results {
			cancel()
			return true
		}
	}
	return false
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
		writeError(w, http.StatusBadGateway, "BACKEND_UNAVAILABLE", "配置加载失败，请稍后重试", nil)
		return
	}

	snapshot, err := s.fetchSubscriptionSnapshot(r.Context(), businessToken)
	if err != nil {
		s.log.Printf("subscription sync failed after login, using fallback limit: %v", err)
		snapshot = SubscriptionSnapshot{
			Email:          req.Email,
			DeviceLimit:    intPtr(s.cfg.DefaultDeviceLimit),
			DeviceLimitSet: true,
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
	data["device_policy"] = s.cfg.DevicePolicy
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

type sessionAuthorizationError struct {
	code    string
	message string
}

func (e *sessionAuthorizationError) Error() string { return e.message }

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
	s.updateDeviceIPInfoLocked(device, clientIP)
	device.UserAgent = userAgent
	device.RevokedAt = nil
	device.RevokedBy = ""
	s.store.markDeviceLocked(device.ID)

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
	s.store.indexSessionLocked(session)
	s.store.markSessionLocked(session.ID)
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

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"device":        publicDevice(ctx.Device, ctx.Device.ID),
			"device_policy": s.cfg.DevicePolicy,
		},
	})
}

// handleServiceStatus exposes a read-only, sanitized view of the business
// backends used by this gateway. It is authenticated with the normal device
// session and never returns raw backend URLs or mutates failover state.
func (s *Server) handleServiceStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "Method not allowed", nil)
		return
	}
	if _, ok := s.requireSession(w, r); !ok {
		return
	}

	statuses := s.businessServiceStatuses(r.Context())
	healthyCount := 0
	for _, item := range statuses {
		if item.Status == "healthy" || item.Status == "recovering" {
			healthyCount++
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"checked_at":     time.Now().UTC().Format(time.RFC3339),
			"source_gateway": maskEndpointAddress(s.publicBaseURL(r)),
			"healthy_count":  healthyCount,
			"total_count":    len(statuses),
			"backends":       statuses,
		},
	})
}

func (s *Server) writeUserDevices(w http.ResponseWriter, ctx *SessionContext) {
	s.store.mu.RLock()
	defer s.store.mu.RUnlock()

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
	if path == "dashboard" && r.Method == http.MethodGet {
		s.handleAdminServiceHealth(w, r)
		return
	}
	if path == "service-health" && r.Method == http.MethodGet {
		s.handleAdminServiceHealth(w, r)
		return
	}
	if path == "statistics" && r.Method == http.MethodGet {
		s.handleAdminStatistics(w, r)
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
	page, pageSize := adminPaginationParams(r)
	query := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("q")))
	deviceStatus := strings.TrimSpace(r.URL.Query().Get("device_status"))
	limitMode := strings.TrimSpace(r.URL.Query().Get("limit_mode"))
	sortBy := normalizeAdminUserSort(r.URL.Query().Get("sort"))
	order := normalizeSortOrder(r.URL.Query().Get("order"))

	s.store.mu.RLock()
	defer s.store.mu.RUnlock()

	rows := make([]adminUserRow, 0, len(s.store.Users))
	for _, user := range s.store.Users {
		activeCount := len(s.activeDevicesLocked(user.ID))
		effectiveLimit := s.effectiveLimitLocked(user)
		if !adminUserMatchesFilters(user, activeCount, query, deviceStatus, limitMode) {
			continue
		}
		rows = append(rows, adminUserRow{
			user:           user,
			activeCount:    activeCount,
			effectiveLimit: effectiveLimit,
			public:         publicUser(user, effectiveLimit, activeCount),
		})
	}
	sort.Slice(rows, func(i, j int) bool {
		return compareAdminUsers(rows[i], rows[j], sortBy, order)
	})

	total := len(rows)
	page = clampPage(page, pageSize, total)
	start, end := pageBounds(page, pageSize, total)
	users := make([]map[string]any, 0, end-start)
	for _, row := range rows[start:end] {
		users = append(users, row.public)
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"users":      users,
			"pagination": paginationMeta(page, pageSize, total),
			"filters": map[string]any{
				"q":             query,
				"device_status": deviceStatus,
				"limit_mode":    limitMode,
				"sort":          sortBy,
				"order":         order,
			},
		},
	})
}

func (s *Server) handleAdminStatistics(w http.ResponseWriter, r *http.Request) {
	s.store.mu.RLock()
	now := time.Now().UTC()
	totalUsers := len(s.store.Users)
	totalDevices := len(s.store.Devices)
	activeDevices := 0
	revokedDevices := 0
	onlineDevices := 0
	recentDevices := 0
	provinces := map[string]int{}
	isps := map[string]int{}
	versions := map[string]int{}

	for _, device := range s.store.Devices {
		if device.Status == statusActive {
			activeDevices++
		}
		if device.Status == statusRevoked {
			revokedDevices++
		}
		if device.Status == statusActive && now.Sub(device.LastSeenAt) < 5*time.Minute {
			onlineDevices++
		}
		if device.Status == statusActive && now.Sub(device.LastSeenAt) < 24*time.Hour {
			recentDevices++
		}
		if province := provinceFromRegion(device.LastIPRegion); province != "" {
			provinces[province]++
		}
		if isp := normalizeBucket(device.LastIPISP, "未知运营商"); isp != "" {
			isps[isp]++
		}
		if version := normalizeBucket(device.AppVersion, "未知版本"); version != "" {
			versions[version]++
		}
	}
	s.store.mu.RUnlock()

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"summary": map[string]any{
				"total_users":     totalUsers,
				"total_devices":   totalDevices,
				"active_devices":  activeDevices,
				"revoked_devices": revokedDevices,
				"online_devices":  onlineDevices,
				"recent_devices":  recentDevices,
				"device_policy":   s.cfg.DevicePolicy,
			},
			"activity": map[string]any{
				"online_devices":   onlineDevices,
				"recent_devices":   recentDevices,
				"inactive_devices": maxInt(totalDevices-recentDevices, 0),
			},
			"regions":  distributionBuckets(provinces),
			"isps":     distributionBuckets(isps),
			"versions": distributionBuckets(versions),
		},
	})
}

func (s *Server) handleAdminUserDevices(w http.ResponseWriter, r *http.Request, userKey string) {
	s.store.mu.RLock()
	defer s.store.mu.RUnlock()

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
	s.store.markUserLocked(user.ID)
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
	page, pageSize := adminPaginationParams(r)

	s.store.mu.RLock()
	defer s.store.mu.RUnlock()

	items := append([]AuditLog(nil), s.store.Audits...)
	sort.Slice(items, func(i, j int) bool {
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})
	total := len(items)
	page = clampPage(page, pageSize, total)
	start, end := pageBounds(page, pageSize, total)
	items = items[start:end]

	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data": map[string]any{
			"audit_logs": items,
			"pagination": paginationMeta(page, pageSize, total),
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
		writeError(w, http.StatusBadGateway, "BUSINESS_PROXY_FAILED", "服务暂时不可用，请稍后重试", nil)
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

	if resp.StatusCode >= 500 && !strings.Contains(resp.Header.Get("Content-Type"), "json") {
		if s.log != nil {
			s.log.Printf("business backend error (HTTP %d) for %s", resp.StatusCode, r.URL.Path)
		}
		writeError(w, http.StatusBadGateway, "BACKEND_UNAVAILABLE", "配置加载失败，请稍后重试", nil)
		return
	}

	copyResponseHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = w.Write(respBody)
}

func (s *Server) requireSession(w http.ResponseWriter, r *http.Request) (*SessionContext, bool) {
	ctx, err := s.authorize(r)
	if err != nil {
		var authErr *sessionAuthorizationError
		if errors.As(err, &authErr) {
			writeError(w, http.StatusUnauthorized, authErr.code, authErr.message, nil)
			return nil, false
		}
		writeError(w, http.StatusUnauthorized, "DEVICE_SESSION_INVALID", "Device session is invalid or expired", nil)
		return nil, false
	}
	return ctx, true
}

func (s *Server) authorize(r *http.Request) (*SessionContext, error) {
	return s.authorizeWithReload(r, true)
}

func (s *Server) authorizeWithReload(r *http.Request, allowPostgresReload bool) (*SessionContext, error) {
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
	s.store.initRuntimeStateLocked()
	if sessionID := s.store.sessionByTokenHash[tokenHash]; sessionID != "" {
		if session := s.store.Sessions[sessionID]; session != nil {
			if session.Status != statusActive || now.After(session.ExpiresAt) {
				authErr := s.sessionAuthorizationErrorLocked(session, now)
				if session.Status == statusActive {
					session.Status = statusExpired
					s.store.markSessionLocked(session.ID)
					shouldSave = true
				}
				s.store.mu.Unlock()
				if shouldSave {
					_ = s.store.Save()
				}
				return nil, authErr
			}
			device := s.store.Devices[session.DeviceID]
			user := s.store.Users[session.UserID]
			if device == nil || user == nil || device.Status != statusActive {
				authErr := s.sessionAuthorizationErrorLocked(session, now)
				s.store.mu.Unlock()
				return nil, authErr
			}
			if now.Sub(session.LastSeenAt) > time.Minute {
				session.LastSeenAt = now
				session.LastIP = clientIP
				session.UserAgent = userAgent
				device.LastSeenAt = now
				s.updateDeviceIPInfoLocked(device, clientIP)
				device.UserAgent = userAgent
				s.store.markSessionLocked(session.ID)
				s.store.markDeviceLocked(device.ID)
				shouldSave = true
			}
			sessionCopy = *session
			deviceCopy = *device
			userCopy = *user
		}
	}
	if sessionCopy.ID == "" {
		s.store.mu.Unlock()
		if allowPostgresReload {
			reloaded, err := s.store.reloadFromPostgresOnMiss()
			if err != nil {
				if s.log != nil {
					s.log.Printf("postgres session reload failed: %v", err)
				}
			} else if reloaded {
				return s.authorizeWithReload(r, false)
			}
		}
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

func (s *Server) sessionAuthorizationErrorLocked(session *SessionRecord, now time.Time) error {
	if session.Status == statusRevoked {
		if device := s.store.Devices[session.DeviceID]; device != nil {
			switch device.RevokedBy {
			case "system:kick_oldest":
				return &sessionAuthorizationError{
					code:    "DEVICE_KICKED_BY_NEW_LOGIN",
					message: "This device was signed out because the account logged in on another device",
				}
			case "user", "admin":
				return &sessionAuthorizationError{
					code:    "DEVICE_REVOKED",
					message: "This device has been removed",
				}
			}
		}
	}
	if session.Status == statusExpired || now.After(session.ExpiresAt) {
		return &sessionAuthorizationError{
			code:    "DEVICE_SESSION_EXPIRED",
			message: "Device session has expired",
		}
	}
	return &sessionAuthorizationError{
		code:    "DEVICE_SESSION_INVALID",
		message: "Device session is invalid",
	}
}

func (s *Server) authorizeSubscribeToken(r *http.Request, token string) (*SessionContext, error) {
	return s.authorizeSubscribeTokenWithReload(r, token, true)
}

func (s *Server) authorizeSubscribeTokenWithReload(r *http.Request, token string, allowPostgresReload bool) (*SessionContext, error) {
	tokenHash := s.hashValue("subscribe", token)
	now := time.Now().UTC()
	clientIP := s.clientIP(r)
	userAgent := r.UserAgent()

	var sessionCopy SessionRecord
	var deviceCopy DeviceRecord
	var userCopy UserCache
	shouldSave := false

	s.store.mu.Lock()
	s.store.initRuntimeStateLocked()
	if sessionID := s.store.sessionBySubscribeHash[tokenHash]; sessionID != "" {
		if session := s.store.Sessions[sessionID]; session != nil {
			if session.Status != statusActive || now.After(session.ExpiresAt) {
				if session.Status == statusActive {
					session.Status = statusExpired
					s.store.markSessionLocked(session.ID)
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
				s.updateDeviceIPInfoLocked(device, clientIP)
				device.UserAgent = userAgent
				s.store.markSessionLocked(session.ID)
				s.store.markDeviceLocked(device.ID)
				shouldSave = true
			}
			sessionCopy = *session
			deviceCopy = *device
			userCopy = *user
		}
	}
	if sessionCopy.ID == "" {
		s.store.mu.Unlock()
		if allowPostgresReload {
			reloaded, err := s.store.reloadFromPostgresOnMiss()
			if err != nil {
				if s.log != nil {
					s.log.Printf("postgres subscription session reload failed: %v", err)
				}
			} else if reloaded {
				return s.authorizeSubscribeTokenWithReload(r, token, false)
			}
		}
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

	if resp.StatusCode >= 500 && !strings.Contains(resp.Header.Get("Content-Type"), "json") {
		return "", nil, fmt.Errorf("business backend unavailable (HTTP %d)", resp.StatusCode)
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
	if resp.StatusCode >= 500 {
		return SubscriptionSnapshot{}, fmt.Errorf("business backend unavailable (HTTP %d)", resp.StatusCode)
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
	if snapshot.hasDeviceLimit() {
		user.DeviceLimit = normalizedDeviceLimit(snapshot.DeviceLimit)
	}
	user.LastSyncedAt = now
	user.UpdatedAt = now
	s.store.markUserLocked(user.ID)

	if encryptedSubURL != "" {
		if session := s.store.Sessions[sessionCtx.Session.ID]; session != nil {
			session.BusinessSubURLCipher = encryptedSubURL
			s.store.markSessionLocked(session.ID)
		}
	}
	if err := s.store.saveLocked(); err != nil {
		s.log.Printf("subscription persistence failed: %v", err)
	}

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
	limit, limitSet := subscriptionDeviceLimit(data, plan)

	snapshot := SubscriptionSnapshot{
		Email:          stringFromAny(data["email"]),
		UUID:           stringFromAny(data["uuid"]),
		PlanID:         intFromAny(data["plan_id"]),
		DeviceLimit:    limit,
		DeviceLimitSet: limitSet,
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

// subscriptionDeviceLimit preserves the distinction between an absent limit
// and an explicitly null limit. XBoard uses null (and non-positive values) for
// unlimited devices; an absent field means the gateway default still applies.
func subscriptionDeviceLimit(data, plan map[string]any) (*int, bool) {
	if value, ok := data["device_limit"]; ok {
		return intPtrFromAny(value), true
	}
	if plan != nil {
		if value, ok := plan["device_limit"]; ok {
			return intPtrFromAny(value), true
		}
	}
	return nil, false
}

func (snapshot SubscriptionSnapshot) hasDeviceLimit() bool {
	return snapshot.DeviceLimitSet || snapshot.DeviceLimit != nil
}

func normalizedDeviceLimit(limit *int) *int {
	if limit == nil || *limit <= 0 {
		return intPtr(0)
	}
	return limit
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
	if snapshot.hasDeviceLimit() {
		user.DeviceLimit = normalizedDeviceLimit(snapshot.DeviceLimit)
	}
	if user.DeviceLimit == nil {
		user.DeviceLimit = intPtr(s.cfg.DefaultDeviceLimit)
	}
	user.LastSyncedAt = now
	user.UpdatedAt = now
	s.store.markUserLocked(user.ID)
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
	s.store.markDeviceLocked(device.ID)
}

func (s *Server) revokeDeviceSessionsLocked(deviceID string, now time.Time) {
	for _, session := range s.store.Sessions {
		if session.DeviceID == deviceID && session.Status == statusActive {
			session.Status = statusRevoked
			session.ExpiresAt = now
			s.store.markSessionLocked(session.ID)
		}
	}
}

func (s *Server) addAuditLocked(action, userID, deviceID, actor, ip, userAgent string, details map[string]any, now time.Time) {
	audit := AuditLog{
		ID:        "aud_" + randomHex(12),
		UserID:    userID,
		DeviceID:  deviceID,
		Action:    action,
		Actor:     actor,
		IP:        ip,
		UserAgent: userAgent,
		Details:   details,
		CreatedAt: now,
	}
	s.store.Audits = append(s.store.Audits, audit)
	s.store.markAuditLocked(audit)
	if len(s.store.Audits) > 5000 {
		for _, removed := range s.store.Audits[:len(s.store.Audits)-5000] {
			delete(s.store.dirtyAudits, removed.ID)
			s.store.deletedAudits[removed.ID] = struct{}{}
		}
		s.store.Audits = s.store.Audits[len(s.store.Audits)-5000:]
	}
}

func (s *Server) businessURLs() []string {
	s.ossMu.RLock()
	configured := append([]string(nil), s.cfg.BusinessBaseURLs...)
	s.ossMu.RUnlock()

	s.backendMu.Lock()
	defer s.backendMu.Unlock()
	now := time.Now()
	ordered := make([]string, 0, len(configured))
	if s.activeBusinessURL != "" && containsString(configured, s.activeBusinessURL) {
		if state := s.backendStates[s.activeBusinessURL]; state == nil || !state.DisabledUntil.After(now) {
			ordered = append(ordered, s.activeBusinessURL)
		}
	}
	for _, baseURL := range configured {
		if containsString(ordered, baseURL) {
			continue
		}
		state := s.backendStates[baseURL]
		if state != nil && state.DisabledUntil.After(now) {
			continue
		}
		ordered = append(ordered, baseURL)
	}
	// If every backend is in its cooling period, allow one recovery attempt
	// instead of making the gateway unavailable until a timer expires.
	if len(ordered) == 0 && len(configured) > 0 {
		ordered = append(ordered, configured[0])
	}
	return ordered
}

func containsString(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func (s *Server) syncBusinessBackends(urls []string) {
	s.backendMu.Lock()
	defer s.backendMu.Unlock()
	if s.backendStates == nil {
		s.backendStates = make(map[string]*BusinessBackendState)
	}
	valid := make(map[string]struct{}, len(urls))
	for _, baseURL := range urls {
		valid[baseURL] = struct{}{}
		if s.backendStates[baseURL] == nil {
			s.backendStates[baseURL] = &BusinessBackendState{}
		}
	}
	for baseURL := range s.backendStates {
		if _, ok := valid[baseURL]; !ok {
			delete(s.backendStates, baseURL)
		}
	}
	if !containsString(urls, s.activeBusinessURL) {
		s.activeBusinessURL = ""
	}
}

func (s *Server) markBusinessSuccess(baseURL string) {
	s.backendMu.Lock()
	defer s.backendMu.Unlock()
	if s.backendStates == nil {
		s.backendStates = make(map[string]*BusinessBackendState)
	}
	state := s.backendStates[baseURL]
	if state == nil {
		state = &BusinessBackendState{}
		s.backendStates[baseURL] = state
	}
	state.FailureCount = 0
	state.DisabledUntil = time.Time{}
	state.LastSuccessAt = time.Now()
	state.RecoverySuccessCount = 0
	if s.activeBusinessURL != baseURL {
		s.activeBusinessURL = baseURL
		s.activeBusinessSince = time.Now()
	}
}

func (s *Server) markBusinessFailure(baseURL string) {
	s.backendMu.Lock()
	defer s.backendMu.Unlock()
	if s.backendStates == nil {
		s.backendStates = make(map[string]*BusinessBackendState)
	}
	state := s.backendStates[baseURL]
	if state == nil {
		state = &BusinessBackendState{}
		s.backendStates[baseURL] = state
	}
	state.FailureCount++
	state.RecoverySuccessCount = 0
	state.LastFailureAt = time.Now()
	threshold := s.cfg.BusinessFailureThreshold
	if threshold < 1 {
		threshold = 2
	}
	if state.FailureCount >= threshold {
		cooldown := s.cfg.BusinessCircuitBreak
		if cooldown <= 0 {
			cooldown = 90 * time.Second
		}
		state.DisabledUntil = time.Now().Add(cooldown)
		if s.activeBusinessURL == baseURL {
			s.activeBusinessURL = ""
		}
		if s.log != nil {
			s.log.Printf("business backend %s circuit opened for %s after %d failures", baseURL, cooldown, state.FailureCount)
		}
	}
}

func (s *Server) startBusinessRecoveryChecker() {
	if s.cfg.BusinessHealthInterval <= 0 {
		return
	}
	go func() {
		ticker := time.NewTicker(s.cfg.BusinessHealthInterval)
		defer ticker.Stop()
		for range ticker.C {
			s.checkBusinessRecovery(context.Background())
		}
	}()
}

// checkBusinessRecovery probes only backends with a higher configured
// priority than the current active backend. It never touches in-flight
// requests; after the recovery threshold is met only new requests use the
// recovered backend.
func (s *Server) checkBusinessRecovery(ctx context.Context) {
	s.ossMu.RLock()
	configured := append([]string(nil), s.cfg.BusinessBaseURLs...)
	s.ossMu.RUnlock()
	if len(configured) < 2 {
		return
	}

	s.backendMu.Lock()
	active := s.activeBusinessURL
	activeSince := s.activeBusinessSince
	s.backendMu.Unlock()
	activeIndex := -1
	for i, baseURL := range configured {
		if baseURL == active {
			activeIndex = i
			break
		}
	}
	if activeIndex <= 0 {
		return
	}

	for _, candidate := range configured[:activeIndex] {
		s.backendMu.Lock()
		state := s.backendStates[candidate]
		if state != nil && state.DisabledUntil.After(time.Now()) {
			s.backendMu.Unlock()
			continue
		}
		s.backendMu.Unlock()

		if !s.probeBusinessBackend(ctx, candidate) {
			s.backendMu.Lock()
			if state := s.backendStates[candidate]; state != nil {
				state.RecoverySuccessCount = 0
			}
			s.backendMu.Unlock()
			continue
		}

		s.backendMu.Lock()
		state = s.backendStates[candidate]
		if state == nil {
			state = &BusinessBackendState{}
			s.backendStates[candidate] = state
		}
		state.RecoverySuccessCount++
		requiredSuccesses := s.cfg.BusinessRecoverySuccess
		if requiredSuccesses < 1 {
			requiredSuccesses = 3
		}
		minHold := s.cfg.BusinessBackupMinHold
		ready := state.RecoverySuccessCount >= requiredSuccesses &&
			(activeSince.IsZero() || time.Since(activeSince) >= minHold)
		s.backendMu.Unlock()
		if ready {
			s.markBusinessSuccess(candidate)
			if s.log != nil {
				s.log.Printf("business backend automatically failed back to %s", candidate)
			}
			return
		}
		// Only the highest-priority reachable candidate needs recovery votes.
		return
	}
}

func (s *Server) probeBusinessBackend(ctx context.Context, baseURL string) bool {
	targetURL, err := s.businessURLFor(baseURL, s.cfg.APIPrefix+"/guest/comm/config", "")
	if err != nil {
		return false
	}
	timeout := 5 * time.Second
	if s.cfg.BusinessHealthInterval > 0 && s.cfg.BusinessHealthInterval < timeout {
		timeout = s.cfg.BusinessHealthInterval
	}
	probeCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(probeCtx, http.MethodGet, targetURL, nil)
	if err != nil {
		return false
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
	return resp.StatusCode >= 200 && resp.StatusCode < 300
}

func (s *Server) businessServiceStatuses(ctx context.Context) []BusinessServiceStatus {
	return s.businessServiceStatusesWithAddress(ctx, true)
}

func (s *Server) adminBusinessServiceStatuses(ctx context.Context) []BusinessServiceStatus {
	return s.businessServiceStatusesWithAddress(ctx, false)
}

func (s *Server) businessServiceStatusesWithAddress(ctx context.Context, maskAddress bool) []BusinessServiceStatus {
	s.ossMu.RLock()
	configured := append([]string(nil), s.cfg.BusinessBaseURLs...)
	s.ossMu.RUnlock()
	if len(configured) == 0 {
		return []BusinessServiceStatus{}
	}

	now := time.Now()
	s.backendMu.Lock()
	active := s.activeBusinessURL
	if active == "" {
		active = configured[0]
	}
	states := make(map[string]BusinessBackendState, len(s.backendStates))
	for baseURL, state := range s.backendStates {
		if state != nil {
			states[baseURL] = *state
		}
	}
	s.backendMu.Unlock()
	recoveryRequired := s.cfg.BusinessRecoverySuccess
	if recoveryRequired < 1 {
		recoveryRequired = 3
	}

	results := make(chan BusinessServiceStatus, len(configured))
	for index, baseURL := range configured {
		go func(index int, baseURL string) {
			state := states[baseURL]
			status, latency, statusCode, reason := s.probeBusinessBackendStatus(ctx, baseURL)
			if status == "healthy" && !state.DisabledUntil.IsZero() && state.DisabledUntil.After(now) {
				status = "recovering"
			} else if status == "healthy" && state.RecoverySuccessCount > 0 && baseURL != active {
				status = "recovering"
			} else if status != "healthy" && !state.DisabledUntil.IsZero() && state.DisabledUntil.After(now) {
				status = "circuit_open"
			}
			remaining := int64(0)
			if state.DisabledUntil.After(now) {
				remaining = int64(time.Until(state.DisabledUntil).Seconds())
				if remaining < 1 {
					remaining = 1
				}
			}
			address := baseURL
			if maskAddress {
				address = maskEndpointAddress(baseURL)
			}
			item := BusinessServiceStatus{
				Index:                   index + 1,
				Role:                    map[bool]string{true: "primary", false: "backup"}[index == 0],
				Address:                 address,
				Active:                  baseURL == active,
				Status:                  status,
				LatencyMS:               latency,
				StatusCode:              statusCode,
				FailureReason:           reason,
				FailureCount:            state.FailureCount,
				RecoverySuccessCount:    state.RecoverySuccessCount,
				RecoveryRequired:        recoveryRequired,
				CircuitRemainingSeconds: remaining,
				CheckedAt:               time.Now().UTC().Format(time.RFC3339),
			}
			if !state.LastSuccessAt.IsZero() {
				item.LastSuccessAt = state.LastSuccessAt.UTC().Format(time.RFC3339)
			}
			if !state.LastFailureAt.IsZero() {
				item.LastFailureAt = state.LastFailureAt.UTC().Format(time.RFC3339)
			}
			results <- item
		}(index, baseURL)
	}

	statuses := make([]BusinessServiceStatus, 0, len(configured))
	for range configured {
		statuses = append(statuses, <-results)
	}
	sort.Slice(statuses, func(i, j int) bool { return statuses[i].Index < statuses[j].Index })
	return statuses
}

func (s *Server) probeBusinessBackendStatus(ctx context.Context, baseURL string) (status string, latencyMS int64, statusCode int, reason string) {
	targetURL, err := s.businessURLFor(baseURL, s.cfg.APIPrefix+"/guest/comm/config", "")
	if err != nil {
		return "unreachable", 0, 0, "configuration"
	}
	probeCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(probeCtx, http.MethodGet, targetURL, nil)
	if err != nil {
		return "unreachable", 0, 0, "configuration"
	}
	started := time.Now()
	client := s.client
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(req)
	latencyMS = time.Since(started).Milliseconds()
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(probeCtx.Err(), context.DeadlineExceeded) {
			return "timeout", latencyMS, 0, "timeout"
		}
		var networkError net.Error
		if errors.As(err, &networkError) && networkError.Timeout() {
			return "timeout", latencyMS, 0, "timeout"
		}
		return "unreachable", latencyMS, 0, "connection"
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return "healthy", latencyMS, resp.StatusCode, ""
	}
	if resp.StatusCode >= 500 {
		return "service_error", latencyMS, resp.StatusCode, "server"
	}
	return "unavailable", latencyMS, resp.StatusCode, "http"
}

func maskEndpointAddress(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	hasScheme := strings.Contains(raw, "://")
	parseTarget := raw
	if !hasScheme {
		parseTarget = "https://" + raw
	}
	parsed, err := url.Parse(parseTarget)
	if err != nil || parsed.Hostname() == "" {
		return "[redacted-endpoint]"
	}
	prefix := ""
	if hasScheme {
		prefix = parsed.Scheme + "://"
	}
	host := maskEndpointHost(parsed.Hostname())
	port := parsed.Port()
	if port != "" {
		port = ":" + maskEndpointPort(port)
	}
	return prefix + host + port
}

func maskEndpointHost(host string) string {
	if ip := net.ParseIP(host); ip != nil {
		if ipv4 := ip.To4(); ipv4 != nil {
			parts := strings.Split(ipv4.String(), ".")
			return parts[0] + ".***.***." + parts[3]
		}
		return "[redacted-ipv6]"
	}
	parts := strings.Split(host, ".")
	for index, part := range parts {
		if len(part) == 0 {
			parts[index] = "*"
		} else if len(part) == 1 {
			parts[index] = "*"
		} else if len(part) == 2 {
			parts[index] = part[:1] + "*"
		} else {
			parts[index] = part[:1] + strings.Repeat("*", len(part)-2) + part[len(part)-1:]
		}
	}
	return strings.Join(parts, ".")
}

func maskEndpointPort(port string) string {
	if len(port) == 0 {
		return "*"
	}
	if len(port) == 1 {
		return "*"
	}
	if len(port) == 2 {
		return port[:1] + "*"
	}
	return port[:1] + strings.Repeat("*", len(port)-2) + port[len(port)-1:]
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

// tryBusinessURLs executes a request against every business URL in order until
// a backend sends any HTTP response. Non-2xx statuses are still real backend
// responses and must be preserved so clients can display the business error
// payload instead of a gateway-level proxy failure.
func (s *Server) tryBusinessURLs(ctx context.Context, makeReq func(baseURL string) (*http.Request, error)) (*http.Response, error) {
	var lastErr error
	urls := s.businessURLs()
	for i, baseURL := range urls {
		req, err := makeReq(baseURL)
		if err != nil {
			lastErr = err
			continue
		}
		resp, err := s.client.Do(req)
		if err != nil {
			s.markBusinessFailure(baseURL)
			s.log.Printf("business request to %s failed (%d/%d): %v", baseURL, i+1, len(urls), err)
			lastErr = err
			// Once a state-changing request may have reached the backend, replaying
			// it elsewhere can create duplicate orders or payments. Login and
			// read-only requests are explicitly safe to fail over.
			if i+1 < len(urls) && safeBusinessRetry(req) {
				continue
			}
			return nil, err
		}
		// A reachable reverse proxy may still return 5xx while another business
		// backend is healthy. Retry only requests that are safe to repeat; avoid
		// duplicating state-changing operations such as orders and payments.
		if resp.StatusCode >= 500 {
			s.markBusinessFailure(baseURL)
		}
		if resp.StatusCode >= 500 && i+1 < len(urls) && safeBusinessRetry(req) {
			_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
			_ = resp.Body.Close()
			s.log.Printf("business request to %s returned HTTP %d (%d/%d), trying next backend", baseURL, resp.StatusCode, i+1, len(urls))
			lastErr = fmt.Errorf("business backend %s returned HTTP %d", baseURL, resp.StatusCode)
			continue
		}
		if resp.StatusCode < 500 {
			s.markBusinessSuccess(baseURL)
		}
		return resp, nil
	}
	if lastErr != nil {
		return nil, lastErr
	}
	return nil, errors.New("no business URLs configured")
}

func safeBusinessRetry(req *http.Request) bool {
	if req == nil {
		return false
	}
	switch req.Method {
	case http.MethodGet, http.MethodHead, http.MethodOptions:
		return true
	case http.MethodPost:
		return strings.HasSuffix(req.URL.Path, "/passport/auth/login")
	default:
		return false
	}
}

func (s *Server) probeBusinessBackends(ctx context.Context) map[string]any {
	urls := s.businessURLs()
	results := make([]map[string]any, 0, len(urls))
	overall := "offline"
	loginPath := s.cfg.APIPrefix + "/passport/auth/login"

	for _, baseURL := range urls {
		item := map[string]any{
			"url":    baseURL,
			"status": "offline",
		}
		targetURL, err := s.businessURLFor(baseURL, loginPath, "")
		if err != nil {
			item["error"] = err.Error()
			results = append(results, item)
			continue
		}
		reqCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		req, err := http.NewRequestWithContext(reqCtx, http.MethodPost, targetURL, strings.NewReader("{}"))
		if err != nil {
			cancel()
			item["error"] = err.Error()
			results = append(results, item)
			continue
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json")
		resp, err := s.client.Do(req)
		cancel()
		if err != nil {
			item["error"] = err.Error()
			results = append(results, item)
			continue
		}
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		_ = resp.Body.Close()
		item["status_code"] = resp.StatusCode
		if resp.StatusCode >= 500 {
			item["status"] = "error"
			if overall != "online" {
				overall = "error"
			}
		} else {
			item["status"] = "online"
			overall = "online"
		}
		results = append(results, item)
	}

	if len(urls) == 0 {
		overall = "unknown"
	}
	return map[string]any{
		"status":   overall,
		"backends": results,
	}
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
			s.store.markSessionLocked(session.ID)
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
		if cloudflareIP := cleanPublicIP(r.Header.Get("CF-Connecting-IP")); cloudflareIP != "" {
			return cloudflareIP
		}
		if forwardedIP := firstPublicIP(r.Header.Get("X-Forwarded-For")); forwardedIP != "" {
			return forwardedIP
		}
		if realIP := cleanPublicIP(r.Header.Get("X-Real-IP")); realIP != "" {
			return realIP
		}
	}
	return remoteHost(r.RemoteAddr)
}

func firstPublicIP(headerValue string) string {
	for _, part := range strings.Split(headerValue, ",") {
		if ip := cleanPublicIP(part); ip != "" {
			return ip
		}
	}
	return ""
}

func cleanPublicIP(raw string) string {
	host := remoteHost(strings.TrimSpace(raw))
	ip := net.ParseIP(host)
	if ip == nil || !isPublicIP(ip) {
		return ""
	}
	return host
}

func remoteHost(raw string) string {
	if raw == "" {
		return ""
	}
	host, _, err := net.SplitHostPort(raw)
	if err == nil {
		return strings.Trim(host, "[]")
	}
	return strings.Trim(raw, "[]")
}

func isPublicIP(ip net.IP) bool {
	return !ip.IsLoopback() &&
		!ip.IsPrivate() &&
		!ip.IsUnspecified() &&
		!ip.IsMulticast() &&
		!ip.IsLinkLocalUnicast() &&
		!ip.IsLinkLocalMulticast()
}

func NewIPRegionResolver(dbPath string) (*IPRegionResolver, error) {
	dbPath = strings.TrimSpace(dbPath)
	if dbPath == "" {
		return nil, errors.New("empty IP region database path")
	}
	db, err := ip2region.New(dbPath)
	if err != nil {
		return nil, err
	}
	return &IPRegionResolver{db: db}, nil
}

func (r *IPRegionResolver) Close() {
	if r == nil || r.db == nil {
		return
	}
	r.db.Close()
}

func (r *IPRegionResolver) Lookup(ip string) (IPRegionInfo, bool) {
	if r == nil || r.db == nil || net.ParseIP(ip).To4() == nil {
		return IPRegionInfo{}, false
	}
	r.mu.Lock()
	info, err := r.db.MemorySearch(ip)
	r.mu.Unlock()
	if err != nil {
		return IPRegionInfo{}, false
	}
	region := regionInfoFromIP2Region(info)
	return region, region.Location != "" || region.ISP != ""
}

func regionInfoFromIP2Region(info ip2region.IpInfo) IPRegionInfo {
	locationParts := cleanRegionParts(info.Country, info.Province, info.City)
	if len(locationParts) == 0 {
		locationParts = cleanRegionParts(info.Country, info.Region)
	}
	return IPRegionInfo{
		Location: strings.Join(locationParts, " "),
		ISP:      cleanRegionPart(info.ISP),
	}
}

func cleanRegionParts(parts ...string) []string {
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		if clean := cleanRegionPart(part); clean != "" {
			out = append(out, clean)
		}
	}
	return out
}

func cleanRegionPart(value string) string {
	value = strings.TrimSpace(value)
	if value == "" || value == "0" {
		return ""
	}
	return value
}

func (s *Server) updateDeviceIPInfoLocked(device *DeviceRecord, ip string) {
	if device == nil {
		return
	}
	ip = strings.TrimSpace(ip)
	if ip == "" {
		device.LastIP = ""
		device.LastIPRegion = ""
		device.LastIPISP = ""
		return
	}
	if device.LastIP == ip && (device.LastIPRegion != "" || device.LastIPISP != "") {
		return
	}
	device.LastIP = ip
	if region, ok := s.ipGeo.Lookup(ip); ok {
		device.LastIPRegion = region.Location
		device.LastIPISP = region.ISP
		return
	}
	device.LastIPRegion = ""
	device.LastIPISP = ""
}

// loadFromFile reads the local JSON data file into the store.
// Returns nil if the file does not exist (fresh start).
func loadFromFile(s *Store) error {
	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return err
	}
	data, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if len(bytes.TrimSpace(data)) == 0 {
		return nil
	}
	if err := json.Unmarshal(data, s); err != nil {
		return err
	}
	if s.Users == nil {
		s.Users = map[string]*UserCache{}
	}
	if s.Devices == nil {
		s.Devices = map[string]*DeviceRecord{}
	}
	if s.Sessions == nil {
		s.Sessions = map[string]*SessionRecord{}
	}
	if s.Audits == nil {
		s.Audits = []AuditLog{}
	}
	return nil
}
func (s *Store) initRuntimeStateLocked() {
	if s.sessionByTokenHash == nil {
		s.sessionByTokenHash = make(map[string]string, len(s.Sessions))
	}
	if s.sessionBySubscribeHash == nil {
		s.sessionBySubscribeHash = make(map[string]string, len(s.Sessions))
	}
	if s.dirtyUsers == nil {
		s.dirtyUsers = map[string]struct{}{}
	}
	if s.dirtyDevices == nil {
		s.dirtyDevices = map[string]struct{}{}
	}
	if s.dirtySessions == nil {
		s.dirtySessions = map[string]struct{}{}
	}
	if s.dirtyAudits == nil {
		s.dirtyAudits = map[string]AuditLog{}
	}
	if s.deletedDevices == nil {
		s.deletedDevices = map[string]struct{}{}
	}
	if s.deletedSessions == nil {
		s.deletedSessions = map[string]struct{}{}
	}
	if s.deletedAudits == nil {
		s.deletedAudits = map[string]struct{}{}
	}
}

func (s *Store) rebuildSessionIndexesLocked() {
	s.sessionByTokenHash = make(map[string]string, len(s.Sessions))
	s.sessionBySubscribeHash = make(map[string]string, len(s.Sessions))
	for id, session := range s.Sessions {
		if session.TokenHash != "" {
			s.sessionByTokenHash[session.TokenHash] = id
		}
		if session.SubscribeTokenHash != "" {
			s.sessionBySubscribeHash[session.SubscribeTokenHash] = id
		}
	}
}

func (s *Store) indexSessionLocked(session *SessionRecord) {
	s.initRuntimeStateLocked()
	if session.TokenHash != "" {
		s.sessionByTokenHash[session.TokenHash] = session.ID
	}
	if session.SubscribeTokenHash != "" {
		s.sessionBySubscribeHash[session.SubscribeTokenHash] = session.ID
	}
}

func (s *Store) markUserLocked(id string) {
	s.initRuntimeStateLocked()
	s.dirtyUsers[id] = struct{}{}
	s.revision++
}

func (s *Store) markDeviceLocked(id string) {
	s.initRuntimeStateLocked()
	delete(s.deletedDevices, id)
	s.dirtyDevices[id] = struct{}{}
	s.revision++
}

func (s *Store) markSessionLocked(id string) {
	s.initRuntimeStateLocked()
	delete(s.deletedSessions, id)
	s.dirtySessions[id] = struct{}{}
	s.revision++
}

func (s *Store) markAuditLocked(audit AuditLog) {
	s.initRuntimeStateLocked()
	delete(s.deletedAudits, audit.ID)
	s.dirtyAudits[audit.ID] = audit
	s.revision++
}

func (s *Store) deleteDeviceLocked(id string) {
	s.initRuntimeStateLocked()
	delete(s.dirtyDevices, id)
	s.deletedDevices[id] = struct{}{}
	delete(s.Devices, id)
	s.revision++
}

func (s *Store) deleteSessionLocked(id string) {
	s.initRuntimeStateLocked()
	if session := s.Sessions[id]; session != nil {
		delete(s.sessionByTokenHash, session.TokenHash)
		delete(s.sessionBySubscribeHash, session.SubscribeTokenHash)
	}
	delete(s.dirtySessions, id)
	s.deletedSessions[id] = struct{}{}
	delete(s.Sessions, id)
	s.revision++
}

func keysOf(values map[string]struct{}) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	return keys
}

func (s *Store) postgresChangesLocked() PostgresChanges {
	s.initRuntimeStateLocked()
	changes := PostgresChanges{
		Users:           make(map[string]*UserCache, len(s.dirtyUsers)),
		Devices:         make(map[string]*DeviceRecord, len(s.dirtyDevices)),
		Sessions:        make(map[string]*SessionRecord, len(s.dirtySessions)),
		Audits:          make(map[string]AuditLog, len(s.dirtyAudits)),
		DeletedDevices:  keysOf(s.deletedDevices),
		DeletedSessions: keysOf(s.deletedSessions),
		DeletedAudits:   keysOf(s.deletedAudits),
	}
	for id := range s.dirtyUsers {
		if record := s.Users[id]; record != nil {
			changes.Users[id] = record
		}
	}
	for id := range s.dirtyDevices {
		if record := s.Devices[id]; record != nil {
			changes.Devices[id] = record
		}
	}
	for id := range s.dirtySessions {
		if record := s.Sessions[id]; record != nil {
			changes.Sessions[id] = record
		}
	}
	for id, record := range s.dirtyAudits {
		changes.Audits[id] = record
	}
	return changes
}

func (s *Store) clearDirtyLocked() {
	s.dirtyUsers = map[string]struct{}{}
	s.dirtyDevices = map[string]struct{}{}
	s.dirtySessions = map[string]struct{}{}
	s.dirtyAudits = map[string]AuditLog{}
	s.deletedDevices = map[string]struct{}{}
	s.deletedSessions = map[string]struct{}{}
	s.deletedAudits = map[string]struct{}{}
}

func (s *Store) hasPendingChangesLocked() bool {
	s.initRuntimeStateLocked()
	return len(s.dirtyUsers) > 0 || len(s.dirtyDevices) > 0 ||
		len(s.dirtySessions) > 0 || len(s.dirtyAudits) > 0 ||
		len(s.deletedDevices) > 0 || len(s.deletedSessions) > 0 ||
		len(s.deletedAudits) > 0
}

// reloadFromPostgresOnMiss makes a session created by another gateway
// immediately visible. The regular sync loop remains the inexpensive steady
// state path; this reload runs only after a local session-index miss.
func (s *Store) reloadFromPostgresOnMiss() (bool, error) {
	s.mu.Lock()
	pg := s.pg
	startRevision := s.revision
	hasPendingChanges := s.hasPendingChangesLocked()
	s.mu.Unlock()
	if pg == nil || hasPendingChanges {
		return false, nil
	}

	fresh := &Store{
		Users:    map[string]*UserCache{},
		Devices:  map[string]*DeviceRecord{},
		Sessions: map[string]*SessionRecord{},
		Audits:   []AuditLog{},
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	err := pg.LoadAll(ctx, fresh)
	cancel()
	if err != nil {
		return false, err
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	if s.revision != startRevision || s.hasPendingChangesLocked() {
		return false, nil
	}
	s.Users = fresh.Users
	s.Devices = fresh.Devices
	s.Sessions = fresh.Sessions
	s.Audits = fresh.Audits
	s.rebuildSessionIndexesLocked()
	return true, nil
}

func LoadStore(path, pgDSN string) (*Store, func(), error) {
	store := &Store{
		path:     path,
		Users:    map[string]*UserCache{},
		Devices:  map[string]*DeviceRecord{},
		Sessions: map[string]*SessionRecord{},
		Audits:   []AuditLog{},
	}

	if pgDSN != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		pg, err := NewPostgresStore(ctx, pgDSN)
		if err != nil {
			return nil, nil, fmt.Errorf("postgres init: %w", err)
		}
		store.pg = pg
		if err := pg.LoadAll(ctx, store); err != nil {
			return nil, nil, fmt.Errorf("postgres load: %w", err)
		}
		if len(store.Users) == 0 {
			if err := loadFromFile(store); err == nil && len(store.Users) > 0 {
				if err := pg.SaveAll(context.Background(), store); err != nil {
					return nil, nil, fmt.Errorf("postgres migration save: %w", err)
				}
			}
		}
		store.initRuntimeStateLocked()
		store.rebuildSessionIndexesLocked()
		return store, func() { pg.Close() }, nil
	}

	if err := loadFromFile(store); err != nil {
		return nil, nil, err
	}
	store.initRuntimeStateLocked()
	store.rebuildSessionIndexesLocked()
	return store, nil, nil
}

func (s *Store) Save() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.saveLocked()
}

func (s *Store) saveLocked() error {
	if s.pg != nil {
		changes := s.postgresChangesLocked()
		if changes.Empty() {
			return nil
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := s.pg.SaveChanges(ctx, changes); err != nil {
			return err
		}
		s.clearDirtyLocked()
		return nil
	}
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
		"id":             device.ID,
		"device_name":    device.DeviceName,
		"platform":       device.Platform,
		"app_version":    device.AppVersion,
		"os_version":     device.OSVersion,
		"status":         device.Status,
		"last_seen_at":   device.LastSeenAt.Format(time.RFC3339),
		"created_at":     device.CreatedAt.Format(time.RFC3339),
		"revoked_at":     timePtrString(device.RevokedAt),
		"revoked_by":     device.RevokedBy,
		"last_ip":        device.LastIP,
		"last_ip_region": device.LastIPRegion,
		"last_ip_isp":    device.LastIPISP,
		"is_online":      device.Status == statusActive && time.Since(device.LastSeenAt) < 5*time.Minute,
		"is_current":     currentDeviceID != "" && device.ID == currentDeviceID,
	}
}

func distributionBuckets(counts map[string]int) []map[string]any {
	total := 0
	for _, count := range counts {
		total += count
	}
	items := make([]map[string]any, 0, len(counts))
	for name, count := range counts {
		percent := 0.0
		if total > 0 {
			percent = float64(count) * 100 / float64(total)
		}
		items = append(items, map[string]any{
			"name":    name,
			"count":   count,
			"percent": percent,
		})
	}
	sort.Slice(items, func(i, j int) bool {
		ci, _ := items[i]["count"].(int)
		cj, _ := items[j]["count"].(int)
		if ci == cj {
			return fmt.Sprint(items[i]["name"]) < fmt.Sprint(items[j]["name"])
		}
		return ci > cj
	})
	return items
}

func provinceFromRegion(region string) string {
	region = strings.TrimSpace(region)
	if region == "" {
		return ""
	}
	parts := strings.Fields(region)
	if len(parts) >= 2 && parts[0] == "中国" {
		return parts[1]
	}
	if len(parts) > 0 {
		return parts[0]
	}
	return ""
}

func normalizeBucket(value, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" || value == "0" {
		return fallback
	}
	return value
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
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

type adminUserRow struct {
	user           *UserCache
	activeCount    int
	effectiveLimit int
	public         map[string]any
}

func adminPaginationParams(r *http.Request) (int, int) {
	page := queryInt(r, "page", 1)
	if page < 1 {
		page = 1
	}
	pageSize := queryInt(r, "page_size", adminDefaultPageSize)
	if pageSize < 1 {
		pageSize = adminDefaultPageSize
	}
	if pageSize > adminMaxPageSize {
		pageSize = adminMaxPageSize
	}
	return page, pageSize
}

func clampPage(page, pageSize, total int) int {
	if total <= 0 {
		return 1
	}
	totalPages := (total + pageSize - 1) / pageSize
	if page > totalPages {
		return totalPages
	}
	return page
}

func pageBounds(page, pageSize, total int) (int, int) {
	if total <= 0 {
		return 0, 0
	}
	start := (page - 1) * pageSize
	if start >= total {
		return total, total
	}
	end := start + pageSize
	if end > total {
		end = total
	}
	return start, end
}

func paginationMeta(page, pageSize, total int) map[string]any {
	totalPages := 0
	if total > 0 {
		totalPages = (total + pageSize - 1) / pageSize
	}
	return map[string]any{
		"page":        page,
		"page_size":   pageSize,
		"total":       total,
		"total_pages": totalPages,
		"has_prev":    page > 1 && totalPages > 0,
		"has_next":    totalPages > 0 && page < totalPages,
	}
}

func normalizeAdminUserSort(value string) string {
	switch strings.TrimSpace(value) {
	case "email", "plan_name", "active_device_count", "effective_device_limit", "created_at", "updated_at", "last_synced_at":
		return strings.TrimSpace(value)
	default:
		return "updated_at"
	}
}

func normalizeSortOrder(value string) string {
	if strings.EqualFold(strings.TrimSpace(value), "asc") {
		return "asc"
	}
	return "desc"
}

func adminUserMatchesFilters(user *UserCache, activeCount int, query, deviceStatus, limitMode string) bool {
	if query != "" {
		haystack := strings.ToLower(strings.Join([]string{
			user.ID,
			user.BusinessUserID,
			user.Email,
			strconv.Itoa(user.PlanID),
			user.PlanName,
		}, " "))
		if !strings.Contains(haystack, query) {
			return false
		}
	}
	switch deviceStatus {
	case "", "all":
	case "active":
		if activeCount <= 0 {
			return false
		}
	case "inactive":
		if activeCount > 0 {
			return false
		}
	default:
		return false
	}
	switch limitMode {
	case "", "all":
	case "overridden":
		if user.DeviceLimitOverride == nil {
			return false
		}
	case "default":
		if user.DeviceLimitOverride != nil {
			return false
		}
	default:
		return false
	}
	return true
}

func compareAdminUsers(a, b adminUserRow, sortBy, order string) bool {
	cmp := 0
	switch sortBy {
	case "email":
		cmp = strings.Compare(strings.ToLower(a.user.Email), strings.ToLower(b.user.Email))
	case "plan_name":
		cmp = strings.Compare(strings.ToLower(a.user.PlanName), strings.ToLower(b.user.PlanName))
	case "active_device_count":
		cmp = compareInt(a.activeCount, b.activeCount)
	case "effective_device_limit":
		cmp = compareInt(a.effectiveLimit, b.effectiveLimit)
	case "created_at":
		cmp = compareTime(a.user.CreatedAt, b.user.CreatedAt)
	case "last_synced_at":
		cmp = compareTime(a.user.LastSyncedAt, b.user.LastSyncedAt)
	default:
		cmp = compareTime(a.user.UpdatedAt, b.user.UpdatedAt)
	}
	if cmp == 0 {
		cmp = strings.Compare(a.user.ID, b.user.ID)
	}
	if order == "asc" {
		return cmp < 0
	}
	return cmp > 0
}

func compareInt(a, b int) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

func compareTime(a, b time.Time) int {
	switch {
	case a.Before(b):
		return -1
	case a.After(b):
		return 1
	default:
		return 0
	}
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
					s.store.deleteSessionLocked(sid)
				}
			}
			s.store.deleteDeviceLocked(id)
			removed++
		}
	}
	if autoRevoked > 0 || removed > 0 {
		s.log.Printf("cleanup: auto-revoked %d offline devices (>30d), removed %d expired revoked devices (>90d)", autoRevoked, removed)
		_ = s.store.saveLocked()
	}
}

// syncPostgresLoop periodically reloads the in-memory store from PostgreSQL
// so other instances' writes become visible to this process.
func syncPostgresLoop(s *Store, interval time.Duration, logger *log.Logger) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for range ticker.C {
		s.mu.Lock()
		pg := s.pg
		startRevision := s.revision
		hasPendingChanges := s.hasPendingChangesLocked()
		s.mu.Unlock()
		if pg == nil || hasPendingChanges {
			continue
		}

		fresh := &Store{
			Users:    map[string]*UserCache{},
			Devices:  map[string]*DeviceRecord{},
			Sessions: map[string]*SessionRecord{},
			Audits:   []AuditLog{},
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		err := pg.LoadAll(ctx, fresh)
		cancel()
		if err != nil {
			if logger != nil {
				logger.Printf("postgres sync failed: %v", err)
			}
			continue
		}

		s.mu.Lock()
		if s.revision == startRevision {
			s.Users = fresh.Users
			s.Devices = fresh.Devices
			s.Sessions = fresh.Sessions
			s.Audits = fresh.Audits
			s.rebuildSessionIndexesLocked()
		}
		s.mu.Unlock()
	}
}
