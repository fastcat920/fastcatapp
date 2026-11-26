package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

type credential struct {
	ID        string `json:"id"`
	Key       string `json:"key"`
	NotBefore int64  `json:"not_before"`
	NotAfter  int64  `json:"not_after"`
	Disabled  bool   `json:"disabled"`
}
type credentialDocument struct {
	Revision uint64       `json:"revision"`
	Keys     []credential `json:"keys"`
}
type credentialLease struct {
	fingerprint [32]byte
	cancel      context.CancelFunc
	mu          sync.Mutex
	conn        net.Conn
	closed      bool
	interrupt   func()
}

func (l *credentialLease) stop() {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.closed {
		return
	}
	l.closed = true
	l.cancel()
	if l.conn != nil {
		l.conn.Close()
	}
	l.interrupt()
}
func (l *credentialLease) bind(c net.Conn) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.closed {
		c.Close()
		return false
	}
	l.conn = c
	return true
}

type credentialStore struct {
	mu     sync.Mutex
	doc    credentialDocument
	digest [32]byte
	active map[*credentialLease]bool
}

func credentialActive(k credential, now time.Time) bool {
	return !k.Disabled && now.Unix() >= k.NotBefore && now.Unix() < k.NotAfter
}
func canonicalKey(s string) string { b, _ := hex.DecodeString(s); return hex.EncodeToString(b) }
func credentialFingerprint(k credential) [32]byte {
	return sha256.Sum256([]byte(k.ID + "\x00" + canonicalKey(k.Key)))
}
func parseCredentials(b []byte) (credentialDocument, error) {
	var d credentialDocument
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	if len(b) > 8192 {
		return d, errors.New("credentials too large")
	}
	if e := dec.Decode(&d); e != nil {
		return d, errors.New("invalid credentials document")
	}
	var extra any
	if dec.Decode(&extra) != io.EOF {
		return d, errors.New("trailing credentials data")
	}
	if d.Revision == 0 || len(d.Keys) < 1 || len(d.Keys) > 4 {
		return d, errors.New("credentials revision or count")
	}
	ids := map[string]bool{}
	keys := map[string]bool{}
	for _, k := range d.Keys {
		if len(k.ID) < 1 || len(k.ID) > 32 || ids[k.ID] || keys[canonicalKey(k.Key)] || k.NotBefore < 0 || k.NotAfter <= k.NotBefore {
			return d, errors.New("invalid credential entry")
		}
		for _, c := range k.ID {
			if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
				return d, errors.New("invalid credential ID")
			}
		}
		if _, e := keyBytes(k.Key); e != nil {
			return d, errors.New("invalid credential key")
		}
		ids[k.ID] = true
		keys[canonicalKey(k.Key)] = true
	}
	return d, nil
}
func (s *credentialStore) reload(path string) error {
	fd, e := syscall.Open(path, syscall.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if e != nil {
		return errors.New("credentials open failed")
	}
	f := os.NewFile(uintptr(fd), path)
	defer f.Close()
	st, e := f.Stat()
	if e != nil || !st.Mode().IsRegular() || st.Mode().Perm()&0077 != 0 {
		return errors.New("credentials require private regular file")
	}
	if raw, ok := st.Sys().(*syscall.Stat_t); !ok || raw.Uid != uint32(os.Geteuid()) {
		return errors.New("credentials owner mismatch")
	}
	b, e := io.ReadAll(io.LimitReader(f, 8193))
	if e != nil {
		return errors.New("credentials read failed")
	}
	d, e := parseCredentials(b)
	if e != nil {
		return e
	}
	digest := sha256.Sum256(b)
	s.mu.Lock()
	if d.Revision < s.doc.Revision || d.Revision == s.doc.Revision && digest != s.digest {
		s.mu.Unlock()
		return errors.New("credentials rollback or revision reuse")
	}
	s.doc = d
	s.digest = digest
	if s.active == nil {
		s.active = map[*credentialLease]bool{}
	}
	stale := s.staleLocked(time.Now())
	s.mu.Unlock()
	for _, l := range stale {
		l.stop()
	}
	return nil
}
func (s *credentialStore) allowedLocked(fp [32]byte, now time.Time) bool {
	for _, k := range s.doc.Keys {
		if credentialActive(k, now) && credentialFingerprint(k) == fp {
			return true
		}
	}
	return false
}
func (s *credentialStore) staleLocked(now time.Time) []*credentialLease {
	var stale []*credentialLease
	for l := range s.active {
		if !s.allowedLocked(l.fingerprint, now) {
			delete(s.active, l)
			stale = append(stale, l)
		}
	}
	return stale
}
func (s *credentialStore) verify(state *tls.ConnectionState, token string, now time.Time) (string, [32]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var target string
	var fp [32]byte
	valid := false
	// Four HMAC checks irrespective of the number of configured keys. Dummy slots never authenticate.
	for i := 0; i < 4; i++ {
		key := make([]byte, 32)
		var k credential
		if i < len(s.doc.Keys) {
			k = s.doc.Keys[i]
			key, _ = keyBytes(k.Key)
		}
		v, e := verify(state, key, token, now)
		if i < len(s.doc.Keys) && e == nil && credentialActive(k, now) {
			target = v
			fp = credentialFingerprint(k)
			valid = true
		}
	}
	if !valid {
		return "", fp, errors.New("invalid capability")
	}
	return target, fp, nil
}
func (s *credentialStore) lease(parent context.Context, fp [32]byte, interrupt func()) (context.Context, *credentialLease, func(), error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.allowedLocked(fp, time.Now()) || len(s.active) >= 32 {
		return nil, nil, nil, errors.New("credential no longer active")
	}
	ctx, cancel := context.WithCancel(parent)
	l := &credentialLease{fingerprint: fp, cancel: cancel, interrupt: interrupt}
	s.active[l] = true
	return ctx, l, func() { s.mu.Lock(); delete(s.active, l); s.mu.Unlock(); cancel() }, nil
}
func (s *credentialStore) watch(path string) func() {
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGHUP)
	done := make(chan struct{})
	go func() {
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-done:
				return
			case <-signals:
				if s.reload(path) != nil {
					println("credential reload rejected; retained last valid revision")
				}
			case now := <-ticker.C:
				s.mu.Lock()
				stale := s.staleLocked(now)
				s.mu.Unlock()
				for _, l := range stale {
					l.stop()
				}
			}
		}
	}()
	return func() { signal.Stop(signals); close(done) }
}
