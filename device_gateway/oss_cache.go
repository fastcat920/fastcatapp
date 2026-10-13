package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const ossCacheFormat = "fastcat-gateway-raw-cache-v1"

// Only locally observed verification time is used. The raw signed envelope is
// verified again with the CURRENT public key on every read; decoded JSON never
// crosses the persistence boundary. Legacy XOR has no authenticity guarantee.
type ossCacheRecord struct {
	Raw        []byte    `json:"raw_content"`
	VerifiedAt time.Time `json:"verified_at"`
}
type ossCacheFile struct {
	Format   string          `json:"format"`
	Current  *ossCacheRecord `json:"current"`
	Previous *ossCacheRecord `json:"previous,omitempty"`
}

var ossCacheMu sync.Mutex

func positiveEnvInt(name string, fallback int) int {
	value := envInt(name, fallback)
	if value <= 0 {
		return fallback
	}
	return value
}

func ossCacheAges() (time.Duration, time.Duration) {
	fresh := time.Duration(positiveEnvInt("DG_OSS_CACHE_TTL_HOURS", 72)) * time.Hour
	graceHours := envInt("DG_OSS_OFFLINE_GRACE_HOURS", 168)
	if graceHours < 0 {
		graceHours = 0
	}
	return fresh, fresh + time.Duration(graceHours)*time.Hour
}

func ossCacheUsable(result *ossFetchResult, now time.Time) bool {
	if result == nil || result.verifiedAt.IsZero() {
		return false
	}
	_, maximum := ossCacheAges()
	age := now.Sub(result.verifiedAt)
	return age >= 0 && age <= maximum
}

// Plain JSON includes the old parsed on-disk cache. It cannot be authenticated
// and is deliberately NOT upgraded into a trusted raw record.
func decodeOSSRaw(raw []byte, xorKey string) ([]byte, bool, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || len(raw) > 1<<20 {
		return nil, false, errors.New("empty or oversized OSS envelope")
	}
	signed := raw[0] == '{'
	if signed {
		var header struct {
			Format string `json:"_format"`
		}
		if json.Unmarshal(raw, &header) != nil || header.Format != "fastcat-config-v2" {
			return nil, false, errors.New("OSS requires signed v2 or legacy XOR+Base64, not parsed JSON")
		}
	} else if raw[0] == '[' {
		return nil, false, errors.New("unsigned JSON OSS is not accepted")
	}
	plain, err := xorDecrypt(raw, xorKey)
	return plain, signed, err
}

func decodeOSSCacheRecord(record *ossCacheRecord, now time.Time) *ossFetchResult {
	if record == nil || record.VerifiedAt.IsZero() || record.VerifiedAt.After(now) {
		return nil
	}
	plain, signed, err := decodeOSSRaw(record.Raw, env("DG_OSS_XOR_KEY", ""))
	if err != nil {
		return nil
	}
	domains, gateways, version, err := extractOSSConfig(plain)
	if err != nil {
		return nil
	}
	return &ossFetchResult{raw: record.Raw, decrypted: plain, domains: domains,
		gatewayURLs: gateways, configVersion: version, signed: signed,
		verifiedAt: record.VerifiedAt, source: "local_cache"}
}

// An expired, still-verifiable record remains a revision floor, not an offline
// route. Publish rollback contents as a NEW higher config_version. Once signed
// v2 has been accepted, legacy unsigned data cannot silently downgrade it.
func ossCandidateAllowed(cached, candidate *ossFetchResult) bool {
	if candidate == nil {
		return true
	}
	if cached == nil {
		return true
	}
	if cached.signed && !candidate.signed {
		return false
	}
	comparison := compareConfigVersions(candidate.configVersion, cached.configVersion)
	return comparison > 0 || (comparison == 0 && bytes.Equal(bytes.TrimSpace(candidate.decrypted), bytes.TrimSpace(cached.decrypted)))
}

func readOSSCacheFile() (ossCacheFile, error) {
	file, err := os.Open(ossConfigCachePath())
	if err != nil {
		return ossCacheFile{}, err
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, (3<<20)+1))
	if err != nil || len(data) > 3<<20 {
		return ossCacheFile{}, errors.New("cannot read bounded OSS cache")
	}
	var saved ossCacheFile
	if json.Unmarshal(data, &saved) != nil || saved.Format != ossCacheFormat {
		return ossCacheFile{}, errors.New("legacy parsed or invalid OSS cache rejected; fetch original envelope online")
	}
	return saved, nil
}

func bestOSSCache(saved ossCacheFile, now time.Time) *ossFetchResult {
	current := decodeOSSCacheRecord(saved.Current, now)
	previous := decodeOSSCacheRecord(saved.Previous, now)
	if current == nil {
		return previous
	}
	if previous != nil && ((previous.signed && !current.signed) || compareConfigVersions(previous.configVersion, current.configVersion) > 0) {
		return previous
	}
	return current
}

func loadCachedOSSResult(logger *log.Logger) *ossFetchResult {
	ossCacheMu.Lock()
	defer ossCacheMu.Unlock()
	saved, err := readOSSCacheFile()
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			logger.Printf("OSS cache rejected: %v", err)
		}
		return nil
	}
	result := bestOSSCache(saved, time.Now().UTC())
	if result == nil {
		logger.Printf("OSS cache failed current-key verification")
	} else {
		fresh, _ := ossCacheAges()
		if !ossCacheUsable(result, time.Now()) {
			logger.Printf("OSS cache expired beyond offline grace; retaining revision floor only")
		} else if time.Since(result.verifiedAt) > fresh {
			logger.Printf("OSS cache is in offline grace; remote verification is required before expiry")
		}
	}
	return result
}

func persistOSSConfigCache(logger *log.Logger, result *ossFetchResult) {
	if result == nil || len(result.raw) == 0 {
		return
	}
	ossCacheMu.Lock()
	defer ossCacheMu.Unlock()
	now := time.Now().UTC()
	record := &ossCacheRecord{Raw: result.raw, VerifiedAt: now}
	verified := decodeOSSCacheRecord(record, now)
	if verified == nil {
		logger.Printf("OSS cache write rejected: raw verification failed")
		return
	}
	saved, _ := readOSSCacheFile()
	previous := bestOSSCache(saved, now)
	if !ossCandidateAllowed(previous, verified) {
		logger.Printf("OSS cache write rejected: rollback or signature downgrade")
		return
	}
	next := ossCacheFile{Format: ossCacheFormat, Current: record}
	if previous != nil && !bytes.Equal(previous.raw, result.raw) {
		next.Previous = &ossCacheRecord{Raw: previous.raw, VerifiedAt: previous.verifiedAt}
	} else {
		next.Previous = saved.Previous
	}
	data, err := json.Marshal(next)
	if err == nil {
		err = atomicOSSCacheWrite(ossConfigCachePath(), data)
	}
	if err != nil {
		logger.Printf("OSS cache write failed: %v", err)
	}
}

func atomicOSSCacheWrite(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	file, err := os.CreateTemp(filepath.Dir(path), ".oss-cache-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	defer file.Close()
	if _, err = file.Write(data); err != nil {
		return err
	}
	if err = file.Sync(); err != nil {
		return err
	}
	if err = file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), path)
}
