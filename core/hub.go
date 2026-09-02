package main

import (
	"context"
	"core/state"
	"encoding/json"
	"fmt"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/common/observable"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/mmdb"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/updater"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"net"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const coreLogBufferLimit = 500

var (
	isInit            = false
	externalProviders = map[string]cp.Provider{}
	logSubscriber     observable.Subscription[log.Event]
	coreLogBufferMu   sync.Mutex
	coreLogBuffer     []Message
)

func handleInitClash(paramsString string) bool {
	var params = InitParams{}
	err := json.Unmarshal([]byte(paramsString), &params)
	if err != nil {
		return false
	}
	version = params.Version
	if !isInit {
		constant.SetHomeDir(params.HomeDir)
		isInit = true
	}
	return isInit
}

func handleStartListener() bool {
	runLock.Lock()
	defer runLock.Unlock()
	isRunning = true
	updateListeners()
	resolver.ResetConnection()
	return true
}

func handleStopListener() bool {
	runLock.Lock()
	defer runLock.Unlock()
	isRunning = false
	stopListeners()
	return true
}

func handleGetIsInit() bool {
	return isInit
}

func handleForceGc() {
	go func() {
		log.Infoln("[APP] request force GC")
		runtime.GC()
	}()
}

func handleShutdown() bool {
	stopListeners()
	executor.Shutdown()
	runtime.GC()
	isInit = false
	return true
}

func handleValidateConfig(bytes []byte) string {
	_, err := config.UnmarshalRawConfig(bytes)
	if err != nil {
		return err.Error()
	}
	return ""
}

func handleGetProxies() map[string]constant.Proxy {
	runLock.Lock()
	defer runLock.Unlock()
	return tunnel.Proxies()
}

func handleChangeProxy(data string, fn func(string string)) {
	runLock.Lock()
	go func() {
		defer runLock.Unlock()
		var params = &ChangeProxyParams{}
		err := json.Unmarshal([]byte(data), params)
		if err != nil {
			fn(err.Error())
			return
		}
		groupName := *params.GroupName
		proxyName := *params.ProxyName
		proxies := tunnel.Proxies()
		group, ok := proxies[groupName]
		if !ok {
			fn("Not found group")
			return
		}
		adapterProxy := group.(*adapter.Proxy)
		selector, ok := adapterProxy.ProxyAdapter.(outboundgroup.SelectAble)
		if !ok {
			fn("Group is not selectable")
			return
		}
		if proxyName == "" {
			selector.ForceSet(proxyName)
		} else {
			err = selector.Set(proxyName)
		}
		if err != nil {
			fn(err.Error())
			return
		}

		fn("")
		return
	}()
}

func handleGetTraffic() string {
	up, down := statistic.DefaultManager.Now()
	traffic := map[string]int64{
		"up":   up,
		"down": down,
	}
	data, err := json.Marshal(traffic)
	if err != nil {
		fmt.Println("Error:", err)
		return ""
	}
	return string(data)
}

func handleGetTotalTraffic() string {
	up, down := statistic.DefaultManager.Total()
	traffic := map[string]int64{
		"up":   up,
		"down": down,
	}
	data, err := json.Marshal(traffic)
	if err != nil {
		fmt.Println("Error:", err)
		return ""
	}
	return string(data)
}

func handleResetTraffic() {
	statistic.DefaultManager.ResetStatistic()
}

func handleAsyncTestDelay(paramsString string, fn func(string)) {
	mBatch.Go(paramsString, func() (bool, error) {
		var params = &TestDelayParams{}
		err := json.Unmarshal([]byte(paramsString), params)
		if err != nil {
			fn("")
			return false, nil
		}

		expectedStatus, err := utils.NewUnsignedRanges[uint16]("")
		if err != nil {
			fn("")
			return false, nil
		}

		ctx, cancel := context.WithTimeout(context.Background(), time.Millisecond*time.Duration(params.Timeout))
		defer cancel()

		proxies := tunnel.Proxies()
		proxy := proxies[params.ProxyName]

		delayData := &Delay{
			Name: params.ProxyName,
		}

		if proxy == nil {
			delayData.Value = -1
			data, _ := json.Marshal(delayData)
			fn(string(data))
			return false, nil
		}

		testUrl := testURL

		if params.TestUrl != "" {
			testUrl = params.TestUrl
		}
		delayData.Url = testUrl

		delay, err := proxy.URLTest(ctx, testUrl, expectedStatus)
		if err != nil || delay == 0 {
			delayData.Value = -1
			data, _ := json.Marshal(delayData)
			fn(string(data))
			return false, nil
		}

		delayData.Value = int32(delay)
		data, _ := json.Marshal(delayData)
		fn(string(data))
		return false, nil
	})
}

func handleDiagnoseProxy(paramsString string) string {
	params := &DiagnoseProxyParams{}
	if err := json.Unmarshal([]byte(paramsString), params); err != nil {
		return marshalProxyDiagnostic(&ProxyDiagnosticResult{
			DiagnosticStatus: "complete",
			DNSStatus:        "unavailable", TCPStatus: "unavailable",
			ProxyStatus: "failed", FailureStage: "configuration", Error: err.Error(),
		})
	}

	timeout := time.Duration(params.Timeout) * time.Millisecond
	if timeout <= 0 {
		timeout = 8 * time.Second
	}
	result := &ProxyDiagnosticResult{
		DiagnosticStatus: "complete",
		DNSStatus:        "unavailable", TCPStatus: "skipped", ProxyStatus: "failed",
	}
	proxy := tunnel.Proxies()[params.ProxyName]
	if proxy == nil {
		result.FailureStage = "configuration"
		result.Error = "proxy not found"
		return marshalProxyDiagnostic(result)
	}

	proxyAdapter := proxy.Adapter()
	result.ProxyType = proxyAdapter.Type().String()
	result.Network = proxyDiagnosticNetwork(proxyAdapter.Type())
	address := proxyAdapter.Addr()
	host, port, err := net.SplitHostPort(address)
	if err != nil {
		result.FailureStage = "configuration"
		result.Error = "node endpoint unavailable"
		return marshalProxyDiagnostic(result)
	}
	result.Host = host
	result.Port = port

	dnsStarted := time.Now()
	dnsCtx, dnsCancel := context.WithTimeout(context.Background(), timeout)
	// Diagnose the endpoint with the same resolver that real proxy dialing
	// uses. The default resolver can be a fake-IP resolver and report a false
	// DNS failure even while the selected node is carrying traffic normally.
	ips, dnsErr := resolver.LookupIPWithResolver(
		dnsCtx,
		host,
		resolver.ProxyServerHostResolver,
	)
	dnsCancel()
	result.DNSElapsedMs = time.Since(dnsStarted).Milliseconds()
	if dnsErr != nil {
		result.DNSStatus = "failed"
		result.FailureStage = "dns"
		result.Error = dnsErr.Error()
		return marshalProxyDiagnostic(result)
	}
	result.DNSStatus = "success"
	for _, ip := range ips {
		result.ResolvedIPs = append(result.ResolvedIPs, ip.String())
	}

	if result.Network == "tcp" {
		tcpStarted := time.Now()
		tcpCtx, tcpCancel := context.WithTimeout(context.Background(), timeout)
		conn, tcpErr := dialer.DialContext(tcpCtx, "tcp", address)
		tcpCancel()
		result.TCPElapsedMs = time.Since(tcpStarted).Milliseconds()
		if tcpErr != nil {
			result.TCPStatus = classifyTCPError(tcpErr)
			result.FailureStage = "tcp"
			result.Error = tcpErr.Error()
			return marshalProxyDiagnostic(result)
		}
		result.TCPStatus = "success"
		_ = conn.Close()
	}

	testURL := params.TestUrl
	if testURL == "" {
		testURL = testURL
	}
	expectedStatus, _ := utils.NewUnsignedRanges[uint16]("")
	httpStarted := time.Now()
	httpCtx, httpCancel := context.WithTimeout(context.Background(), timeout)
	delay, proxyErr := proxy.URLTest(httpCtx, testURL, expectedStatus)
	httpCancel()
	result.HTTPElapsedMs = time.Since(httpStarted).Milliseconds()
	if proxyErr != nil || delay == 0 {
		result.ProxyStatus = "failed"
		result.FailureStage = classifyProxyFailure(proxyErr, result.TCPStatus)
		if result.Network == "udp" && proxyErr != nil && isTimeoutError(proxyErr) {
			result.FailureStage = "udp"
		}
		if proxyErr != nil {
			result.Error = proxyErr.Error()
		} else {
			result.Error = "proxy test returned zero delay"
		}
		return marshalProxyDiagnostic(result)
	}
	result.ProxyStatus = "success"
	result.HTTPElapsedMs = int64(delay)
	return marshalProxyDiagnostic(result)
}

func isTimeoutError(err error) bool {
	if err == nil {
		return false
	}
	lower := strings.ToLower(err.Error())
	return strings.Contains(lower, "timeout") || strings.Contains(lower, "deadline exceeded")
}

func marshalProxyDiagnostic(result *ProxyDiagnosticResult) string {
	data, _ := json.Marshal(result)
	return string(data)
}

func proxyDiagnosticNetwork(adapterType constant.AdapterType) string {
	switch adapterType {
	case constant.Hysteria, constant.Hysteria2, constant.Tuic, constant.WireGuard:
		return "udp"
	default:
		return "tcp"
	}
}

func classifyTCPError(err error) string {
	if err == nil {
		return "success"
	}
	lower := strings.ToLower(err.Error())
	if strings.Contains(lower, "refused") {
		return "refused"
	}
	if strings.Contains(lower, "unreachable") || strings.Contains(lower, "no route") {
		return "unreachable"
	}
	if strings.Contains(lower, "timeout") || strings.Contains(lower, "deadline exceeded") {
		return "timeout"
	}
	return "failed"
}

func classifyProxyFailure(err error, tcpStatus string) string {
	if err == nil {
		return "http"
	}
	lower := strings.ToLower(err.Error())
	if strings.Contains(lower, "no such host") || strings.Contains(lower, "lookup ") || strings.Contains(lower, "dns") {
		return "dns"
	}
	if strings.Contains(lower, "tls") || strings.Contains(lower, "x509") || strings.Contains(lower, "certificate") {
		return "tls"
	}
	if strings.Contains(lower, "websocket") || strings.Contains(lower, "grpc") || strings.Contains(lower, "authentication") || strings.Contains(lower, "handshake") {
		return "protocol"
	}
	if tcpStatus != "success" && tcpStatus != "skipped" {
		return "tcp"
	}
	if strings.Contains(lower, "http") || strings.Contains(lower, "status") {
		return "http"
	}
	return "protocol"
}

func handleGetConnections() string {
	runLock.Lock()
	defer runLock.Unlock()
	snapshot := statistic.DefaultManager.Snapshot()
	data, err := json.Marshal(snapshot)
	if err != nil {
		fmt.Println("Error:", err)
		return ""
	}
	return string(data)
}

func handleCloseConnections() bool {
	runLock.Lock()
	defer runLock.Unlock()
	closeConnections()
	return true
}

func closeConnections() {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		err := c.Close()
		if err != nil {
			return false
		}
		return true
	})
}

func handleResetConnections() bool {
	runLock.Lock()
	defer runLock.Unlock()
	resolver.ResetConnection()
	return true
}

func handleCloseConnection(connectionId string) bool {
	runLock.Lock()
	defer runLock.Unlock()
	c := statistic.DefaultManager.Get(connectionId)
	if c == nil {
		return false
	}
	_ = c.Close()
	return true
}

func handleGetExternalProviders() string {
	runLock.Lock()
	defer runLock.Unlock()
	externalProviders = getExternalProvidersRaw()
	eps := make([]ExternalProvider, 0)
	for _, p := range externalProviders {
		externalProvider, err := toExternalProvider(p)
		if err != nil {
			continue
		}
		eps = append(eps, *externalProvider)
	}
	sort.Sort(ExternalProviders(eps))
	data, err := json.Marshal(eps)
	if err != nil {
		return ""
	}
	return string(data)
}

func handleGetExternalProvider(externalProviderName string) string {
	runLock.Lock()
	defer runLock.Unlock()
	externalProvider, exist := externalProviders[externalProviderName]
	if !exist {
		return ""
	}
	e, err := toExternalProvider(externalProvider)
	if err != nil {
		return ""
	}
	data, err := json.Marshal(e)
	if err != nil {
		return ""
	}
	return string(data)
}

func handleUpdateGeoData(geoType string, geoName string, fn func(value string)) {
	go func() {
		switch geoType {
		case "MMDB":
			err := updater.UpdateMMDB()
			if err != nil {
				fn(err.Error())
				return
			}
		case "ASN":
			err := updater.UpdateASN()
			if err != nil {
				fn(err.Error())
				return
			}
		case "GeoIp":
			err := updater.UpdateGeoIp()
			if err != nil {
				fn(err.Error())
				return
			}
		case "GeoSite":
			err := updater.UpdateGeoSite()
			if err != nil {
				fn(err.Error())
				return
			}
		}
		fn("")
	}()
}

func handleUpdateExternalProvider(providerName string, fn func(value string)) {
	go func() {
		externalProvider, exist := externalProviders[providerName]
		if !exist {
			fn("external provider is not exist")
			return
		}
		err := externalProvider.Update()
		if err != nil {
			fn(err.Error())
			return
		}
		fn("")
	}()
}

func handleSideLoadExternalProvider(providerName string, data []byte, fn func(value string)) {
	go func() {
		runLock.Lock()
		defer runLock.Unlock()
		externalProvider, exist := externalProviders[providerName]
		if !exist {
			fn("external provider is not exist")
			return
		}
		err := sideUpdateExternalProvider(externalProvider, data)
		if err != nil {
			fn(err.Error())
			return
		}
		fn("")
	}()
}

func handleStartLog() {
	if logSubscriber != nil {
		log.UnSubscribe(logSubscriber)
		logSubscriber = nil
	}
	logSubscriber = log.Subscribe()
	subscriber := logSubscriber
	go func() {
		for logData := range subscriber {
			if logData.LogLevel < log.Level() {
				continue
			}
			message := &Message{
				Type: LogMessage,
				Data: logData,
			}
			appendCoreLog(*message)
		}
	}()
}

func handleStopLog() {
	if logSubscriber != nil {
		log.UnSubscribe(logSubscriber)
		logSubscriber = nil
	}
}

func appendCoreLog(message Message) {
	coreLogBufferMu.Lock()
	defer coreLogBufferMu.Unlock()
	if len(coreLogBuffer) >= coreLogBufferLimit {
		copy(coreLogBuffer, coreLogBuffer[1:])
		coreLogBuffer = coreLogBuffer[:coreLogBufferLimit-1]
	}
	coreLogBuffer = append(coreLogBuffer, message)
}

func handleDrainLogs() string {
	coreLogBufferMu.Lock()
	messages := coreLogBuffer
	coreLogBuffer = nil
	coreLogBufferMu.Unlock()
	if len(messages) == 0 {
		return "[]"
	}
	data, err := json.Marshal(messages)
	if err != nil {
		return "[]"
	}
	return string(data)
}

func handleGetCountryCode(ip string, fn func(value string)) {
	go func() {
		runLock.Lock()
		defer runLock.Unlock()
		codes := mmdb.IPInstance().LookupCode(net.ParseIP(ip))
		if len(codes) == 0 {
			fn("")
			return
		}
		fn(codes[0])
	}()
}

func handleGetMemory(fn func(value string)) {
	go func() {
		fn(strconv.FormatUint(statistic.DefaultManager.Memory(), 10))
	}()
}

func handleSetState(params string) {
	_ = json.Unmarshal([]byte(params), state.CurrentState)
}

func handleGetConfig(path string) (*config.RawConfig, error) {
	bytes, err := readFile(path)
	if err != nil {
		return nil, err
	}
	prof, err := config.UnmarshalRawConfig(bytes)
	if err != nil {
		return nil, err
	}
	return prof, nil
}

func handleCrash() {
	panic("handle invoke crash")
}

func handleUpdateConfig(bytes []byte) string {
	var params = &UpdateParams{}
	err := json.Unmarshal(bytes, params)
	if err != nil {
		return err.Error()
	}
	updateConfig(params)
	return ""
}

func handleSetupConfig(bytes []byte) string {
	var params = defaultSetupParams()
	err := UnmarshalJson(bytes, params)
	if err != nil {
		log.Errorln("unmarshalRawConfig error %v", err)
		return err.Error()
	}
	err = setupConfig(params)
	if err != nil {
		return err.Error()
	}
	return ""
}
