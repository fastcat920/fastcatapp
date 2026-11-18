import Cocoa
import FlutterMacOS
import Metal
import ServiceManagement
import window_manager
import UserNotifications

class MainFlutterWindow: NSWindow, UNUserNotificationCenterDelegate {
    private var supportNotificationChannel: FlutterMethodChannel?
    private let supportNotificationID = "fastcat-support-replies"

    func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == supportNotificationID {
            DispatchQueue.main.async { [weak self] in
                self?.supportNotificationChannel?.invokeMethod("open", arguments: nil)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Flutter checks focus before scheduling; don't show a late banner after refocus.
        if NSApp.isActive { completionHandler([]) }
        else { completionHandler([.banner, .sound]) }
    }
    private static var launchAtStartupIsEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    private static func setLaunchAtStartupEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw NSError(
                domain: "FastCat",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Launch at startup requires macOS 13 or later."]
            )
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    private static func rendererInfo() -> [String: Any] {
        let device = MTLCreateSystemDefaultDevice()
        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = "unknown"
        #endif
        return [
            "architecture": architecture,
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "metalDevice": device?.name ?? "unavailable",
            "metalLowPower": device?.isLowPower ?? false,
            "metalHeadless": device?.isHeadless ?? false,
            "metalRemovable": device?.isRemovable ?? false
        ]
    }

    override func awakeFromNib() {
        let rendererInfo = Self.rendererInfo()
        NSLog(
            "[FastCatStartup] architecture=%@ macOS=%@ Metal=%@",
            rendererInfo["architecture"] as? String ?? "unknown",
            rendererInfo["macOS"] as? String ?? "unknown",
            rendererInfo["metalDevice"] as? String ?? "unavailable"
        )
        let flutterViewController = FlutterViewController()
        supportNotificationChannel = FlutterMethodChannel(name: "fastcat/support_desktop",
            binaryMessenger: flutterViewController.engine.binaryMessenger)
        UNUserNotificationCenter.current().delegate = self
        supportNotificationChannel?.setMethodCallHandler { [weak self] call, result in
                guard let self = self else { result(nil); return }
                if call.method == "clear" {
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [self.supportNotificationID])
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [self.supportNotificationID])
                    result(nil)
                    return
                }
                if call.method == "notify" {
                    let args = call.arguments as? [String: Any] ?? [:]
                    let count = args["count"] as? Int ?? 0
                    let sound = args["sound"] as? Bool ?? true
                    let center = UNUserNotificationCenter.current()
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { allowed, error in
                        guard allowed else {
                            DispatchQueue.main.async { result(FlutterError(code: "NOTIFICATIONS_DISABLED", message: "Notification permission denied", details: nil)) }
                            return
                        }
                        let content = UNMutableNotificationContent()
                        content.title = "FastCat 客服"
                        content.body = "你有 \(count) 条未读客服消息，点击查看"
                        content.sound = sound ? .default : nil
                        let request = UNNotificationRequest(identifier: self.supportNotificationID, content: content, trigger: nil)
                        center.add(request) { error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    result(FlutterError(code: "NOTIFICATION_FAILED", message: error.localizedDescription, details: nil))
                                } else { result(nil) }
                            }
                        }
                    }
                    return
                }
                guard call.method == "badge" else {
                    result(FlutterMethodNotImplemented)
                    return
                }
                let count = (call.arguments as? NSNumber)?.intValue ?? 0
                NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
                result(nil)
            }
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        FlutterMethodChannel(
            name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "launchAtStartupIsEnabled":
                result(Self.launchAtStartupIsEnabled)
            case "launchAtStartupSetEnabled":
                guard let arguments = call.arguments as? [String: Any],
                      let enabled = arguments["setEnabledValue"] as? Bool else {
                    result(FlutterError(
                        code: "invalid_arguments",
                        message: "setEnabledValue must be a boolean.",
                        details: nil
                    ))
                    return
                }
                do {
                    try Self.setLaunchAtStartupEnabled(enabled)
                    result(nil)
                } catch {
                    result(FlutterError(
                        code: "launch_at_startup_failed",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        FlutterMethodChannel(
            name: "fastcat/startup_diagnostics",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "getRendererInfo":
                result(Self.rendererInfo())
            case "firstFrameRendered":
                NSLog("[FastCatStartup] Flutter first-frame callback reached")
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        super.awakeFromNib()
    }
    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
