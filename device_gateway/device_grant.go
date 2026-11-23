package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const deviceGrantHeader = "X-FastCat-Device-Grant"

// Bind the authenticated device to this upstream account subscription. Never
// trust an assertion supplied by the client or put its proof in a URL.
func setDeviceGrantProof(req *http.Request, device *DeviceRecord, key string, now time.Time) {
	req.Header.Del(deviceGrantHeader)
	token := req.URL.Query().Get("token")
	if req.URL.Query().Get("fc_v2") != "1" || token == "" || device == nil || len(key) < 32 {
		return
	}
	ts := strconv.FormatInt(now.Unix(), 10)
	digest := sha256.Sum256([]byte(token))
	signed := "v2." + device.ID + "." + ts
	mac := hmac.New(sha256.New, []byte(key))
	mac.Write([]byte(signed + "." + hex.EncodeToString(digest[:])))
	req.Header.Set(deviceGrantHeader, signed+"."+hex.EncodeToString(mac.Sum(nil)))
}

// Go copies custom headers on redirects; the device assertion belongs only to
// the upstream which supplied this subscription URL.
func fetchDeviceSubscription(client *http.Client, req *http.Request) (*http.Response, error) {
	if req.Header.Get(deviceGrantHeader) == "" {
		return client.Do(req)
	}
	scoped := *client
	scoped.CheckRedirect = func(next *http.Request, prior []*http.Request) error {
		origin := prior[0].URL
		if !strings.EqualFold(origin.Scheme, next.URL.Scheme) || !strings.EqualFold(origin.Host, next.URL.Host) {
			next.Header.Del(deviceGrantHeader)
		}
		if client.CheckRedirect != nil {
			return client.CheckRedirect(next, prior)
		}
		if len(prior) >= 10 {
			return errors.New("stopped after 10 redirects")
		}
		return nil
	}
	return scoped.Do(req)
}
