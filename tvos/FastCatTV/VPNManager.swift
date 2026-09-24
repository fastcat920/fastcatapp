import Foundation
import NetworkExtension

// App Group identifier shared between Runner and PacketTunnel.
// Dynamically derived from the bundle ID at runtime, so it works with both
// TrollStore (no build-time variable replacement) and TestFlight/App Store.
// setup_ios.rb also patches this as a safety net, but runtime derivation is primary.
private let kAppGroupId: String = {
  // Try Info.plist first (set by setup_ios.rb or Xcode build settings)
  if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
     !fromPlist.isEmpty, !fromPlist.contains("$(") {
    return fromPlist
  }
  // Derive from bundle ID
  return "group.\(Bundle.main.bundleIdentifier ?? "com.fastcat.app")"
}()

/// User-initiated VPN manager. The app does not create or start a tunnel during
/// launch; the first connection is initiated only after the in-app data notice.
class VPNManager: NSObject {
  static let shared = VPNManager()
  static let statusDidChangeNotification = Notification.Name("fastcat.vpn.statusChanged")
  private var manager: NETunnelProviderManager?
  /// Last error message from VPN operations, readable from Dart.
  var lastError: String = ""

  /// Whether traffic routing is active (proxy/DNS settings applied).
  /// This is the user-facing "connected" state.
  private(set) var isTrafficActive = false

  /// Whether the tunnel process is running (mihomo available for IPC).
  var isTunnelRunning: Bool {
    let status = manager?.connection.status ?? .invalid
    return status == .connected || status == .connecting
  }

  var isConnected: Bool {
    return isTrafficActive && isTunnelRunning
  }

  var statusString: String {
    if isTrafficActive {
      switch manager?.connection.status {
      case .connected:     return "connected"
      case .connecting:    return "connecting"
      case .disconnecting: return "disconnecting"
      default:             return "disconnected"
      }
    }
    return "disconnected"
  }

  private override init() {
    super.init()
    loadManager(createIfMissing: false, completion: nil)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(vpnStatusDidChange),
      name: .NEVPNStatusDidChange,
      object: nil
    )
  }

  // MARK: - Manager lifecycle

  private func loadManager(
    createIfMissing: Bool,
    completion: (() -> Void)? = nil
  ) {
    NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
      if let error = error {
        NSLog("[VPNManager] loadAllFromPreferences error: %@", error.localizedDescription)
        self?.lastError = "loadPreferences: \(error.localizedDescription)"
      }
      if let existing = managers?.first {
        NSLog("[VPNManager] loaded existing manager")
        // Migrate older builds away from always-on behavior. This prevents an
        // idle Packet Tunnel from being restarted before a user action.
        if existing.isOnDemandEnabled || !(existing.onDemandRules?.isEmpty ?? true) {
          existing.isOnDemandEnabled = false
          existing.onDemandRules = []
          existing.saveToPreferences { saveError in
            if let saveError = saveError {
              NSLog("[VPNManager] disable on-demand error: %@", saveError.localizedDescription)
            }
          }
        }
        self?.manager = existing
        completion?()
      } else if createIfMissing {
        NSLog("[VPNManager] no existing manager, creating on user request")
        self?.createManager(completion: completion)
      } else {
        NSLog("[VPNManager] no existing manager; waiting for user connection")
        self?.manager = nil
        completion?()
      }
    }
  }

  private func createManager(completion: (() -> Void)? = nil) {
    let mgr = NETunnelProviderManager()
    let proto = NETunnelProviderProtocol()
    // Must match the PacketTunnel extension bundle ID set in build.yaml
    proto.providerBundleIdentifier = Bundle.main.bundleIdentifier! + ".PacketTunnel"
    proto.serverAddress = "FastCat"
    mgr.protocolConfiguration = proto
    mgr.localizedDescription = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "FastCat"
    mgr.isEnabled = true

    mgr.onDemandRules = []
    mgr.isOnDemandEnabled = false

    NSLog("[VPNManager] saving new manager, provider=%@", proto.providerBundleIdentifier!)
    mgr.saveToPreferences { [weak self] error in
      if let error = error {
        NSLog("[VPNManager] createManager saveToPreferences error: %@", error.localizedDescription)
        self?.lastError = "createManager: \(error.localizedDescription)"
      } else {
        NSLog("[VPNManager] createManager saveToPreferences success")
      }
      self?.manager = mgr
      completion?()
    }
  }

  // MARK: - Ensure tunnel running (idle mode)

  /// Start the tunnel in idle mode if not already running.
  /// mihomo will be initialized and available for IPC (delay tests, proxy queries)
  /// but no traffic is routed through it.
  func ensureTunnelRunning(config: String, completion: @escaping (String?) -> Void) {
    // Already running — just make sure config is up to date
    if isTunnelRunning {
      NSLog("[VPNManager] ensureTunnelRunning: tunnel already running")
      if !config.isEmpty {
        sendConfigUpdate(config) { _ in }
      }
      completion(nil)
      return
    }

    guard let mgr = manager else {
      NSLog("[VPNManager] ensureTunnelRunning: manager is nil, loading...")
      loadManager(createIfMissing: true) { [weak self] in
        guard self?.manager != nil else {
          let err = "Failed to load VPN manager"
          NSLog("[VPNManager] %@", err)
          self?.lastError = err
          completion(err)
          return
        }
        self?.ensureTunnelRunning(config: config, completion: completion)
      }
      return
    }

    mgr.isEnabled = true
    // Never persist profile YAML in VPN preferences.
    (mgr.protocolConfiguration as? NETunnelProviderProtocol)?
      .providerConfiguration = ["profileFormat": "FCATCFG1"]

    mgr.onDemandRules = []
    mgr.isOnDemandEnabled = false

    NSLog("[VPNManager] ensureTunnelRunning: saving preferences...")
    mgr.saveToPreferences { [weak self] error in
      if let error = error {
        let err = "saveToPreferences: \(error.localizedDescription)"
        NSLog("[VPNManager] ensureTunnelRunning %@", err)
        self?.lastError = err
        completion(err)
        return
      }
      mgr.loadFromPreferences { [weak self] loadError in
        if let loadError = loadError {
          let err = "loadFromPreferences: \(loadError.localizedDescription)"
          NSLog("[VPNManager] ensureTunnelRunning %@", err)
          self?.lastError = err
          completion(err)
          return
        }
        self?.manager = mgr
        do {
          // Start in idle mode — mihomo runs but no traffic routing
          let options: [String: NSObject] = [
            "mode": "idle" as NSObject,
            "config": config as NSObject,
          ]
          NSLog("[VPNManager] ensureTunnelRunning: starting tunnel in idle mode...")
          try mgr.connection.startVPNTunnel(options: options)
          NSLog("[VPNManager] ensureTunnelRunning: startVPNTunnel called successfully")
          completion(nil)
        } catch {
          let err = "startVPNTunnel: \(error.localizedDescription)"
          NSLog("[VPNManager] ensureTunnelRunning %@", err)
          self?.lastError = err
          completion(err)
        }
      }
    }
  }

  // MARK: - Connect / Disconnect (traffic routing toggle)

  /// Supply the decoded profile only to the active tunnel; never persist YAML.
  func connect(config: String, completion: @escaping (String?) -> Void) {
    if isTunnelRunning {
      // The subscription or mode may have changed while the tunnel was idle.
      // Reload the supplied profile before enabling traffic so reconnecting never
      // resumes a stale configuration.
      NSLog("[VPNManager] connect: tunnel running, updating config before enabling traffic")
      sendConfigUpdate(config) { [weak self] updateError in
        if let updateError {
          completion(updateError)
          return
        }
        self?.setTrafficMode(active: true) { error in
          if let error = error {
            completion(error)
          } else {
            self?.isTrafficActive = true
            self?.notifyStatusChange()
            completion(nil)
          }
        }
      }
      return
    }

    // Tunnel not running — start it with traffic enabled
    guard let mgr = manager else {
      NSLog("[VPNManager] connect: manager is nil, loading...")
      loadManager(createIfMissing: true) { [weak self] in
        guard self?.manager != nil else {
          let err = "Failed to load VPN manager"
          NSLog("[VPNManager] %@", err)
          self?.lastError = err
          completion(err)
          return
        }
        self?.connect(config: config, completion: completion)
      }
      return
    }
    mgr.isEnabled = true
    (mgr.protocolConfiguration as? NETunnelProviderProtocol)?
      .providerConfiguration = ["profileFormat": "FCATCFG1"]

    mgr.onDemandRules = []
    mgr.isOnDemandEnabled = false

    NSLog("[VPNManager] connect: saving preferences...")
    mgr.saveToPreferences { [weak self] error in
      if let error = error {
        let err = "saveToPreferences: \(error.localizedDescription)"
        NSLog("[VPNManager] connect %@", err)
        self?.lastError = err
        completion(err)
        return
      }
      NSLog("[VPNManager] connect: reloading after save...")
      mgr.loadFromPreferences { [weak self] loadError in
        if let loadError = loadError {
          let err = "loadFromPreferences: \(loadError.localizedDescription)"
          NSLog("[VPNManager] connect %@", err)
          self?.lastError = err
          completion(err)
          return
        }
        self?.manager = mgr
        do {
          // Start with traffic active
          let options: [String: NSObject] = [
            "mode": "active" as NSObject,
            "config": config as NSObject,
          ]
          NSLog("[VPNManager] connect: starting VPN tunnel (active mode)...")
          try mgr.connection.startVPNTunnel(options: options)
          self?.isTrafficActive = true
          NSLog("[VPNManager] connect: startVPNTunnel called successfully")
          completion(nil)
        } catch {
          let err = "startVPNTunnel: \(error.localizedDescription)"
          NSLog("[VPNManager] connect %@", err)
          self?.lastError = err
          completion(err)
        }
      }
    }
  }

  /// Fully stop the tunnel when the user disconnects.
  func disconnect(completion: @escaping (Bool) -> Void) {
    NSLog("[VPNManager] disconnect: stopping user-initiated tunnel")
    guard let mgr = manager else {
      isTrafficActive = false
      notifyStatusChange()
      completion(true)
      return
    }
    mgr.isOnDemandEnabled = false
    mgr.onDemandRules = []
    mgr.saveToPreferences { saveError in
      if let saveError = saveError {
        NSLog("[VPNManager] disconnect save error: %@", saveError.localizedDescription)
      }
    }
    mgr.connection.stopVPNTunnel()
    isTrafficActive = false
    notifyStatusChange()
    completion(true)
  }

  /// Fully stop the tunnel (kills mihomo). Used on app termination or explicit request.
  func stopTunnel(completion: @escaping (Bool) -> Void) {
    NSLog("[VPNManager] stopTunnel: fully stopping tunnel")
    // Disable on-demand so the system doesn't restart it
    if let mgr = manager {
      mgr.isOnDemandEnabled = false
      mgr.saveToPreferences { _ in }
    }
    manager?.connection.stopVPNTunnel()
    isTrafficActive = false
    notifyStatusChange()
    completion(true)
  }

  // MARK: - Traffic mode IPC

  /// Reconfigure an already-running tunnel without writing YAML to disk.
  private func sendConfigUpdate(_ config: String, completion: @escaping (String?) -> Void) {
    sendClashMessage(method: "_updateConfig", data: config) { response in
      if (response ?? "").hasPrefix("error") {
        NSLog("[VPNManager] config update failed: %@", response ?? "unknown")
        completion(response)
      } else {
        completion(nil)
      }
    }
  }

  /// Apply a Clash routing mode without reconnecting the packet tunnel.
  func updateMode(_ mode: String, completion: @escaping (String?) -> Void) {
    guard isTunnelRunning else {
      completion(nil)
      return
    }
    guard let data = try? JSONSerialization.data(withJSONObject: ["mode": mode]),
          let payload = String(data: data, encoding: .utf8) else {
      completion("代理模式参数无效")
      return
    }
    sendClashMessage(method: "updateConfig", data: payload) { response in
      let value = response ?? ""
      completion(value.isEmpty ? nil : value)
    }
  }

  /// Select a proxy in a live Mihomo group.
  func changeProxy(groupName: String, proxyName: String, completion: @escaping (String?) -> Void) {
    guard isTunnelRunning else {
      completion("VPN 核心尚未启动")
      return
    }
    let value = ["group-name": groupName, "proxy-name": proxyName]
    guard let data = try? JSONSerialization.data(withJSONObject: value),
          let payload = String(data: data, encoding: .utf8) else {
      completion("线路参数无效")
      return
    }
    sendClashMessage(method: "changeProxy", data: payload) { response in
      let result = response ?? ""
      completion(result.isEmpty ? nil : result)
    }
  }

  /// Return Mihomo's live proxy/group graph as JSON.
  func getProxies(completion: @escaping (String?) -> Void) {
    guard isTunnelRunning else {
      completion(nil)
      return
    }
    sendClashMessage(method: "getProxies", data: nil, completion: completion)
  }

  /// Reconcile the in-memory state with the Network Extension after app launch.
  func refreshStatus(completion: @escaping (String) -> Void) {
    loadManager(createIfMissing: false) { [weak self] in
      guard let self else {
        completion("disconnected")
        return
      }
      guard self.isTunnelRunning else {
        self.isTrafficActive = false
        self.notifyStatusChange()
        completion(self.statusString)
        return
      }
      self.sendClashMessage(method: "_getTrafficMode", data: nil) { response in
        self.isTrafficActive = response == "active"
        self.notifyStatusChange()
        completion(self.statusString)
      }
    }
  }

  /// Toggle traffic routing in the PacketTunnel extension via IPC.
  private func setTrafficMode(active: Bool, completion: @escaping (String?) -> Void) {
    let mode = active ? "active" : "idle"
    sendClashMessage(method: "_setTrafficMode", data: mode) { response in
      let resp = response ?? ""
      if resp.hasPrefix("error") {
        NSLog("[VPNManager] setTrafficMode(%@) error: %@", mode, resp)
        completion(resp)
      } else {
        NSLog("[VPNManager] setTrafficMode(%@) success", mode)
        completion(nil)
      }
    }
  }

  // MARK: - Clash IPC

  /// Forward a Clash operation to the running PacketTunnel extension.
  /// Returns an empty response while the user is disconnected.
  func sendClashMessage(method: String, data: String?, completion: @escaping (String?) -> Void) {
    guard let session = manager?.connection as? NETunnelProviderSession else {
      NSLog("[VPNManager] sendClashMessage(%@): no session available", method)
      completion("")
      return
    }
    let status = manager?.connection.status ?? .invalid
    guard status == .connected || status == .connecting else {
      NSLog("[VPNManager] sendClashMessage(%@): tunnel not running (status=%d)", method, status.rawValue)
      completion("")
      return
    }
    var payload: [String: Any] = ["method": method]
    if let data = data { payload["data"] = data }
    guard let encoded = try? JSONSerialization.data(withJSONObject: payload) else {
      NSLog("[VPNManager] sendClashMessage(%@): JSON encoding failed", method)
      completion("")
      return
    }
    do {
      try session.sendProviderMessage(encoded) { responseData in
        guard let d = responseData else { completion(""); return }
        completion(String(data: d, encoding: .utf8))
      }
    } catch {
      NSLog("[VPNManager] sendClashMessage(%@): IPC error: %@", method, error.localizedDescription)
      completion("")
    }
  }

  // MARK: - Status notification

  @objc private func vpnStatusDidChange() {
    if !isTunnelRunning {
      isTrafficActive = false
      notifyStatusChange()
      return
    }
    sendClashMessage(method: "_getTrafficMode", data: nil) { [weak self] response in
      guard let self else { return }
      if response == "active" || response == "idle" {
        self.isTrafficActive = response == "active"
      }
      NSLog("[VPNManager] VPN status changed: %@ (tunnelRunning=%d, trafficActive=%d)",
            self.statusString, self.isTunnelRunning ? 1 : 0, self.isTrafficActive ? 1 : 0)
      self.notifyStatusChange()
    }
  }

  private func notifyStatusChange() {
    NotificationCenter.default.post(
      name: Self.statusDidChangeNotification,
      object: statusString
    )
  }
}
