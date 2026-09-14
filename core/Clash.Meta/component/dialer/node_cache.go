package dialer

import (
	"encoding/json"
	"net/netip"
	"os"
	"strings"
	"sync"
	"time"
)

// Only public addresses confirmed by a TCP connection are retained. TLS and
// proxy authentication still run normally after dialing a cached address.
type nodeCacheEntry struct {
	IP    netip.Addr
	Saved time.Time
}

var nodeCacheMu sync.Mutex

// NodeCachePath is supplied by the configuration layer to avoid dependency cycles.
var NodeCachePath = func() string { return "" }

func nodeCachePath() string { return NodeCachePath() }

func readNodeCache(path string) map[string]nodeCacheEntry {
	entries := map[string]nodeCacheEntry{}
	data, err := os.ReadFile(path)
	if err == nil && len(data) <= 256*1024 {
		_ = json.Unmarshal(data, &entries)
	}
	if entries == nil {
		entries = map[string]nodeCacheEntry{}
	}
	return entries
}

func publicNodeIP(ip netip.Addr) bool {
	return ip.IsValid() && ip.IsGlobalUnicast() && !ip.IsPrivate() &&
		!netip.MustParsePrefix("100.64.0.0/10").Contains(ip) &&
		!netip.MustParsePrefix("198.18.0.0/15").Contains(ip)
}

func cachedNodeIP(address, network string) []netip.Addr {
	nodeCacheMu.Lock()
	defer nodeCacheMu.Unlock()
	entry, ok := readNodeCache(nodeCachePath())[strings.ToLower(address)]
	age := time.Since(entry.Saved)
	if !ok || age < 0 || age > 24*time.Hour || !publicNodeIP(entry.IP) {
		return nil
	}
	if strings.HasSuffix(network, "4") && !entry.IP.Is4() {
		return nil
	}
	if strings.HasSuffix(network, "6") && !entry.IP.Is6() {
		return nil
	}
	return []netip.Addr{entry.IP}
}

func saveNodeIP(path, address string, ip netip.Addr) {
	if path == "" {
		return
	}
	if !publicNodeIP(ip) {
		return
	}
	nodeCacheMu.Lock()
	defer nodeCacheMu.Unlock()
	entries := readNodeCache(path)
	for key, entry := range entries {
		if time.Since(entry.Saved) > 24*time.Hour {
			delete(entries, key)
		}
	}
	key := strings.ToLower(address)
	if old, ok := entries[key]; ok && old.IP == ip && time.Since(old.Saved) < time.Hour {
		return
	}
	if len(entries) >= 512 {
		return
	}
	entries[key] = nodeCacheEntry{ip, time.Now()}
	data, err := json.Marshal(entries)
	if err != nil {
		return
	}
	if err = os.WriteFile(path+".tmp", data, 0600); err == nil {
		_ = os.Rename(path+".tmp", path)
	}
}
