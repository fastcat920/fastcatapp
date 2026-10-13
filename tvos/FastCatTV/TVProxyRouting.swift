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

  private struct RawGroup {
    var name = ""
    var type = ""
    var proxies: [String] = []
  }

  private static func parseGroups(from configuration: String) -> [RawGroup] {
    var insideGroups = false
    var current: RawGroup?
    var collectingProxies = false
    var proxiesIndent = 0
    var result: [RawGroup] = []

    func finish(_ group: RawGroup?, into result: inout [RawGroup]) {
      guard let group, !group.name.isEmpty else { return }
      result.append(group)
    }

    for line in configuration.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let indent = indentation(of: line)
      if indent == 0, trimmed == "proxy-groups:" {
        insideGroups = true
        continue
      }
      if insideGroups, indent == 0, !trimmed.isEmpty, !trimmed.hasPrefix("#") {
        finish(current, into: &result)
        insideGroups = false
        current = nil
        break
      }
      guard insideGroups, !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

      if collectingProxies {
        if indent > proxiesIndent, trimmed.hasPrefix("- ") {
          let value = unquote(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
          if !value.isEmpty { current?.proxies.append(value) }
          continue
        }
        collectingProxies = false
      }

      if trimmed.hasPrefix("- name:") {
        finish(current, into: &result)
        current = RawGroup(
          name: yamlValue(after: "name:", in: String(trimmed.dropFirst(2))) ?? "",
          type: "",
          proxies: []
        )
      } else if trimmed.hasPrefix("type:") {
        current?.type = yamlValue(after: "type:", in: trimmed) ?? ""
      } else if trimmed.hasPrefix("proxies:") {
        let value = yamlValue(after: "proxies:", in: trimmed) ?? ""
        if value.hasPrefix("["), value.hasSuffix("]") {
          current?.proxies = value.dropFirst().dropLast().split(separator: ",").map {
            unquote(String($0).trimmingCharacters(in: .whitespaces))
          }.filter { !$0.isEmpty }
        } else {
          collectingProxies = true
          proxiesIndent = indent
        }
      }
    }
    if insideGroups { finish(current, into: &result) }
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
