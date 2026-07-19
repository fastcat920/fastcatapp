import Cocoa
import FlutterMacOS
import Metal
import window_manager
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
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
                result(LaunchAtLogin.isEnabled)
            case "launchAtStartupSetEnabled":
                if let arguments = call.arguments as? [String: Any] {
                    LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
                }
                result(nil)
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
