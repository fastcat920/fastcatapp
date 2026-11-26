package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

// Exercise the shipped flags, TLS server and signal handler in a real process.
func TestServerDeviceCredentials(t *testing.T) {
	dir := t.TempDir()
	binary := os.Getenv("FASTCAT_TEST_V1_BINARY")
	if binary == "" {
		binary = filepath.Join(dir, "fastcat-https")
		if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
			t.Fatalf("build: %v %s", err, out)
		}
	}
	cert := httptest.NewTLSServer(http.NotFoundHandler())
	pair := cert.TLS.Certificates[0]
	roots := x509.NewCertPool()
	roots.AddCert(cert.Certificate())
	cert.Close()
	private, err := x509.MarshalPKCS8PrivateKey(pair.PrivateKey)
	if err != nil {
		t.Fatal(err)
	}
	write := func(path string, data []byte) {
		t.Helper()
		if err := os.WriteFile(path, data, 0600); err != nil {
			t.Fatal(err)
		}
	}
	certPath, keyPath := filepath.Join(dir, "cert.pem"), filepath.Join(dir, "key.pem")
	write(certPath, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: pair.Certificate[0]}))
	write(keyPath, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: private}))
	echo, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer echo.Close()
	go func() {
		for {
			c, err := echo.Accept()
			if err != nil {
				return
			}
			go func() { defer c.Close(); io.Copy(c, c) }()
		}
	}()
	const old = "fixture-legacy-with spaces-0123456789"
	const a = "fixture-device-a-01234567890123456789"
	const b = "fixture-device-b-01234567890123456789"
	const foreign = "fixture-other-device-01234567890123456789"
	start := func(t *testing.T, envToken string, extra ...string) (*os.Process, string, string) {
		t.Helper()
		ln, err := net.Listen("tcp4", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		address := ln.Addr().String()
		ln.Close()
		args := []string{"-mode", "server", "-listen", address, "-cert", certPath, "-key", keyPath, "-target", echo.Addr().String(), "-session-timeout", "10s"}
		cmd := exec.Command(binary, append(args, extra...)...)
		cmd.Env = append(os.Environ(), "FASTCAT_LAB_TOKEN="+envToken)
		logfile := filepath.Join(t.TempDir(), "server.log")
		f, err := os.Create(logfile)
		if err != nil {
			t.Fatal(err)
		}
		cmd.Stderr = f
		if err = cmd.Start(); err != nil {
			f.Close()
			t.Fatal(err)
		}
		f.Close()
		t.Cleanup(func() { cmd.Process.Kill(); cmd.Wait() })
		return cmd.Process, address, logfile
	}
	connect := func(address string, tokens ...string) (int, net.Conn, error) {
		raw, err := tls.DialWithDialer(&net.Dialer{Timeout: time.Second}, "tcp", address, &tls.Config{RootCAs: roots, MinVersion: tls.VersionTLS12})
		if err != nil {
			return 0, nil, err
		}
		raw.SetDeadline(time.Now().Add(3 * time.Second))
		w := bufio.NewWriter(raw)
		fmt.Fprintf(w, "CONNECT %s HTTP/1.1\r\nHost: %s\r\n", echo.Addr(), echo.Addr())
		for _, token := range tokens {
			fmt.Fprintf(w, "Authorization: Bearer %s\r\n", token)
		}
		fmt.Fprint(w, "FastCat-Version: 1\r\n\r\n")
		if err = w.Flush(); err != nil {
			raw.Close()
			return 0, nil, err
		}
		resp, err := http.ReadResponse(bufio.NewReader(raw), &http.Request{Method: http.MethodConnect})
		if err != nil {
			raw.Close()
			return 0, nil, err
		}
		return resp.StatusCode, raw, nil
	}
	wait := func(t *testing.T, what string, ready func() bool) {
		t.Helper()
		deadline := time.Now().Add(4 * time.Second)
		for !ready() {
			if time.Now().After(deadline) {
				t.Fatal(what)
			}
			time.Sleep(15 * time.Millisecond)
		}
	}
	expect := func(t *testing.T, addr string, want int, tokens ...string) {
		t.Helper()
		wait(t, fmt.Sprintf("expected HTTP %d", want), func() bool {
			code, c, err := connect(addr, tokens...)
			if c != nil {
				c.Close()
			}
			return err == nil && code == want
		})
	}
	t.Run("legacy single token", func(t *testing.T) {
		_, addr, _ := start(t, old)
		expect(t, addr, 200, old)
		expect(t, addr, 403, a)
		expect(t, addr, 403, old, old)
	})
	t.Run("file reload", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "grants")
		write(path, []byte(a+"\n"+b+"\n"))
		proc, addr, logfile := start(t, old, "-tokens-file", path)
		expect(t, addr, 200, a)
		expect(t, addr, 200, b)
		expect(t, addr, 403, old)
		expect(t, addr, 403, foreign)
		expect(t, addr, 403, a, b)
		_, live, err := connect(addr, a)
		if err != nil {
			t.Fatal(err)
		}
		defer live.Close()
		reload := func(content string) {
			t.Helper()
			write(path+".tmp", []byte(content))
			if err := os.Rename(path+".tmp", path); err != nil {
				t.Fatal(err)
			}
			if err := proc.Signal(syscall.SIGHUP); err != nil {
				t.Fatal(err)
			}
		}
		reload(b + "\n")
		expect(t, addr, 403, a)
		expect(t, addr, 200, b)
		msg := []byte("established stream")
		if _, err := live.Write(msg); err != nil {
			t.Fatal(err)
		}
		got := make([]byte, len(msg))
		if _, err = io.ReadFull(live, got); err != nil || string(got) != string(msg) {
			t.Fatal("revocation interrupted an established session", err)
		}

		for i, invalid := range []string{"short\n", b + "\n" + b + "\n"} {
			reload(invalid)
			wait(t, "reload error was not observed", func() bool {
				data, _ := os.ReadFile(logfile)
				return strings.Count(string(data), "device token reload failed:") >= i+1
			})
			expect(t, addr, 200, b)
			expect(t, addr, 403, a)
		}
		reload("")
		expect(t, addr, 403, b)
		expect(t, addr, 403, a)
		reload(a + "\n")
		expect(t, addr, 200, a)
		data, err := os.ReadFile(logfile)
		if err != nil {
			t.Fatal(err)
		}
		for _, token := range []string{old, a, b, foreign} {
			if strings.Contains(string(data), token) {
				t.Fatal("server logged credentials")
			}
		}
	})
	t.Run("empty startup file", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "grants")
		write(path, nil)
		_, addr, _ := start(t, old, "-tokens-file", path)
		expect(t, addr, 403, old)
		expect(t, addr, 403, a)
	})
	t.Run("invalid startup file", func(t *testing.T) {
		path := filepath.Join(t.TempDir(), "invalid")
		write(path, []byte("short\n"))
		for _, file := range []string{path, path + ".missing"} {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			cmd := exec.CommandContext(ctx, binary, "-mode", "server", "-tokens-file", file, "-listen", "127.0.0.1:0", "-cert", certPath, "-key", keyPath)
			cmd.Env = append(os.Environ(), "FASTCAT_LAB_TOKEN="+old)
			err := cmd.Run()
			timedOut := ctx.Err() != nil
			cancel()
			if err == nil || timedOut {
				t.Fatal("accepted invalid startup file")
			}
		}
	})
}
