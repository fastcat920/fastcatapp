//go:build go1.25

package fastcattls

import "crypto/tls"

func negotiatedGroup(state tls.ConnectionState) string {
	if state.CurveID == 0 {
		return ""
	}
	return state.CurveID.String()
}
