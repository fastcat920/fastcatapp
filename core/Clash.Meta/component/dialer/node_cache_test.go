package dialer

import (
	"encoding/json"
	"net/netip"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestNodeCachePersistenceAndLimits(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nodes.json")
	original := NodeCachePath
	NodeCachePath = func() string { return path }
	defer func() { NodeCachePath = original }()
	saveNodeIP(path, "node.example:443", netip.MustParseAddr("1.1.1.1"))
	if got := cachedNodeIP("node.example:443", "tcp4"); len(got) != 1 {
		t.Fatal("persisted address unavailable")
	}
	if got := cachedNodeIP("node.example:443", "tcp6"); len(got) != 0 {
		t.Fatal("wrong address family")
	}
	if got := cachedNodeIP("node.example:8443", "tcp"); len(got) != 0 {
		t.Fatal("cache crossed endpoint port")
	}
	saveNodeIP(path, "private.example:443", netip.MustParseAddr("192.168.1.1"))
	if got := cachedNodeIP("private.example:443", "tcp"); len(got) != 0 {
		t.Fatal("private address persisted")
	}
	entries := readNodeCache(path)
	entry := entries["node.example:443"]
	entry.Saved = time.Now().Add(-25 * time.Hour)
	entries["node.example:443"] = entry
	data, _ := json.Marshal(entries)
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	if got := cachedNodeIP("node.example:443", "tcp"); len(got) != 0 {
		t.Fatal("expired address reused")
	}
	if err := os.WriteFile(path, []byte("invalid"), 0600); err != nil {
		t.Fatal(err)
	}
	if got := cachedNodeIP("node.example:443", "tcp"); len(got) != 0 {
		t.Fatal("corrupt cache used")
	}
}
