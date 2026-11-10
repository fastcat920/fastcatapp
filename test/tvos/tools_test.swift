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
    print("TV tools validation passed")
  }
}
