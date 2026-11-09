package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http/httptest"
	"reflect"
	"testing"
	"time"
)

func TestDeviceSortStatusTimeAndStableTies(t *testing.T) {
	now := time.Date(2026, 11, 9, 12, 0, 0, 0, time.UTC)
	olderOffset := now.Add(-2 * time.Minute).In(time.FixedZone("UTC+8", 8*3600))
	devices := []*DeviceRecord{
		{ID: "revoked-new", Status: statusRevoked, LastSeenAt: now},
		{ID: "offline-old", Status: statusActive, LastSeenAt: now.Add(-time.Hour)},
		{ID: "online-old", Status: statusActive, LastSeenAt: olderOffset},
		{ID: "online-new", Status: statusActive, LastSeenAt: now.Add(-time.Minute)},
		{ID: "current", Status: statusActive, LastSeenAt: now.Add(-24 * time.Hour)},
		{ID: "tie-b", Status: statusActive, LastSeenAt: now.Add(-10 * time.Minute)},
		{ID: "tie-a", Status: statusActive, LastSeenAt: now.Add(-10 * time.Minute).In(time.FixedZone("UTC-5", -5*3600))},
		{ID: "missing-time", Status: statusActive},
		{ID: "revoked-old", Status: statusRevoked, LastSeenAt: now.Add(-24 * time.Hour)},
	}
	want := []string{"current", "online-new", "online-old", "tie-a", "tie-b", "offline-old", "missing-time", "revoked-new", "revoked-old"}
	for i := 0; i < 5; i++ {
		sortDeviceList(devices, "current", now)
		got := make([]string, len(devices))
		for j, d := range devices {
			got[j] = d.ID
		}
		if !reflect.DeepEqual(got, want) {
			t.Fatalf("order=%v want=%v", got, want)
		}
	}
	// The exact 5-minute cutoff is shared with the response badge.
	boundary := &DeviceRecord{ID: "boundary", Status: statusActive, LastSeenAt: now.Add(-5 * time.Minute)}
	if deviceOnlineAt(boundary, now) || publicDeviceAt(boundary, "", now)["is_online"] != false {
		t.Fatal("boundary classified inconsistently")
	}
	sortDeviceList(nil, "", now)
}

func TestUserDevicesResponseUsesStatusOrderAndKeepsCounts(t *testing.T) {
	now := time.Now()
	user := &UserCache{ID: "user"}
	current := &DeviceRecord{ID: "current", UserID: user.ID, Status: statusActive, LastSeenAt: now.Add(-time.Hour)}
	devices := map[string]*DeviceRecord{
		"current":    current,
		"online":     {ID: "online", UserID: user.ID, Status: statusActive, LastSeenAt: now},
		"offline":    {ID: "offline", UserID: user.ID, Status: statusActive, LastSeenAt: now.Add(-10 * time.Minute)},
		"history":    {ID: "history", UserID: user.ID, Status: statusRevoked, LastSeenAt: now},
		"other-user": {ID: "other-user", UserID: "other", Status: statusActive, LastSeenAt: now},
	}
	server := &Server{cfg: Config{DefaultDeviceLimit: 5}, store: &Store{Devices: devices}, log: log.New(io.Discard, "", 0)}
	w := httptest.NewRecorder()
	server.writeUserDevices(w, &SessionContext{User: user, Device: current})
	var result struct {
		Data struct {
			Devices []struct {
				ID      string `json:"id"`
				Current bool   `json:"is_current"`
				Online  bool   `json:"is_online"`
			} `json:"devices"`
			Count int `json:"active_count"`
			Limit int `json:"device_limit"`
		} `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	got := []string{}
	for _, d := range result.Data.Devices {
		got = append(got, d.ID)
	}
	if !reflect.DeepEqual(got, []string{"current", "online", "offline", "history"}) {
		t.Fatalf("order=%v", got)
	}
	if result.Data.Count != 3 || result.Data.Limit != 5 {
		t.Fatalf("counts changed: %+v", result.Data)
	}
	if !result.Data.Devices[0].Current || result.Data.Devices[0].Online || !result.Data.Devices[1].Online {
		t.Fatal("bad current/online badges")
	}
}
