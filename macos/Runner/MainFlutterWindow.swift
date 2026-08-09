import Cocoa
import FlutterMacOS
import Metal
import ServiceManagement
import window_manager

class MainFlutterWindow: NSWindow {
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
