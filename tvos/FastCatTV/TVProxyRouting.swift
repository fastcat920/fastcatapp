import Foundation

struct TVProxyNode: Identifiable, Hashable {
  let name: String
  let type: String
  let delayMS: Int?
  var id: String { name }

  init(_ name: String, type: String = "", delayMS: Int? = nil) {
    self.name = name
    self.type = type
    self.delayMS = delayMS
  }
}

struct TVProxySnapshot {
  let groupName: String
  let nodes: [TVProxyNode]
  let selectedName: String?
}

enum TVSubscriptionNodes {
  static func parse(from configuration: String) -> [TVProxyNode] {
    let groups = parseGroups(from: configuration)
    if let group = groups.first(where: { $0.type.lowercased() == "select" }),
       !group.proxies.isEmpty {
      return group.proxies
        .filter { $0 != "DIRECT" && $0 != "REJECT" }
        .map { TVProxyNode($0) }
    }

    var insideProxies = false
    var names: [String] = []

    for line in configuration.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let normalized = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
      if indentation(of: line) == 0, normalized == "proxies:" {
        insideProxies = true
        continue
      }
      if insideProxies, indentation(of: line) == 0, !normalized.isEmpty, !normalized.hasPrefix("#") { break }
      guard insideProxies, let name = extractName(from: normalized) else { continue }
      if !name.isEmpty, !names.contains(name) { names.append(name) }
    }
    return names.map { TVProxyNode($0) }
  }

  static func preferredGroupName(from configuration: String, mode: String) -> String? {
    if mode == "global" { return "GLOBAL" }
    let groups = parseGroups(from: configuration)
    return groups.first(where: { $0.type.lowercased() == "select" })?.name ?? groups.first?.name
  }

  static func liveSnapshot(from response: String, mode: String) -> TVProxySnapshot? {
    guard let data = response.data(using: .utf8),
          let proxies = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

    let groups: [(name: String, value: [String: Any])] = proxies.compactMap { key, raw in
      guard let value = raw as? [String: Any], value["all"] is [Any] else { return nil }
      return (key, value)
    }
    let selectedGroup: (name: String, value: [String: Any])?
    if mode == "global" {
      guard let global = groups.first(where: { $0.name == "GLOBAL" }) else { return nil }
      selectedGroup = global
    } else {
      selectedGroup = groups.first(where: {
        $0.name != "GLOBAL" && (($0.value["type"] as? String)?.lowercased() == "selector")
      }) ?? groups.first(where: { $0.name != "GLOBAL" })
    }
    guard let selectedGroup,
          let names = selectedGroup.value["all"] as? [String] else { return nil }

    let nodes = names.compactMap { name -> TVProxyNode? in
      guard name != "DIRECT", name != "REJECT" else { return nil }
      let value = proxies[name] as? [String: Any]
      let type = value?["type"] as? String ?? ""
      let history = value?["history"] as? [[String: Any]]
      let delay = history?.last?["delay"] as? Int
      return TVProxyNode(name, type: type, delayMS: delay)
    }
    return TVProxySnapshot(
      groupName: selectedGroup.name,
      nodes: nodes,
      selectedName: selectedGroup.value["now"] as? String
    )
  }

  private static func indentation(of line: String) -> Int { line.prefix { $0 == " " }.count }

  private static func extractName(from line: String) -> String? {
    var candidate = line
    if candidate.hasPrefix("-") {
      candidate = String(candidate.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
    let pattern = #"(?:^|[,{]\s*)[\"']?name[\"']?\s*:\s*(?:\"([^\"]+)\"|'([^']+)'|([^,}]+))"#
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(
            in: candidate,
            range: NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
          ) else { return nil }
    for capture in 1...3 where match.range(at: capture).location != NSNotFound {
      guard let range = Range(match.range(at: capture), in: candidate) else { continue }
      let name = String(candidate[range]).trimmingCharacters(in: .whitespacesAndNewlines)
      if !name.isEmpty { return name }
    }
    return nil
  }

  private static func unquote(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
      return String(value.dropFirst().dropLast())
    }
    return value
  }

  private static func yamlValue(after key: String, in line: String) -> String? {
    guard let range = line.range(of: key) else { return nil }
    let value = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    let result = unquote(value)
    return result.isEmpty ? nil : result
  }

  static func testURL(from yaml: String, node: String, group: String?, fallback: String) -> String {
    func valid(_ value: String?) -> String? {
      guard let value, let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
      return value
    }
    let groups = parseGroups(from: yaml)
    let selected = groups.first { $0.name == group } ?? groups.first { $0.proxies.contains(node) }
    return valid(selected?.testURL) ?? valid(fallback) ?? "https://www.gstatic.com/generate_204"
  }

  private struct RawGroup {
    var name = ""
    var type = ""
    var proxies: [String] = []
    var testURL: String?
  }

  /// Split YAML flow values without splitting quoted commas or nested lists.
  private static func flowParts(_ value: String) -> [String] {
    var result: [String] = [], part = "", quote: Character?, depth = 0
    var escaped = false
    for character in value {
      if let active = quote {
        part.append(character)
        if escaped { escaped = false }
        else if character == "\\" && active == "\"" { escaped = true }
        else if character == active { quote = nil }
      } else if character == "\"" || character == "'" {
        quote = character; part.append(character)
      } else if character == "[" || character == "{" {
        depth += 1; part.append(character)
      } else if character == "]" || character == "}" {
        depth -= 1; part.append(character)
      } else if character == "," && depth == 0 {
        result.append(part.trimmingCharacters(in: .whitespaces)); part = ""
      } else { part.append(character) }
    }
    if !part.isEmpty { result.append(part.trimmingCharacters(in: .whitespaces)) }
    return result
  }

  private static func parseGroups(from configuration: String) -> [RawGroup] {
    if let data = configuration.data(using: .utf8),
       let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let groups = object["proxy-groups"] as? [[String: Any]] {
      return groups.compactMap { item in
        guard let name = item["name"] as? String, !name.isEmpty else { return nil }
        return RawGroup(name: name, type: item["type"] as? String ?? "",
          proxies: item["proxies"] as? [String] ?? [], testURL: item["url"] as? String)
      }
    }
    var insideGroups = false, collectingProxies = false
    var current: RawGroup?, groupIndent: Int?, proxiesIndent = 0
    var result: [RawGroup] = []
    func finish() {
      if let current, !current.name.isEmpty { result.append(current) }
      current = nil
    }
    func field(_ text: String, indent: Int) {
      guard let colon = text.firstIndex(of: ":") else { return }
      let key = unquote(String(text[..<colon]).trimmingCharacters(in: .whitespaces))
      let raw = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
      switch key {
      case "name": current?.name = unquote(raw)
      case "type": current?.type = unquote(raw)
      case "url": current?.testURL = unquote(raw)
      case "proxies":
        if raw.hasPrefix("["), raw.hasSuffix("]") {
          current?.proxies = flowParts(String(raw.dropFirst().dropLast())).map(unquote)
        } else { collectingProxies = true; proxiesIndent = indent }
      default: break
      }
    }
    func flowGroup(_ raw: String) {
      finish(); current = RawGroup()
      for part in flowParts(String(raw.dropFirst().dropLast())) { field(part, indent: 0) }
      finish()
    }
    for line in configuration.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
      if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
      let indent = indentation(of: line)
      if !insideGroups {
        guard indent == 0, let colon = trimmed.firstIndex(of: ":"),
          unquote(String(trimmed[..<colon])) == "proxy-groups" else { continue }
        insideGroups = true
        let tail = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        if tail.hasPrefix("["), tail.hasSuffix("]") {
          for item in flowParts(String(tail.dropFirst().dropLast())) where item.hasPrefix("{") && item.hasSuffix("}") { flowGroup(item) }
          return result
        }
        continue
      }
      let sequence = trimmed.hasPrefix("- ") || trimmed == "-"
      // YAML permits unindented sequences directly under a root mapping key.
      if indent == 0 && !sequence { break }
      if collectingProxies {
        if sequence, indent >= proxiesIndent, indent > (groupIndent ?? -1) {
          let name = unquote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
          if !name.isEmpty { current?.proxies.append(name) }
          continue
        }
        collectingProxies = false
      }
      if sequence, groupIndent == nil || indent == groupIndent {
        finish(); groupIndent = indent
        let entry = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        if entry.hasPrefix("{"), entry.hasSuffix("}") { flowGroup(entry) }
        else { current = RawGroup(); field(entry, indent: indent + 2) }
      } else if current != nil { field(trimmed, indent: indent) }
    }
    finish()
    return result
  }
}

enum TVRoutingFailure: Error { case unavailable, nodeMissing, notConfirmed }

/// Write the selected node before changing mode, then read it back. Updating
/// `mode` alone does not update Mihomo's independent GLOBAL selector.
enum TVProxyRouting {
  static func select(
    mode: String, node: String,
    read: () async -> String?,
    change: (String, String) async -> String?
  ) async throws -> TVProxySnapshot {
    try Task.checkCancellation()
    guard let response = await read(),
          let before = TVSubscriptionNodes.liveSnapshot(from: response, mode: mode) else {
      throw TVRoutingFailure.unavailable
    }
    try Task.checkCancellation()
    guard before.nodes.contains(where: { $0.name == node }) else { throw TVRoutingFailure.nodeMissing }
    guard await change(before.groupName, node) == nil else { throw TVRoutingFailure.notConfirmed }
    try Task.checkCancellation()
    guard let response = await read(),
          let after = TVSubscriptionNodes.liveSnapshot(from: response, mode: mode),
          after.groupName == before.groupName, after.selectedName == node else {
      throw TVRoutingFailure.notConfirmed
    }
    return after
  }

  static func changeMode(
    from previous: String, to next: String, node: String,
    read: () async -> String?,
    change: (String, String) async -> String?,
    setMode: (String) async -> String?
  ) async throws -> TVProxySnapshot {
    let snapshot = try await select(mode: next, node: node, read: read, change: change)
    guard await setMode(next) == nil else {
      _ = await setMode(previous)
      throw TVRoutingFailure.notConfirmed
    }
    try Task.checkCancellation()
    guard let response = await read(),
          let verified = TVSubscriptionNodes.liveSnapshot(from: response, mode: next),
          verified.groupName == snapshot.groupName, verified.selectedName == node else {
      _ = await setMode(previous)
      throw TVRoutingFailure.notConfirmed
    }
    return verified
  }
}

/// Display only; keep raw latency for routing, history and subsequent refreshes.
func tvDisplayedDelay(_ raw: Int?, discount: Int) -> Int? {
  guard let raw, raw > 0 else { return raw }
  return max(1, raw * (100 - min(90, max(0, discount))) / 100)
}
