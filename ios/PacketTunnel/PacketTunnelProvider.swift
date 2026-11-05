import NetworkExtension
import Foundation
import Darwin

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
        for packet in packets {
          guard owner.packetSessionIsCurrent(generation) else { return }
          packet.withUnsafeBytes { raw in
            guard let address = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            _ = ClashCore_write_packet(generation, address, Int32(packet.count))
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

    // Initialise the mihomo core (synchronous C call via bridging header).
    // The Go layer force-disables TUN, enables DNS on 127.0.0.1:53,
    // and ensures mixed-port is set.
    let initResult = ClashCore_init(homeDir, config)
    guard initResult == 0 else {
      NSLog("[PacketTunnel] ERROR: ClashCore_init failed with code %d", initResult)
      completionHandler(makeError("ClashCore_init failed: \(initResult)"))
      return
    }
    NSLog("[PacketTunnel] ClashCore_init succeeded")
    guard startPacketForwarding() else {
      ClashCore_shutdown()
      completionHandler(makeError("Unable to start VPN packet stack"))
      return
    }

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
        NSLog("[PacketTunnel] Tunnel started (idle mode, mihomo on port %d)", mixedPort)
        completionHandler(nil)
      }
    }
  }

  // MARK: - Tunnel stop

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
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
    if method == "streamingProbe" {
      DispatchQueue.global(qos: .utility).async {
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
    // Provider-originated upstream sockets use the underlying network.
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
