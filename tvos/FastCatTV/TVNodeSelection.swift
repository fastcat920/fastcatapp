import SwiftUI

struct TVProxyNode: Identifiable, Hashable {
  let name: String
  var id: String { name }
}

enum TVSubscriptionNodes {
  static func parse(from configuration: String) -> [TVProxyNode] {
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
    return names.map(TVProxyNode.init)
  }

  static func prioritizing(_ selectedName: String?, in configuration: String) -> String {
    guard let selectedName, !selectedName.isEmpty else { return configuration }
    var lines = configuration.components(separatedBy: .newlines)
    var index = 0

    while index < lines.count {
      guard lines[index].trimmingCharacters(in: .whitespaces) == "proxies:" else { index += 1; continue }
      let proxiesIndent = indentation(of: lines[index])
      var end = index + 1
      while end < lines.count {
        let candidate = lines[end]
        let trimmed = candidate.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, !trimmed.hasPrefix("#"), indentation(of: candidate) <= proxiesIndent { break }
        end += 1
      }

      let listRange = (index + 1)..<end
      if let selectedIndex = listRange.first(where: { line in
        let item = lines[line].trimmingCharacters(in: .whitespaces)
        guard item.hasPrefix("- ") else { return false }
        return unquote(String(item.dropFirst(2)).trimmingCharacters(in: .whitespaces)) == selectedName
      }), let firstIndex = listRange.first(where: {
        lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("- ")
      }), selectedIndex != firstIndex {
        let selectedLine = lines.remove(at: selectedIndex)
        lines.insert(selectedLine, at: firstIndex)
      }
      index = end
    }
    return lines.joined(separator: "\n")
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
}

struct TVNodeSelectorView: View {
  let nodes: [TVProxyNode]
  let selectedName: String?
  let isLoading: Bool
  let errorMessage: String?
  let onClose: () -> Void
  let onRefresh: () -> Void
  let onSelect: (TVProxyNode) -> Void

  private let columns = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]

  var body: some View {
    ZStack {
      TVTheme.background.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 28) {
        HStack {
          TVFocusButton(cornerRadius: 18, action: onClose) { focused in
            Image(systemName: "chevron.left")
              .font(.system(size: 24, weight: .bold))
              .frame(width: 58, height: 58)
              .background(focused ? TVTheme.primary.opacity(0.45) : TVTheme.surfaceStrong)
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          VStack(alignment: .leading, spacing: 6) {
            Text("选择线路").font(.system(size: 38, weight: .bold))
            Text("使用方向键选择节点，按 Return 确认").font(.system(size: 18)).foregroundStyle(TVTheme.textSecondary)
          }
          Spacer()
          TVFocusButton(cornerRadius: 18, action: onRefresh) { focused in
            Label("刷新", systemImage: "arrow.clockwise")
              .font(.system(size: 18, weight: .semibold))
              .padding(.horizontal, 24)
              .frame(height: 58)
              .background(focused ? TVTheme.primary.opacity(0.45) : TVTheme.surfaceStrong)
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
        }

        if isLoading {
          Spacer()
          HStack { Spacer(); ProgressView("正在加载线路…").controlSize(.large); Spacer() }
          Spacer()
        } else if let errorMessage {
          Spacer()
          VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
            Text(errorMessage).font(.system(size: 20, weight: .medium))
          }
          .frame(maxWidth: .infinity)
          Spacer()
        } else {
          ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
              ForEach(Array(nodes.enumerated()), id: \.element.id) { offset, node in
                TVFocusButton(cornerRadius: 20, autofocus: selectedName == node.name || (selectedName == nil && offset == 0), action: {
                  onSelect(node)
                }) { focused in
                  HStack(spacing: 18) {
                    Image(systemName: "network").font(.system(size: 27, weight: .semibold)).foregroundStyle(TVTheme.primaryBright)
                    Text(node.name).font(.system(size: 20, weight: .semibold)).lineLimit(1)
                    Spacer()
                    if selectedName == node.name {
                      Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(TVTheme.success)
                    }
                  }
                  .padding(.horizontal, 22)
                  .frame(maxWidth: .infinity, minHeight: 82)
                  .background(focused ? TVTheme.primary.opacity(0.32) : TVTheme.surface)
                  .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
              }
            }
            .padding(3)
          }
        }
      }
      .padding(.horizontal, 78)
      .padding(.vertical, 58)
    }
    .onExitCommand(perform: onClose)
  }
}
