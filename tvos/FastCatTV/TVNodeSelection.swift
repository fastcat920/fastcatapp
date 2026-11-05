import SwiftUI

struct TVNodeSelectorView: View {
  let nodes: [TVProxyNode]
  let selectedName: String?
  let routeMode: String
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
            title: tvText("更新节点", "Update nodes", language: language),
            icon: .refresh,
            loading: isRefreshing,
            disabled: isRefreshing || isTesting,
            action: onRefresh
          )
          nodeToolbarButton(
            title: tvText("测试延迟", "Test latency", language: language),
            icon: .networkCheck,
            loading: isTesting,
            disabled: isRefreshing || isTesting,
            action: onTest
          )
        }
        .frame(height: tv(56))

        if isLoading {
          Spacer()
          HStack { Spacer(); ProgressView(tvText("正在加载线路…", "Loading nodes…", language: language)).scaleEffect(1.3).font(TVFont.regular(14)); Spacer() }
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
            Text(tvText("暂无可用节点", "No available nodes", language: language)).font(TVFont.regular(14))
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
                        if selected { nodeTag(tvText("当前节点", "Current node", language: language), color: TVTheme.primary) }
                      }
                    }
                    Spacer()
                    if testingNodeNames.contains(node.name) {
                      ProgressView()
                        .scaleEffect(0.8)
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
            Text(overviewModeTitle).font(TVFont.medium(14)).foregroundStyle(TVTheme.primary)
          }
          Text(overviewModeDescription)
            .font(TVFont.regular(12)).foregroundStyle(TVTheme.textSecondary).lineSpacing(tv(4.2))
        }
        Spacer()
      }
      .padding(tv(14))
    }
  }

  private var overviewModeTitle: String {
    routeMode == "global"
      ? tvText("全局代理", "Global Proxy", language: language)
      : tvText("智能分流", "Smart Routing", language: language)
  }

  private var overviewModeDescription: String {
    routeMode == "global"
      ? tvText(
        "全球网络均通过代理进行访问（建议特殊网址无法访问时使用）",
        "Route all network traffic through the proxy (recommended when specific sites are inaccessible)",
        language: language
      )
      : tvText(
        "智能区分目标网络地区实现加速（推荐使用）",
        "Intelligently route traffic by destination region for acceleration (recommended)",
        language: language
      )
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
          ProgressView().scaleEffect(0.8).tint(TVTheme.primary).frame(width: tv(18), height: tv(18))
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
