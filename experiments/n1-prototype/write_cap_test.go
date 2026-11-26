package main

import (
	"bytes"
	"encoding/binary"
	"io"
	"net/http/httputil"
	"testing"
)

func TestWriteCapEveryPaddingLength(t *testing.T) {
	for pad := 0; pad < 32; pad++ {
		p := make([]byte, 8+16337+pad)
		binary.BigEndian.PutUint16(p, uint16(len(p)-2))
		binary.BigEndian.PutUint16(p[6:], 16337)
		var b countedBuffer
		w := &chunkBatchWriter{destination: &b, maxWrite: 16384}
		if _, e := w.Write(p); e != nil || b.Len() > 16384 || b.calls != 1 {
			t.Fatal(pad, e, b.Len())
		}
	}
	p := make([]byte, 8+16384+31)
	binary.BigEndian.PutUint16(p, uint16(len(p)-2))
	binary.BigEndian.PutUint16(p[6:], 16384)
	var b bytes.Buffer
	if _, e := (&chunkBatchWriter{destination: &b, maxWrite: 16384}).Write(p); e == nil || b.Len() != 0 {
		t.Fatal("cap allowed oversize write")
	}
}
func TestWriteCapPreservesStreamAndFIN(t *testing.T) {
	var b bytes.Buffer
	s := &records{w: &chunkBatchWriter{destination: &b, maxWrite: 16384}, payloadLimit: 16337}
	payload := bytes.Repeat([]byte("cap-payload\x00"), 100000)
	if e := sendRecords(s, bytes.NewReader(payload)); e != nil {
		t.Fatal(e)
	}
	// Validate the same standard HTTP chunk reader and N1 reader end-to-end.
	reader := &records{r: httputil.NewChunkedReader(&b)}
	var got bytes.Buffer
	if e := receiveRecords(&got, reader); e != nil {
		t.Fatal(e)
	}
	if !bytes.Equal(payload, got.Bytes()) {
		t.Fatal("cap changed stream")
	}
	var one [1]byte
	if _, e := reader.r.Read(one[:]); e != io.EOF {
		t.Fatal("missing HTTP ending", e)
	}
}
