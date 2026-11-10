import Combine
import CryptoKit
import Foundation
import Network

enum TVToolsError: LocalizedError {
  case invalidRule
  var errorDescription: String? { "Invalid routing rule" }
}
struct TVUserRoute: Codable, Identifiable {
  var id = UUID()
  let destination: String
  let proxy: Bool
  let kind: String
  init(destination input: String, proxy: Bool) throws {
    let raw = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
    guard !raw.isEmpty, parts.count <= 2, !raw.contains(","),
      !raw.contains(where: { $0.isWhitespace })
    else { throw TVToolsError.invalidRule }
    self.proxy = proxy
    if let address = IPv4Address(String(parts[0])) {
      let prefix = parts.count == 2 ? Int(parts[1]) : 32
      guard let prefix, (0...32).contains(prefix) else { throw TVToolsError.invalidRule }
      let bytes = Array(address.rawValue).enumerated().map { i, b -> UInt8 in
        let bits = max(0, min(8, prefix - i * 8))
        return b & (bits == 0 ? 0 : UInt8(truncatingIfNeeded: 0xff << (8 - bits)))
      }
      destination = IPv4Address(Data(bytes))!.debugDescription + "/\(prefix)"
      kind = "IP-CIDR"
    } else if let address = IPv6Address(String(parts[0])) {
      let prefix = parts.count == 2 ? Int(parts[1]) : 128
      guard let prefix, (0...128).contains(prefix) else { throw TVToolsError.invalidRule }
      let bytes = Array(address.rawValue).enumerated().map { i, b -> UInt8 in
        let bits = max(0, min(8, prefix - i * 8))
        return b & (bits == 0 ? 0 : UInt8(truncatingIfNeeded: 0xff << (8 - bits)))
      }
      destination = IPv6Address(Data(bytes))!.debugDescription + "/\(prefix)"
      kind = "IP-CIDR6"
    } else {
      let domain = raw.hasPrefix("+.") ? String(raw.dropFirst(2)) : raw
      guard parts.count == 1, domain.contains("."), domain.count <= 253,
        domain.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ label in
          label.count <= 63
            && label.range(of: "^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", options: .regularExpression)
              != nil
        })
      else { throw TVToolsError.invalidRule }
      destination = domain
      kind = "DOMAIN-SUFFIX"
    }
  }
  func coreRule(group: String) throws -> String {
    let target = proxy ? group : "DIRECT"
    guard !target.isEmpty, !target.contains(where: { ",\r\n".contains($0) }) else {
      throw TVToolsError.invalidRule
    }
    return "\(kind),\(destination),\(target)" + (kind.hasPrefix("IP-CIDR") ? ",no-resolve" : "")
  }
}
enum TVUserRouteStore {
  private static func key(_ scope: String) -> String {
    "fastcat.tv.routes."
      + SHA256.hash(data: Data(scope.lowercased().utf8)).map { String(format: "%02x", $0) }.joined()
  }
  static func load(scope: String) -> [TVUserRoute] {
    guard !scope.isEmpty, let data = UserDefaults.standard.data(forKey: key(scope)) else {
      return []
    }
    return (try? JSONDecoder().decode([TVUserRoute].self, from: data)) ?? []
  }
  static func save(_ rules: [TVUserRoute], scope: String) {
    guard !scope.isEmpty else { return }
    UserDefaults.standard.set(try? JSONEncoder().encode(rules), forKey: key(scope))
  }
  static func runtime(_ source: String, scope: String, group: String) throws -> String {
    guard
      !source.components(separatedBy: .newlines).contains(where: {
        $0.hasPrefix("fastcat-added-rules:") || $0.hasPrefix("\"fastcat-added-rules\":")
          || $0.hasPrefix("'fastcat-added-rules':")
      })
    else { throw TVToolsError.invalidRule }
    let rules = try load(scope: scope).map { try $0.coreRule(group: group) }
    guard !rules.isEmpty else { return source }
    let data = try JSONSerialization.data(withJSONObject: rules, options: [.withoutEscapingSlashes])
    return source + "\nfastcat-added-rules: " + String(decoding: data, as: UTF8.self) + "\n"
  }
}

enum TVStreamingTargets {
  static let all: [(String, String)] = [
    ("Netflix", "https://www.netflix.com/title/70143836"),
    ("Disney+", "https://www.disneyplus.com/"),
    ("YouTube Premium", "https://www.youtube.com/premium"),
    ("Prime Video", "https://www.primevideo.com/"),
    ("Max", "https://www.max.com/"),
    ("Apple TV+", "https://tv.apple.com/"),
    ("BBC iPlayer", "https://www.bbc.co.uk/iplayer"),
    ("DAZN", "https://www.dazn.com/"),
    ("ChatGPT", "https://chatgpt.com/"),
    ("Claude", "https://claude.ai/"),
    ("Gemini", "https://gemini.google.com/"),
    ("Microsoft Copilot", "https://copilot.microsoft.com/"),
    ("Crunchyroll", "https://www.crunchyroll.com/"),
    ("TikTok", "https://www.tiktok.com/explore"),
    ("Grok", "https://grok.com/"),
    ("Google AI Studio", "https://aistudio.google.com/welcome"),
  ]
  static func summary(_ raw: [String: Any]?, chinese: Bool, name: String = "") -> String {
    func label(_ a: String, _ b: String) -> String { chinese ? a : b }
    guard let raw, raw["ok"] as? Bool == true else { return label("检测失败或超时", "Error or timeout") }
    let status = raw["status-code"] as? Int ?? 0
    let text = raw["body"] as? String ?? ""
    let body = text.lowercased()
    let final = (raw["final-url"] as? String ?? "").lowercased()
    let headers = raw["headers"] as? [String: String] ?? [:]
    let challenge =
      headers.contains {
        $0.key.lowercased() == "cf-mitigated" && $0.value.lowercased().contains("challenge")
      } || body.contains("cf-chl-") || body.contains("just a moment")
      || (status == 403
        && headers.contains {
          $0.key.lowercased() == "server" && $0.value.lowercased().contains("cloudflare")
        } && body.contains("cloudflare"))
    let accessible = label("可用", "Accessible")
    let restricted = label("地区受限", "Region restricted")
    let blocked = label("IP 被拒绝", "IP blocked")
    let uncertain = label("待确认", "Uncertain")
    if status == 451 { return restricted }
    if name == "Netflix", let aux = raw["aux"] as? [String: Any] {
      guard aux["ok"] as? Bool == true else { return label("检测失败或超时", "Error or timeout") }
      let other = aux["status-code"] as? Int ?? 0
      if status == 403 && other == 403 { return blocked }
      if (status == 404 && other == 404)
        || (body.contains("oh no!")
          && (aux["body"] as? String ?? "").lowercased().contains("oh no!"))
      {
        return label("仅原创内容", "Originals only")
      }
      if (200..<400).contains(status) || (200..<400).contains(other) { return accessible }
      return uncertain
    }
    if name == "BBC iPlayer" {
      if body.contains("geolocation") { return restricted }
      if body.contains("vs-hls-push-uk") || body.contains("href") { return accessible }
      if let aux = raw["aux"] as? [String: Any],
        let bytes = (aux["body"] as? String)?.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]
      {
        if (json["X-Ip_is_uk_combined"] as? String)?.lowercased() == "no" { return restricted }
        if status == 403 { return blocked }
        if (json["X-Ip_is_uk_combined"] as? String)?.lowercased() == "yes" {
          return accessible + " · GB"
        }
      }
      return status == 403 ? blocked : uncertain
    }
    if name == "DAZN" {
      if status == 403 || body.contains("security policy has been breached") { return blocked }
      if let value = findJSON(text, key: "isAllowed") as? Bool {
        return value ? accessible : restricted
      }
      return uncertain
    }
    if name == "ChatGPT" {
      if body.contains("unsupported_country") { return restricted }
      if challenge { return label("需要浏览器验证", "Verification required") }
      return status == 200 && body.contains("cookie_consent_required") ? accessible : uncertain
    }
    let regionDenied = [
      "unsupported_country", "not available in your country", "not available in your region",
      "app-unavailable-in-region",
    ].contains { body.contains($0) }
    if name == "Claude" {
      if regionDenied { return restricted }
      if challenge { return label("需要浏览器验证", "Verification required") }
      return status == 401 && body.contains("x-api-key header is required") ? accessible : uncertain
    }
    if name == "YouTube Premium" {
      if body.contains("premium is not available in your country") || body.contains("www.google.cn")
      {
        return restricted
      }
      return ["premiumpurchasebutton", "managesubscriptionbutton", "ad-free", "/month"].contains {
        body.contains($0)
      } ? accessible : uncertain
    }
    if name == "Prime Video" {
      if match(text, "\"isServiceRestricted\"\\s*:\\s*true") != nil { return restricted }
      if let region = match(text, "\"currentTerritory\"\\s*:\\s*\"([A-Za-z]{2})\"") {
        return accessible + " · " + region.uppercased()
      }
      return uncertain
    }
    if name == "Max",
      final.contains("geo-availability") || body.contains("not available in your region")
    {
      return restricted
    }
    if name == "Disney+",
      final.contains("unavailable") || body.contains("not available in your region")
    {
      return restricted
    }
    if ["Gemini", "Grok", "Claude", "Microsoft Copilot", "Google AI Studio"].contains(name),
      regionDenied
    {
      return restricted
    }
    if challenge { return label("需要浏览器验证", "Verification required") }
    if name == "Gemini", body.contains("45631641,null,true") { return accessible }
    if name == "Crunchyroll" {
      guard let aux = raw["aux"] as? [String: Any], aux["ok"] as? Bool == true,
        let region = match(aux["body"] as? String ?? "", "'code'\\s*:\\s*'([a-z]{2})'")
      else { return uncertain }
      return (200..<400).contains(status) ? accessible + " · " + region.uppercased() : uncertain
    }
    if name == "TikTok" {
      if body.contains("tiktok.com/hk/notfound") { return restricted + " · HK" }
      if let region = match(text, "\"region\"\\s*:\\s*\"([A-Za-z]{2})\""),
        (200..<400).contains(status)
      {
        return accessible + " · " + region.uppercased()
      }
      return uncertain
    }
    if ["Grok", "Microsoft Copilot", "Google AI Studio"].contains(name) {
      let marker =
        name == "Grok" ? "grok" : (name == "Google AI Studio" ? "google ai studio" : "copilot")
      return (200..<400).contains(status) && body.contains(marker) ? accessible : uncertain
    }
    if (200..<400).contains(status) { return accessible }
    return status == 403 ? uncertain : label("不可用", "Unavailable")
  }
  private static func findJSON(_ text: String, key: String) -> Any? {
    guard let data = text.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data)
    else { return nil }
    func walk(_ value: Any) -> Any? {
      if let map = value as? [String: Any] {
        if let result = map[key] { return result }
        for child in map.values { if let result = walk(child) { return result } }
      }
      if let array = value as? [Any] {
        for child in array { if let result = walk(child) { return result } }
      }
      return nil
    }
    return walk(json)
  }
  private static func match(_ text: String, _ pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
      let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    else { return nil }
    let range = m.numberOfRanges > 1 ? m.range(at: 1) : m.range
    guard let r = Range(range, in: text) else { return nil }
    return String(text[r])
  }
}

/// One attempt per launch/session; never reconnect an existing tunnel.
enum TVStartupPolicy {
  static let preferenceKey = "fastcat.tv.auto-connect-on-open"
  static func shouldConnect(
    enabled: Bool, status: String, active: Bool, signedIn: Bool, cancelled: Bool
  ) -> Bool {
    enabled && status == "disconnected" && active && signedIn && !cancelled
  }
}

/// Path changes invalidate results instead of reusing data from a prior network.
@MainActor final class TVStreamingNetworkMonitor: ObservableObject {
  @Published private(set) var generation = 0
  private let monitor = NWPathMonitor()
  private var receivedInitialPath = false
  init() {
    monitor.pathUpdateHandler = { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if self.receivedInitialPath { self.generation += 1 }
        self.receivedInitialPath = true
      }
    }
    monitor.start(queue: DispatchQueue(label: "fastcat.tv.streaming.network"))
  }
  deinit { monitor.cancel() }
}
