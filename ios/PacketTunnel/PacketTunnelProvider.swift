import NetworkExtension
import Foundation
import Darwin
import Network

// App Group identifier — must match Runner's entitlements.
// Dynamically derived from the extension's bundle ID at runtime.
// Extension bundle ID: "com.fastcat.app.PacketTunnel" → App: "com.fastcat.app" → Group: "group.com.fastcat.app"
private let kAppGroupId: String = {
  // Try Info.plist first (set by setup_ios.rb or Xcode build settings)
  if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
     !fromPlist.isEmpty, !fromPlist.contains("$(") {
    return fromPlist
  }
  // Derive from bundle ID: strip ".PacketTunnel" suffix to get app's bundle ID
  let extId = Bundle.main.bundleIdentifier ?? ""
  let appId = extId.hasSuffix(".PacketTunnel")
    ? String(extId.dropLast(".PacketTunnel".count))
    : extId
  return "group.\(appId.isEmpty ? "com.fastcat.app" : appId)"
}()

/// NEPacketTunnelProvider hosting Mihomo and a userspace IP packet stack.
///
/// NetworkExtension owns routes and exchanges raw IPv4/IPv6 packets with
/// a bounded Go bridge using the public packetFlow API. sing-tun/gVisor
/// forwards TCP/UDP through Mihomo, including rule matching and DNS hijacking.
///
/// Communication with the main app:
///   Main app  →  NETunnelProviderSession.sendProviderMessage()
///            →  handleAppMessage()  →  ClashCore.invoke()
///            →  response via completionHandler
///
/// libclash is statically linked into this extension target.
/// The bridging header PacketTunnel-Bridging-Header.h exposes
/// the C API from libclash.a.
class PacketTunnelProvider: NEPacketTunnelProvider {
  private let upstreamQueue = DispatchQueue(label: "fastcat.upstream-path")
  private var upstreamMonitor: NWPathMonitor?
  private var upstreamGeneration = UUID()
  private var upstreamIndex: UInt32 = 0

  private func watchUnderlyingPath(completion: @escaping (Error?) -> Void) {
    upstreamQueue.async {
      self.upstreamMonitor?.cancel()
      let generation=UUID();self.upstreamGeneration=generation
      let monitor=NWPathMonitor();self.upstreamMonitor=monitor
      var firstReply: ((Error?) -> Void)? = completion
      monitor.pathUpdateHandler = { [weak self] path in
        guard let self, self.upstreamGeneration==generation else {return}
        let interface = path.status == .satisfied ? path.availableInterfaces.first(where: {
          ($0.type == .wifi || $0.type == .cellular || $0.type == .wiredEthernet)
            && path.usesInterfaceType($0.type)
        }) : nil
        let index=interface.map {UInt32($0.index)} ?? 0
        if index != self.upstreamIndex {
          self.upstreamIndex=index
          ClashCore_set_upstream_interface(index)
          NSLog("[PacketTunnelUpstream] physical-path ready=%d index=%u",index != 0,index)
        }
        if index != 0, let reply=firstReply {
          firstReply=nil
          DispatchQueue.global(qos:.userInitiated).async {reply(nil)}
        }
      }
      // Install the fail-closed socket policy before loading any provider/DNS.
      self.upstreamIndex=0
      ClashCore_set_upstream_interface(0)
      monitor.start(queue:self.upstreamQueue)
      self.upstreamQueue.asyncAfter(deadline:.now()+8) {
        guard self.upstreamGeneration==generation, let reply=firstReply else {return}
        firstReply=nil
        self.upstreamMonitor?.cancel()
        DispatchQueue.global().async {reply(self.makeError("Underlying network is unavailable"))}
      }
    }
  }

  private let probeOperations: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "fastcat.extension.probes"
    queue.maxConcurrentOperationCount = 2
    queue.qualityOfService = .utility
    return queue
  }()
  private var memoryTimer: DispatchSourceTimer?

  private let memoryCounterLock = NSLock()
  private var runningMemoryProbes = 0
  private var pendingMemoryProbes = 0

  private func sampleMemory(_ stage: String) {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    memoryCounterLock.lock()
    let running = runningMemoryProbes
    let pending = pendingMemoryProbes
    memoryCounterLock.unlock()
    if result == KERN_SUCCESS {
      NSLog("[PacketTunnelMemory] stage=%@ pid=%d footprint=%llu resident=%llu probesRunning=%d probesPending=%d",
            stage, getpid(), info.phys_footprint, info.resident_size, running, pending)
    }
  }

  private func startMemoryDiagnostics() {
    memoryTimer?.cancel()
    probeOperations.cancelAllOperations()
    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "fastcat.memory"))
    let started = Date()
    var samples = 0
    timer.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(100))
    timer.setEventHandler { [weak self] in
      samples += 1
      if Date().timeIntervalSince(started) <= 60 || samples % 30 == 0 {
        self?.sampleMemory("periodic")
      }
    }
    memoryTimer = timer
    timer.resume()
  }

  private let packetLock = NSLock()
  private var packetGeneration: UInt64 = 0
  private let packetInputQueue = DispatchQueue(label: "fastcat.packet.input")
  private let packetOutputQueue = DispatchQueue(label: "fastcat.packet.output")

  private func packetSessionIsCurrent(_ generation: UInt64) -> Bool {
    packetLock.lock()
    defer { packetLock.unlock() }
    return packetGeneration == generation && generation != 0
  }

  private func startPacketForwarding() -> Bool {
    let generation = ClashCore_start_packets()
    guard generation != 0 else { return false }
    packetLock.lock()
    packetGeneration = generation
    packetLock.unlock()
    readPacketBatch(generation)
    packetOutputQueue.async { [weak self] in
      var bytes = [UInt8](repeating: 0, count: 65535)
      while self?.packetSessionIsCurrent(generation) == true {
        let count = ClashCore_read_packet(generation, &bytes, Int32(bytes.count))
        guard let owner = self, owner.packetSessionIsCurrent(generation) else { return }
        guard count > 0 else {
          owner.cancelTunnelWithError(owner.makeError("VPN packet stack stopped unexpectedly"))
          return
        }
        let family = (bytes[0] >> 4) == 6 ? AF_INET6 : AF_INET
        let written = autoreleasepool {
          owner.packetFlow.writePackets([Data(bytes.prefix(Int(count)))],
                                        withProtocols: [NSNumber(value: family)])
        }
        if !written {
          owner.cancelTunnelWithError(owner.makeError("Unable to write VPN packets"))
          return
        }
      }
    }
    return true
  }

  private func readPacketBatch(_ generation: UInt64) {
    guard packetSessionIsCurrent(generation) else { return }
    packetFlow.readPackets { [weak self] packets, _ in
      self?.packetInputQueue.async { [weak self] in
        guard let owner = self, owner.packetSessionIsCurrent(generation) else { return }
        autoreleasepool {
          for packet in packets {
            guard owner.packetSessionIsCurrent(generation) else { return }
            packet.withUnsafeBytes { raw in
              guard let address = raw.bindMemory(to: UInt8.self).baseAddress else { return }
              _ = ClashCore_write_packet(generation, address, Int32(packet.count))
            }
          }
        }
        owner.readPacketBatch(generation)
      }
    }
  }

  private func stopPacketForwarding() {
    packetLock.lock()
    packetGeneration = 0
    packetLock.unlock()
    ClashCore_stop_packets()
  }

  /// Whether traffic routing (proxy/DNS network settings) is active.
  /// When false, mihomo is running for IPC (delay tests etc.) but no traffic is routed.
  private var isTrafficEnabled = false

  /// Cached mixed-port from mihomo, used when toggling traffic on/off.
  private var cachedMixedPort: Int = 0

  /// Literal bootstrap resolvers derived from the active Mihomo config.
  /// NEDNSSettings only accepts IP addresses, so encrypted DNS hostnames remain
  /// inside Mihomo while their bootstrap IPs come from default-nameserver.
  private var cachedDnsServers = ["223.5.5.5", "119.29.29.29"]

  // MARK: - Tunnel start

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    watchUnderlyingPath { [weak self] error in
      guard let self else {return}
      if let error {completionHandler(error);return}
      self.startTunnelOnReadyPath(options:options,completionHandler:completionHandler)
    }
  }

  private func startTunnelOnReadyPath(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    startMemoryDiagnostics()
    sampleMemory("start.begin")
    NSLog("[PacketTunnel] startTunnel called")
    // The main app supplies the decoded profile only for this tunnel start.
    // Do not restore YAML from the shared container or VPN preferences: those
    // locations persist beyond the active session and expose node metadata.
    let config = options?["config"] as? String ?? ""
    guard !config.isEmpty else {
      NSLog("[PacketTunnel] ERROR: No clash config available")
      completionHandler(makeError("No clash config available"))
      return
    }
    NSLog("[PacketTunnel] Config loaded: %d chars", config.count)
    cachedDnsServers = extractDnsServers(from: config)

    let homeDir = appGroupContainerURL()?.path ?? NSTemporaryDirectory()
    NSLog("[PacketTunnel] homeDir: %@", homeDir)
    do {
      try prepareBundledGeoData(home: URL(fileURLWithPath: homeDir))
    } catch {
      NSLog("[PacketTunnel] Geo preparation failed: %@", error.localizedDescription)
      completionHandler(makeError("Routing data preparation failed: \(error.localizedDescription)"))
      return
    }

    sampleMemory("geo.ready")
    // Initialise the mihomo core (synchronous C call via bridging header).
    // The Go layer force-disables TUN, enables DNS on 127.0.0.1:53,
    // and ensures mixed-port is set.
    sampleMemory("core.init.before")
    let initResult = ClashCore_init(homeDir, config)
    sampleMemory("core.init.after")
    guard initResult == 0 else {
      NSLog("[PacketTunnel] ERROR: ClashCore_init failed with code %d", initResult)
      ClashCore_shutdown()
      let message = initResult == 6 ? "Bundled routing databases are missing or empty" : initResult == 5 ? "Saved proxy selection is unavailable; select a valid node" : "ClashCore_init failed: \(initResult)"
      completionHandler(makeError(message))
      return
    }
    NSLog("[PacketTunnel] ClashCore_init succeeded")
    guard startPacketForwarding() else {
      ClashCore_shutdown()
      completionHandler(makeError("Unable to start VPN packet stack"))
      return
    }

    sampleMemory("packet_stack.ready")

    // Get the mixed-port that mihomo is listening on.
    let mixedPort = Int(ClashCore_get_mixed_port())
    guard mixedPort > 0 else {
      NSLog("[PacketTunnel] ERROR: mixed-port not available")
      stopPacketForwarding()
      ClashCore_shutdown()
      completionHandler(makeError("mihomo mixed-port not available"))
      return
    }
    cachedMixedPort = mixedPort
    NSLog("[PacketTunnel] mixed-port: %d", mixedPort)

    // Check if caller wants traffic routing enabled immediately.
    // "ensureRunning" starts tunnel in idle mode (mihomo running, no traffic).
    // "start" (normal connect) starts with traffic enabled.
    let startMode = options?["mode"] as? String ?? "active"
    let enableTraffic = (startMode != "idle")
    NSLog("[PacketTunnel] start mode: %@, enableTraffic: %d", startMode, enableTraffic ? 1 : 0)

    if enableTraffic {
      // Apply full proxy network settings — traffic routes through mihomo.
      let settings = buildNetworkSettings(mixedPort: mixedPort)
      setTunnelNetworkSettings(settings) { [weak self] error in
        if let error = error {
          NSLog("[PacketTunnel] ERROR: setTunnelNetworkSettings: %@", error.localizedDescription)
          self?.stopPacketForwarding()
          ClashCore_shutdown()
          completionHandler(error)
          return
        }
        self?.isTrafficEnabled = true
        self?.sampleMemory("network_settings.ready")
        NSLog("[PacketTunnel] Tunnel started (active mode, port %d)", mixedPort)
        completionHandler(nil)
      }
    } else {
      // Idle mode: mihomo is running for IPC but no traffic routing.
      // Minimal network settings so the system considers the tunnel "up".
      let settings = buildIdleNetworkSettings()
      setTunnelNetworkSettings(settings) { [weak self] error in
        if let error = error {
          NSLog("[PacketTunnel] ERROR: setTunnelNetworkSettings (idle): %@", error.localizedDescription)
          self?.stopPacketForwarding()
          ClashCore_shutdown()
          completionHandler(error)
          return
        }
        self?.isTrafficEnabled = false
        self?.sampleMemory("network_settings.ready")
        NSLog("[PacketTunnel] Tunnel started (idle mode, mihomo on port %d)", mixedPort)
        completionHandler(nil)
      }
    }
  }

  // MARK: - Tunnel stop

  /// The extension has its own home; Flutter's asset preparation cannot fill it.
  private func prepareBundledGeoData(home: URL) throws {
    let files = FileManager.default
    let app = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    let assets = app.appendingPathComponent("Frameworks/App.framework/flutter_assets/assets/data")
    try files.createDirectory(at: home, withIntermediateDirectories: true)
    let mapping = ["GeoIP.dat": "GeoIP.dat", "GeoSite.dat": "GeoSite.dat",
                   "ASN.mmdb": "ASN.mmdb", "geoip.metadb": "geoip.metadb"]
    let existing = try files.contentsOfDirectory(at: home, includingPropertiesForKeys: [.fileSizeKey])
    for (name, asset) in mapping {
      let aliases = name == "geoip.metadb" ? ["geoip.metadb", "country.mmdb", "geoip.db"] : [name.lowercased()]
      if let found = existing.first(where: { aliases.contains($0.lastPathComponent.lowercased()) }),
         (try found.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 { continue }
      let source = assets.appendingPathComponent(asset)
      let destination = home.appendingPathComponent(name)
      // Atomic replacement prevents a cancelled first start leaving half a file.
      let data = try Data(contentsOf: source, options: .mappedIfSafe)
      guard !data.isEmpty else { throw makeError("Bundled routing data is empty") }
      try data.write(to: destination, options: .atomic)
      NSLog("[PacketTunnel] Prepared bundled routing data: %@", name)
    }
    NSLog("[PacketTunnel] Routing data preparation complete")
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    NSLog("[PacketTunnel] stopTunnel reason=%ld", reason.rawValue)
    upstreamQueue.sync {
      upstreamGeneration=UUID()
      upstreamMonitor?.cancel();upstreamMonitor=nil;upstreamIndex=0
      ClashCore_set_upstream_interface(0)
    }
    sampleMemory("stop.begin")
    memoryTimer?.cancel()
    memoryTimer = nil
    stopPacketForwarding()
    isTrafficEnabled = false
    ClashCore_shutdown()
    completionHandler()
  }

  // MARK: - App ↔ Extension IPC

  /// Receives JSON messages from [VPNManager.sendClashMessage] in the main app.
  /// Payload format: { "method": "<ActionMethod name>", "data": "<optional string>" }
  ///
  /// Special internal methods:
  /// - `_setTrafficMode`: data = "active" | "idle" — toggles proxy network settings
  /// - `_getTrafficMode`: returns "active" or "idle"
  /// - `_updateConfig`: data = JSON SetupParams — hot-reload mihomo config
  override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
    guard
      let payload = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
      let method = payload["method"] as? String
    else {
      completionHandler?(nil)
      return
    }
    let data = payload["data"] as? String

    // Internal traffic mode toggle — not forwarded to mihomo.
    if method == "_setTrafficMode" {
      handleSetTrafficMode(data ?? "active", completionHandler: completionHandler)
      return
    }
    if method == "_getTrafficMode" {
      let mode = isTrafficEnabled ? "active" : "idle"
      completionHandler?(mode.data(using: .utf8))
      return
    }
    if method == "_updateConfig" {
      handleUpdateConfig(data ?? "", completionHandler: completionHandler)
      return
    }

    // A probe can take seconds. Do not block delivery of its cancellation IPC.
    if method == "streamingProbe" || method == "asyncTestDelay" || method == "diagnoseProxy" {
      // Network probes must not occupy NetworkExtension's message delivery
      // thread: node selection and cancellation need immediate delivery.
      let queuedAt = Date()
      memoryCounterLock.lock()
      pendingMemoryProbes += 1
      memoryCounterLock.unlock()
      sampleMemory("probe.queued." + method)
      probeOperations.addOperation {
        self.memoryCounterLock.lock()
        self.pendingMemoryProbes -= 1
        self.runningMemoryProbes += 1
        self.memoryCounterLock.unlock()
        self.sampleMemory("probe.begin." + method)
        defer {
          self.memoryCounterLock.lock()
          self.runningMemoryProbes -= 1
          self.memoryCounterLock.unlock()
          self.sampleMemory("probe.end." + method)
        }
        guard Date().timeIntervalSince(queuedAt) < 8 else {
          completionHandler?(nil)
          return
        }
        let result = ClashCore_invoke(method, data)
        defer { ClashCore_free(result) }
        let value = result.map { String(cString: $0) } ?? ""
        completionHandler?(value.data(using: .utf8))
      }
      return
    }
    let resultCStr = ClashCore_invoke(method, data)
    defer { ClashCore_free(resultCStr) }

    let resultString = resultCStr.map { String(cString: $0) } ?? ""
    completionHandler?(resultString.data(using: .utf8))
  }

  // MARK: - Traffic mode toggle

  /// Switch between active (proxy routing) and idle (mihomo running, no routing).
  private func handleSetTrafficMode(_ mode: String, completionHandler: ((Data?) -> Void)?) {
    let wantActive = (mode == "active")
    NSLog("[PacketTunnel] setTrafficMode: %@ (currently %@)", mode, isTrafficEnabled ? "active" : "idle")

    if wantActive {
      guard cachedMixedPort > 0 else {
        NSLog("[PacketTunnel] ERROR: cannot enable traffic, mixedPort not available")
        completionHandler?("error: mixedPort not available".data(using: .utf8))
        return
      }
      let settings = buildNetworkSettings(mixedPort: cachedMixedPort)
      setTunnelNetworkSettings(settings) { [weak self] error in
        if let error = error {
          NSLog("[PacketTunnel] ERROR: setTrafficMode active: %@", error.localizedDescription)
          completionHandler?("error: \(error.localizedDescription)".data(using: .utf8))
          return
        }
        self?.isTrafficEnabled = true
        NSLog("[PacketTunnel] Traffic mode: active (port %d)", self?.cachedMixedPort ?? 0)
        completionHandler?("ok".data(using: .utf8))
      }
    } else {
      let settings = buildIdleNetworkSettings()
      setTunnelNetworkSettings(settings) { [weak self] error in
        if let error = error {
          NSLog("[PacketTunnel] ERROR: setTrafficMode idle: %@", error.localizedDescription)
          completionHandler?("error: \(error.localizedDescription)".data(using: .utf8))
          return
        }
        self?.isTrafficEnabled = false
        NSLog("[PacketTunnel] Traffic mode: idle")
        completionHandler?("ok".data(using: .utf8))
      }
    }
  }

  /// Hot-reload mihomo config without restarting the tunnel.
  private func handleUpdateConfig(_ config: String, completionHandler: ((Data?) -> Void)?) {
    guard !config.isEmpty else {
      completionHandler?("error: empty config".data(using: .utf8))
      return
    }
    // Use mihomo's built-in config reload via ClashCore_invoke
    guard let resultCStr = ClashCore_invoke("setupConfig", config) else {
      completionHandler?("error: core did not acknowledge configuration".data(using: .utf8))
      return
    }
    defer { ClashCore_free(resultCStr) }
    let resultString = String(cString: resultCStr)
    guard resultString.isEmpty || resultString == "ok" else {
      completionHandler?(resultString.data(using: .utf8))
      return
    }
    let mixedPort = Int(ClashCore_get_mixed_port())
    guard mixedPort > 0 else {
      completionHandler?("error: mixed-port unavailable after configuration update".data(using: .utf8))
      return
    }
    cachedDnsServers = extractDnsServers(from: config)
    cachedMixedPort = mixedPort
    if isTrafficEnabled {
      setTunnelNetworkSettings(buildNetworkSettings(mixedPort: cachedMixedPort)) { error in
        let result = error.map { "error: \($0.localizedDescription)" } ?? resultString
        completionHandler?(result.data(using: .utf8))
      }
      return
    }
    completionHandler?(resultString.data(using: .utf8))
  }

  // MARK: - Network settings (packet forwarding)

  private func buildNetworkSettings(mixedPort: Int) -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")

    // A virtual resolver address; TCP and UDP port 53 enter Mihomo's resolver.
    let dnsServers = ["198.18.0.2"]

    // NetworkExtension owns routes; the userspace stack owns TCP/UDP and DNS.
    // Provider-originated sockets are explicitly bound by the upstream path policy.
    let ipv4 = NEIPv4Settings(
      addresses: ["198.18.0.1"],
      subnetMasks: ["255.255.255.252"]
    )
    ipv4.includedRoutes = [NEIPv4Route.default()]
    settings.ipv4Settings = ipv4
    let ipv6 = NEIPv6Settings(addresses: ["fdfe:dcba:9876::1"],
                             networkPrefixLengths: [126])
    ipv6.includedRoutes = [NEIPv6Route.default()]
    settings.ipv6Settings = ipv6

    // DNS settings
    let dns = NEDNSSettings(servers: dnsServers)
    dns.matchDomains = [""]  // capture all DNS queries
    settings.dnsSettings = dns

    // Do not install HTTP/PAC proxy settings: all application sockets now
    // traverse packetFlow, and rules decide DIRECT versus proxy in Mihomo.

    settings.mtu = 1500

    return settings
  }

  private func extractDnsServers(from setupPayload: String) -> [String] {
    guard
      let data = setupPayload.data(using: .utf8),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let dns = ((root["config"] as? [String: Any]) ?? root)["dns"] as? [String: Any]
    else { return ["223.5.5.5", "119.29.29.29"] }

    let values = (dns["default-nameserver"] as? [Any] ?? []) +
      (dns["nameserver"] as? [Any] ?? [])
    var result: [String] = []
    for case let value as String in values {
      if let ip = literalIp(from: value), !result.contains(ip) {
        result.append(ip)
      }
      if result.count == 4 { break }
    }
    return result.isEmpty ? ["223.5.5.5", "119.29.29.29"] : result
  }

  private func literalIp(from endpoint: String) -> String? {
    let value = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    if isLiteralIp(value) { return value }
    if value.hasPrefix("["), let closing = value.firstIndex(of: "]") {
      let start = value.index(after: value.startIndex)
      let candidate = String(value[start..<closing])
      return isLiteralIp(candidate) ? candidate : nil
    }
    if value.filter({ $0 == ":" }).count == 1,
       let separator = value.lastIndex(of: ":") {
      let candidate = String(value[..<separator])
      return isLiteralIp(candidate) ? candidate : nil
    }
    if let host = URLComponents(string: value)?.host, isLiteralIp(host) {
      return host
    }
    return nil
  }

  private func isLiteralIp(_ value: String) -> Bool {
    var ipv4 = in_addr()
    var ipv6 = in6_addr()
    return value.withCString {
      inet_pton(AF_INET, $0, &ipv4) == 1 || inet_pton(AF_INET6, $0, &ipv6) == 1
    }
  }

  // MARK: - Idle network settings (no traffic routing)

  /// Minimal network settings: tunnel appears "up" to the system but
  /// no DNS/proxy routing is applied. mihomo keeps running for IPC.
  private func buildIdleNetworkSettings() -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")
    // Minimal IPv4 — just enough for the system to consider the tunnel active.
    let ipv4 = NEIPv4Settings(
      addresses: ["198.18.0.1"],
      subnetMasks: ["255.255.255.0"]
    )
    // No included routes → no traffic routed through tunnel.
    ipv4.includedRoutes = []
    settings.ipv4Settings = ipv4
    // No DNS settings, no proxy settings → system uses normal network path.
    settings.mtu = 1500
    return settings
  }

  // MARK: - Helpers

  /// The App Group remains the core's runtime directory. Profile YAML is never
  /// stored there; it is supplied only in the active tunnel start message.
  private func appGroupContainerURL() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: kAppGroupId
    )
  }

  private func makeError(_ msg: String) -> NSError {
    NSError(
      domain: "FastCatPacketTunnel",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: msg]
    )
  }
}
