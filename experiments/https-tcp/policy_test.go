package main

import (
	"context"
	"testing"
)

func TestTargetPolicy(t *testing.T) {
	for _, target := range []string{"100.100.100.200:80", "[64:ff9b::a00:1]:80", "127.0.0.1:80", "[::1]:80", "10.0.0.1:443", "169.254.169.254:80", "localhost:80", "example.com:0", "bad"} {
		if _, e := resolveTarget(context.Background(), target, false); e == nil {
			t.Fatalf("accepted %s", target)
		}
	}
	if _, e := resolveTarget(context.Background(), "127.0.0.1:80", true); e != nil {
		t.Fatal(e)
	}
}
