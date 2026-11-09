package main

import (
	"sort"
	"time"
)

// Order device views using one request timestamp, so ordering and online badges
// agree even when a device crosses the heartbeat cutoff while rendering.
func deviceOnlineAt(device *DeviceRecord, now time.Time) bool {
	return device.Status == statusActive && now.Sub(device.LastSeenAt) < 5*time.Minute
}

func sortDeviceList(devices []*DeviceRecord, currentDeviceID string, now time.Time) {
	rank := func(device *DeviceRecord) int {
		if currentDeviceID != "" && device.ID == currentDeviceID {
			return 0
		}
		if deviceOnlineAt(device, now) {
			return 1
		}
		if device.Status == statusActive {
			return 2
		}
		return 3
	}
	sort.Slice(devices, func(i, j int) bool {
		a, b := devices[i], devices[j]
		if ar, br := rank(a), rank(b); ar != br {
			return ar < br
		}
		// Compare instants, not RFC3339 strings with potentially different offsets.
		if !a.LastSeenAt.Equal(b.LastSeenAt) {
			return a.LastSeenAt.After(b.LastSeenAt)
		}
		return a.ID < b.ID
	})
}
