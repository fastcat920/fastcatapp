package main

import (
	"context"
	"crypto/x509"
	"encoding/json"
	"errors"
	"net/http/httptrace"
	"os"
	"sync/atomic"
	"time"
)

func runDoHTrials(endpoint, name, bootstrap, ca string, n int) error {
	if name == "" || n < 1 || n > 1000 {
		return errors.New("DoH trials require a lookup name and 1–1000 samples")
	}
	var roots *x509.CertPool
	if ca != "" {
		pem, err := os.ReadFile(ca)
		if err != nil {
			return err
		}
		roots = x509.NewCertPool()
		if !roots.AppendCertsFromPEM(pem) {
			return errors.New("could not load CA bundle")
		}
	}
	client, u, closeIdle, err := newDoHClient(endpoint, bootstrap, roots)
	if err != nil {
		return err
	}
	defer closeIdle()
	freshClient, _, closeFresh, err := newDoHClient(endpoint, bootstrap, roots)
	if err != nil {
		return err
	}
	defer closeFresh()
	enc := json.NewEncoder(os.Stdout)
	for round := 0; round < n; round++ {
		for i := 0; i < 2; i++ {
			probe, mode := client, "shared"
			if (round+i)%2 != 0 {
				closeFresh()
				probe, mode = freshClient, "fresh"
			}
			var reused atomic.Bool
			ctx := httptrace.WithClientTrace(context.Background(), &httptrace.ClientTrace{
				GotConn: func(info httptrace.GotConnInfo) { reused.Store(info.Reused) },
			})
			ctx, cancel := context.WithTimeout(ctx, 4*time.Second)
			start := time.Now()
			_, err := lookupDoH(ctx, probe, u, name)
			elapsed := time.Since(start).Microseconds()
			cancel()
			if err := encodeTrial(enc, "doh", mode, round, elapsed, reused.Load(), err); err != nil {
				return err
			}
		}
	}
	return nil
}

func runECHPairs(address, name string, roots *x509.CertPool, ech []byte, n int) error {
	enc := json.NewEncoder(os.Stdout)
	modes := []struct {
		name string
		ech  []byte
	}{{"baseline", nil}, {"ech", ech}}
	for round := 0; round < n; round++ {
		paths := [2]string{"h2/tcp", "h3/quic"}
		for p := range paths {
			path := paths[(p+round)%len(paths)]
			for i := range modes {
				mode := modes[(round+i)%len(modes)]
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				start := time.Now()
				s, err := remoteHandshake(ctx, address, name, path, "default", roots, mode.ech)
				cancel()
				elapsed := s.took.Microseconds()
				if err != nil {
					elapsed = time.Since(start).Microseconds()
				}
				if err := encodeTrial(enc, path, mode.name, round, elapsed, false, err); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func encodeTrial(enc *json.Encoder, path, mode string, round int, elapsed int64, reused bool, err error) error {
	row := struct {
		Path    string `json:"path"`
		Mode    string `json:"mode"`
		Round   int    `json:"round"`
		Elapsed int64  `json:"elapsed_us"`
		Reused  bool   `json:"connection_reused,omitempty"`
		Error   string `json:"error,omitempty"`
	}{path, mode, round + 1, elapsed, reused, ""}
	if err != nil {
		row.Error = err.Error()
	}
	return enc.Encode(row)
}
