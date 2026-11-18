import Foundation

/// Main app and extension agree on explicit mutation acknowledgements.
/// Empty/nil IPC is not success. Raw Mihomo's empty success is wrapped only by
/// the extension, which can distinguish an empty result from a missing pointer.
enum TVCoreProtocol {
  static func acknowledgement(error: String? = nil) -> Data {
    let value: [String: Any] = error.map { ["ok": false, "message": $0] } ?? ["ok": true]
    return (try? JSONSerialization.data(withJSONObject: value)) ?? Data()
  }

  static func isAcknowledged(_ response: String?) -> Bool {
    struct Reply: Decodable { let ok: Bool }
    guard let response, let data = response.data(using: .utf8),
          let value = try? JSONDecoder().decode(Reply.self, from: data) else { return false }
    return value.ok
  }
}

/// Provider callbacks can arrive after the local deadline. Complete once and
/// release the UI callback so a late response cannot finish a newer operation.
final class TVOnceReply {
  private let lock = NSLock()
  private var callback: ((String?) -> Void)?
  init(_ callback: @escaping (String?) -> Void) { self.callback = callback }
  func finish(_ value: String?) {
    lock.lock()
    let action = callback
    callback = nil
    lock.unlock()
    action?(value)
  }
}

/// Same HH:mm:ss and 99:59:59 cap as Flutter's getTimeText.
func tvConnectionDuration(since start: Date?, now: Date) -> String {
  guard let start else { return "00:00:00" }
  let seconds = Int(min(99 * 86400, max(0, now.timeIntervalSince(start))))
  return String(format: "%02d:%02d:%02d", seconds / 3600 % 24, seconds / 60 % 60, seconds % 60)
}

/// One conversion between the 1280x720 TV design space and native points.
/// Typography's accessibility/display multiplier is deliberately not part of it.
enum TVDesignMetrics {
  static func density(width: Double, height: Double) -> Double {
    max(0.85, min(width / 1280, height / 720))
  }
  static func logical(_ native: Double, density: Double) -> Double {
    native / max(density, 0.01)
  }
}

/// Home-only frame calibration from the Android TV reference photographs.
/// These are explicit page margins, not assumed OS safe-area measurements.
enum TVHomeFrame {
  static let top: Double = 0
  static let horizontal: Double = 0
  static let bottom: Double = 0
  static func contentHeight(_ height: Double) -> Double {
    max(0, height - top - bottom)
  }
}

/// Shared minimum gutters for full-screen TV pages, in design units.
enum TVPageSpacing {
  static func horizontal(logicalWidth:Double)->Double {logicalWidth>=1400 ? 33:25}
  static let contentTop:Double = 19
  static let bottom:Double = 23
}
enum TVThemePreference {
  /// UIKit: 0 removes the application override; 1/2 force light/dark.
  static func windowStyle(mode:String,legacyDark:Bool)->Int {
    if mode == "system" { return 0 }
    return isDark(mode:mode,legacyDark:legacyDark,systemDark:false) ? 2:1
  }
  static func isDark(mode:String,legacyDark:Bool,systemDark:Bool)->Bool {
    switch mode {case "system":return systemDark;case "light":return false;case "dark":return true;default:return legacyDark}
  }
}

/// UIKit raw style: unspecified is not a valid light-theme decision.
enum TVSystemAppearancePolicy {
  static func resolve(rawStyle:Int,active:Bool,windowReady:Bool)->Bool? {
    guard active,windowReady else {return nil}
    switch rawStyle {case 1:return false;case 2:return true;default:return nil}
  }
}

func tvConnectionDays(since start: Date?, now: Date) -> Int {
  guard let start else { return 0 }
  return Int(min(99, max(0, now.timeIntervalSince(start) / 86400)))
}
