package main

import (
	"math"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

func (s *Server) httpServer() *http.Server {
	return &http.Server{
		Addr: s.cfg.ListenAddr, Handler: s.routes(),
		ReadHeaderTimeout: time.Duration(positiveEnvInt("DG_SERVER_HEADER_TIMEOUT_SECONDS", 5)) * time.Second,
		ReadTimeout:       time.Duration(positiveEnvInt("DG_SERVER_READ_TIMEOUT_SECONDS", 30)) * time.Second,
		WriteTimeout:      time.Duration(positiveEnvInt("DG_SERVER_WRITE_TIMEOUT_SECONDS", 90)) * time.Second,
		IdleTimeout:       time.Duration(positiveEnvInt("DG_SERVER_IDLE_TIMEOUT_SECONDS", 60)) * time.Second,
		MaxHeaderBytes:    32 << 10,
	}
}

type requestBucket struct {
	tokens float64
	last   time.Time
}
type gatewayRequestLimits struct {
	mu         sync.Mutex
	buckets    map[string]requestBucket
	lastSweep  time.Time
	maxKeys    int
	login      int
	create     int
	poll       int
	admin      int
	publicAuth int
}

func newGatewayRequestLimits() *gatewayRequestLimits {
	return &gatewayRequestLimits{buckets: map[string]requestBucket{},
		maxKeys:    positiveEnvInt("DG_RATE_LIMIT_MAX_KEYS", 4096),
		login:      positiveEnvInt("DG_LOGIN_RATE_PER_MINUTE", 60),
		create:     positiveEnvInt("DG_QR_CREATE_RATE_PER_MINUTE", 60),
		poll:       positiveEnvInt("DG_QR_POLL_RATE_PER_MINUTE", 2400),
		admin:      positiveEnvInt("DG_ADMIN_RATE_PER_MINUTE", 600),
		publicAuth: positiveEnvInt("DG_PUBLIC_AUTH_RATE_PER_MINUTE", 30)}
}

// Bounded per-IP token buckets are intentionally separate: login/create abuse
// cannot consume a target's polling budget or authenticated heartbeats. This
// is a per-process boundary; use a shared edge limiter for a cluster-wide quota.
func (l *gatewayRequestLimits) allow(key string, perMinute int, now time.Time) (bool, int) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if now.Sub(l.lastSweep) >= time.Minute {
		for key, bucket := range l.buckets {
			if now.Sub(bucket.last) >= 2*time.Minute {
				delete(l.buckets, key)
			}
		}
		l.lastSweep = now
	}
	bucket, exists := l.buckets[key]
	if !exists {
		if len(l.buckets) >= l.maxKeys {
			return false, 60
		}
		bucket = requestBucket{tokens: float64(perMinute), last: now}
	}
	rate := float64(perMinute) / 60
	if now.After(bucket.last) {
		bucket.tokens = math.Min(float64(perMinute), bucket.tokens+now.Sub(bucket.last).Seconds()*rate)
	}
	bucket.last = now
	allowed := bucket.tokens >= 1
	if allowed {
		bucket.tokens--
	}
	l.buckets[key] = bucket
	if !allowed {
		return false, int(math.Ceil((1 - bucket.tokens) / rate))
	}
	return true, 0
}

func (s *Server) withBoundaryLimits(next http.Handler) http.Handler {
	s.limitsOnce.Do(func() { s.requestLimits = newGatewayRequestLimits() })
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		prefix := s.cfg.APIPrefix
		class, quota := "", 0
		switch {
		case r.URL.Path == prefix+"/passport/auth/login":
			class, quota = "login", s.requestLimits.login
		case r.URL.Path == prefix+"/passport/auth/register" || r.URL.Path == prefix+"/passport/auth/forget" || r.URL.Path == prefix+"/passport/comm/sendEmailVerify":
			class, quota = "public-auth", s.requestLimits.publicAuth
		case r.URL.Path == prefix+"/auth/qr/sessions":
			class, quota = "qr-create", s.requestLimits.create
		case strings.HasPrefix(r.URL.Path, prefix+"/auth/qr/sessions/"):
			class, quota = "qr-poll", s.requestLimits.poll
		case strings.HasPrefix(r.URL.Path, prefix+"/admin/"):
			class, quota = "admin", s.requestLimits.admin
		}
		if class != "" && r.Method != http.MethodOptions {
			key := s.hashValue("rate", class+"|"+s.clientIP(r))
			if ok, retry := s.requestLimits.allow(key, quota, time.Now()); !ok {
				w.Header().Set("Retry-After", strconv.Itoa(retry))
				writeError(w, http.StatusTooManyRequests, "RATE_LIMITED", "Too many requests, please retry shortly", nil)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}
