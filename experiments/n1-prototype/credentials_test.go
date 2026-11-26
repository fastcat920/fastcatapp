package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func writeCredentialDoc(t *testing.T, path string, d credentialDocument) {
	t.Helper()
	b, e := json.Marshal(d)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(path, b, 0600); e != nil {
		t.Fatal(e)
	}
}
func TestCredentialRotationRevokesLiveAndResumed(t *testing.T) {
	cfg, n, target := fixtureWithEmission(t, "coalesced")
	cfg.ClientEmission = "coalesced"
	cfg.SessionCacheSize = 8
	cfg.NetworkEpoch = "rotation"
	path := filepath.Join(t.TempDir(), "credentials.json")
	old := credential{ID: "old", Key: cfg.Key, NotAfter: time.Now().Add(time.Hour).Unix()}
	next := credential{ID: "next", Key: strings.Repeat("08", 32), NotAfter: old.NotAfter}
	d := credentialDocument{Revision: 1, Keys: []credential{old, next}}
	writeCredentialDoc(t, path, d)
	n.credentials = &credentialStore{}
	if e := n.credentials.reload(path); e != nil {
		t.Fatal(e)
	}
	cachedDialState(t, cfg, target)
	if !cachedDialState(t, cfg, target).DidResume {
		t.Fatal("expected resumed TLS")
	}
	live, e := dial(context.Background(), cfg, target)
	if e != nil {
		t.Fatal(e)
	}
	defer live.Close()
	payload := []byte("alive")
	if _, e = live.Write(payload); e != nil {
		t.Fatal(e)
	}
	got := make([]byte, len(payload))
	if _, e = io.ReadFull(live, got); e != nil || !bytes.Equal(got, payload) {
		t.Fatal(e)
	}
	d.Revision = 2
	d.Keys = []credential{next}
	writeCredentialDoc(t, path, d)
	if e = n.credentials.reload(path); e != nil {
		t.Fatal(e)
	}
	live.conn.SetReadDeadline(time.Now().Add(time.Second))
	if _, e = live.Read(make([]byte, 1)); e == nil {
		t.Fatal("revoked active session remained open")
	}
	if c, e := dial(context.Background(), cfg, target); e == nil {
		c.Close()
		t.Fatal("revoked credential authenticated")
	}
	cfg.Key = next.Key
	if cachedDialState(t, cfg, target).DidResume {
		t.Fatal("different credential reused ticket")
	}
	if !cachedDialState(t, cfg, target).DidResume {
		t.Fatal("new credential cannot resume")
	}
	d.Revision = 3
	d.Keys[0].Disabled = true
	writeCredentialDoc(t, path, d)
	if e = n.credentials.reload(path); e != nil {
		t.Fatal(e)
	}
	if c, e := dial(context.Background(), cfg, target); e == nil {
		c.Close()
		t.Fatal("deny-all fell back to legacy key")
	}
}
func TestCredentialReloadSafetyAndExpiry(t *testing.T) {
	path := filepath.Join(t.TempDir(), "keys")
	k := credential{ID: "one", Key: strings.Repeat("01", 32), NotAfter: time.Now().Add(time.Hour).Unix()}
	d := credentialDocument{Revision: 2, Keys: []credential{k}}
	writeCredentialDoc(t, path, d)
	s := &credentialStore{}
	if e := s.reload(path); e != nil {
		t.Fatal(e)
	}
	if e := s.reload(path); e != nil {
		t.Fatal("idempotent", e)
	}
	for _, bad := range []credentialDocument{{Revision: 1, Keys: []credential{k}}, {Revision: 2, Keys: []credential{{ID: "two", Key: k.Key, NotAfter: k.NotAfter}}}, {Revision: 3, Keys: []credential{k, k}}} {
		writeCredentialDoc(t, path, bad)
		if s.reload(path) == nil {
			t.Fatal("unsafe revision accepted")
		}
		if s.doc.Revision != 2 {
			t.Fatal("lost last good")
		}
	}
	os.Chmod(path, 0644)
	if s.reload(path) == nil {
		t.Fatal("public secret file")
	}
	os.Chmod(path, 0600)
	link := path + "-link"
	os.Symlink(path, link)
	if s.reload(link) == nil {
		t.Fatal("symlink accepted")
	}
	writeCredentialDoc(t, path, d)
	fp := credentialFingerprint(k)
	_, lease, release, e := s.lease(context.Background(), fp, func() {})
	if e != nil {
		t.Fatal(e)
	}
	defer release()
	s.mu.Lock()
	stale := s.staleLocked(time.Unix(k.NotAfter, 0))
	s.mu.Unlock()
	if len(stale) != 1 || stale[0] != lease {
		t.Fatal("expiry failed")
	}
	stale[0].stop()
	if !lease.closed {
		t.Fatal("lease not closed")
	}
}
func TestCredentialCacheIdentityIsolation(t *testing.T) {
	cfg := settings{Server: "cache.test:443", Name: "cache.test", SessionCacheSize: 8, Key: strings.Repeat("01", 32)}
	a, _ := tlsConfigFor(cfg)
	cfg.Key = strings.Repeat("02", 32)
	b, _ := tlsConfigFor(cfg)
	if a.ClientSessionCache == b.ClientSessionCache {
		t.Fatal("account caches shared")
	}
	_ = tls.VersionTLS13
}
func FuzzRecordDecode(f *testing.F) {
	for _, b := range [][]byte{{}, {0, 6, 0, 0, 0, 0, 0, 0}, {255, 255}, {0, 5, 0, 0, 0, 0, 0}} {
		f.Add(b)
	}
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > 65536 {
			return
		}
		r := &records{r: bytes.NewReader(b)}
		for i := 0; i < 8; i++ {
			v, e := r.read()
			if len(v) > maxPayload {
				t.Fatal("oversized payload")
			}
			if e != nil {
				return
			}
		}
	})
}
func FuzzCredentialDocument(f *testing.F) {
	f.Add([]byte(`{"revision":1,"keys":[]}`))
	f.Add([]byte(`null`))
	f.Fuzz(func(t *testing.T, b []byte) { _, _ = parseCredentials(b) })
}
func FuzzPublicTarget(f *testing.F) {
	f.Add("example.com:443")
	f.Add("127.0.0.1:1")
	f.Fuzz(func(t *testing.T, s string) {
		if len(s) > 8192 {
			return
		}
		_, _ = publicTargetName(s)
	})
}

func TestCredentialRegistrationCannotRaceRevocation(t *testing.T) {
	s := &credentialStore{active: map[*credentialLease]bool{}}
	k := credential{ID: "one", Key: strings.Repeat("01", 32), NotAfter: time.Now().Add(time.Hour).Unix()}
	s.doc = credentialDocument{Revision: 1, Keys: []credential{k}}
	fp := credentialFingerprint(k)
	s.mu.Lock()
	s.doc.Keys = nil
	s.mu.Unlock()
	if _, _, _, e := s.lease(context.Background(), fp, func() {}); e == nil {
		t.Fatal("verify/register race allowed revoked key")
	}
}

func FuzzCapabilityEnvelope(f *testing.F) {
	f.Add("")
	f.Add(strings.Repeat("A", 76))
	f.Add("invalid!")
	f.Fuzz(func(t *testing.T, s string) {
		if len(s) > 1024 {
			return
		}
		_, _ = verify(&tls.ConnectionState{}, make([]byte, 32), s, time.Unix(1795500000, 0))
	})
}
