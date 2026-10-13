package main

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"io"
	"log"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func encodeTestOSS(plain []byte, key string) []byte {
	encoded := append([]byte(nil), plain...)
	for i := range encoded {
		encoded[i] ^= key[i%len(key)]
	}
	return []byte(base64.StdEncoding.EncodeToString(encoded))
}

func setupOSSCacheTest(t *testing.T) (func(string) *ossFetchResult, *log.Logger) {
	t.Helper()
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("DG_OSS_XOR_KEY", "test-cache-key")
	t.Setenv("DG_OSS_SIGNING_PUBLIC_KEY", base64.StdEncoding.EncodeToString(public))
	t.Setenv("DG_OSS_CACHE_FILE", filepath.Join(t.TempDir(), "cache.json"))
	t.Setenv("DG_OSS_CACHE_TTL_HOURS", "72")
	t.Setenv("DG_OSS_OFFLINE_GRACE_HOURS", "168")
	makeResult := func(version string) *ossFetchResult {
		plain := []byte(`{"config_version":"` + version + `","domains":["https://business.example.invalid"],"gateway_urls":["https://gateway.example.invalid"]}`)
		payload := string(encodeTestOSS(plain, "test-cache-key"))
		raw, _ := json.Marshal(map[string]string{"_format": "fastcat-config-v2", "algorithm": "Ed25519", "encoding": "xor+base64", "payload": payload,
			"signature": base64.StdEncoding.EncodeToString(ed25519.Sign(private, []byte(payload)))})
		return decodeOSSCacheRecord(&ossCacheRecord{Raw: raw, VerifiedAt: time.Now().Add(-time.Second)}, time.Now())
	}
	return makeResult, log.New(io.Discard, "", 0)
}

func TestOSSCacheStoresOriginalAndRechecksCurrentPublicKey(t *testing.T) {
	makeResult, logger := setupOSSCacheTest(t)
	result := makeResult("5")
	persistOSSConfigCache(logger, result)
	body, err := os.ReadFile(ossConfigCachePath())
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(body, []byte("business.example.invalid")) {
		t.Fatal("cache persisted parsed plaintext")
	}
	saved, err := readOSSCacheFile()
	if err != nil || !bytes.Equal(saved.Current.Raw, result.raw) {
		t.Fatal("original signed envelope was not retained")
	}
	if got := loadCachedOSSResult(logger); got == nil || got.configVersion != "5" {
		t.Fatal("valid raw cache unavailable")
	}
	newPublic, _, _ := ed25519.GenerateKey(rand.Reader)
	t.Setenv("DG_OSS_SIGNING_PUBLIC_KEY", base64.StdEncoding.EncodeToString(newPublic))
	if loadCachedOSSResult(logger) != nil {
		t.Fatal("cached signature was not rechecked")
	}
}

func TestOSSCacheLegacyXORButNotParsedPlaintext(t *testing.T) {
	makeResult, logger := setupOSSCacheTest(t)
	plain := makeResult("2").decrypted
	if err := os.WriteFile(ossConfigCachePath(), plain, 0600); err != nil {
		t.Fatal(err)
	}
	if loadCachedOSSResult(logger) != nil {
		t.Fatal("trusted unverified legacy parsed cache")
	}
	if _, _, err := decodeOSSRaw(plain, "test-cache-key"); err == nil {
		t.Fatal("accepted unsigned plaintext as raw")
	}
	legacy := decodeOSSCacheRecord(&ossCacheRecord{Raw: encodeTestOSS(plain, "test-cache-key"), VerifiedAt: time.Now().Add(-time.Second)}, time.Now())
	if legacy == nil || legacy.signed {
		t.Fatal("legacy XOR compatibility missing")
	}
	persistOSSConfigCache(logger, legacy)
	if loadCachedOSSResult(logger) == nil {
		t.Fatal("legacy raw cache failed")
	}
	persistOSSConfigCache(logger, makeResult("3"))
	legacy.configVersion = "100"
	if ossCandidateAllowed(loadCachedOSSResult(logger), legacy) {
		t.Fatal("accepted signature downgrade")
	}
}

func TestOSSCacheAgeRollbackAndPreviousRules(t *testing.T) {
	makeResult, logger := setupOSSCacheTest(t)
	now := time.Now()
	old, newer := makeResult("2"), makeResult("3")
	newer.verifiedAt = now.Add(-11 * 24 * time.Hour)
	if ossCacheUsable(newer, now) {
		t.Fatal("expired cache eligible for offline route")
	}
	if ossCandidateAllowed(newer, old) {
		t.Fatal("expired revision floor allowed rollback")
	}
	newer.verifiedAt = now.Add(-4 * 24 * time.Hour)
	if !ossCacheUsable(newer, now) {
		t.Fatal("offline grace unavailable")
	}
	newer.verifiedAt = now.Add(time.Second)
	if ossCacheUsable(newer, now) {
		t.Fatal("future verification timestamp accepted")
	}
	persistOSSConfigCache(logger, old)
	persistOSSConfigCache(logger, makeResult("3"))
	saved, _ := readOSSCacheFile()
	if saved.Previous == nil {
		t.Fatal("previous verified envelope lost")
	}
	// Broken current envelope may fall back only to another independently
	// verified raw record, not its untrusted parsed values.
	saved.Current.Raw = []byte(`{"domains":["https://untrusted.invalid"]}`)
	if best := bestOSSCache(saved, now.Add(time.Second)); best == nil || best.configVersion != "2" {
		t.Fatal("previous raw record not independently recovered")
	}
}

func TestOSSCacheConcurrentWritesCannotRollBack(t *testing.T) {
	makeResult, logger := setupOSSCacheTest(t)
	low, high := makeResult("4"), makeResult("9")
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if i%2 == 0 {
				persistOSSConfigCache(logger, low)
			} else {
				persistOSSConfigCache(logger, high)
			}
		}(i)
	}
	wg.Wait()
	if got := loadCachedOSSResult(logger); got == nil || got.configVersion != "9" {
		t.Fatal("concurrent lower revision replaced newer cache")
	}
}
