package listener

import (
	"errors"
	"github.com/metacubex/mihomo/adapter/inbound"
	C "github.com/metacubex/mihomo/constant"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"testing"
)

func TestFailedTunCreationIsNotReadyAndCanBeRetried(t *testing.T) {
	if TunListenerReady() {
		t.Fatal("test must not run with an active TUN")
	}
	previous, previousConfig := newTunListener, LastTunConf
	defer func() { newTunListener, LastTunConf = previous, previousConfig }()
	calls := 0
	newTunListener = func(LC.Tun, C.Tunnel, ...inbound.Addition) (*sing_tun.Listener, error) {
		calls++
		return nil, errors.New("injected adapter construction failure")
	}
	requested := LC.Tun{Enable: true, Device: "fastcat-readiness-test"}
	ReCreateTun(requested, nil)
	if TunListenerReady() || GetTunConf().Enable {
		t.Fatal("failed adapter was published as ready")
	}
	ReCreateTun(requested, nil)
	if calls != 2 {
		t.Fatal("a failed creation must not suppress the next attempt")
	}
}
