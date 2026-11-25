package main

import (
	"crypto/sha256"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/component/ech"
)

func TestReadECHKeys(t *testing.T) {
	_, keyPEM, err := ech.GenECHConfig("public.fcn3.test")
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	path := filepath.Join(dir, "keys.pem")
	if err := os.WriteFile(path, []byte(keyPEM), 0600); err != nil {
		t.Fatal(err)
	}
	keys, version, err := readECHKeys(path)
	if err != nil || len(keys) != 1 || version != sha256.Sum256([]byte(keyPEM)) {
		t.Fatalf("expected one valid key and a matching file digest: %v", err)
	}
	link := filepath.Join(dir, "link.pem")
	if err := os.Symlink(path, link); err != nil {
		t.Fatal(err)
	}
	if _, _, err := readECHKeys(link); err == nil {
		t.Fatal("accepted a symbolic link")
	}
	if err := os.Chmod(path, 0644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := readECHKeys(path); err == nil || !strings.Contains(err.Error(), "mode 0600") {
		t.Fatalf("expected an error for incorrect permissions: %v", err)
	}
}

func TestReadECHKeysRejectsInvalidPEM(t *testing.T) {
	_, keyPEM, err := ech.GenECHConfig("public.fcn3.test")
	if err != nil {
		t.Fatal(err)
	}
	for name, data := range map[string]string{
		"empty":         "",
		"wrong type":    strings.ReplaceAll(keyPEM, "ECH KEYS", "PRIVATE KEY"),
		"trailing data": keyPEM + "unexpected data",
		"multiple":      keyPEM + keyPEM,
	} {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "keys.pem")
			if err := os.WriteFile(path, []byte(data), 0600); err != nil {
				t.Fatal(err)
			}
			if _, _, err := readECHKeys(path); err == nil {
				t.Fatal("accepted invalid PEM")
			}
		})
	}
}
