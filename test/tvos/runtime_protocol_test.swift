import Foundation

@main
struct TVRuntimeProtocolTests {
  static func graph(_ global: String = "DIRECT", rule: String = "node-a") -> String {
    let map: [String: Any] = [
      "GLOBAL": ["type": "Selector", "all": ["DIRECT", "node-a", "node-b"], "now": global],
      "FastCat": ["type": "Selector", "all": ["node-a", "node-b"], "now": rule],
      "node-a": ["type": "Vless"], "node-b": ["type": "Vless"],
    ]
    return String(decoding: try! JSONSerialization.data(withJSONObject: map), as: UTF8.self)
  }

  static func main() async throws {
    precondition(TVCoreProtocol.isAcknowledged(String(decoding: TVCoreProtocol.acknowledgement(), as: UTF8.self)))
    for response: String? in [nil, "", "ok", "invalid character 'm'", "{}", "null", "{\"ok\":false}", "{\"ok\":1}"] {
      precondition(!TVCoreProtocol.isAcknowledged(response))
    }
    var completions = 0
    let once = TVOnceReply { value in precondition(value == nil); completions += 1 }
    once.finish(nil)
    once.finish("late")
    precondition(completions == 1)

    var current = graph()
    var events: [String] = []
    let snapshot = try await TVProxyRouting.changeMode(from: "rule", to: "global", node: "node-a",
      read: { current }, change: { group, node in
        events.append("select:\(group):\(node)")
        current = graph(node)
        return nil
      }, setMode: { mode in events.append("mode:\(mode)"); return nil })
    precondition(events == ["select:GLOBAL:node-a", "mode:global"])
    precondition(snapshot.selectedName == "node-a")
    precondition(TVSubscriptionNodes.liveSnapshot(from: "{\"x\":{\"type\":\"Selector\",\"all\":[\"node-a\"]}}", mode: "global") == nil)

    events = []
    do {
      _ = try await TVProxyRouting.changeMode(from: "rule", to: "global", node: "missing",
        read: { graph() }, change: { _, _ in events.append("change"); return nil },
        setMode: { _ in events.append("mode"); return nil })
      fatalError("Missing node must not silently pick DIRECT")
    } catch TVRoutingFailure.nodeMissing { }
    precondition(events.isEmpty)
    do {
      _ = try await TVProxyRouting.select(mode: "global", node: "node-a",
        read: { graph() }, change: { _, _ in nil })
      fatalError("ACK without changed selection must fail readback")
    } catch TVRoutingFailure.notConfirmed { }

    current = graph("node-a")
    events = []
    do {
      _ = try await TVProxyRouting.changeMode(from: "rule", to: "global", node: "node-a",
        read: { current }, change: { _, _ in nil },
        setMode: { mode in events.append(mode); return mode == "global" ? "failed" : nil })
      fatalError("Failed mode write must fail")
    } catch TVRoutingFailure.notConfirmed { }
    precondition(events == ["global", "rule"])

    var build = TVBuildConfiguration(xorKey: "", remoteConfigPublicKey: "", subscriptionFlag: "",
      subscriptionKeys: ["test": Data(repeating: 1, count: 32)], requireSubscriptionEncryption: true, fallbackAPIBaseURL: nil)
    build.currentSubscriptionKeyID = "test"
    let original = "mode: rule\nproxies: []"
    let runtime = try build.runtimeConfiguration(original)
    precondition(runtime.contains("fastcat-provider-cache: {"))
    precondition(runtime.contains("\"currentKeyId\":\"test\""))
    precondition(!original.contains("fastcat-provider-cache"))
    do { _ = try build.runtimeConfiguration(runtime); fatalError("Duplicate private config must fail") }
    catch { }

    let home = try String(contentsOfFile: "tvos/FastCatTV/TVHomeView.swift", encoding: .utf8)
    precondition(home.contains("if !forceRefresh, connected, await refreshLiveNodes()"))
    precondition(home.contains("sendConfigUpdate(runtimeConfig)"))
    let provider = try String(contentsOfFile: "tvos/PacketTunnel/PacketTunnelProvider.swift", encoding: .utf8)
    precondition(provider.contains("ClashCore_invoke(\"setupConfigYaml\", config)"))
    precondition(provider.contains("guard resultString == \"\" else"))
    print("PASS: tvOS explicit ACK, late response, GLOBAL write/readback, rollback, refresh routing and transient provider cache keys")
  }
}
