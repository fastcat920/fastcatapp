package main

import (
	"crypto/hmac"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

const browserHTML = `<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>网络测试</title><style>body{font:18px system-ui;padding:30px;max-width:650px;margin:auto;background:#f7f8fa;color:#17202a}section{background:white;padding:24px;border-radius:16px}small{color:#667}</style><section><h1>网络测试</h1><p id="state">正在测试，请稍候…</p><small>仅下载合成测试数据，不上传个人文件。</small></section><script>
const token="__TOKEN__",label="__LABEL__";
async function trial(size,index){let started=performance.now(),first=null,total=0,ok=true,error="";let url="/data/"+size+"?case="+label+"&i="+index;try{let r=await fetch(url,{cache:"no-store",headers:{"X-Lab-Run":token}});if(!r.ok)throw new Error("status "+r.status);let rd=r.body.getReader();while(true){let x=await rd.read();if(x.done)break;if(first===null)first=performance.now()-started;for(let i=0;i<x.value.length;i++)if(x.value[i]!==((total+i)%251))ok=false;total+=x.value.length;}if(total!==size)ok=false;}catch(e){ok=false;error=String(e).slice(0,120)}let timing=performance.getEntriesByName(new URL(url,location).href).slice(-1)[0];return {bytes:size,received:total,ok,duration_ms:performance.now()-started,first_byte_ms:first,protocol:timing?timing.nextHopProtocol:"",error};}
(async()=>{let rows=[];for(let n of [7001,33331,131101])rows.push(await trial(n,rows.length));rows.push(...await Promise.all([0,1,2,3].map(i=>trial(65536,3+i))));rows.push(await trial(1048576,7));let good=rows.filter(x=>x.ok).length;document.getElementById("state").textContent="已完成："+good+" / "+rows.length;try{await fetch("/results",{method:"POST",headers:{"Content-Type":"application/json","X-Lab-Run":token},body:JSON.stringify({label,user_agent:navigator.userAgent.slice(0,256),rows})});document.getElementById("state").textContent+="，结果已记录。";}catch(e){document.getElementById("state").textContent+="，结果记录失败。"}})();</script></html>`

type browserRow struct {
	Bytes    int      `json:"bytes"`
	Received int      `json:"received"`
	OK       bool     `json:"ok"`
	Duration float64  `json:"duration_ms"`
	First    *float64 `json:"first_byte_ms"`
	Protocol string   `json:"protocol"`
	Error    string   `json:"error"`
}
type browserReport struct {
	Label string       `json:"label"`
	Agent string       `json:"user_agent"`
	Rows  []browserRow `json:"rows"`
}
type browserLab struct {
	token     string
	remaining atomic.Int64
	requests  atomic.Int64
	local     map[string]bool
}

func (b *browserLab) authorized(token string) bool {
	return len(token) == 32 && hmac.Equal([]byte(token), []byte(b.token))
}
func browserLabel(s string) bool {
	return s == "wifi-direct" || s == "wifi-proxy" || s == "cellular-direct" || s == "cellular-proxy"
}
func (b *browserLab) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")

	if r.Method == "GET" && strings.HasPrefix(r.URL.Path, "/lab/") {
		p := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
		if len(p) != 3 || !b.authorized(p[1]) || !browserLabel(p[2]) {
			http.NotFound(w, r)
			return
		}
		if b.requests.Add(1) > 128 {
			http.Error(w, "test limit", 429)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		io.WriteString(w, strings.ReplaceAll(strings.ReplaceAll(browserHTML, "__TOKEN__", b.token), "__LABEL__", p[2]))
		return
	}
	if !b.authorized(r.Header.Get("X-Lab-Run")) {
		http.NotFound(w, r)
		return
	}
	if b.requests.Add(1) > 128 {
		http.Error(w, "test limit", 429)
		return
	}
	if r.Method == "GET" && strings.HasPrefix(r.URL.Path, "/data/") {
		n, e := strconv.Atoi(strings.TrimPrefix(r.URL.Path, "/data/"))
		if e != nil || n < 1 || n > 1048576 {
			http.NotFound(w, r)
			return
		}
		for {
			old := b.remaining.Load()
			if int64(n) > old {
				http.Error(w, "data limit", 429)
				return
			}
			if b.remaining.CompareAndSwap(old, old-int64(n)) {
				break
			}
		}
		servePattern(w, r, workload{N: n, Chunk: 8192}, true)
		return
	}
	if r.Method == "POST" && r.URL.Path == "/results" {
		var report browserReport
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8192))
		decoder.DisallowUnknownFields()
		if e := decoder.Decode(&report); e != nil || !browserLabel(report.Label) || len(report.Agent) > 256 || len(report.Rows) != 8 {
			http.Error(w, "invalid result", 400)
			return
		}
		for _, v := range report.Rows {
			if v.Bytes < 1 || v.Bytes > 1048576 || v.Received < 0 || v.Received > 1048576 || v.Duration < 0 || v.Duration > 120000 || len(v.Protocol) > 32 || len(v.Error) > 120 || (v.OK && v.Received != v.Bytes) || (v.First != nil && (*v.First < 0 || *v.First > v.Duration)) {
				http.Error(w, "invalid row", 400)
				return
			}
		}
		if e := decoder.Decode(new(any)); e != io.EOF {
			http.Error(w, "trailing result", 400)
			return
		}
		peer, _, _ := net.SplitHostPort(r.RemoteAddr)
		viaNode := b.local[peer]
		data, _ := json.Marshal(map[string]any{"report": report, "via_node": viaNode, "http_protocol": r.Proto, "unix": time.Now().UnixMilli()})
		log.Printf("BROWSER_RESULT %s", data)
		w.WriteHeader(204)
		return
	}
	http.NotFound(w, r)
}
func serveBrowserLab(listen, cert, key, tokenFile string) error {
	raw, e := os.ReadFile(tokenFile)
	if e != nil {
		return e
	}
	token := strings.TrimSpace(string(raw))
	decoded, e := hex.DecodeString(token)
	if e != nil || len(decoded) != 16 {
		return fmt.Errorf("invalid browser test token")
	}
	h := &browserLab{token: token, local: map[string]bool{"127.0.0.1": true, "::1": true}}
	h.remaining.Store(16 * 1048576)
	addresses, _ := net.InterfaceAddrs()
	for _, a := range addresses {
		ip, _, e := net.ParseCIDR(a.String())
		if e == nil {
			h.local[ip.String()] = true
		}
	}
	listener, e := net.Listen("tcp", listen)
	if e != nil {
		return e
	}
	server := &http.Server{Handler: h, ReadHeaderTimeout: 15 * time.Second, ReadTimeout: 30 * time.Second, WriteTimeout: 30 * time.Second, IdleTimeout: 5 * time.Second, MaxHeaderBytes: 8192, TLSConfig: &tls.Config{MinVersion: tls.VersionTLS13}}
	return server.ServeTLS(&boundedListener{Listener: listener, slots: make(chan struct{}, 64), perPeer: 8}, cert, key)
}
