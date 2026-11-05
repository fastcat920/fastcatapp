// Offline tests against the production state machine and monitor.
// swiftc tvos/FastCatTV/TVServiceConnectivity.swift test/tvos/connectivity_test.swift -o /tmp/fastcat-connectivity-tests
// /tmp/fastcat-connectivity-tests
import Foundation

func tvText(_ zh: String, _ en: String, language: String) -> String { language == "en" ? en : zh }

actor ProbeRecorder {
  var gatewayOK = false
  var publicOK = false
  var proxyOK = false
  var calls = 0
  var activated: URL?
  func set(gateway: Bool, publicNetwork: Bool, proxy: Bool) {
    gatewayOK = gateway; publicOK = publicNetwork; proxyOK = proxy
  }
  func check(_ url: URL, _ gateway: Bool) -> Bool {
    calls += 1
    return gateway ? gatewayOK && url.host == "good.invalid" : publicOK
  }
  func proxy(_ name: String) -> Bool { proxyOK }
  func activate(_ url: URL) { activated = url }
}

actor TestGate {
  private var pending: CheckedContinuation<[URL], Never>?
  private var entered: CheckedContinuation<Void, Never>?
  private var didEnter = false
  func wait() async -> [URL] {
    didEnter = true; entered?.resume(); entered = nil
    return await withCheckedContinuation { pending = $0 }
  }
  func waitForEntry() async {
    if didEnter { return }
    await withCheckedContinuation { entered = $0 }
  }
  func release() { pending?.resume(returning: []); pending = nil }
}

final class OfflineHTTP: URLProtocol {
  static var code = 204
  static var paths: [String] = []
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    precondition(request.url?.host == "probe.invalid")
    precondition(request.value(forHTTPHeaderField: "Authorization") == nil)
    Self.paths.append(request.url!.path)
    client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.code,
      httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data())
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

@main
struct ConnectivityTests {
  @MainActor
  static func main() async {
    let healthy = TVConnectivitySample(hasNetwork: true, gatewayReachable: true,
      publicReachable: true, proxyConnected: false, proxyReachable: nil)
    let samples: [(TVConnectivitySample, TVServiceCause)] = [
      (healthy, .none),
      (.init(hasNetwork: false, gatewayReachable: false, publicReachable: false,
             proxyConnected: false, proxyReachable: nil), .noNetwork),
      (.init(hasNetwork: true, gatewayReachable: false, publicReachable: false,
             proxyConnected: false, proxyReachable: nil), .networkRestricted),
      (.init(hasNetwork: true, gatewayReachable: false, publicReachable: true,
             proxyConnected: false, proxyReachable: nil), .gatewayUnavailable),
      (.init(hasNetwork: true, gatewayReachable: false, publicReachable: false,
             proxyConnected: true, proxyReachable: true), .gatewayUnavailable),
      (.init(hasNetwork: true, gatewayReachable: true, publicReachable: true,
             proxyConnected: true, proxyReachable: false), .proxyUnavailable),
      (.init(hasNetwork: true, gatewayReachable: false, publicReachable: false,
             proxyConnected: true, proxyReachable: false), .proxyUnavailable),
      (.init(hasNetwork: false, gatewayReachable: false, publicReachable: false,
             proxyConnected: true, proxyReachable: true), .gatewayUnavailable),
    ]
    for (sample, cause) in samples { precondition(sample.cause == cause) }
    var state = TVServiceState()
    precondition(!state.showBadge && state.protectsLogout)
    let failed = samples[2].0
    state.record(failed)
    precondition(!state.showBadge && state.retrySeconds == 5)
    state.record(failed)
    precondition(state.showBadge && state.status == .offline && state.retrySeconds == 15)
    state.record(failed); precondition(state.retrySeconds == 30)
    state.record(failed); precondition(state.retrySeconds == 60)
    state.record(healthy)
    precondition(state.status == .recovering && state.showBadge && state.retrySeconds == 2)
    state.record(healthy)
    precondition(state.status == .online && !state.showBadge && !state.protectsLogout)
    for language in ["en", "zh"] {
      for (sample, _) in samples {
        var value = TVServiceState()
        value.record(sample); value.record(sample)
        precondition(!value.title(language: language).isEmpty && !value.detail(language: language).isEmpty)
      }
    }

    let recorder = ProbeRecorder()
    let good = URL(string: "https://good.invalid/api/v1")!
    let monitor = TVServiceConnectivityMonitor(
      gatewayURLs: { [URL(string: "https://bad.invalid/api/v1")!, good] },
      probe: { await recorder.check($0, $1) },
      proxyProbe: { await recorder.proxy($0) },
      gatewayRecovered: { await recorder.activate($0) })
    monitor.updateNetworkPath(reachable: true, signature: "wifi")
    await monitor.verifyNow(); await monitor.verifyNow()
    precondition(monitor.state.cause == .networkRestricted && monitor.state.showBadge)
    await recorder.set(gateway: false, publicNetwork: true, proxy: false)
    await monitor.verifyNow(); precondition(monitor.state.cause == .gatewayUnavailable)
    await recorder.set(gateway: true, publicNetwork: true, proxy: true)
    await monitor.verifyNow(); await monitor.verifyNow()
    precondition(monitor.state.status == .online)
    let activated = await recorder.activated
    precondition(activated == good, "A healthy backup must be adopted")

    monitor.updateProxy(connected: true, name: "GLOBAL")
    let beforeWarmup = await recorder.calls
    await monitor.verifyNow()
    let afterWarmup = await recorder.calls
    precondition(beforeWarmup == afterWarmup, "No probe during VPN warmup")
    await recorder.set(gateway: true, publicNetwork: true, proxy: false)
    await monitor.verifyNow(now: .distantFuture)
    await monitor.verifyNow(now: .distantFuture)
    precondition(monitor.state.cause == .proxyUnavailable && monitor.state.showBadge)
    monitor.updateProxy(connected: true, name: "new-node")
    await recorder.set(gateway: true, publicNetwork: true, proxy: true)
    await monitor.verifyNow(now: .distantFuture); await monitor.verifyNow(now: .distantFuture)
    precondition(monitor.state.status == .online)
    // The group can stay the same while its selected node changes.
    monitor.updateProxy(connected: true, name: "new-node", selectionID: "node-b")
    precondition(monitor.state.status == .recovering)
    let beforeSelectionWarmup = await recorder.calls
    await monitor.verifyNow()
    let afterSelectionWarmup = await recorder.calls
    precondition(beforeSelectionWarmup == afterSelectionWarmup)
    monitor.stop(reset: true)
    precondition(monitor.state == TVServiceState())

    // A result from before logout/background or a network change cannot win.
    for change in ["stop", "network", "node"] {
      let gate = TestGate()
      let pending = TVServiceConnectivityMonitor(gatewayURLs: { await gate.wait() },
        probe: { _, _ in false }, proxyProbe: { _ in false })
      pending.updateNetworkPath(reachable: true, signature: "old")
      let task = Task { await pending.verifyNow() }
      await gate.waitForEntry()
      precondition(pending.isChecking)
      await pending.verifyNow() // Must coalesce rather than enqueue another call.
      if change == "stop" { pending.stop(reset: true) }
      else if change == "network" { pending.updateNetworkPath(reachable: false, signature: "new") }
      else { pending.updateProxy(connected: true, name: "same-group", selectionID: "new-node") }
      await gate.release(); await task.value
      precondition(pending.state.failures == 0 && !pending.isChecking)
    }

    let base = URL(string: "https://probe.invalid/api/v1")!
    for (code, gatewayExpected, publicExpected) in [(204, true, true), (403, false, true), (500, false, false)] {
      OfflineHTTP.code = code
      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [OfflineHTTP.self]
      let gateway = await TVConnectivityHTTPProbe.check(base, gateway: true, configuration: configuration)
      let publicNetwork = await TVConnectivityHTTPProbe.check(base, gateway: false, configuration: configuration)
      precondition(gateway == gatewayExpected && publicNetwork == publicExpected)
    }
    precondition(OfflineHTTP.paths.contains("/api/v1/guest/comm/config"))
    print("PASS: state classification, debounce/recovery, warmup, proxy changes, backup gateway, stale-result cancellation, HTTP probes; all offline.")
  }
}
