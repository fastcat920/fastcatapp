package main

import (
	"encoding/json"
	"fmt"
	panel "github.com/wyx2685/v2node/api/v2board"
	"github.com/wyx2685/v2node/conf"
	cat "github.com/wyx2685/v2node/core"
	"github.com/wyx2685/v2node/limiter"
	"os"
	"os/signal"
	"syscall"
)

type settings struct {
	Cert, Key, UUID, Password string
	VlessPort, TrojanPort     int
}

func run() error {
	b, e := os.ReadFile(os.Args[1])
	if e != nil {
		return e
	}
	var c settings
	if e = json.Unmarshal(b, &c); e != nil {
		return e
	}
	limiter.Init()
	cfg := conf.New()
	cfg.LogConfig.Level = "none"
	cfg.LogConfig.Access = "none"
	cfg.LogConfig.Output = "none"
	infos := []*panel.NodeInfo{}
	for i, p := range []string{"vless", "trojan"} {
		port := c.VlessPort
		flow := "xtls-rprx-vision"
		if i == 1 {
			port = c.TrojanPort
			flow = ""
		}
		infos = append(infos, &panel.NodeInfo{Id: i + 1, Type: p, Security: panel.Tls, Tag: "lab-" + p, Common: &panel.CommonNode{Protocol: p, ListenIP: "0.0.0.0", ServerPort: port, Network: "tcp", NetworkSettings: json.RawMessage(`{}`), Encryption: "", Flow: flow, CertInfo: &panel.CertInfo{CertMode: "file", CertFile: c.Cert, KeyFile: c.Key}}})
	}
	v := cat.New(cfg)
	if e = v.Start(infos); e != nil {
		return e
	}
	defer v.Close()
	for i, info := range infos {
		secret := c.UUID
		if i == 1 {
			secret = c.Password
		}
		users := []panel.UserInfo{{Id: i + 1, Uuid: secret}}
		limiter.AddLimiter(info.Type, info.Tag, users, map[int]int{})
		if e = v.AddNode(info.Tag, info); e != nil {
			return e
		}
		if _, e = v.AddUsers(&cat.AddUsersParams{Tag: info.Tag, Users: users, NodeInfo: info}); e != nil {
			return e
		}
	}
	fmt.Println("CATNODE_LAB_READY")
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch
	return nil
}
func main() {
	if e := run(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
