package fcn

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
)

// AccountCredentials derives the per-account authentication key from the subscription UUID.
// The UUID remains a secret bearer credential, exactly as in other account-based protocols.
func AccountCredentials(uuid string) (string, []byte, error) {
	uuid = strings.ToLower(uuid)
	if len(uuid) != 36 || uuid[8] != '-' || uuid[13] != '-' || uuid[18] != '-' || uuid[23] != '-' {
		return "", nil, ErrAuth
	}
	raw, err := hex.DecodeString(strings.ReplaceAll(uuid, "-", ""))
	if err != nil || len(raw) != 16 {
		return "", nil, ErrAuth
	}
	sum := sha256.Sum256([]byte("fastcat:fcn:account:v1:\x00" + uuid))
	return uuid, append([]byte(nil), sum[:]...), nil
}

// AccountConfig pins the tested FCN profile. Versions share a wire format.
func AccountConfig(version int, endpoint, sni, uuid string) (Config, error) {
	a, k, e := AccountCredentials(uuid)
	if e != nil {
		return Config{}, e
	}
	c := Config{Endpoint: endpoint, ServerName: sni, Account: a, Key: k, Congestion: "bbr", QUICLanes: 1}
	switch version {
	case 1:
	case 2:
		c.QUICLanes = 2
		c.AdaptiveLanes = true
		c.RecoveryAware = true
	default:
		return Config{}, ErrProtocol
	}
	return c, nil
}
