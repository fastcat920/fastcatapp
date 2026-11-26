package main

import (
	"context"
	"crypto/x509"
	"fmt"
	"net"
	"time"
)

func runIdle(ctx context.Context, cfg configuration, roots *x509.CertPool, versions []string, target string, seconds int, emit func(sample)) error {
	type group struct {
		v, p  string
		c     client
		ended time.Time
	}
	groups := []group{}
	defer func() {
		for _, g := range groups {
			g.c.close()
		}
	}()
	for _, p := range comparisonProtocols(versions) {
		for _, v := range versions {
			if !comparisonCase(v, p) {
				continue
			}
			c, e := newClient(ctx, cfg, roots, v, p)
			if e != nil {
				failure := fmt.Errorf("idle prepare failed: %w", e)
				c = client{dial: func(context.Context, string) (net.Conn, error) { return nil, failure }, close: func() {}}
			}
			s := sample{Phase: "idle-prime", Version: v, Protocol: p}
			start := time.Now()
			s.Start = start.UnixMicro()
			child, stop := context.WithTimeout(ctx, 12*time.Second)
			e = request(child, c, target, roots, &s, start)
			stop()
			s.Elapsed = time.Since(start).Microseconds()
			if e != nil {
				s.Error = e.Error()
			}
			emit(s)
			groups = append(groups, group{v, p, c, time.Now()})
		}
	}
	timer := time.NewTimer(time.Duration(seconds) * time.Second)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
	}
	for _, g := range groups {
		for round := 0; round < 3; round++ {
			s := sample{Phase: "idle-resume", Version: g.v, Protocol: g.p, Round: round + 1, IdleUS: time.Since(g.ended).Microseconds()}
			start := time.Now()
			s.Start = start.UnixMicro()
			child, stop := context.WithTimeout(ctx, 12*time.Second)
			e := request(child, g.c, target, roots, &s, start)
			stop()
			s.Elapsed = time.Since(start).Microseconds()
			if e != nil {
				s.Error = e.Error()
			}
			emit(s)
			g.ended = time.Now()
		}
	}
	return nil
}
