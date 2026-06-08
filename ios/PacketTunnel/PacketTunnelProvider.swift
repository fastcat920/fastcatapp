import NetworkExtension
import Foundation

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

/// NEPacketTunnelProvider that hosts the mihomo (libclash) core in **proxy mode**.
///
/// Architecture:
///   1. mihomo starts with `mixed-port` (HTTP+SOCKS5 proxy on 127.0.0.1).
///      TUN is force-disabled in the Go layer — sing-tun is NOT used.
///   2. NEPacketTunnelNetworkSettings configures:
///      - DNS → mihomo fake-ip resolver (198.18.0.2)
///      - HTTP/HTTPS proxy → 127.0.0.1:<mixed-port>
///   3. The OS routes HTTP/HTTPS traffic through the local proxy automatically.
///      DNS queries are hijacked to mihomo for fake-ip / rule-based resolution.
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

  /// Whether traffic routing (proxy/DNS network settings) is active.
  /// When false, mihomo is running for IPC (delay tests etc.) but no traffic is routed.
  private var isTrafficEnabled = false

  /// Cached mixed-port from mihomo, used when toggling traffic on/off.
  private var cachedMixedPort: Int = 0

  // MARK: - Tunnel start

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    NSLog("[PacketTunnel] startTunnel called")
    let config = loadClashConfig()
    guard !config.isEmpty else {
      NSLog("[PacketTunnel] ERROR: No clash config available")
      completionHandler(makeError("No clash config available"))
      return
    }
    NSLog("[PacketTunnel] Config loaded: %d chars", config.count)

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

    // Get the mixed-port that mihomo is listening on.
    let mixedPort = Int(ClashCore_get_mixed_port())
    guard mixedPort > 0 else {
      NSLog("[PacketTunnel] ERROR: mixed-port not available")
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
  /// - `_updateConfig`: data = YAML config string — hot-reload mihomo config
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
    // Write updated config to App Group for persistence
    if let url = appGroupContainerURL()?.appendingPathComponent("clash.yaml") {
      try? config.write(to: url, atomically: true, encoding: .utf8)
    }
    // Use mihomo's built-in config reload via ClashCore_invoke
    let resultCStr = ClashCore_invoke("setupConfig", config)
    defer { ClashCore_free(resultCStr) }
    let resultString = resultCStr.map { String(cString: $0) } ?? "ok"
    completionHandler?(resultString.data(using: .utf8))
  }

  // MARK: - Network settings (proxy mode)

  private func buildNetworkSettings(mixedPort: Int) -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")

    // DNS servers must be Chinese-accessible (8.8.8.8 is blocked/polluted).
    // DNS pollution doesn't matter: HTTP CONNECT proxy sends hostnames,
    // not resolved IPs, so mihomo resolves the real address remotely.
    let dnsServers = ["223.5.5.5", "119.29.29.29"]

    // IPv4: minimal TUN interface — needed for the VPN to appear "active".
    // We do NOT use NEIPv4Route.default() because:
    // 1. There's no TUN packet reader, so routed traffic would be blackholed
    // 2. mihomo's own connections to remote proxy servers would also be lost
    // Instead, traffic routing is handled entirely by NEProxySettings below.
    let ipv4 = NEIPv4Settings(
      addresses: ["198.18.0.1"],
      subnetMasks: ["255.255.255.0"]
    )
    ipv4.includedRoutes = [
      // Only route the fake-ip range through the tunnel (for mihomo's
      // internal DNS mapping). All other traffic uses proxy settings.
      NEIPv4Route(destinationAddress: "198.18.0.0", subnetMask: "255.254.0.0")
    ]
    settings.ipv4Settings = ipv4

    // DNS settings
    let dns = NEDNSSettings(servers: dnsServers)
    dns.matchDomains = [""]  // capture all DNS queries
    settings.dnsSettings = dns

    // Proxy: route HTTP/HTTPS/SOCKS through mihomo's mixed-port.
    // mixed-port supports both HTTP CONNECT and SOCKS5 protocols.
    let proxy = NEProxySettings()
    proxy.httpEnabled = true
    proxy.httpServer = NEProxyServer(address: "127.0.0.1", port: mixedPort)
    proxy.httpsEnabled = true
    proxy.httpsServer = NEProxyServer(address: "127.0.0.1", port: mixedPort)
    // Auto-proxy via PAC: ensures all traffic (not just browser HTTP) uses
    // the proxy. The PAC script routes everything through SOCKS5 first
    // (better for non-HTTP traffic), with HTTP CONNECT as fallback.
    proxy.proxyAutoConfigurationJavaScript = """
      function FindProxyForURL(url, host) {
        return "SOCKS 127.0.0.1:\(mixedPort); PROXY 127.0.0.1:\(mixedPort); DIRECT";
      }
      """
    proxy.matchDomains = [""]  // apply to all domains
    proxy.excludeSimpleHostnames = false
    settings.proxySettings = proxy

    settings.mtu = 1500

    return settings
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

  private func loadClashConfig() -> String {
    // 1. Try App Group shared container (written by main app on connect).
    //    This is the primary path for TestFlight/App Store and well-configured TrollStore.
    if let url = appGroupContainerURL() {
      let configUrl = url.appendingPathComponent("clash.yaml")
      NSLog("[PacketTunnel] loadClashConfig: trying App Group at %@", configUrl.path)
      if let content = try? String(contentsOf: configUrl, encoding: .utf8),
         !content.isEmpty {
        NSLog("[PacketTunnel] loadClashConfig: loaded from App Group (%d chars)", content.count)
        return content
      }
      NSLog("[PacketTunnel] loadClashConfig: App Group file missing or empty")
    } else {
      NSLog("[PacketTunnel] loadClashConfig: App Group container unavailable (kAppGroupId=%@)", kAppGroupId)
    }

    // 2. Fallback: providerConfiguration embedded in the tunnel protocol.
    //    Works for small configs. TrollStore apps may rely on this path if
    //    App Group containers aren't accessible.
    if let config = (protocolConfiguration as? NETunnelProviderProtocol)?
      .providerConfiguration?["config"] as? String,
       !config.isEmpty {
      NSLog("[PacketTunnel] loadClashConfig: loaded from providerConfiguration (%d chars)", config.count)
      return config
    }

    NSLog("[PacketTunnel] loadClashConfig: ERROR — no config available from any source")
    return ""
  }

  private func appGroupContainerURL() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: kAppGroupId
    )
  }

  private func makeError(_ msg: String) -> NSError {
    NSError(
      domain: "ApexPacketTunnel",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: msg]
    )
  }
}
