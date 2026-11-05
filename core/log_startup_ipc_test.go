//go:build !cgo

package main

import (
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"
)

// Exercise the desktop process/IPC path, not just a pre-initialized fixture.
// The child does not load a profile or change any system proxy/DNS settings.
func TestColdStartLoggingIPCProcess(t *testing.T) {
	const envKey = "FASTCAT_TEST_LOG_IPC_PORT"
	if port := os.Getenv(envKey); port != "" {
		startServer(port)
		return
	}
	listener, err := net.ListenTCP("tcp", &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	if err := listener.SetDeadline(time.Now().Add(10 * time.Second)); err != nil {
		t.Fatal(err)
	}
	_, port, _ := net.SplitHostPort(listener.Addr().String())
	child := exec.Command(os.Args[0], "-test.run=^TestColdStartLoggingIPCProcess$")
	child.Env = append(os.Environ(), envKey+"="+port)
	var output strings.Builder
	child.Stdout, child.Stderr = &output, &output
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = child.Process.Kill(); _ = child.Wait() }()
	connection, err := listener.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer connection.Close()
	if err := connection.SetDeadline(time.Now().Add(10 * time.Second)); err != nil {
		t.Fatal(err)
	}
	encoder, decoder := json.NewEncoder(connection), json.NewDecoder(connection)
	for _, step := range []struct {
		method Method
		data   interface{}
		want   interface{}
	}{
		{updateConfigMethod, `{"log-level":"info"}`, ""},
		{updateConfigMethod, `{"mixed-port":7890}`, "core configuration is not ready; apply a profile before updating it"},
		{updateConfigMethod, `null`, "missing configuration update"},
		{updateConfigMethod, `{"log-level":"error"}`, ""},
		{updateConfigMethod, `{"log-level":"info"}`, ""},
		{getIsInitMethod, nil, false}, // still alive and has not fabricated config
	} {
		if err := encoder.Encode(Action{Id: "cold-start", Method: step.method, Data: step.data}); err != nil {
			t.Fatal(err)
		}
		var result ActionResult
		if err := decoder.Decode(&result); err != nil {
			t.Fatalf("core did not survive %s: %v", step.method, err)
		}
		if result.Id != "cold-start" || result.Data != step.want {
			t.Fatalf("%s returned %+v; expected %v", step.method, result, step.want)
		}
	}
}
