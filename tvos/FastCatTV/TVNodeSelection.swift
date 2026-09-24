import SwiftUI

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
    if mode == "global", let global = groups.first(where: { $0.name == "GLOBAL" }) {
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

struct TVNodeSelectorView: View {
  let nodes: [TVProxyNode]
  let selectedName: String?
  let isLoading: Bool
  let isRefreshing: Bool
  let isTesting: Bool
  let testingNodeNames: Set<String>
  let errorMessage: String?
  let onClose: () -> Void
  let onRefresh: () -> Void
  let onTest: () -> Void
  let onSelect: (TVProxyNode) -> Void
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue

  private let columns = [GridItem(.flexible(), spacing: tv(10)), GridItem(.flexible(), spacing: tv(10))]

  var body: some View {
    ZStack {
      TVTheme.background
      VStack(alignment: .leading, spacing: tv(0)) {
        HStack(spacing: tv(8)) {
          TVFocusButton(cornerRadius: tv(12), action: onClose) { _ in
            MaterialIcon(glyph: .arrowBack, size: 24, color: TVTheme.textPrimary)
              .frame(width: tv(48), height: tv(48))
          }
          Text(tvText("节点选择", "Node Selection", language: language))
            .font(TVFont.regular(22))
            .foregroundStyle(TVTheme.textPrimary)
          Spacer()
          nodeToolbarButton(
            title: tvText("更新节点", "Update Nodes", language: language),
            icon: .refresh,
            loading: isRefreshing,
            disabled: isRefreshing || isTesting,
            action: onRefresh
          )
          nodeToolbarButton(
            title: tvText("测试延迟", "Test Latency", language: language),
            icon: .networkCheck,
            loading: isTesting,
            disabled: isRefreshing || isTesting,
            action: onTest
          )
        }
        .frame(height: tv(56))

        if isLoading {
          Spacer()
          HStack { Spacer(); ProgressView(tvText("正在加载线路…", "Loading nodes…", language: language)).controlSize(.large).font(TVFont.regular(14)); Spacer() }
          Spacer()
        } else if let errorMessage {
          Spacer()
          VStack(spacing: tv(18)) {
            MaterialIcon(glyph: .wifiOff, size: 44, color: TVTheme.warning)
            Text(errorMessage).font(TVFont.regular(14))
          }
          .frame(maxWidth: .infinity)
          Spacer()
        } else if nodes.isEmpty {
          Spacer()
          VStack(spacing: tv(18)) {
            MaterialIcon(glyph: .wifiOff, size: 46, color: TVTheme.textSecondary)
            Text(tvText("订阅中没有可用线路", "No available nodes in this subscription", language: language)).font(TVFont.regular(14))
            Text(tvText("请选择更新节点重试", "Select Update Nodes to try again", language: language)).font(TVFont.regular(12)).foregroundStyle(TVTheme.textSecondary)
          }
          .frame(maxWidth: .infinity)
          Spacer()
        } else {
          ScrollView {
            overviewCard
              .padding(.top, tv(4))
              .padding(.bottom, tv(10))
            LazyVGrid(columns: columns, spacing: tv(8)) {
              ForEach(Array(nodes.enumerated()), id: \.element.id) { offset, node in
                let selected = selectedName == node.name
                TVFocusButton(cornerRadius: tv(16), autofocus: selected || (selectedName == nil && offset == 0), action: {
                  onSelect(node)
                }) { _ in
                  HStack(spacing: tv(9)) {
                    MaterialIcon(glyph: selected ? .checkCircle : .circleOutlined, size: 21, color: selected ? TVTheme.primary : TVTheme.outline)
                    Text(nodeCountryFlag(node.name)).font(.system(size: tv(20)))
                    VStack(alignment: .leading, spacing: tv(5)) {
                      Text(node.name).font(selected ? TVFont.medium(14) : TVFont.regular(14)).lineLimit(1)
                      HStack(spacing: tv(6)) {
                        nodeTag(node.type.isEmpty ? "Proxy" : node.type, color: TVTheme.outline)
                        if selected { nodeTag(tvText("当前节点", "Current Node", language: language), color: TVTheme.primary) }
                      }
                    }
                    Spacer()
                    if testingNodeNames.contains(node.name) {
                      ProgressView()
                        .controlSize(.small)
                        .tint(TVTheme.primary)
                        .frame(width: tv(64), height: tv(42))
                    } else if let delay = node.delayMS, delay < 0 {
                      Text(tvText("超时", "Timeout", language: language))
                        .font(TVFont.medium(11))
                        .foregroundStyle(TVTheme.danger)
                        .frame(width: tv(64), height: tv(42))
                    } else if let delay = node.delayMS, delay > 0 {
                      Text("\(delay)ms")
                        .font(TVFont.medium(11))
                        .foregroundStyle(delay < 500 ? TVTheme.success : TVTheme.warning)
                        .frame(width: tv(64), height: tv(42))
                    } else {
                      Text("--").font(TVFont.medium(11)).foregroundStyle(TVTheme.outline).frame(width: tv(64), height: tv(42))
                    }
                  }
                  .padding(.horizontal, tv(14))
                  .frame(maxWidth: .infinity, minHeight: tv(66), maxHeight: tv(66))
                  .background(selected ? TVTheme.primary.opacity(0.08) : TVTheme.surface)
                  .clipShape(RoundedRectangle(cornerRadius: tv(16), style: .continuous))
                  .overlay { RoundedRectangle(cornerRadius: tv(16), style: .continuous).strokeBorder(selected ? TVTheme.primary.opacity(0.65) : TVTheme.stroke, lineWidth: selected ? tv(1.4) : tv(1)) }
                }
              }
            }
            .padding(.bottom, tv(24))
          }
          .padding(.horizontal, tv(16))
        }
      }
    }
    .onExitCommand(perform: onClose)
  }

  private var overviewCard: some View {
    TVGlassCard {
      HStack(spacing: tv(12)) {
        ZStack {
          RoundedRectangle(cornerRadius: tv(13), style: .continuous).fill(TVTheme.primary.opacity(0.12))
          MaterialIcon(glyph: .hubOutlined, size: 22, color: TVTheme.primary)
        }
        .frame(width: tv(42), height: tv(42))
        VStack(alignment: .leading, spacing: tv(4)) {
          HStack(spacing: tv(0)) {
            Text(tvText("当前代理模式：", "Current Proxy Mode: ", language: language)).font(TVFont.medium(14))
            Text(tvText("规则", "Rule", language: language)).font(TVFont.medium(14)).foregroundStyle(TVTheme.primary)
          }
          Text(tvText("按规则自动分流，国内直连、其他流量按规则选择线路", "Route traffic automatically according to rules", language: language))
            .font(TVFont.regular(12)).foregroundStyle(TVTheme.textSecondary).lineSpacing(tv(4.2))
        }
        Spacer()
      }
      .padding(tv(14))
    }
  }

  private func nodeToolbarButton(
    title: String,
    icon: MaterialGlyph,
    loading: Bool,
    disabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    TVFocusButton(cornerRadius: tv(10), action: action) { _ in
      HStack(spacing: tv(8)) {
        if loading {
          ProgressView().controlSize(.small).tint(TVTheme.primary).frame(width: tv(18), height: tv(18))
        } else {
          MaterialIcon(glyph: icon, size: 18, color: TVTheme.primary)
        }
        Text(title).font(TVFont.regular(14)).foregroundStyle(TVTheme.primary)
      }
      .padding(.horizontal, tv(10))
      .frame(height: tv(40))
    }
    .disabled(disabled)
    .opacity(disabled && !loading ? 0.38 : 1)
  }

  private func nodeTag(_ title: String, color: Color) -> some View {
    Text(title)
      .font(TVFont.regular(10))
      .foregroundStyle(color)
      .padding(.horizontal, tv(7)).padding(.vertical, tv(2))
      .background(color.opacity(0.10))
      .clipShape(RoundedRectangle(cornerRadius: tv(7), style: .continuous))
  }

  private func nodeCountryFlag(_ name: String) -> String {
    let upper = name.uppercased()
    let rules: [(String, [String])] = [
      ("🇭🇰", ["香港", "HONG KONG", " HK ", "HKG"]), ("🇲🇴", ["澳门", "澳門", "MACAU"]),
      ("🇹🇼", ["台湾", "台灣", "TAIWAN", " TW "]), ("🇨🇳", ["中国", "中國", "CHINA", " CN "]),
      ("🇯🇵", ["日本", "JAPAN", "TOKYO", "OSAKA", " JP "]), ("🇸🇬", ["新加坡", "SINGAPORE", " SG "]),
      ("🇰🇷", ["韩国", "韓國", "KOREA", "SEOUL"]), ("🇺🇸", ["美国", "美國", "UNITED STATES", "AMERICA", " USA"]),
      ("🇬🇧", ["英国", "英國", "UNITED KINGDOM", "BRITAIN"]), ("🇩🇪", ["德国", "德國", "GERMANY"]),
      ("🇫🇷", ["法国", "法國", "FRANCE"]), ("🇨🇦", ["加拿大", "CANADA"]), ("🇦🇺", ["澳大利亚", "澳大利亞", "AUSTRALIA"])
    ]
    if let scalarPair = name.range(of: "[🇦-🇿]{2}", options: .regularExpression).map({ String(name[$0]) }) { return scalarPair }
    return rules.first(where: { $0.1.contains(where: upper.contains) })?.0 ?? "🌐"
  }
}
