//go:build ignore

// Build this file explicitly from the CatNode module directory.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/signal"
	"strconv"
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

type fixtureConfig struct {
	Kind     string `json:"kind"`
	Port     int    `json:"port,omitempty"`
	Cert     string `json:"cert"`
	Key      string `json:"key"`
	UUID     string `json:"uuid"`
	ListenIP string `json:"listen_ip,omitempty"`
}

func loadConfig(path string) (fixtureConfig, error) {
	var c fixtureConfig
	file, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if err != nil {
		return c, errors.New("cannot open native fixture config")
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || info.Mode() != 0600 || info.Size() > 4096 {
		return c, errors.New("native fixture config requires a regular 0600 file up to 4 KiB")
	}
	decoder := json.NewDecoder(io.LimitReader(file, 4097))
	decoder.DisallowUnknownFields()
	var extra any
	if decoder.Decode(&c) != nil || decoder.Decode(&extra) != io.EOF || c.Cert == "" || c.Key == "" {
		return c, errors.New("invalid native fixture config")
	}
	id, err := uuid.Parse(c.UUID)
	if err != nil || id == uuid.Nil || c.UUID != id.String() {
		return c, errors.New("invalid native fixture UUID")
	}
	defaultPorts := map[string]int{"fcn-v1": 18530, "tuic": 18533, "hysteria2": 18535}
	defaultPort, ok := defaultPorts[c.Kind]
	if !ok {
		return c, errors.New("native fixture kind must be fcn-v1, tuic or hysteria2")
	}
	if c.Port == 0 {
		c.Port = defaultPort
	}
	if c.Port < 1 || c.Port > 65535 {
		return c, errors.New("invalid native fixture port")
	}
	if c.ListenIP == "" {
		c.ListenIP = "127.0.0.1"
	}
	if c.ListenIP != "127.0.0.1" && c.ListenIP != "0.0.0.0" {
		return c, errors.New("invalid native fixture listen address")
	}
	return c, nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) != 2 {
		return errors.New("usage: five-native-server config.json")
	}
	c, err := loadConfig(os.Args[1])
	if err != nil {
		return err
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(stop)
	config := conf.New()
	config.LogConfig.Level = "warning"
	loopbackOnly := `{"tag":"lab-origin-only","protocol":"freedom","settings":{"finalRules":[{"action":"allow","network":"tcp","port":18476,"ip":["127.0.0.1/32"]},{"action":"allow","network":"udp","port":18477,"ip":["127.0.0.1/32"]},{"action":"block","delay":0}]}}`
	// CatNode serves FCN v1 and v2 with the same FCN/1 implementation.
	node := &panel.NodeInfo{
		Id: 1, Type: c.Kind, Security: panel.Tls, Tag: "lab-five",
		Common: &panel.CommonNode{
			Protocol: c.Kind, ListenIP: c.ListenIP, ServerPort: c.Port, Network: c.Kind,
			CongestionControl: "bbr", ZeroRTTHandshake: false, BaseConfig: &panel.BaseConfig{},
			CertInfo: &panel.CertInfo{CertMode: "file", CertFile: c.Cert, KeyFile: c.Key},
			Routes:   []panel.Route{{Action: "default_out", ActionValue: &loopbackOnly}},
		},
	}
	users := []panel.UserInfo{{Id: 1, Uuid: c.UUID}}
	limiter.Init()
	limiter.AddLimiter(c.Kind, node.Tag, users, map[int]int{})
	server := native.New(config)
	if err := server.Start([]*panel.NodeInfo{node}); err != nil {
		return err
	}
	defer server.Close()
	if err := installRoutes(server); err != nil {
		return err
	}
	if err := server.AddNode(node.Tag, node); err != nil {
		return err
	}
	if _, err := server.AddUsers(&native.AddUsersParams{Tag: node.Tag, Users: users, NodeInfo: node}); err != nil {
		return errors.New("cannot install native fixture user")
	}
	fmt.Fprintf(os.Stderr, "%s fixture listening on %s\n", c.Kind, net.JoinHostPort(c.ListenIP, strconv.Itoa(c.Port)))
	<-stop
	return nil
}

func installRoutes(server *native.V2Core) error {
	// Replace CatNode's stock UDP/53 rule before starting the inbound.
	manager := server.Server.GetFeature(outbound.ManagerType()).(outbound.Manager)
	origin := manager.GetHandler("lab-origin-only")
	if origin == nil || manager.GetHandler("block") == nil {
		return errors.New("missing native fixture outbound")
	}
	ctx := context.Background()
	if err := manager.RemoveHandler(ctx, origin.Tag()); err != nil {
		return err
	}
	if err := manager.AddHandler(ctx, fixtureOutbound{Handler: origin}); err != nil {
		return err
	}
	config := xconf.RouterConfig{RuleList: []json.RawMessage{
		json.RawMessage(`{"type":"field","inboundTag":["lab-five"],"network":"tcp","ip":["127.0.0.1/32"],"port":18476,"outboundTag":"lab-origin-only"}`),
		json.RawMessage(`{"type":"field","inboundTag":["lab-five"],"network":"udp","ip":["127.0.0.1/32"],"port":18477,"outboundTag":"lab-origin-only"}`),
		json.RawMessage(`{"type":"field","network":"tcp,udp","outboundTag":"block"}`),
	}}
	rules, err := config.Build()
	if err != nil {
		return fmt.Errorf("build native fixture routes: %w", err)
	}
	router := server.Server.GetFeature(routing.RouterType()).(routing.Router)
	return router.AddRule(serial.ToTypedMessage(rules), false)
}

type fixtureOutbound struct{ outbound.Handler }

func (o fixtureOutbound) Dispatch(ctx context.Context, link *transport.Link) {
	targets := session.OutboundsFromContext(ctx)
	if len(targets) > 0 {
		target := targets[len(targets)-1].Target
		switch {
		case target.Network == xnet.Network_TCP && loopbackPort(target, 18476):
			o.Handler.Dispatch(ctx, link)
			return
		case target.Network == xnet.Network_UDP && loopbackPort(target, 18477):
			link.Reader = fixtureUDPReader{Reader: link.Reader}
			o.Handler.Dispatch(ctx, link)
			return
		}
	}
	_ = common.Interrupt(link.Reader)
	_ = common.Close(link.Writer)
}

func loopbackPort(dest xnet.Destination, port xnet.Port) bool {
	return dest.Port == port && dest.Address != nil && dest.Address.Family().IsIP() &&
		dest.Address.String() == "127.0.0.1"
}

type fixtureUDPReader struct{ buf.Reader }

// Native associations may override destinations per packet. FCN supplies a
// fixed destination via its connection, so those packets inherit the route.
func (r fixtureUDPReader) ReadMultiBuffer() (buf.MultiBuffer, error) {
	packets, err := r.Reader.ReadMultiBuffer()
	allowed := packets[:0]
	for _, packet := range packets {
		dest := packet.UDP
		if dest == nil || (dest.Network == xnet.Network_UDP && loopbackPort(*dest, 18477)) {
			allowed = append(allowed, packet)
		} else {
			packet.Release()
		}
	}
	clear(packets[len(allowed):])
	return allowed, err
}

func (r fixtureUDPReader) Interrupt() { _ = common.Interrupt(r.Reader) }

func (r fixtureUDPReader) Close() error { return common.Close(r.Reader) }
