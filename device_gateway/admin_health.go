package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

type adminEndpointHealthItem struct {
	Index          int    `json:"index"`
	Name           string `json:"name"`
	Role           string `json:"role"`
	Address        string `json:"address"`
	Status         string `json:"status"`
	LatencyMS      int64  `json:"latency_ms"`
	StatusCode     int    `json:"status_code,omitempty"`
	Error          string `json:"error,omitempty"`
	Active         bool   `json:"active"`
	MatchesCurrent bool   `json:"matches_current,omitempty"`
	ConfigVersion  string `json:"config_version,omitempty"`
	BusinessCount  int    `json:"business_count,omitempty"`
	GatewayCount   int    `json:"gateway_count,omitempty"`
	CheckedAt      string `json:"checked_at"`
}

type adminOSSProbeResult struct {
	item        adminEndpointHealthItem
	domains     []string
	gatewayURLs []string
}

type adminHealthGroupSummary struct {
	Healthy int `json:"healthy"`
	Total   int `json:"total"`
}

type adminServiceHealthSnapshot struct {
	CheckedAt string `json:"checked_at"`
	Summary   struct {
		OSS      adminHealthGroupSummary `json:"oss"`
		Gateways adminHealthGroupSummary `json:"gateways"`
		Business adminHealthGroupSummary `json:"business"`
	} `json:"summary"`
	OSS struct {
		Items []adminEndpointHealthItem `json:"items"`
	} `json:"oss"`
	Gateways struct {
		Items              []adminEndpointHealthItem `json:"items"`
		PublicBaseURL      string                    `json:"public_base_url"`
		RequestBaseURL     string                    `json:"request_base_url"`
		PublicBaseMismatch bool                      `json:"public_base_mismatch"`
	} `json:"gateways"`
	Business struct {
		Items []BusinessServiceStatus `json:"items"`
	} `json:"business"`
}

func (s *Server) handleAdminServiceHealth(w http.ResponseWriter, r *http.Request) {
	snapshot := s.collectAdminServiceHealth(r.Context(), r)
	writeJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"data":    snapshot,
	})
}

func (s *Server) collectAdminServiceHealth(ctx context.Context, r *http.Request) adminServiceHealthSnapshot {
	type ossResult struct{ items []adminEndpointHealthItem }
	type gatewayResult struct{ items []adminEndpointHealthItem }
	ossChannel := make(chan ossResult, 1)
	gatewayChannel := make(chan gatewayResult, 1)
	businessChannel := make(chan []BusinessServiceStatus, 1)

	go func() { ossChannel <- ossResult{items: s.probeAdminOSS(ctx)} }()
	go func() { gatewayChannel <- gatewayResult{items: s.probeAdminGateways(ctx)} }()
	go func() { businessChannel <- s.adminBusinessServiceStatuses(ctx) }()

	ossItems := (<-ossChannel).items
	gatewayItems := (<-gatewayChannel).items
	businessItems := <-businessChannel
	checkedAt := time.Now().UTC().Format(time.RFC3339)

	var snapshot adminServiceHealthSnapshot
	snapshot.CheckedAt = checkedAt
	snapshot.OSS.Items = ossItems
	snapshot.Gateways.Items = gatewayItems
	snapshot.Business.Items = businessItems
	snapshot.Summary.OSS = summarizeAdminEndpointHealth(ossItems, true)
	snapshot.Summary.Gateways = summarizeAdminEndpointHealth(gatewayItems, false)
	snapshot.Summary.Business = summarizeBusinessServiceHealth(businessItems)
	snapshot.Gateways.PublicBaseURL = s.cfg.PublicBaseURL
	snapshot.Gateways.RequestBaseURL = adminRequestBaseURL(r)
	snapshot.Gateways.PublicBaseMismatch = endpointComparable(snapshot.Gateways.PublicBaseURL) != "" &&
		endpointComparable(snapshot.Gateways.RequestBaseURL) != "" &&
		endpointComparable(snapshot.Gateways.PublicBaseURL) != endpointComparable(snapshot.Gateways.RequestBaseURL)
	return snapshot
}

func (s *Server) probeAdminOSS(ctx context.Context) []adminEndpointHealthItem {
	normalURLs := splitAndNormalizeURLs(env("DG_OSS_CONFIG_URLS", ""))
	emergencyURL := strings.TrimSpace(env("DG_EMERGENCY_OSS_CONFIG_URL", defaultEmergencyOSSConfigURL))
	xorKey := env("DG_OSS_XOR_KEY", "")

	type source struct {
		index   int
		name    string
		role    string
		address string
	}
	sources := make([]source, 0, len(normalURLs)+1)
	for index, address := range normalURLs {
		sources = append(sources, source{
			index: index + 1, name: fmt.Sprintf("source_%d", index), role: map[bool]string{true: "primary", false: "backup"}[index == 0], address: address,
		})
	}
	if emergencyURL != "" && !containsString(normalURLs, emergencyURL) {
		sources = append(sources, source{
			index: len(sources) + 1, name: "emergency", role: "emergency", address: emergencyURL,
		})
	}

	results := make(chan adminOSSProbeResult, len(sources))
	for _, candidate := range sources {
		go func(candidate source) {
			results <- s.probeAdminOSSSource(ctx, candidate.index, candidate.name, candidate.role, candidate.address, xorKey)
		}(candidate)
	}
	probes := make([]adminOSSProbeResult, 0, len(sources)+1)
	for range sources {
		probes = append(probes, <-results)
	}
	sortAdminOSSProbeResults(probes)
	cacheResult := probeAdminOSSCache()
	cacheResult.item.Index = len(probes) + 1
	probes = append(probes, cacheResult)

	s.ossMu.RLock()
	currentBusiness := append([]string(nil), s.cfg.BusinessBaseURLs...)
	currentGateways := append([]string(nil), s.cfg.GatewayURLs...)
	s.ossMu.RUnlock()
	items := make([]adminEndpointHealthItem, 0, len(probes))
	for _, probe := range probes {
		if probe.item.Status == "healthy" &&
			sameStringList(probe.domains, currentBusiness) &&
			sameStringList(probe.gatewayURLs, currentGateways) {
			probe.item.MatchesCurrent = true
		}
		items = append(items, probe.item)
	}
	return items
}

func (s *Server) probeAdminOSSSource(
	ctx context.Context,
	index int,
	name string,
	role string,
	address string,
	xorKey string,
) adminOSSProbeResult {
	item := adminEndpointHealthItem{
		Index: index, Name: name, Role: role, Address: address, Status: "unreachable", CheckedAt: time.Now().UTC().Format(time.RFC3339),
	}
	if xorKey == "" {
		item.Status = "not_configured"
		item.Error = "DG_OSS_XOR_KEY 未配置"
		return adminOSSProbeResult{item: item}
	}
	started := time.Now()
	probeCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(probeCtx, http.MethodGet, address, nil)
	if err != nil {
		item.Status = "invalid_address"
		item.Error = err.Error()
		return adminOSSProbeResult{item: item}
	}
	resp, err := s.adminHealthHTTPClient().Do(req)
	item.LatencyMS = time.Since(started).Milliseconds()
	if err != nil {
		item.Status, item.Error = adminNetworkError(err, probeCtx)
		return adminOSSProbeResult{item: item}
	}
	defer resp.Body.Close()
	item.StatusCode = resp.StatusCode
	if resp.StatusCode != http.StatusOK {
		item.Status = "http_error"
		item.Error = fmt.Sprintf("HTTP %d", resp.StatusCode)
		return adminOSSProbeResult{item: item}
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		item.Status = "read_error"
		item.Error = err.Error()
		return adminOSSProbeResult{item: item}
	}
	decrypted, err := xorDecrypt(body, xorKey)
	if err != nil {
		item.Status = "decrypt_error"
		item.Error = err.Error()
		return adminOSSProbeResult{item: item}
	}
	domains, gateways, version, err := extractOSSConfig(decrypted)
	if err != nil {
		item.Status = "invalid_config"
		item.Error = err.Error()
		return adminOSSProbeResult{item: item}
	}
	item.Status = "healthy"
	item.ConfigVersion = version
	item.BusinessCount = len(domains)
	item.GatewayCount = len(gateways)
	return adminOSSProbeResult{item: item, domains: domains, gatewayURLs: gateways}
}

func probeAdminOSSCache() adminOSSProbeResult {
	item := adminEndpointHealthItem{
		Name: "local_cache", Role: "cache", Address: ossConfigCachePath(), Status: "missing", CheckedAt: time.Now().UTC().Format(time.RFC3339),
	}
	started := time.Now()
	data, err := os.ReadFile(ossConfigCachePath())
	item.LatencyMS = time.Since(started).Milliseconds()
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			item.Status = "read_error"
			item.Error = err.Error()
		}
		return adminOSSProbeResult{item: item}
	}
	domains, gateways, version, err := extractOSSConfig(data)
	if err != nil {
		item.Status = "invalid_config"
		item.Error = err.Error()
		return adminOSSProbeResult{item: item}
	}
	item.Status = "healthy"
	item.ConfigVersion = version
	item.BusinessCount = len(domains)
	item.GatewayCount = len(gateways)
	return adminOSSProbeResult{item: item, domains: domains, gatewayURLs: gateways}
}

func (s *Server) probeAdminGateways(ctx context.Context) []adminEndpointHealthItem {
	urls := s.ossGatewayURLs()
	results := make(chan adminEndpointHealthItem, len(urls))
	for index, address := range urls {
		go func(index int, address string) {
			results <- s.probeAdminGateway(ctx, index, address)
		}(index, address)
	}
	items := make([]adminEndpointHealthItem, 0, len(urls))
	for range urls {
		items = append(items, <-results)
	}
	sortAdminHealthItems(items)
	return items
}

func (s *Server) probeAdminGateway(ctx context.Context, index int, address string) adminEndpointHealthItem {
	item := adminEndpointHealthItem{
		Index:     index + 1,
		Name:      fmt.Sprintf("gateway_%d", index+1),
		Role:      map[bool]string{true: "primary", false: "backup"}[index == 0],
		Address:   address,
		Status:    "unreachable",
		Active:    endpointComparable(address) == endpointComparable(s.cfg.PublicBaseURL),
		CheckedAt: time.Now().UTC().Format(time.RFC3339),
	}
	target, err := url.Parse(address)
	if err != nil || target.Hostname() == "" {
		item.Status = "invalid_address"
		item.Error = "网关地址无效"
		return item
	}
	target.Path = joinURLPath(target.Path, "/healthz")
	started := time.Now()
	probeCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(probeCtx, http.MethodGet, target.String(), nil)
	if err != nil {
		item.Status = "invalid_address"
		item.Error = err.Error()
		return item
	}
	resp, err := s.adminHealthHTTPClient().Do(req)
	item.LatencyMS = time.Since(started).Milliseconds()
	if err != nil {
		item.Status, item.Error = adminNetworkError(err, probeCtx)
		return item
	}
	defer resp.Body.Close()
	item.StatusCode = resp.StatusCode
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		item.Status = "http_error"
		item.Error = fmt.Sprintf("HTTP %d", resp.StatusCode)
		return item
	}
	var payload map[string]any
	if json.Unmarshal(body, &payload) != nil || payload["success"] != true {
		item.Status = "invalid_response"
		item.Error = "健康检查响应格式无效"
		return item
	}
	data, _ := payload["data"].(map[string]any)
	if data == nil || data["status"] != "ok" {
		item.Status = "invalid_response"
		item.Error = "健康检查状态不是 ok"
		return item
	}
	item.Status = "healthy"
	return item
}

func (s *Server) adminHealthHTTPClient() *http.Client {
	if s.client != nil {
		return s.client
	}
	return &http.Client{Timeout: 5 * time.Second}
}

func adminNetworkError(err error, ctx context.Context) (string, string) {
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return "timeout", "请求超时"
	}
	var networkError net.Error
	if errors.As(err, &networkError) && networkError.Timeout() {
		return "timeout", "请求超时"
	}
	return "unreachable", err.Error()
}

func summarizeAdminEndpointHealth(items []adminEndpointHealthItem, excludeCache bool) adminHealthGroupSummary {
	var summary adminHealthGroupSummary
	for _, item := range items {
		if excludeCache && item.Role == "cache" {
			continue
		}
		summary.Total++
		if item.Status == "healthy" || item.Status == "recovering" {
			summary.Healthy++
		}
	}
	return summary
}

func summarizeBusinessServiceHealth(items []BusinessServiceStatus) adminHealthGroupSummary {
	summary := adminHealthGroupSummary{Total: len(items)}
	for _, item := range items {
		if item.Status == "healthy" || item.Status == "recovering" {
			summary.Healthy++
		}
	}
	return summary
}

func adminRequestBaseURL(r *http.Request) string {
	if r == nil {
		return ""
	}
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	if forwarded := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-Proto"), ",")[0]); forwarded != "" {
		scheme = forwarded
	}
	host := r.Host
	if forwarded := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-Host"), ",")[0]); forwarded != "" {
		host = forwarded
	}
	if host == "" {
		return ""
	}
	return scheme + "://" + host
}

func endpointComparable(raw string) string {
	parsed, err := url.Parse(strings.TrimRight(strings.TrimSpace(raw), "/"))
	if err != nil || parsed.Host == "" {
		return ""
	}
	return strings.ToLower(parsed.Scheme + "://" + parsed.Host)
}

func sameStringList(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for index := range left {
		if strings.TrimRight(left[index], "/") != strings.TrimRight(right[index], "/") {
			return false
		}
	}
	return true
}

func sortAdminHealthItems(items []adminEndpointHealthItem) {
	for i := 0; i < len(items); i++ {
		for j := i + 1; j < len(items); j++ {
			if items[j].Index < items[i].Index {
				items[i], items[j] = items[j], items[i]
			}
		}
	}
}

func sortAdminOSSProbeResults(items []adminOSSProbeResult) {
	for i := 0; i < len(items); i++ {
		for j := i + 1; j < len(items); j++ {
			if items[j].item.Index < items[i].item.Index {
				items[i], items[j] = items[j], items[i]
			}
		}
	}
}
