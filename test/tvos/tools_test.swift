import Foundation

@main struct ToolsTests {
  static func main() throws {
    let route = try TVUserRoute(destination: "192.0.2.123/24", proxy: false)
    precondition(route.destination == "192.0.2.0/24")
    let rule = try route.coreRule(group: "Proxy")
    precondition(rule == "IP-CIDR,192.0.2.0/24,DIRECT,no-resolve")
    for invalid in ["", "example.com,REJECT", "-bad.com", "1.2.3.4/33", "example.com\nMATCH"] {
      do {
        _ = try TVUserRoute(destination: invalid, proxy: true)
        fatalError("Invalid route accepted")
      } catch {}
    }
    let proxy = try TVUserRoute(destination: "Example.COM", proxy: true)
    precondition(proxy.destination == "example.com")
    do {
      _ = try proxy.coreRule(group: "bad,REJECT")
      fatalError("Invalid group accepted")
    } catch {}
    precondition(
      TVStreamingTargets.summary(["ok": true, "status-code": 451], chinese: false)
        == "Region restricted")
    precondition(TVStreamingTargets.summary(nil, chinese: false) == "Error or timeout")
    precondition(
      TVStreamingTargets.summary(
        ["ok": true, "status-code": 403, "body": "Just a moment"], chinese: false)
        == "Verification required")
    precondition(
      TVStartupPolicy.shouldConnect(
        enabled: true, status: "disconnected", active: true, signedIn: true, cancelled: false))
    for status in ["connected", "connecting", "disconnecting", "invalid"] {
      precondition(
        !TVStartupPolicy.shouldConnect(
          enabled: true, status: status, active: true, signedIn: true, cancelled: false))
    }
    precondition(
      !TVStartupPolicy.shouldConnect(
        enabled: false, status: "disconnected", active: true, signedIn: true, cancelled: false))
    precondition(
      !TVStartupPolicy.shouldConnect(
        enabled: true, status: "disconnected", active: false, signedIn: true, cancelled: false))
    precondition(
      !TVStartupPolicy.shouldConnect(
        enabled: true, status: "disconnected", active: true, signedIn: false, cancelled: false))
    precondition(
      !TVStartupPolicy.shouldConnect(
        enabled: true, status: "disconnected", active: true, signedIn: true, cancelled: true))
    precondition(TVStreamingTargets.isAccessible("Originals only"))
    precondition(!TVStreamingTargets.isFullyAccessible("Originals only"))
    precondition(TVStreamingTargets.isFullyAccessible("Accessible · GB"))
    let names = TVStreamingTargets.media.map(\.0)
    precondition(names.count == 10 && Set(names).count == 10)
    precondition(
      !names.contains("ChatGPT") && !names.contains("Claude") && !names.contains("Gemini"))
    precondition(
      TVStreamingNavigation.next(from: "start", direction: "down", names: names, canStop: false)
        == "result:Netflix")
    precondition(
      TVStreamingNavigation.next(
        from: "result:Netflix", direction: "right", names: names, canStop: false)
        == "result:Disney+")
    precondition(
      TVStreamingNavigation.next(
        from: "result:Disney+", direction: "left", names: names, canStop: false) == "result:Netflix"
    )
    precondition(
      TVStreamingNavigation.next(
        from: "visit:Netflix", direction: "right", names: names, canStop: false) == nil)
    var focus = "result:Netflix"
    for _ in 0..<4 {
      focus = TVStreamingNavigation.next(
        from: focus, direction: "down", names: names, canStop: false)!
    }
    precondition(focus == "result:Crunchyroll")
    focus = TVStreamingNavigation.next(
      from: focus, direction: "right", names: names, canStop: false)!
    precondition(focus == "result:TikTok")
    precondition(
      TVStreamingNavigation.next(from: focus, direction: "down", names: names, canStop: false)
        == nil)
    for _ in 0..<5 {
      focus = TVStreamingNavigation.next(
        from: focus, direction: "up", names: names, canStop: false)!
    }
    precondition(focus == "start")
    precondition(
      TVStreamingNavigation.next(from: "start", direction: "up", names: names, canStop: false)
        == "back")
    precondition(
      TVStreamingNavigation.next(from: "start", direction: "right", names: names, canStop: true)
        == "stop")
    precondition(
      TVStreamingNavigation.next(from: "stop", direction: "left", names: names, canStop: true)
        == "start")
    let account = [["account.plan"], ["account.logout"], ["account.delete"]]
    precondition(
      TVToolsNavigation.next(from: "back", direction: "down", rows: account) == "account.plan")
    precondition(
      TVToolsNavigation.next(from: "account.plan", direction: "down", rows: account)
        == "account.logout")
    precondition(
      TVToolsNavigation.next(from: "account.logout", direction: "down", rows: account)
        == "account.delete")
    precondition(
      TVToolsNavigation.next(from: "account.plan", direction: "up", rows: account) == "back")
    let startup = [["startup.auto"]]
    precondition(
      TVToolsNavigation.next(from: "startup.auto", direction: "up", rows: startup) == "back")
    precondition(
      TVToolsNavigation.next(from: "back", direction: "down", rows: startup) == "startup.auto")
    let routing = [["routing.input"], ["routing.direct", "routing.proxy"], ["routing.save"]]
    precondition(
      TVToolsNavigation.next(from: "routing.input", direction: "up", rows: routing) == "back")
    precondition(
      TVToolsNavigation.next(from: "routing.proxy", direction: "up", rows: routing)
        == "routing.input")
    let about = [["row:Check for updates"], ["about.privacy", "about.terms"]]
    precondition(
      TVToolsNavigation.next(from: "row:Check for updates", direction: "up", rows: about) == "back")
    precondition(
      TVToolsNavigation.next(from: "back", direction: "down", rows: about)
        == "row:Check for updates")
    precondition(
      TVToolsNavigation.next(from: "about.terms", direction: "up", rows: about)
        == "row:Check for updates")
    precondition(TVToolsNavigation.next(from: "logo", direction: "up", rows: about) == nil)
    precondition(TVToolsNavigation.next(from: "back", direction: "down", rows: []) == nil)
    let ruleActions = TVRuleActions.identifiers(ruleID: "test-id")
    precondition(
      ruleActions == [
        "rule.test-id.edit", "rule.test-id.delete", "rule.test-id.up", "rule.test-id.down",
      ])
    precondition(
      TVToolsNavigation.next(from: ruleActions[1], direction: "right", rows: [ruleActions])
        == ruleActions[2])
    precondition(
      TVToolsNavigation.next(from: ruleActions[2], direction: "right", rows: [ruleActions])
        == ruleActions[3])
    precondition(
      TVToolsNavigation.next(from: ruleActions[3], direction: "left", rows: [ruleActions])
        == ruleActions[2])
    precondition(TVInitialLatencyPolicy.target(selected: "JP", names: ["HK", "JP", "TW"]) == "JP")
    precondition(TVInitialLatencyPolicy.target(selected: "missing", names: ["HK", "JP"]) == "HK")
    precondition(TVInitialLatencyPolicy.target(selected: nil, names: ["HK", "JP"]) == "HK")
    precondition(TVInitialLatencyPolicy.target(selected: "JP", names: []) == nil)
    let date = Date(timeIntervalSince1970: 10000)
    let cache = TVStreamingCache(
      account: "a", node: "JP", network: 1, language: "en", created: date, region: "JP",
      results: ["Netflix": "Accessible"])
    precondition(
      cache.matches(
        account: "a", node: "JP", network: 1, language: "en", now: date.addingTimeInterval(599)))
    precondition(
      !cache.matches(
        account: "a", node: "JP", network: 1, language: "en", now: date.addingTimeInterval(600)))
    precondition(!cache.matches(account: "b", node: "JP", network: 1, language: "en", now: date))
    precondition(!cache.matches(account: "a", node: "HK", network: 1, language: "en", now: date))
    precondition(!cache.matches(account: "a", node: "JP", network: 2, language: "en", now: date))
    precondition(!cache.matches(account: "a", node: "JP", network: 1, language: "zh-CN", now: date))
    precondition(
      !cache.matches(
        account: "a", node: "JP", network: 1, language: "en", now: date.addingTimeInterval(-1)))
    precondition(TVLogSanitizer.message("token=example") == "[Sensitive log omitted]")
    let masked = TVLogSanitizer.message(
      "connect https://example.com/path from 192.0.2.1:443 user@example.com")
    precondition(
      !masked.contains("example.com") && !masked.contains("192.0.2.1") && !masked.contains("user@"))
    let parsed = TVLogSanitizer.lines(
      "[{\"type\":\"log\",\"data\":{\"Payload\":\"dial 192.0.2.1\"}}]")
    precondition(parsed.count == 1 && !parsed[0].contains("192.0.2.1"))
    precondition(TVLogSanitizer.lines("not json").isEmpty)
    print("TV tools validation passed")
  }
}
