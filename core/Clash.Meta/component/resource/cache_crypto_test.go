package resource

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestProviderCacheCrossRuntimeFixture(t *testing.T) {
	testCacheKeys(t)
	path := filepath.Join(t.TempDir(), "fastcat-runtime-providers", "p1", "proxies", "fixture")
	tag := "5UCjPuVqMjvstS1/Pq2LrQ=="
	if runtime.GOOS == "windows" {
		tag = "ZiWbUQwmN1p9Ve0eojpZ2w=="
	}
	fixture := `{"v":1,"alg":"A256GCM","purpose":"fastcat-local-cache","kid":"test","nonce":"AwMDAwMDAwMDAwMD","data":"/vXgYsce6Q/bRn/Na0O1cg==","tag":"` + tag + `"}`
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(fixture), 0600); err != nil {
		t.Fatal(err)
	}
	plain, err := readProviderCache(path, false)
	if err != nil || string(plain) != "proxies: []\n" {
		t.Fatalf("cross-runtime fixture: %v", err)
	}
}

func testCacheKeys(t *testing.T) {
	t.Helper()
	cacheCrypto.Lock()
	old := cacheCrypto.keyring
	cacheCrypto.keyring = nil
	cacheCrypto.Unlock()
	t.Cleanup(func() { cacheCrypto.Lock(); cacheCrypto.keyring = old; cacheCrypto.Unlock() })
	if err := ConfigureCacheEncryption(&CacheEncryption{"test", map[string]string{
		"test": base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{42}, 32)),
	}}); err != nil {
		t.Fatal(err)
	}
}

func TestProviderCacheEncryptedRoundTrip(t *testing.T) {
	testCacheKeys(t)
	path := filepath.Join(t.TempDir(), "fastcat-runtime-providers", "p1", "proxies", "fixture")
	plain := []byte("proxies:\n  - name: secret-node\n    server: private.example\n")
	if err := safeWrite(path, plain); err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	if bytes.Contains(raw, []byte("secret-node")) || bytes.Contains(raw, []byte("private.example")) {
		t.Fatal("plaintext persisted")
	}
	got, err := readProviderCache(path, true)
	if err != nil || !bytes.Equal(got, plain) {
		t.Fatalf("round trip: %v", err)
	}
	if providerRecordID(path) != "provider|p1|"+filepath.Join("proxies", "fixture") {
		t.Fatal("Dart record binding mismatch")
	}
	entries, _ := os.ReadDir(filepath.Dir(path))
	if len(entries) != 1 {
		t.Fatal("temporary write artifact retained")
	}
}

func TestProviderCacheAuthenticationAndBinding(t *testing.T) {
	testCacheKeys(t)
	dir := t.TempDir()
	path := filepath.Join(dir, "a")
	if err := safeWrite(path, []byte("secret")); err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	other := filepath.Join(dir, "b")
	if err := os.WriteFile(other, raw, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := readProviderCache(other, true); err == nil {
		t.Fatal("cross-provider replay accepted")
	}
	var env cacheEnvelope
	_ = json.Unmarshal(raw, &env)
	env.Tag = base64.StdEncoding.EncodeToString(make([]byte, 16))
	broken, _ := json.Marshal(env)
	_ = os.WriteFile(path, broken, 0600)
	if _, err := readProviderCache(path, true); err == nil {
		t.Fatal("tampering accepted")
	}
}

func TestProviderCacheUpgradeAndFailedKeyRotation(t *testing.T) {
	testCacheKeys(t)
	path := filepath.Join(t.TempDir(), "legacy")
	plain := []byte("old provider content")
	_ = os.WriteFile(path, plain, 0600)
	got, err := readProviderCache(path, true)
	if err != nil || !bytes.Equal(got, plain) {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	if bytes.Equal(raw, plain) {
		t.Fatal("legacy plaintext was not migrated")
	}
	if ConfigureCacheEncryption(&CacheEncryption{"missing", map[string]string{}}) == nil {
		t.Fatal("invalid keyring accepted")
	}
	if _, err = readProviderCache(path, true); err != nil {
		t.Fatal("bad rotation replaced valid keyring")
	}
}

func TestProviderReadDoesNotRewriteUserOwnedFile(t *testing.T) {
	testCacheKeys(t)
	path := filepath.Join(t.TempDir(), "manual.yaml")
	plain := []byte("payload: [example.test]")
	_ = os.WriteFile(path, plain, 0600)
	if _, err := readProviderCache(path, false); err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	if !bytes.Equal(raw, plain) {
		t.Fatal("modified a user-owned file provider")
	}
}

func TestManagedProviderNeverWritesWithoutKey(t *testing.T) {
	cacheCrypto.Lock()
	old := cacheCrypto.keyring
	cacheCrypto.keyring = nil
	cacheCrypto.Unlock()
	t.Cleanup(func() { cacheCrypto.Lock(); cacheCrypto.keyring = old; cacheCrypto.Unlock() })
	path := filepath.Join(t.TempDir(), "fastcat-runtime-providers", "p", "rules", "test")
	if safeWrite(path, []byte("secret")) == nil {
		t.Fatal("keyless plaintext write accepted")
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("file written despite rejection")
	}
}
