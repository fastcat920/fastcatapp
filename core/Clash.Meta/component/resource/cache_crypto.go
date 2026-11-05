package resource

// Provider caches use the same authenticated envelope as the application's
// FastCatLocalCacheCodec. Keys arrive over the existing private core channel;
// neither keys nor decrypted providers are written to runtime cache files.
import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

type CacheEncryption struct {
	CurrentKeyID string            `json:"currentKeyId" yaml:"currentKeyId"`
	Keys         map[string]string `json:"keys" yaml:"keys"`
}

type cacheKeyring struct {
	current string
	keys    map[string]cipher.AEAD
}

type cacheEnvelope struct {
	Version int    `json:"v"`
	Alg     string `json:"alg"`
	Purpose string `json:"purpose"`
	Kid     string `json:"kid"`
	Nonce   string `json:"nonce"`
	Data    string `json:"data"`
	Tag     string `json:"tag"`
}

var cacheCrypto struct {
	sync.RWMutex
	keyring *cacheKeyring
}

const cachePurpose = "fastcat-local-cache"

// ConfigureCacheEncryption validates the entire keyring before publishing it.
// A missing optional config preserves the current ring during profile reloads.
func ConfigureCacheEncryption(config *CacheEncryption) error {
	if config == nil {
		return nil
	}
	next := &cacheKeyring{current: config.CurrentKeyID, keys: map[string]cipher.AEAD{}}
	if next.current == "" || len(config.Keys) > 8 {
		return errors.New("invalid provider cache keyring")
	}
	for kid, encoded := range config.Keys {
		key, err := base64.StdEncoding.DecodeString(encoded)
		if err != nil || len(key) != 32 || kid == "" {
			return errors.New("invalid provider cache key")
		}
		block, err := aes.NewCipher(key)
		if err != nil {
			return errors.New("invalid provider cache cipher")
		}
		aead, err := cipher.NewGCM(block)
		if err != nil {
			return err
		}
		next.keys[kid] = aead
	}
	if next.keys[next.current] == nil {
		return errors.New("missing current provider cache key")
	}
	cacheCrypto.Lock()
	cacheCrypto.keyring = next
	cacheCrypto.Unlock()
	return nil
}

func providerRecordID(path string) string {
	clean := filepath.Clean(path)
	parts := strings.Split(clean, string(filepath.Separator))
	for i, part := range parts {
		if part == "fastcat-runtime-providers" && i+3 < len(parts) {
			return "provider|" + parts[i+1] + "|" + filepath.Join(parts[i+2:]...)
		}
	}
	return "provider-core|" + filepath.ToSlash(clean)
}

func cacheAAD(kid, path string) []byte {
	return []byte(cachePurpose + "|v1|" + kid + "|" + providerRecordID(path))
}

func encryptProviderCache(path string, plaintext []byte) ([]byte, error) {
	cacheCrypto.RLock()
	ring := cacheCrypto.keyring
	cacheCrypto.RUnlock()
	if ring == nil {
		// Managed Flutter paths must never silently revert to plaintext, even
		// when a mismatched/old initialization payload omitted the keyring.
		if strings.Contains(filepath.ToSlash(path), "/fastcat-runtime-providers/") {
			return nil, errors.New("provider cache encryption is not configured")
		}
		return plaintext, nil // upstream standalone core compatibility
	}
	aead := ring.keys[ring.current]
	nonce := make([]byte, aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}
	data := aead.Seal(nil, nonce, []byte(base64.StdEncoding.EncodeToString(plaintext)), cacheAAD(ring.current, path))
	return json.Marshal(cacheEnvelope{1, "A256GCM", cachePurpose, ring.current,
		base64.StdEncoding.EncodeToString(nonce), base64.StdEncoding.EncodeToString(data[:len(data)-aead.Overhead()]),
		base64.StdEncoding.EncodeToString(data[len(data)-aead.Overhead():])})
}

func readProviderCache(path string, migrate bool) ([]byte, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var envelope cacheEnvelope
	parsed := json.Unmarshal(data, &envelope) == nil && envelope.Purpose == cachePurpose
	cacheCrypto.RLock()
	ring := cacheCrypto.keyring
	cacheCrypto.RUnlock()
	if !parsed {
		if ring != nil && migrate {
			// One-time upgrade: rewrite old cached providers before giving their
			// contents to the parser. An encryption failure leaves no false success.
			if err := safeWrite(path, data); err != nil {
				return nil, err
			}
		}
		return data, nil
	}
	if ring == nil || envelope.Version != 1 || envelope.Alg != "A256GCM" {
		return nil, errors.New("unsupported encrypted provider cache")
	}
	aead := ring.keys[envelope.Kid]
	if aead == nil {
		return nil, errors.New("provider cache key unavailable")
	}
	nonce, e1 := base64.StdEncoding.DecodeString(envelope.Nonce)
	ciphertext, e2 := base64.StdEncoding.DecodeString(envelope.Data)
	tag, e3 := base64.StdEncoding.DecodeString(envelope.Tag)
	if e1 != nil || e2 != nil || e3 != nil || len(nonce) != aead.NonceSize() || len(tag) != aead.Overhead() {
		return nil, errors.New("invalid encrypted provider cache")
	}
	plaintext, err := aead.Open(nil, nonce, append(ciphertext, tag...), cacheAAD(envelope.Kid, path))
	if err != nil {
		return nil, errors.New("provider cache authentication failed")
	}
	return base64.StdEncoding.DecodeString(string(plaintext))
}
