import UIKit
import Flutter
import NetworkExtension
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var supportNotification: [String: String]?
  private var supportPushToken: String?
  private var pushWaiters: [FlutterResult] = []
  private var pushRequestID = 0
  private var visibleSupportConversation: String?

  private func finishPushRegistration(_ value: Any?) {
    let waiters = pushWaiters
    pushWaiters.removeAll()
    waiters.forEach { $0(value) }
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    NSLog("[SupportPush] APNs registration failed: %@", error.localizedDescription)
    finishPushRegistration(FlutterError(code: "APNS_REGISTRATION", message: error.localizedDescription, details: nil))
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let info = notification.request.content.userInfo
    if info["type"] as? String == "support.reply" {
      // willPresent is the foreground path. Realtime chat owns the one
      // in-app sound; showing/sounding APNs here would duplicate that alert.
      // Background and lock-screen notifications are presented by iOS itself.
      completionHandler([.badge])
      return
    }
    completionHandler([.banner, .sound, .badge])
  }
  
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void) {
    let info = response.notification.request.content.userInfo
    if info["type"] as? String == "support.reply" {
      supportNotification = ["type": "support.reply",
        "conversationId": info["conversationId"] as? String ?? "",
        "messageId": info["messageId"] as? String ?? ""]
    }
    completionHandler()
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    supportPushToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    NSLog("[SupportPush] APNs token received")
    finishPushRegistration(supportPushToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The app does not use a main storyboard. Let FlutterViewController own
    // its engine instead of attaching a manually-run engine during launch.
    // This avoids a fatal engine/view-controller attachment failure on iOS 16.
    window = UIWindow(frame: UIScreen.main.bounds)
    let controller = FlutterViewController(project: nil, initialRoute: nil, nibName: nil, bundle: nil)
    window?.rootViewController = controller
    window?.makeKeyAndVisible()

    let probeChannel = FlutterMethodChannel(name: "fastcat/latency", binaryMessenger: controller.binaryMessenger)
    probeChannel.setMethodCallHandler { call, result in
      guard call.method == "test", let args = call.arguments as? [String: String],
        let config = args["config"], let home = args["home"], let data = args["data"] else {
        result(FlutterMethodNotImplemented)
        return
      }
      IOSLatencyProbe.shared.test(config: config, home: home, data: data, completion: result)
    }

    let pushChannel = FlutterMethodChannel(name: "fastcat/support_push", binaryMessenger: controller.binaryMessenger)
    UNUserNotificationCenter.current().delegate = self
    pushChannel.setMethodCallHandler { [weak self] call, result in
      if call.method == "badge" {
        let count = max(0, call.arguments as? Int ?? 0)
        UIApplication.shared.applicationIconBadgeNumber = count
        result(nil)
        return
      }
      if call.method == "visibility" {
        let args = call.arguments as? [String: Any]
        self?.visibleSupportConversation = args?["visible"] as? Bool == true
            ? args?["conversationId"] as? String : nil
        result(nil)
        return
      }
      if call.method == "environment" {
        // Store/TestFlight builds have no embedded development profile.
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
          result("production")
          return
        }
        guard let bytes = try? Data(contentsOf: url),
          let text = String(data: bytes, encoding: .isoLatin1),
          let start = text.range(of: "<?xml"),
          let end = text.range(of: "</plist>", range: start.lowerBound..<text.endIndex),
          let xml = String(text[start.lowerBound..<end.upperBound]).data(using: .utf8),
          let profile = (try? PropertyListSerialization.propertyList(from: xml, format: nil)) as? [String: Any],
          let entitlements = profile["Entitlements"] as? [String: Any],
          let value = entitlements["aps-environment"] as? String else {
          result(nil)
          return
        }
        result(value == "development" ? "sandbox" : value == "production" ? "production" : nil)
        return
      }
      if call.method == "notification" {
        result(self?.supportNotification)
        self?.supportNotification = nil
        return
      }
      guard call.method == "token" else { result(FlutterMethodNotImplemented); return }
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        DispatchQueue.main.async {
          guard let self = self else { result(nil); return }
          guard granted else { result(nil); return }
          if let token = self.supportPushToken { result(token); return }
          self.pushWaiters.append(result)
          guard self.pushWaiters.count == 1 else { return }
          self.pushRequestID += 1
          let requestID = self.pushRequestID
          UIApplication.shared.registerForRemoteNotifications()
          DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, self.pushRequestID == requestID else { return }
            self.finishPushRegistration(FlutterError(code: "APNS_TIMEOUT", message: "APNs registration timed out", details: nil))
          }
        }
      }
    }

    // ── VPN control channel ──────────────────────────────────────────────
    let vpnChannel = FlutterMethodChannel(
      name: "fastcat/vpn",
      binaryMessenger: controller.binaryMessenger
    )
    vpnChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        let args = call.arguments as? [String: Any]
        let config = args?["config"] as? String ?? ""
        VPNManager.shared.connect(config: config) { error in
          if let error = error {
            result(FlutterError(code: "VPN_ERROR", message: error, details: nil))
          } else {
            result(true)
          }
        }
      case "stop":
        VPNManager.shared.disconnect { success in
          result(success)
        }
      case "stopTunnel":
        VPNManager.shared.stopTunnel { success in
          result(success)
        }
      case "ensureRunning":
        let args = call.arguments as? [String: Any]
        let config = args?["config"] as? String ?? ""
        VPNManager.shared.ensureTunnelRunning(config: config) { error in
          if let error = error {
            result(FlutterError(code: "VPN_ERROR", message: error, details: nil))
          } else {
            result(true)
          }
        }
      case "restoreState":
        VPNManager.shared.restoreState { state in
          if let state = state { result(state) }
          else { result(FlutterError(code: "VPN_RESTORE", message: "Unable to read existing tunnel state", details: nil)) }
        }
      case "isConnected":
        result(VPNManager.shared.isConnected)
      case "isTunnelRunning":
        result(VPNManager.shared.isTunnelRunning)
      case "getStatus":
        result(VPNManager.shared.statusString)
      case "getLastError":
        result(VPNManager.shared.lastError)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ── Clash operations channel ─────────────────────────────────────────
    let clashChannel = FlutterMethodChannel(
      name: "fastcat/clash",
      binaryMessenger: controller.binaryMessenger
    )
    clashChannel.setMethodCallHandler { call, result in
      VPNManager.shared.sendClashMessage(
        method: call.method,
        data: call.arguments as? String
      ) { response in
        if call.method == "_updateConfig", response == nil {
          result(FlutterError(code: "TUNNEL_UNAVAILABLE", message: "The VPN tunnel did not acknowledge the configuration.", details: nil))
        } else {
          // nil means the tunnel did not reply. An explicit empty string is a
          // valid core mutation acknowledgement and must remain distinct.
          result(response)
        }
      }
    }

    // ── VPN status event channel ─────────────────────────────────────────
    let statusChannel = FlutterEventChannel(
      name: "fastcat/vpn_status",
      binaryMessenger: controller.binaryMessenger
    )
    statusChannel.setStreamHandler(VPNStatusStreamHandler())

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Isolated from the NetworkExtension process; never starts packet forwarding.
private final class IOSLatencyProbe {
  static let shared = IOSLatencyProbe()
  private let queue = OperationQueue()
  private let lock = NSCondition()
  private var running = 0
  private var activeConfig: String?
  private var cleanup: DispatchWorkItem?
  private init() { queue.maxConcurrentOperationCount = 4 }

  func test(config: String, home: String, data: String, completion: @escaping FlutterResult) {
    queue.addOperation {
      self.lock.lock()
      while self.running > 0 && self.activeConfig != config { self.lock.wait() }
      self.cleanup?.cancel()
      let code = self.activeConfig == config ? 0 : ClashCore_init_probe(home, config)
      guard code == 0 else {
        self.lock.unlock()
        DispatchQueue.main.async { completion(FlutterError(code: "PROBE_INIT", message: "Latency core initialization failed: \(code)", details: nil)) }
        return
      }
      self.activeConfig = config
      self.running += 1
      self.lock.unlock()
      let started = Date()
      let pointer = ClashCore_invoke("asyncTestDelay", data)
      let response = pointer.map { String(cString: $0) }
      ClashCore_free(pointer)
      NSLog("[LatencyProbe] completed in %.0f ms", Date().timeIntervalSince(started) * 1000)
      self.lock.lock()
      self.running -= 1
      self.lock.broadcast()
      let cleanup = DispatchWorkItem {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard self.running == 0 else { return }
        ClashCore_shutdown()
        self.activeConfig = nil
      }
      self.cleanup = cleanup
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2, execute: cleanup)
      self.lock.unlock()
      DispatchQueue.main.async { completion(response) }
    }
  }
}
