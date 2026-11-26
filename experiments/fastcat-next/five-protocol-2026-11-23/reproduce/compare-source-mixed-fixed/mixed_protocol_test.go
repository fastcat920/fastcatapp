package main
import "testing"
func TestMixedIncludesEveryMeasuredVariant(t *testing.T){
 want:=map[string]string{"next-opt":"quic","next-base":"quic","tuic":"quic","hysteria2":"quic","vless-vision":"tcp-tls"}
 for v,p:=range want{if got:=mixedProtocol(v);got!=p{t.Fatalf("%s workload silently skipped or misrouted: %q want %q",v,got,p)}}
 if mixedProtocol("unknown")!=""{t.Fatal("unknown variant accepted")}
}
