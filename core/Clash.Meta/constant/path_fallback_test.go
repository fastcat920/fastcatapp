package constant

import (
	"path/filepath"
	"testing"
)

func TestMissingGeoDirectoryStillProducesConcretePaths(t *testing.T) {
	home := filepath.Join(t.TempDir(), "missing")
	p := &path{homeDir: home}
	for name, actual := range map[string]string{
		"geoip.metadb": p.MMDB(), "ASN.mmdb": p.ASN(),
		"GeoIP.dat": p.GeoIP(), "GeoSite.dat": p.GeoSite(),
	} {
		if actual != filepath.ToSlash(filepath.Join(home, name)) && actual != filepath.Join(home, name) {
			t.Fatalf("%s resolved to %q", name, actual)
		}
	}
}
