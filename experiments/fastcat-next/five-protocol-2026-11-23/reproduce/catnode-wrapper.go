package main

import (
	"encoding/json"
	"fmt"
	panel "github.com/wyx2685/v2node/api/v2board"
	"github.com/wyx2685/v2node/conf"
	native "github.com/wyx2685/v2node/core"
	"github.com/wyx2685/v2node/limiter"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	if e := run(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
func run() error {
	var c struct {
		Cert, Key, UUID, Kind string
		Port        int
	}
	b, e := os.ReadFile(os.Args[1])
	if e != nil {
		return e
	}
	if e = json.Unmarshal(b, &c); e != nil {
		return e
	}
	cfg := conf.New()
	cfg.LogConfig.Level = "warning"
	n := &panel.NodeInfo{Id: 1, Type: c.Kind, Security: panel.Tls, Tag: "lab-"+c.Kind, Common: &panel.CommonNode{Protocol: c.Kind, ListenIP: "0.0.0.0", ServerPort: c.Port, Network: c.Kind, CongestionControl: "bbr", ZeroRTTHandshake: false, BaseConfig: &panel.BaseConfig{}, CertInfo: &panel.CertInfo{CertMode: "file", CertFile: c.Cert, KeyFile: c.Key}}}
	if c.Kind=="vless" { n.Common.Network="tcp"; n.Common.Flow="xtls-rprx-vision"; n.Common.Encryption="" }
 users := []panel.UserInfo{{Id: 1, Uuid: c.UUID}}
	limiter.Init()
	limiter.AddLimiter(c.Kind, n.Tag, users, map[int]int{})
	s := native.New(cfg)
	if e = s.Start([]*panel.NodeInfo{n}); e != nil {
		return e
	}
	defer s.Close()
	if e = s.AddNode(n.Tag, n); e != nil {
		return e
	}
	if _, e = s.AddUsers(&native.AddUsersParams{Tag: n.Tag, Users: users, NodeInfo: n}); e != nil {
		return e
	}
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	<-sig
	return nil
}
