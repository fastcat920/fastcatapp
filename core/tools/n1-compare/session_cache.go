package main

import (
	"crypto/sha256"
	"crypto/tls"
	"fmt"
	"os"
	"sync"
	"time"
)

// In-memory1min tickets, bounded8/profile and16 profiles. Endpoint, verified
// identity, roots, curve and explicit network epoch are isolated. Never0RTT.
// No tickets or cryptographic secrets are serialized or exposed in metrics.
type timedSessionCache struct {
	mu      sync.Mutex
	cache   tls.ClientSessionCache
	created map[string]time.Time
}

func (c *timedSessionCache) Get(k string) (*tls.ClientSessionState, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if time.Since(c.created[k]) > time.Minute {
		c.cache.Put(k, nil)
		delete(c.created, k)
		return nil, false
	}
	return c.cache.Get(k)
}
func (c *timedSessionCache) Put(k string, v *tls.ClientSessionState) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if v == nil {
		delete(c.created, k)
	} else {
		if len(c.created) >= 8 {
			for name := range c.created {
				c.cache.Put(name, nil)
			}
			clear(c.created)
		}
		c.created[k] = time.Now()
	}
	c.cache.Put(k, v)
}

type cacheProfile struct {
	cache   *timedSessionCache
	used    time.Time
	created time.Time
}

var cacheProfiles = struct {
	sync.Mutex
	profiles map[[32]byte]*cacheProfile
}{profiles: map[[32]byte]*cacheProfile{}}

func applySessionCache(tc *tls.Config, cfg settings) error {
	if cfg.SessionCacheSize == 0 {
		return nil
	}
	if cfg.SessionCacheSize != 8 || len(cfg.NetworkEpoch) > 64 {
		return fmt.Errorf("cache requires size8 and bounded network epoch")
	}
	roots := []byte("system-roots")
	if cfg.CAFile != "" {
		var e error
		roots, e = os.ReadFile(cfg.CAFile)
		if e != nil {
			return e
		}
	}
	rootHash := sha256.Sum256(roots)
	credentialHash := sha256.Sum256([]byte(canonicalKey(cfg.Key)))
	key := sha256.Sum256([]byte(fmt.Sprintf("%s\x00%s\x00%s\x00%s\x00%x\x00%x", cfg.Server, cfg.Name, cfg.TestCurve, cfg.NetworkEpoch, rootHash, credentialHash)))
	cacheProfiles.Lock()
	defer cacheProfiles.Unlock()
	p := cacheProfiles.profiles[key]
	if p != nil && time.Since(p.created) > time.Minute {
		delete(cacheProfiles.profiles, key)
		p = nil
	}
	if p == nil {
		if len(cacheProfiles.profiles) >= 16 {
			var oldest [32]byte
			var when time.Time
			for k, v := range cacheProfiles.profiles {
				if when.IsZero() || v.used.Before(when) {
					oldest = k
					when = v.used
				}
			}
			delete(cacheProfiles.profiles, oldest)
		}
		p = &cacheProfile{created: time.Now(), cache: &timedSessionCache{cache: tls.NewLRUClientSessionCache(8), created: map[string]time.Time{}}}
		cacheProfiles.profiles[key] = p
	}
	p.used = time.Now()
	tc.ClientSessionCache = p.cache
	return nil
}
