package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/component/geodata/router"
	"github.com/metacubex/mihomo/constant"
	"github.com/oschwald/maxminddb-golang"
	"google.golang.org/protobuf/proto"
)

type geoHealthResult struct {
	Invalid []string `json:"invalid"`
	Error   string   `json:"error"`
}

type geoValidationStamp struct {
	Size     int64
	Modified time.Time
}

var geoValidationMu sync.Mutex
var validGeoFiles = map[string]geoValidationStamp{}

// The UI supplies the user's data directory, even when the core runs via the
// Windows Helper. Never substitute the elevated account's profile directory.
func checkGeoHome(home string, create bool) error {
	if strings.TrimSpace(home) == "" || !filepath.IsAbs(home) {
		return errors.New("Geo data directory must be a non-empty absolute path")
	}
	if create {
		if err := os.MkdirAll(home, 0o700); err != nil {
			return fmt.Errorf("cannot create Geo data directory: %w", err)
		}
	}
	if _, err := os.ReadDir(home); err != nil {
		return fmt.Errorf("cannot read Geo data directory: %w", err)
	}
	return nil
}

func handleCheckGeoData() string {
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	result := checkGeoData(ctx, constant.Path.HomeDir())
	encoded, _ := json.Marshal(result)
	return string(encoded)
}

func checkGeoData(ctx context.Context, home string) geoHealthResult {
	result := geoHealthResult{Invalid: []string{}}
	if err := checkGeoHome(home, false); err != nil {
		result.Error = err.Error()
		return result
	}
	geoValidationMu.Lock()
	defer geoValidationMu.Unlock()
	// Resolve aliases exactly as the core does; do not overwrite an updated
	// Country.mmdb merely because the bundled file is named geoip.metadb.
	paths := []string{constant.Path.MMDB(), constant.Path.ASN(), constant.Path.GeoIP(), constant.Path.GeoSite()}
	for _, path := range paths {
		if err := ctx.Err(); err != nil {
			result.Error = "Geo data validation timed out"
			return result
		}
		info, err := os.Stat(path)
		if errors.Is(err, os.ErrNotExist) {
			result.Invalid = append(result.Invalid, filepath.Base(path))
			continue
		}
		if err != nil || !info.Mode().IsRegular() {
			result.Error = fmt.Sprintf("cannot read Geo data file %s", filepath.Base(path))
			return result
		}
		stamp := geoValidationStamp{Size: info.Size(), Modified: info.ModTime()}
		if cached, ok := validGeoFiles[path]; ok && cached == stamp {
			continue
		}
		delete(validGeoFiles, path)
		err = validateGeoFile(ctx, path, info.Size())
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
			result.Error = "Geo data validation timed out"
			return result
		}
		var pathErr *os.PathError
		if errors.As(err, &pathErr) {
			result.Error = fmt.Sprintf("cannot read Geo data file %s: %v", filepath.Base(path), pathErr.Err)
			return result
		}
		if err != nil {
			result.Invalid = append(result.Invalid, filepath.Base(path))
			continue
		}
		validGeoFiles[path] = stamp
	}
	return result
}

func validateGeoFile(ctx context.Context, path string, size int64) error {
	if size == 0 {
		return errors.New("empty Geo data")
	}
	name := strings.ToLower(filepath.Base(path))
	if name == "geoip.dat" || name == "geosite.dat" {
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if name == "geoip.dat" {
			var list router.GeoIPList
			if err := proto.Unmarshal(data, &list); err != nil {
				return err
			}
			if len(list.Entry) == 0 {
				return errors.New("empty GeoIP list")
			}
		} else {
			var list router.GeoSiteList
			if err := proto.Unmarshal(data, &list); err != nil {
				return err
			}
			if len(list.Entry) == 0 {
				return errors.New("empty GeoSite list")
			}
		}
		return ctx.Err()
	}
	reader, err := maxminddb.Open(path)
	if err != nil {
		return err
	}
	defer reader.Close()
	// Use the same decoder as lookups, not Reader.Verify's deliberately stricter
	// metadata rules, which reject some readable third-party database updates.
	networks := reader.Networks(maxminddb.SkipAliasedNetworks)
	for networks.Next() {
		if err := ctx.Err(); err != nil {
			return err
		}
		var value any
		if _, err := networks.Network(&value); err != nil {
			return err
		}
	}
	return networks.Err()
}
