package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func TestBundledGeoDataPassesNativeParsing(t *testing.T) {
	previous := constant.Path.HomeDir()
	defer constant.SetHomeDir(previous)
	home, err := filepath.Abs("../assets/data")
	if err != nil {
		t.Fatal(err)
	}
	constant.SetHomeDir(home)
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	result := checkGeoData(ctx, home)
	if result.Error != "" || len(result.Invalid) != 0 {
		t.Fatalf("bundled Geo check: %+v", result)
	}
	// A second check does not parse the unchanged 34 MB again.
	if len(validGeoFiles) < 4 {
		t.Fatal("valid file metadata was not cached")
	}
}

func TestGeoDataReportsMissingEmptyAndCorruptFiles(t *testing.T) {
	previous := constant.Path.HomeDir()
	defer constant.SetHomeDir(previous)
	home := t.TempDir()
	constant.SetHomeDir(home)
	if err := os.WriteFile(filepath.Join(home, "Country.mmdb"), []byte("broken"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, "GeoIP.dat"), nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, "GeoSite.dat"), []byte("invalid protobuf"), 0o600); err != nil {
		t.Fatal(err)
	}
	result := checkGeoData(context.Background(), home)
	if result.Error != "" || len(result.Invalid) != 4 {
		t.Fatalf("invalid Geo check: %+v", result)
	}
	if result.Invalid[0] != "Country.mmdb" {
		t.Fatalf("did not preserve alias: %+v", result)
	}
}

func TestGeoCheckTimeoutDoesNotClassifyFilesAsCorrupt(t *testing.T) {
	previous := constant.Path.HomeDir()
	defer constant.SetHomeDir(previous)
	home := t.TempDir()
	constant.SetHomeDir(home)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	result := checkGeoData(ctx, home)
	if result.Error == "" || len(result.Invalid) != 0 {
		t.Fatalf("timeout should not trigger recovery: %+v", result)
	}
}

func TestGeoHomeMustBeReadableDirectory(t *testing.T) {
	file := filepath.Join(t.TempDir(), "not-a-directory")
	if err := os.WriteFile(file, []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{"", "relative", file} {
		if checkGeoHome(path, false) == nil {
			t.Fatalf("accepted invalid home %q", path)
		}
	}
	previous, previousInit := constant.Path.HomeDir(), isInit
	defer func() { constant.SetHomeDir(previous); isInit = previousInit }()
	isInit = false
	params, _ := json.Marshal(InitParams{HomeDir: file})
	if handleInitClash(string(params)) || isInit {
		t.Fatal("invalid home initialized core")
	}
}

func TestListenerStartRejectsMissingConfiguration(t *testing.T) {
	oldConfig, oldInit, oldRunning := currentConfig, isInit, isRunning
	defer func() { currentConfig, isInit, isRunning = oldConfig, oldInit, oldRunning }()
	for _, initialized := range []bool{false, true} {
		for _, cfg := range []*config.Config{nil, {}} {
			isInit, isRunning, currentConfig = initialized, true, cfg
			if handleStartListener() || isRunning {
				t.Fatal("missing config reported listening")
			}
		}
	}
}

func TestExpiredConfigurationCannotCommit(t *testing.T) {
	oldConfig, oldURL := currentConfig, testURL
	defer func() { currentConfig, testURL = oldConfig, oldURL }()
	sentinel := &config.Config{}
	currentConfig, testURL = sentinel, "old-url"
	params := &SetupParams{Config: config.DefaultRawConfig(), TestURL: "new-url", DeadlineUnixMs: time.Now().Add(-time.Second).UnixMilli()}
	if err := setupConfig(params); err == nil || !strings.Contains(err.Error(), "expired") {
		t.Fatalf("entry deadline: %v", err)
	}
	// Models a parse that started on time but finished after its caller timed out.
	if err := commitSetupConfig(params, &config.Config{General: &config.General{}}); err == nil {
		t.Fatal("late parsed config committed")
	}
	if currentConfig != sentinel || testURL != "old-url" {
		t.Fatal("expired request changed active state")
	}
	if err := checkSetupDeadline(0); err != nil {
		t.Fatal("legacy native calls must remain compatible")
	}
}

func TestExpiredConfigurationUpdateCannotChangeModeOrTun(t *testing.T) {
	previous := currentConfig
	defer func() { currentConfig = previous }()
	currentConfig = &config.Config{General: &config.General{Mode: tunnel.Rule}}
	nextMode := tunnel.Global
	params := &UpdateParams{
		Mode:           &nextMode,
		Tun:            &tunSchema{Enable: true},
		DeadlineUnixMs: time.Now().Add(-time.Second).UnixMilli(),
	}
	if err := updateConfig(params); err == nil || !strings.Contains(err.Error(), "expired") {
		t.Fatalf("expired update: %v", err)
	}
	if currentConfig.General.Mode != tunnel.Rule || currentConfig.General.Tun.Enable {
		t.Fatal("expired update changed the live profile")
	}
}
