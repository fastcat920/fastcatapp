//go:build android && cgo

package main

import "C"
import (
	"context"
	bridge "core/dart-bridge"
	"core/platform"
	"core/state"
	t "core/tun"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/process"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	ST "github.com/metacubex/sing-tun"
	"golang.org/x/sync/semaphore"
	"net"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"
)

//export fastCatSupportsV2
func fastCatSupportsV2() C.int { return 2 }

//export fastCatSupportsAutoV1
func fastCatSupportsAutoV1() C.int { return 1 }

type TunHandler struct {
	listener *sing_tun.Listener
	fd       int
	callback unsafe.Pointer

	limit *semaphore.Weighted
}

func (t *TunHandler) close() {
	_ = t.limit.Acquire(context.TODO(), 4)
	defer t.limit.Release(4)
	removeTunHook()
	if t.listener != nil {
		_ = t.listener.Close()
	}

	if t.callback != nil {
		releaseObject(t.callback)
	}
	t.callback = nil
	t.listener = nil
}

func (t *TunHandler) handleProtect(fd int) {
	_ = t.limit.Acquire(context.Background(), 1)
	defer t.limit.Release(1)

	if t.callback == nil {
		return
	}

	Protect(t.callback, fd)
}

func (t *TunHandler) handleResolveProcess(source, target net.Addr) string {
	_ = t.limit.Acquire(context.Background(), 1)
	defer t.limit.Release(1)

	if t.callback == nil {
		return ""
	}
	var protocol int
	uid := -1
	switch source.Network() {
	case "udp", "udp4", "udp6":
		protocol = syscall.IPPROTO_UDP
	case "tcp", "tcp4", "tcp6":
		protocol = syscall.IPPROTO_TCP
	}
	if version < 29 {
		uid = platform.QuerySocketUidFromProcFs(source, target)
	}
	return ResolveProcess(t.callback, protocol, source.String(), target.String(), uid)
}

var (
	tunLock    sync.Mutex
	tunRuntime atomic.Pointer[androidTunRuntime]
	errBlocked = errors.New("blocked")
	tunHandler *TunHandler
)

type androidTunRuntime struct {
	fd        int
	startedAt time.Time
}

func stopTunLocked() {
	stopFastCatStartupWarm()
	outbound.ResetFastCatH2Connections()
	tunRuntime.Store(nil)
	if tunHandler != nil {
		tunHandler.close()
		tunHandler = nil
	}
}
func handleStopTun() { tunLock.Lock(); defer tunLock.Unlock(); stopTunLocked() }

func handleStartTun(fd int, callback unsafe.Pointer) bool {
	tunLock.Lock()
	defer tunLock.Unlock()
	stopTunLocked()
	handler := &TunHandler{callback: callback, fd: fd, limit: semaphore.NewWeighted(4)}
	tunHandler = handler
	// Protect must be usable while the stack is being constructed.
	if fd != 0 {
		initTunHook()
		runLock.Lock()
		cfg := currentConfig
		if cfg == nil || cfg.General == nil {
			runLock.Unlock()
			_ = syscall.Close(fd)
			stopTunLocked()
			return false
		}
		device, stack := cfg.General.Tun.Device, cfg.General.Tun.Stack
		runLock.Unlock()
		listener, err := t.Start(fd, device, stack)
		if err != nil || listener == nil {
			log.Errorln("tun_lifecycle event=start outcome=failed stack=%s error=%v", stack.String(), err)
			stopTunLocked()
			return false
		}
		handler.listener = listener
	}
	tunRuntime.Store(&androidTunRuntime{fd: fd, startedAt: time.Now()})
	log.Infoln("tun_lifecycle event=start outcome=ready")
	startFastCatStartupWarm()
	return true
}

func androidTunHealth() ST.ForwarderHealth {
	snapshot := tunRuntime.Load()
	if snapshot == nil {
		return ST.ForwarderHealth{State: "stopped"}
	}
	if snapshot.fd != 0 {
		if h, ok := ST.SystemForwarderHealth(snapshot.fd); ok {
			return h
		}
	}
	return ST.ForwarderHealth{State: "ready"}
}
func handleGetRunTime() string {
	snapshot := tunRuntime.Load()
	if snapshot == nil || androidTunHealth().State == "failed" {
		return ""
	}
	return strconv.FormatInt(snapshot.startedAt.UnixMilli(), 10)
}

//export getAndroidTunStatus
func getAndroidTunStatus() *C.char {
	data, _ := json.Marshal(androidTunHealth())
	return C.CString(string(data))
}

func initTunHook() {
	handler := tunHandler
	dialer.DefaultSocketHook = func(network, address string, conn syscall.RawConn) error {
		if platform.ShouldBlockConnection() {
			return errBlocked
		}
		return conn.Control(func(fd uintptr) {
			handler.handleProtect(int(fd))
		})
	}
	process.DefaultPackageNameResolver = func(metadata *constant.Metadata) (string, error) {
		src, dst := metadata.RawSrcAddr, metadata.RawDstAddr
		if src == nil || dst == nil {
			return "", process.ErrInvalidNetwork
		}
		return handler.handleResolveProcess(src, dst), nil
	}
}

func removeTunHook() {
	dialer.DefaultSocketHook = nil
	process.DefaultPackageNameResolver = nil
}

func handleGetAndroidVpnOptions() string {
	tunLock.Lock()
	defer tunLock.Unlock()
	runLock.Lock()
	options := buildAndroidVpnOptions(currentConfig)
	runLock.Unlock()
	data, err := json.Marshal(options)
	if err != nil {
		fmt.Println("Error:", err)
		return ""
	}
	return string(data)
}

func handleUpdateDns(value string) {
	go func() {
		log.Infoln("[DNS] updateDns %s", value)
		dns.UpdateSystemDNS(strings.Split(value, ","))
		dns.FlushCacheWithDefaultResolver()
		// A physical-network DNS change also invalidates fake-IP mappings.
		// Keep this in the native service path so it still applies while the
		// Flutter UI process is not running.
		if err := resolver.FlushFakeIP(); err != nil {
			log.Warnln("[DNS] flush fake-IP cache failed: %v", err)
		}
	}()
}

func handleGetCurrentProfileName() string {
	if state.CurrentState == nil {
		return ""
	}
	return state.CurrentState.CurrentProfileName
}

func nextHandle(action *Action, result ActionResult) bool {
	switch action.Method {
	case getAndroidVpnOptionsMethod:
		result.success(handleGetAndroidVpnOptions())
		return true
	case updateDnsMethod:
		data := action.Data.(string)
		handleUpdateDns(data)
		result.success(true)
		return true
	case getRunTimeMethod:
		result.success(handleGetRunTime())
		return true
	case getCurrentProfileNameMethod:
		result.success(handleGetCurrentProfileName())
		return true
	}
	return false
}

//export quickStart
func quickStart(initParamsChar *C.char, paramsChar *C.char, stateParamsChar *C.char, port C.longlong) {
	i := int64(port)
	paramsString := C.GoString(initParamsChar)
	bytes := []byte(C.GoString(paramsChar))
	stateParams := C.GoString(stateParamsChar)
	go func() {
		res := handleInitClash(paramsString)
		if res == false {
			bridge.SendToPort(i, "init error")
			return
		}
		handleSetState(stateParams)
		bridge.SendToPort(i, handleSetupConfig(bytes))
	}()
}

//export startTUN
func startTUN(fd C.int, callback unsafe.Pointer) bool {
	return handleStartTun(int(fd), callback)
}

//export getRunTime
func getRunTime() *C.char {
	return C.CString(handleGetRunTime())
}

//export stopTun
func stopTun() {
	handleStopTun()
}

//export getCurrentProfileName
func getCurrentProfileName() *C.char {
	return C.CString(handleGetCurrentProfileName())
}

//export getAndroidVpnOptions
func getAndroidVpnOptions() *C.char {
	return C.CString(handleGetAndroidVpnOptions())
}

//export setState
func setState(s *C.char) {
	paramsString := C.GoString(s)
	handleSetState(paramsString)
}

//export updateDns
func updateDns(s *C.char) {
	dnsList := C.GoString(s)
	handleUpdateDns(dnsList)
}

//export fastCatSupportsFCN
func fastCatSupportsFCN() C.int { return 3 }
