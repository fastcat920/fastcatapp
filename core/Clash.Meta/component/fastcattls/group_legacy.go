//go:build !go1.25

package fastcattls

import "crypto/tls"

func negotiatedGroup(tls.ConnectionState) string { return "" }
