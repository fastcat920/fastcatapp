package fcnv3

import (
	"context"
	"testing"
	"time"
)

func TestNetworkChangeClosesTCPAndReopens(t *testing.T) {
	target, _ := startTestEcho(t)
	_, config := startTestServer(t, target)
	client := newTestClient(t, config)
	ctx, cancel := context.WithTimeout(t.Context(), 6*time.Second)
	defer cancel()
	if err := client.UpdateNetwork("wifi"); err != nil {
		t.Fatal(err)
	}
	first, err := client.acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	stream := dialTestStream(t, ctx, client, target)
	checkEcho(t, stream, []byte("before network change"))
	if err := client.UpdateNetwork("wifi"); err != nil {
		t.Fatal(err)
	}
	same, err := client.acquire(ctx)
	if err != nil || same != first {
		t.Fatalf("unchanged network lost its session: %v", err)
	}
	if err := client.UpdateNetwork("cellular"); err != nil {
		t.Fatal(err)
	}
	select {
	case <-first.quic.Context().Done():
	case <-ctx.Done():
		t.Fatal("previous QUIC connection remained open")
	}
	if _, err := stream.Read(make([]byte, 1)); err == nil {
		t.Fatal("previous TCP stream remained open")
	}
	next, err := client.acquire(ctx)
	if err != nil || next == first {
		t.Fatalf("new network did not establish a new connection: %v", err)
	}
	checkEchoAndHalfClose(t, dialTestStream(t, ctx, client, target), []byte("fresh traffic"))
}

func TestNetworkChangeRetiresDoHTransport(t *testing.T) {
	resolver, err := NewEntryDNSResolver(EntryDNSConfig{URL: "https://resolver.example/dns-query", BootstrapIP: "127.0.0.1"})
	if err != nil {
		t.Fatal(err)
	}
	client, err := NewClient(Config{Endpoint: "127.0.0.1:443", ServerName: "entry.example", Account: testAccount, Secret: testSecret, EntryDNS: resolver})
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	if err = client.UpdateNetwork("wifi"); err != nil {
		t.Fatal(err)
	}
	original := resolver.client.Transport
	staleContext, cancel := context.WithCancel(t.Context())
	defer cancel()
	resolver.pending["entry.example"] = &entryDNSRequest{cancel: cancel, done: make(chan struct{})}
	resolver.cache["entry.example"] = cachedEntryDNS{expires: time.Now().Add(time.Minute)}
	if err = client.UpdateNetwork("cellular"); err != nil {
		t.Fatal(err)
	}
	if original == resolver.client.Transport || len(resolver.pending) != 0 || len(resolver.cache) != 0 || staleContext.Err() == nil || !client.refreshEntry {
		t.Fatal("network change did not invalidate the DoH transport and pending answers")
	}
}
