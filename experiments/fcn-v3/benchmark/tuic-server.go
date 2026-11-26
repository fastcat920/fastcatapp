//go:build ignore

// Build this file explicitly from the CatNode module directory.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"

	"github.com/google/uuid"
	panel "github.com/wyx2685/v2node/api/v2board"
	"github.com/wyx2685/v2node/conf"
	native "github.com/wyx2685/v2node/core"
	"github.com/wyx2685/v2node/limiter"
	"github.com/xtls/xray-core/common"
	"github.com/xtls/xray-core/common/buf"
	xnet "github.com/xtls/xray-core/common/net"
	"github.com/xtls/xray-core/common/serial"
	"github.com/xtls/xray-core/common/session"
	"github.com/xtls/xray-core/features/outbound"
	"github.com/xtls/xray-core/features/routing"
	xconf "github.com/xtls/xray-core/infra/conf"
	"github.com/xtls/xray-core/transport"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) != 2 {
		return errors.New("usage: tuic-server config.json")
	}
	file, err := os.Open(os.Args[1])
	if err != nil {
		return errors.New("cannot open TUIC fixture config")
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || info.Mode() != 0600 || info.Size() > 4096 {
		return errors.New("TUIC fixture config requires a regular 0600 file up to 4 KiB")
	}
	var c struct {
		Cert               string `json:"cert"`
		Key                string `json:"key"`
		UUID               string `json:"uuid"`
		ListenIP           string `json:"listen_ip,omitempty"`
		AllowDiagnosticUDP bool   `json:"allow_diagnostic_udp,omitempty"`
	}
	d := json.NewDecoder(io.LimitReader(file, 4097))
	d.DisallowUnknownFields()
	var extra any
	if d.Decode(&c) != nil || d.Decode(&extra) != io.EOF || c.Cert == "" || c.Key == "" {
		return errors.New("invalid TUIC fixture config")
	}
	id, err := uuid.Parse(c.UUID)
	if err != nil || id == uuid.Nil || c.UUID != id.String() {
		return errors.New("invalid TUIC fixture UUID")
	}

	if c.ListenIP == "" {
		c.ListenIP = "127.0.0.1"
	}
	if c.ListenIP != "127.0.0.1" && c.ListenIP != "0.0.0.0" {
		return errors.New("invalid TUIC fixture listen address")
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(stop)
	config := conf.New()
	config.LogConfig.Level = "warning"
	loopbackOnly := `{"tag":"lab-origin-only","protocol":"freedom","settings":{"finalRules":[{"action":"allow","network":"tcp","port":18476,"ip":["127.0.0.1/32"]},`
	if c.AllowDiagnosticUDP {
		loopbackOnly += `{"action":"allow","network":"udp","port":18477,"ip":["127.0.0.1/32"]},`
	}
	loopbackOnly += `{"action":"block","delay":0}]}}`
	node := &panel.NodeInfo{
		Id: 1, Type: "tuic", Security: panel.Tls, Tag: "lab-tuic",
		Common: &panel.CommonNode{
			Protocol: "tuic", ListenIP: c.ListenIP, ServerPort: 18533, Network: "tuic",
			CongestionControl: "bbr", ZeroRTTHandshake: false, BaseConfig: &panel.BaseConfig{},
			CertInfo: &panel.CertInfo{CertMode: "file", CertFile: c.Cert, KeyFile: c.Key},
			Routes:   []panel.Route{{Action: "default_out", ActionValue: &loopbackOnly}},
		},
	}
	users := []panel.UserInfo{{Id: 1, Uuid: c.UUID}}
	limiter.Init()
	limiter.AddLimiter("tuic", node.Tag, users, map[int]int{})
	server := native.New(config)
	if err := server.Start([]*panel.NodeInfo{node}); err != nil {
		return err
	}
	defer server.Close()
	if c.AllowDiagnosticUDP {
		if err := setDiagnosticRoutes(server); err != nil {
			return err
		}
	}
	if err := server.AddNode(node.Tag, node); err != nil {
		return err
	}
	if _, err := server.AddUsers(&native.AddUsersParams{Tag: node.Tag, Users: users, NodeInfo: node}); err != nil {
		return errors.New("cannot install TUIC fixture user")
	}
	fmt.Fprintf(os.Stderr, "TUIC fixture listening on %s:18533\n", c.ListenIP)
	<-stop
	return nil
}

func setDiagnosticRoutes(server *native.V2Core) error {
	// Replace the stock router's UDP/53 rule before installing the inbound.
	manager := server.Server.GetFeature(outbound.ManagerType()).(outbound.Manager)
	origin := manager.GetHandler("lab-origin-only")
	if origin == nil || manager.GetHandler("block") == nil {
		return errors.New("missing TUIC diagnostic outbound")
	}
	ctx := context.Background()
	if err := manager.RemoveHandler(ctx, origin.Tag()); err != nil {
		return err
	}
	if err := manager.AddHandler(ctx, diagnosticOutbound{Handler: origin}); err != nil {
		return err
	}
	config := xconf.RouterConfig{RuleList: []json.RawMessage{
		json.RawMessage(`{"type":"field","inboundTag":["lab-tuic"],"network":"tcp","ip":["127.0.0.1/32"],"port":18476,"outboundTag":"lab-origin-only"}`),
		json.RawMessage(`{"type":"field","inboundTag":["lab-tuic"],"network":"udp","ip":["127.0.0.1/32"],"port":18477,"outboundTag":"lab-origin-only"}`),
		json.RawMessage(`{"type":"field","network":"tcp,udp","outboundTag":"block"}`),
	}}
	rules, err := config.Build()
	if err != nil {
		return fmt.Errorf("build TUIC diagnostic routes: %w", err)
	}
	router := server.Server.GetFeature(routing.RouterType()).(routing.Router)
	return router.AddRule(serial.ToTypedMessage(rules), false)
}

type diagnosticOutbound struct{ outbound.Handler }

func (o diagnosticOutbound) Dispatch(ctx context.Context, link *transport.Link) {
	targets := session.OutboundsFromContext(ctx)
	if len(targets) > 0 && targets[len(targets)-1].Target.Network == xnet.Network_UDP {
		link.Reader = diagnosticUDPReader{Reader: link.Reader}
	}
	o.Handler.Dispatch(ctx, link)
}

type diagnosticUDPReader struct{ buf.Reader }

// TUIC permits the target to change within an association. Filter each packet
// before freedom can resolve a destination name or send the datagram.
func (r diagnosticUDPReader) ReadMultiBuffer() (buf.MultiBuffer, error) {
	packets, err := r.Reader.ReadMultiBuffer()
	allowed := packets[:0]
	for _, packet := range packets {
		dest := packet.UDP
		if dest != nil && dest.Address != nil && dest.Address.Family().IsIP() &&
			dest.Address.String() == "127.0.0.1" && dest.Port == 18477 {
			allowed = append(allowed, packet)
		} else {
			packet.Release()
		}
	}
	clear(packets[len(allowed):])
	return allowed, err
}

func (r diagnosticUDPReader) Interrupt() { _ = common.Interrupt(r.Reader) }

func (r diagnosticUDPReader) Close() error { return common.Close(r.Reader) }
