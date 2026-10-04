import Combine
import Foundation
import Network

enum TVServiceStatus { case online, degraded, offline, recovering }
enum TVServiceCause { case none, noNetwork, gatewayUnavailable, networkRestricted, proxyUnavailable }

struct TVConnectivitySample {
  var hasNetwork: Bool
  var gatewayReachable: Bool
  var publicReachable: Bool
  var proxyConnected: Bool
  var proxyReachable: Bool?

  var cause: TVServiceCause {
    if !hasNetwork && !gatewayReachable && !publicReachable && proxyReachable != true { return .noNetwork }
    if proxyConnected && proxyReachable == false { return .proxyUnavailable }
    if gatewayReachable { return .none }
    if publicReachable || proxyReachable == true { return .gatewayUnavailable }
    return .networkRestricted
  }
}

struct TVServiceState: Equatable {
  var status: TVServiceStatus = .recovering
  var cause: TVServiceCause = .none
  var failures = 0
  var successes = 0
  var checkedAt: Date?

  var showBadge: Bool { status != .online && failures >= 2 }
  var protectsLogout: Bool { status != .online }
  var retrySeconds: Double {
    if status == .online { return 60 }
    if successes > 0 { return 2 }
    switch failures {
    case 0...1: return 5
    case 2: return 15
    case 3: return 30
    default: return 60
    }
  }

  mutating func record(_ sample: TVConnectivitySample, now: Date = Date()) {
    checkedAt = now
    if sample.cause == .none {
      successes += 1
      if status == .online || successes >= 2 {
        status = .online; cause = .none; failures = 0
      } else { status = .recovering }
    } else {
      failures += 1; successes = 0; cause = sample.cause
      status = failures >= 2 ? .offline : .degraded
    }
  }

  func title(language: String) -> String {
    switch status {
    case .online: return tvText("服务连接正常", "Service connected", language: language)
    case .recovering: return tvText("正在恢复连接", "Restoring connection", language: language)
    case .degraded: return tvText("服务连接不稳定", "Service connection unstable", language: language)
    case .offline:
      switch cause {
      case .noNetwork: return tvText("本地网络不可用", "Local network unavailable", language: language)
      case .proxyUnavailable: return tvText("当前代理连接异常", "Current proxy connection failed", language: language)
      case .networkRestricted: return tvText("网络连接受限", "Network access restricted", language: language)
      default: return tvText("离线缓存模式", "Offline cache mode", language: language)
      }
    }
  }

  func detail(language: String) -> String {
    if status == .online { return tvText("业务网关可用，网络状态检测已通过。", "The business gateway is available and connectivity checks passed.", language: language) }
    if status == .recovering || status == .degraded {
      return tvText("客户端正在确认网络和业务网关状态，请稍候。", "Checking network and business gateway availability. Please wait.", language: language)
    }
    switch cause {
    case .noNetwork:
      return tvText("当前设备没有可用的网络连接，请检查 Wi-Fi 或有线网络。", "No usable network connection. Check Wi-Fi or Ethernet.", language: language)
    case .proxyUnavailable:
      return tvText("VPN 隧道已连接，但当前代理出口检测失败。请尝试切换节点；这不一定是本地网络故障。", "The VPN tunnel is connected, but proxy exit checks failed. Try another node; your local network may still be working.", language: language)
    case .gatewayUnavailable:
      return tvText("公网或代理出口可用，但业务服务器暂不可达。已有缓存节点仍可尝试使用，套餐等在线功能可能暂不可用。恢复后会自动退出离线缓存模式。", "Internet or proxy access is available, but the business service is unreachable. Cached nodes remain available to try; online account features may be unavailable. This mode clears automatically after recovery.", language: language)
    default:
      return tvText("检测到网络接口，但公网基准和业务网关均未通过检测。请检查网络限制、DNS 或切换节点。", "A network interface is present, but public internet and gateway checks failed. Check restrictions or DNS, or try another node.", language: language)
    }
  }
}

/// Foreground-only, read-only probes. Never starts a VPN, logs out, creates
/// orders, clears subscriptions, or retries a mutating business request.
@MainActor
final class TVServiceConnectivityMonitor: ObservableObject {
  @Published private(set) var state = TVServiceState()
  @Published private(set) var isChecking = false
  private let gatewayURLs: () async -> [URL]
  private let probe: (URL, Bool) async -> Bool
  private let proxyProbe: (String) async -> Bool
  private let gatewayRecovered: (URL) async -> Void
  private var pathMonitor: NWPathMonitor?
  private var worker: Task<Void, Never>?
  private var generation = 0
  private var revision = 0
  private var hasNetwork: Bool?
  private var pathSignature: String?
  private var nextCheckAt = Date.distantPast
  private var warmupUntil = Date.distantPast
  private var proxyConnected = false
  private var proxyName: String?
  private var proxySelectionID: String?

  init(gatewayURLs: @escaping () async -> [URL],
       probe: @escaping (URL, Bool) async -> Bool = TVConnectivityHTTPProbe.check,
       proxyProbe: @escaping (String) async -> Bool,
       gatewayRecovered: @escaping (URL) async -> Void = { _ in }) {
    self.gatewayURLs = gatewayURLs
    self.probe = probe
    self.proxyProbe = proxyProbe
    self.gatewayRecovered = gatewayRecovered
  }

  func start() {
    guard worker == nil else { return }
    generation += 1
    let current = generation
    let monitor = NWPathMonitor()
    pathMonitor = monitor
    monitor.pathUpdateHandler = { [weak self] path in
      let reachable = path.status == .satisfied
      let signature = "\(reachable):\(path.availableInterfaces.map { $0.name }.sorted().joined(separator: ","))"
      Task { @MainActor [weak self] in
        guard let self, self.generation == current else { return }
        self.updateNetworkPath(reachable: reachable, signature: signature)
      }
    }
    monitor.start(queue: DispatchQueue(label: "fastcat.tv.connectivity"))
    nextCheckAt = Date()
    worker = Task { [weak self] in
      while !Task.isCancelled {
        guard let self, self.generation == current else { return }
        if self.hasNetwork != nil && Date() >= self.nextCheckAt {
          await self.verifyNow()
        }
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
      }
    }
  }

  func stop(reset: Bool = false) {
    generation += 1; revision += 1
    worker?.cancel(); worker = nil
    pathMonitor?.cancel(); pathMonitor = nil
    hasNetwork = nil; pathSignature = nil
    isChecking = false
    if reset {
      state = TVServiceState()
      proxyConnected = false; proxyName = nil; proxySelectionID = nil; warmupUntil = .distantPast
    }
  }

  func updateNetworkPath(reachable: Bool, signature: String) {
    guard pathSignature != signature else { return }
    hasNetwork = reachable; pathSignature = signature; revision += 1
    state.status = .recovering; state.successes = 0
    nextCheckAt = Date().addingTimeInterval(reachable ? 2 : 3)
  }

  func updateProxy(connected: Bool, name: String?, selectionID: String? = nil) {
    guard proxyConnected != connected || proxyName != name || proxySelectionID != selectionID else { return }
    proxyConnected = connected; proxyName = name; proxySelectionID = selectionID; revision += 1
    // Retain the existing warning during confirmation, rather than flashing
    // between offline/online at every route change.
    state.status = .recovering; state.successes = 0
    warmupUntil = Date().addingTimeInterval(connected ? 8 : 3)
    nextCheckAt = warmupUntil
  }

  func requestCheck() {
    // Coalesce concurrent business errors into one check. Do not probe from
    // every request, or move an already scheduled check further into the future.
    nextCheckAt = min(nextCheckAt, Date().addingTimeInterval(1))
  }

  func verifyNow(now: Date = Date()) async {
    guard !isChecking, let hasNetwork else { return }
    guard now >= warmupUntil else { nextCheckAt = warmupUntil; return }
    isChecking = true
    let current = generation
    let currentRevision = revision
    let connected = proxyConnected
    let name = proxyName
    defer { if generation == current { isChecking = false } }
    let bases = await gatewayURLs()
    guard !Task.isCancelled, generation == current, revision == currentRevision else { return }
    let gateway = await firstReachable(bases, gateway: true)
    let publicReachable = gateway != nil ? true : await firstReachable(Self.publicURLs, gateway: false) != nil
    let proxyReachable: Bool?
    if connected, let name, !name.isEmpty { proxyReachable = await proxyProbe(name) }
    else { proxyReachable = nil }
    guard !Task.isCancelled, generation == current, revision == currentRevision else { return }
    state.record(TVConnectivitySample(hasNetwork: hasNetwork,
      gatewayReachable: gateway != nil, publicReachable: publicReachable,
      proxyConnected: connected, proxyReachable: proxyReachable))
    nextCheckAt = Date().addingTimeInterval(state.retrySeconds)
    if let gateway { await gatewayRecovered(gateway) }
  }

  private func firstReachable(_ urls: [URL], gateway: Bool) async -> URL? {
    let probe = self.probe
    return await withTaskGroup(of: URL?.self) { group in
      for url in Set(urls) {
        group.addTask { await probe(url, gateway) ? url : nil }
      }
      for await result in group {
        if let result { group.cancelAll(); return result }
      }
      return nil
    }
  }

  static let publicURLs = [
    "https://connect.rom.miui.com/generate_204",
    "https://wifi.vivo.com.cn/generate_204",
    "https://connectivitycheck.platform.hicloud.com/generate_204",
  ].compactMap(URL.init(string:))
}

enum TVConnectivityHTTPProbe {
  static func check(_ base: URL, gateway: Bool) async -> Bool {
    await check(base, gateway: gateway, configuration: .ephemeral)
  }

  static func check(_ base: URL, gateway: Bool, configuration config: URLSessionConfiguration) async -> Bool {
    config.timeoutIntervalForRequest = 5
    config.timeoutIntervalForResource = 6
    config.waitsForConnectivity = false
    config.urlCache = nil
    config.httpCookieStorage = nil
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    let url = gateway ? base.appendingPathComponent("guest/comm/config") : base
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    // These requests carry no account token. They use the system's current
    // route, which can include the VPN; do not claim they bypass the tunnel.
    do {
      let (_, response) = try await session.data(for: request)
      guard let response = response as? HTTPURLResponse else { return false }
      return (gateway ? 200..<300 : 200..<500).contains(response.statusCode)
    } catch { return false }
  }
}

#if os(tvOS)
extension TVServiceConnectivityMonitor {
  static func live() -> TVServiceConnectivityMonitor {
    TVServiceConnectivityMonitor(
      gatewayURLs: { await TVRemoteConfigManager.shared.connectivityBaseURLs() },
      proxyProbe: { name in
        // Two independent destinations reduce single-site false alarms.
        for url in ["https://www.gstatic.com/generate_204", "https://cp.cloudflare.com/generate_204"] {
          if Task.isCancelled { return false }
          let reachable = await withCheckedContinuation { continuation in
            let completion = TVProbeCompletion(continuation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { completion.finish(false) }
            VPNManager.shared.testDelay(proxyName: name, testURL: url, timeoutMilliseconds: 4000) {
              completion.finish(($0 ?? -1) > 0)
            }
          }
          if reachable { return true }
        }
        return false
      },
      gatewayRecovered: { await TVRemoteConfigManager.shared.useHealthyGateway($0) }
    )
  }
}

private final class TVProbeCompletion {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Bool, Never>?
  init(_ continuation: CheckedContinuation<Bool, Never>) { self.continuation = continuation }
  func finish(_ value: Bool) {
    lock.lock()
    let callback = continuation
    continuation = nil
    lock.unlock()
    callback?.resume(returning: value)
  }
}
#endif
