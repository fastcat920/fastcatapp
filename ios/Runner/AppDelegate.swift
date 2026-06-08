import UIKit
import Flutter
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate {
  private lazy var flutterEngine = FlutterEngine(name: "my flutter engine")
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 显式创建 Flutter 引擎并启动（解决无 storyboard 时引擎未初始化的问题）
    flutterEngine.run()
    
    // 显式创建 window 和 FlutterViewController
    window = UIWindow(frame: UIScreen.main.bounds)
    let controller = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    window?.rootViewController = controller
    window?.makeKeyAndVisible()

    // ── VPN control channel ──────────────────────────────────────────────
    let vpnChannel = FlutterMethodChannel(
      name: "apex/vpn",
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
      name: "apex/clash",
      binaryMessenger: controller.binaryMessenger
    )
    clashChannel.setMethodCallHandler { call, result in
      VPNManager.shared.sendClashMessage(
        method: call.method,
        data: call.arguments as? String
      ) { response in
        result(response ?? "")
      }
    }

    // ── VPN status event channel ─────────────────────────────────────────
    let statusChannel = FlutterEventChannel(
      name: "apex/vpn_status",
      binaryMessenger: controller.binaryMessenger
    )
    statusChannel.setStreamHandler(VPNStatusStreamHandler())

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
