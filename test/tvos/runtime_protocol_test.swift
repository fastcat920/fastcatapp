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
    for (width, height, scale) in [
      (1280.0, 720.0, 1.0), (1920.0, 1080.0, 1.5), (3840.0, 2160.0, 3.0),
    ] {
      let density = TVDesignMetrics.density(width: width, height: height)
      precondition(density == scale)
      precondition(TVDesignMetrics.logical(width, density: density) == 1280)
      precondition(TVDesignMetrics.logical(height, density: density) - 64 == 656)
      precondition(64 * density / height == 64.0 / 720.0)
    }

    // Android TV owns the page padding; no second outer frame is added.
    precondition(TVHomeFrame.contentHeight(720) == 720)
    precondition(TVHomeFrame.contentHeight(720) - 64 >= 620)
    precondition(TVHomeFrame.contentHeight(4) == 4)
    precondition(TVHomeFrame.horizontal + 25 == 25)
    precondition(TVPageSpacing.horizontal(logicalWidth: 1280) == 25)
    precondition(TVPageSpacing.horizontal(logicalWidth: 1399) == 25)
    precondition(TVPageSpacing.horizontal(logicalWidth: 1400) == 33)
    precondition(TVPageSpacing.contentTop == 19 && TVPageSpacing.bottom == 23)
    for legacy in [false, true] {
      precondition(TVThemePreference.windowStyle(mode: "system", legacyDark: legacy) == 0)
      precondition(TVThemePreference.windowStyle(mode: "light", legacyDark: legacy) == 1)
      precondition(TVThemePreference.windowStyle(mode: "dark", legacyDark: legacy) == 2)
      precondition(TVThemePreference.windowStyle(mode: "legacy", legacyDark: legacy) == (legacy ? 2 : 1))
      // Switching back to automatic must clear the previous explicit style.
      precondition(["light", "system", "dark", "system"].map {
        TVThemePreference.windowStyle(mode: $0, legacyDark: legacy)
      } == [1, 0, 2, 0])
    }
    for systemDark in [false, true] {
      for legacy in [false, true] {
        precondition(
          TVThemePreference.isDark(mode: "system", legacyDark: legacy, systemDark: systemDark)
            == systemDark)
        precondition(
          TVThemePreference.isDark(mode: "dark", legacyDark: legacy, systemDark: systemDark))
        precondition(
          !TVThemePreference.isDark(mode: "light", legacyDark: legacy, systemDark: systemDark))
        precondition(
          TVThemePreference.isDark(mode: "legacy", legacyDark: legacy, systemDark: systemDark)
            == legacy)
      }
    }
    precondition(
      TVSystemAppearancePolicy.resolve(rawStyle: 0, active: false, windowReady: false) == nil)
    precondition(
      TVSystemAppearancePolicy.resolve(rawStyle: 0, active: true, windowReady: true) == nil)
    precondition(
      TVSystemAppearancePolicy.resolve(rawStyle: 1, active: false, windowReady: true) == nil)
    precondition(
      TVSystemAppearancePolicy.resolve(rawStyle: 1, active: true, windowReady: false) == nil)
    precondition(
      TVSystemAppearancePolicy.resolve(rawStyle: 2, active: true, windowReady: false) == nil)
    precondition(
      TVSystemAppearancePolicy.resolve(rawStyle: 2, active: true, windowReady: true) == true)
    precondition(
      TVSystemAppearancePolicy.resolve(rawStyle: 1, active: true, windowReady: true) == false)
    var appearance: Bool? = nil
    for (style, active, attached) in [
      (0, false, false), (1, false, true), (2, true, false), (2, true, true),
    ] {
      if let ready = TVSystemAppearancePolicy.resolve(
        rawStyle: style, active: active, windowReady: attached)
      {
        appearance = ready
      }
      if !active || !attached { precondition(appearance == nil) }
    }
    precondition(appearance == true)
    let now = Date(timeIntervalSince1970: 500000)
    precondition(tvConnectionDuration(since: nil, now: now) == "00:00:00")
    precondition(tvConnectionDuration(since: now.addingTimeInterval(-3661), now: now) == "01:01:01")
    precondition(tvConnectionDuration(since: now.addingTimeInterval(5), now: now) == "00:00:00")
    precondition(
      tvConnectionDuration(since: now.addingTimeInterval(-400000), now: now) == "99:59:59")
    precondition(
      TVCoreProtocol.isAcknowledged(
        String(decoding: TVCoreProtocol.acknowledgement(), as: UTF8.self)))
    for response: String? in [
      nil, "", "ok", "invalid character 'm'", "{}", "null", "{\"ok\":false}", "{\"ok\":1}",
    ] {
      precondition(!TVCoreProtocol.isAcknowledged(response))
    }
    var completions = 0
    let once = TVOnceReply { value in
      precondition(value == nil)
      completions += 1
    }
    once.finish(nil)
    once.finish("late")
    precondition(completions == 1)

    var current = graph()
    var events: [String] = []
    let snapshot = try await TVProxyRouting.changeMode(
      from: "rule", to: "global", node: "node-a",
      read: { current },
      change: { group, node in
        events.append("select:\(group):\(node)")
        current = graph(node)
        return nil
      },
      setMode: { mode in
        events.append("mode:\(mode)")
        return nil
      })
    precondition(events == ["select:GLOBAL:node-a", "mode:global"])
    precondition(snapshot.selectedName == "node-a")
    precondition(
      TVSubscriptionNodes.liveSnapshot(
        from: "{\"x\":{\"type\":\"Selector\",\"all\":[\"node-a\"]}}", mode: "global") == nil)

    events = []
    do {
      _ = try await TVProxyRouting.changeMode(
        from: "rule", to: "global", node: "missing",
        read: { graph() },
        change: { _, _ in
          events.append("change")
          return nil
        },
        setMode: { _ in
          events.append("mode")
          return nil
        })
      fatalError("Missing node must not silently pick DIRECT")
    } catch TVRoutingFailure.nodeMissing {}
    precondition(events.isEmpty)
    do {
      _ = try await TVProxyRouting.select(
        mode: "global", node: "node-a",
        read: { graph() }, change: { _, _ in nil })
      fatalError("ACK without changed selection must fail readback")
    } catch TVRoutingFailure.notConfirmed {}

    current = graph("node-a")
    events = []
    do {
      _ = try await TVProxyRouting.changeMode(
        from: "rule", to: "global", node: "node-a",
        read: { current }, change: { _, _ in nil },
        setMode: { mode in
          events.append(mode)
          return mode == "global" ? "failed" : nil
        })
      fatalError("Failed mode write must fail")
    } catch TVRoutingFailure.notConfirmed {}
    precondition(events == ["global", "rule"])

    precondition(tvDisplayedDelay(100, discount: 30) == 70)
    precondition(tvDisplayedDelay(-1, discount: 30) == -1)
    precondition(tvDisplayedDelay(1, discount: 90) == 1)
    precondition(tvDisplayedDelay(nil, discount: 30) == nil)
    let testProfile =
      "proxy-groups:\n  - name: test-group\n    type: select\n    url: https://group.invalid/check\n    proxies: [node-a]\n"
    precondition(
      TVSubscriptionNodes.testURL(
        from: testProfile, node: "node-a", group: "test-group",
        fallback: "https://client.invalid/check") == "https://group.invalid/check")
    precondition(
      TVSubscriptionNodes.testURL(
        from: "", node: "node-a", group: nil, fallback: "https://client.invalid/check")
        == "https://client.invalid/check")
    precondition(
      TVSubscriptionNodes.testURL(from: "", node: "node-a", group: nil, fallback: "file:///private")
        == "https://www.gstatic.com/generate_204")
    // Both legal YAML sequence indentations and flow maps must resolve a
    // proxy-rule target; an empty target prevents VPN startup with local rules.
    let groupFixtures = [
      "proxy-groups:\n- name: Route\n  type: select\n  proxies:\n  - node-a\nrules:\n- MATCH,Route",
      "proxy-groups:\n  - type: select\n    name: Route\n    proxies: [node-a]",
      "proxy-groups:\n  - {name: Route, type: select, proxies: [node-a], url: 'https://test.invalid/check'}",
      "proxy-groups: [{name: Route, type: select, proxies: [node-a]}]",
      "{\"proxy-groups\":[{\"name\":\"Route\",\"type\":\"select\",\"proxies\":[\"node-a\"]}]}"
    ]
    for fixture in groupFixtures {
      precondition(TVSubscriptionNodes.preferredGroupName(from: fixture, mode: "rule") == "Route")
      precondition(TVSubscriptionNodes.parse(from: fixture).map(\.name) == ["node-a"])
    }
    let commaFixture = "proxy-groups:\n- {name: Route, type: select, proxies: ['node,a', node-b]}"
    precondition(TVSubscriptionNodes.parse(from: commaFixture).map(\.name) == ["node,a", "node-b"])
    var build = TVBuildConfiguration(
      xorKey: "", remoteConfigPublicKey: "", subscriptionFlag: "",
      subscriptionKeys: ["test": Data(repeating: 255, count: 32)],
      requireSubscriptionEncryption: true, fallbackAPIBaseURL: nil)
    build.currentSubscriptionKeyID = "test"
    let original = "mode: rule\nproxies: []"
    let runtime = try build.runtimeConfiguration(original)
    precondition(runtime.contains("unified-delay: true"))
    let overridden = try build.runtimeConfiguration("unified-delay: false\nproxies: []")
    precondition(!overridden.contains("unified-delay: false"))
    precondition(overridden.components(separatedBy: "unified-delay:").count == 2)
    precondition(runtime.contains("fastcat-provider-cache: {"))
    precondition(runtime.contains("\"currentKeyId\":\"test\""))
    precondition(
      !runtime.contains("\\/"), "JSON slash escaping is incompatible with the core YAML parser")
    precondition(!original.contains("fastcat-provider-cache"))
    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: scratch) }
    let bundle = scratch.appendingPathComponent("Test.app")
    let homeDir = scratch.appendingPathComponent("Caches/Core")
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    for name in ["GeoIP.dat", "GeoSite.dat", "ASN.mmdb", "geoip.metadb"] {
      try Data([1, 2, 3]).write(to: bundle.appendingPathComponent(name))
    }
    try TVRoutingAssets.prepare(home: homeDir, bundleURL: bundle)
    // A purged or interrupted cache must be recreated from the app bundle.
    try Data().write(to: homeDir.appendingPathComponent("GeoSite.dat"))
    try TVRoutingAssets.prepare(
      home: homeDir, bundleURL: bundle.appendingPathComponent("PlugIns/PacketTunnel.appex"))
    let restored = try Data(contentsOf: homeDir.appendingPathComponent("GeoSite.dat"))
    precondition(restored == Data([1, 2, 3]))
    do {
      _ = try build.runtimeConfiguration(runtime)
      fatalError("Duplicate private config must fail")
    } catch {}

    let home = try String(contentsOfFile: "tvos/FastCatTV/TVHomeView.swift", encoding: .utf8)
    precondition(home.contains("if !forceRefresh, connected, await refreshLiveNodes()"))
    precondition(home.contains("sendConfigUpdate(runtimeConfig)"))
    let provider = try String(
      contentsOfFile: "tvos/PacketTunnel/PacketTunnelProvider.swift", encoding: .utf8)
    precondition(provider.contains("ClashCore_invoke(\"setupConfigYaml\", config)"))
    precondition(provider.contains("guard resultString == \"\" else"))
    print(
      "PASS: tvOS explicit ACK, late response, GLOBAL write/readback, rollback, refresh routing and transient provider cache keys"
    )
  }
}
