import SwiftUI

private enum TVRouteMode: String, CaseIterable {
  case rule
  case global

  var title: String { self == .rule ? "智能模式" : "全局模式" }
  var subtitle: String { self == .rule ? "按规则自动分流" : "全部流量走代理" }
  var icon: String { self == .rule ? "point.3.connected.trianglepath.dotted" : "globe.asia.australia.fill" }
}

struct TVHomeView: View {
  @EnvironmentObject private var session: SessionStore
  @State private var connected = false
  @State private var isConnecting = false
  @State private var routeMode: TVRouteMode = .rule
  @State private var errorMessage: String?
  @State private var showLogoutConfirmation = false
  @State private var showNodeSelector = false
  @State private var nodes: [TVProxyNode] = []
  @State private var selectedNodeName: String?
  @State private var isLoadingNodes = false
  @State private var nodeLoadError: String?
  @State private var cachedSubscription: String?
  @State private var notices: [TVNotice] = []
  @State private var noticeIndex = 0
  @State private var subscriptionSummary: TVSubscriptionSummary?
  @State private var isLoadingHomeInfo = false
  @State private var homeInfoError: String?
  @State private var showNoticeDetail = false

  private var simulatorPreview: Bool {
#if targetEnvironment(simulator)
    true
#else
    false
#endif
  }

  private var isDebugPreviewSession: Bool {
#if DEBUG
    session.token == "preview-token"
#else
    false
#endif
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.055, green: 0.16, blue: 0.29), TVTheme.background, Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      if showNodeSelector {
        TVNodeSelectorView(
          nodes: nodes,
          selectedName: selectedNodeName,
          isLoading: isLoadingNodes,
          errorMessage: nodeLoadError,
          onClose: { showNodeSelector = false },
          onRefresh: { Task { await loadNodes(forceRefresh: true) } },
          onSelect: {
            selectedNodeName = $0.name
            showNodeSelector = false
          }
        )
      } else {
        Circle()
          .fill(TVTheme.primary.opacity(0.13))
          .frame(width: 720, height: 720)
          .blur(radius: 100)
          .offset(x: -700, y: 390)

        VStack(spacing: 26) {
          header
          serviceBanner
          mainDashboard
        }
        .padding(.horizontal, 72)
        .padding(.vertical, 42)
      }
    }
    .alert("退出登录？", isPresented: $showLogoutConfirmation) {
      Button("取消", role: .cancel) {}
      Button("退出登录", role: .destructive) { session.signOut() }
    } message: {
      Text("退出后需要重新扫描二维码登录。")
    }
    .alert(currentNotice?.title ?? "公告", isPresented: $showNoticeDetail) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(currentNotice.map { plainText($0.content) } ?? "暂无公告内容")
    }
    .task {
#if DEBUG
      if ProcessInfo.processInfo.environment["FASTCAT_PREVIEW_NODES"] == "1" {
        showNodeSelector = true
        await loadNodes(forceRefresh: false)
      }
#endif
      await loadHomeInfo()
    }
    .task(id: notices.count) {
      guard notices.count > 1 else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard !Task.isCancelled else { return }
        await MainActor.run {
          withAnimation(.easeInOut(duration: 0.25)) {
            noticeIndex = (noticeIndex + 1) % notices.count
          }
        }
      }
    }
  }

  private var header: some View {
    HStack(spacing: 18) {
      ZStack {
        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TVTheme.primary)
        Image(systemName: "bolt.shield.fill").font(.system(size: 31, weight: .semibold))
      }
      .frame(width: 62, height: 62)

      VStack(alignment: .leading, spacing: 2) {
        Text("快猫").font(.system(size: 34, weight: .bold))
        Text("FastCat for Apple TV")
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(TVTheme.textSecondary)
      }

      Spacer()

      HStack(spacing: 10) {
        Circle().fill(connected ? TVTheme.success : Color.white.opacity(0.25)).frame(width: 10, height: 10)
        Text(connected ? "VPN 已连接" : simulatorPreview ? "模拟器预览" : "VPN 未连接")
          .font(.system(size: 18, weight: .semibold))
      }
      .padding(.horizontal, 20)
      .frame(height: 48)
      .background(TVTheme.surface)
      .clipShape(Capsule())
    }
  }

  private var serviceBanner: some View {
    HStack(spacing: 20) {
      announcementCard.frame(maxWidth: .infinity)
      subscriptionCard.frame(width: 690)
    }
    .frame(height: 142)
  }

  private var announcementCard: some View {
    TVFocusButton(cornerRadius: TVTheme.cardRadius, action: {
      if currentNotice != nil { showNoticeDetail = true }
    }) { focused in
      HStack(spacing: 22) {
        ZStack {
          Circle().fill(Color.orange.opacity(0.18))
          Image(systemName: "megaphone.fill")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(Color.orange)
        }
        .frame(width: 66, height: 66)

        VStack(alignment: .leading, spacing: 7) {
          HStack(spacing: 10) {
            Text("公告").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.orange)
            if notices.count > 1 {
              Text("\(noticeIndex + 1) / \(notices.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TVTheme.textSecondary)
            }
          }
          Text(currentNotice?.title ?? (isLoadingHomeInfo ? "正在获取最新公告…" : "暂无公告"))
            .font(.system(size: 23, weight: .bold))
            .lineLimit(1)
          Text(announcementSubtitle)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(TVTheme.textSecondary)
            .lineLimit(1)
        }
        Spacer(minLength: 10)
        Image(systemName: currentNotice == nil ? "bell.slash" : "chevron.right")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(focused ? TVTheme.focusRing : TVTheme.textSecondary)
      }
      .padding(.horizontal, 26)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(focused ? TVTheme.surfaceStrong : TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous)
          .stroke(TVTheme.stroke, lineWidth: 1)
      }
    }
    .accessibilityLabel("公告，\(currentNotice?.title ?? "暂无公告")")
  }

  private var subscriptionCard: some View {
    TVFocusButton(cornerRadius: TVTheme.cardRadius, action: {
      Task { await loadHomeInfo(forceRefresh: true) }
    }) { focused in
      HStack(spacing: 22) {
        ZStack {
          Circle().fill(TVTheme.primary.opacity(0.18))
          Image(systemName: "crown.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(TVTheme.primaryBright)
        }
        .frame(width: 66, height: 66)

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(subscriptionTitle).font(.system(size: 21, weight: .bold)).lineLimit(1)
            Spacer()
            Text(expirationText)
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(expirationColor)
          }
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule().fill(Color.white.opacity(0.10))
              Capsule().fill(TVTheme.primaryBright)
                .frame(width: proxy.size.width * (subscriptionSummary?.usageFraction ?? 0))
            }
          }
          .frame(height: 8)
          HStack {
            Text(usageText)
            Spacer()
            Text(remainingText)
          }
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(TVTheme.textSecondary)
        }
        if isLoadingHomeInfo {
          ProgressView().controlSize(.small)
        } else {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(focused ? TVTheme.focusRing : TVTheme.textSecondary)
        }
      }
      .padding(.horizontal, 26)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(focused ? TVTheme.surfaceStrong : TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous)
          .stroke(TVTheme.stroke, lineWidth: 1)
      }
    }
    .accessibilityLabel("套餐信息，\(subscriptionTitle)，\(remainingText)")
  }

  private var mainDashboard: some View {
    HStack(spacing: 28) {
      connectionPanel.frame(maxWidth: .infinity)
      controlsPanel.frame(maxWidth: .infinity)
    }
  }

  private var connectionPanel: some View {
    TVGlassCard {
      VStack(spacing: 16) {
        Spacer(minLength: 12)
        connectButton
        VStack(spacing: 6) {
          Text(isConnecting ? "正在连接" : connected ? "已安全连接" : "未连接")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(connected ? TVTheme.success : .white)
          Text(connectionDetail)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(errorMessage == nil ? TVTheme.textSecondary : Color.orange)
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
        Spacer(minLength: 10)
      }
      .padding(28)
      .frame(maxWidth: .infinity, minHeight: 500)
    }
  }

  private var connectButton: some View {
    TVFocusButton(cornerRadius: 150, autofocus: true, action: toggleConnection) { focused in
      ZStack {
        Circle().fill(connected ? TVTheme.primary : TVTheme.primary.opacity(focused ? 0.30 : 0.14))
        Circle()
          .stroke(connected ? TVTheme.primaryBright.opacity(0.72) : TVTheme.focusRing.opacity(focused ? 0.62 : 0.20), lineWidth: 6)
          .padding(14)
        Circle().stroke(TVTheme.focusRing.opacity(focused ? 0.34 : 0.10), lineWidth: 2).padding(34)
        if isConnecting {
          ProgressView().controlSize(.large).tint(.white).scaleEffect(1.5)
        } else {
          Image(systemName: "power")
            .font(.system(size: 82, weight: .medium))
            .foregroundStyle(connected ? Color.white : TVTheme.primaryBright)
        }
      }
      .frame(width: 270, height: 270)
    }
    .buttonBorderShape(.circle)
    .disabled(isConnecting)
    .accessibilityLabel(connected ? "断开 VPN" : "连接 VPN")
  }

  private var connectionDetail: String {
    if let errorMessage { return errorMessage }
    if simulatorPreview { return "模拟器不支持 Packet Tunnel，仅供界面预览" }
    return connected ? "流量正在通过加密隧道传输" : "按遥控器确认键开始连接"
  }

  private var controlsPanel: some View {
    VStack(spacing: 20) {
      modeCard
      routeCard
      accountCard
    }
    .frame(minHeight: 500)
  }

  private var modeCard: some View {
    TVGlassCard {
      VStack(alignment: .leading, spacing: 18) {
        sectionTitle(icon: "arrow.triangle.branch", title: "代理模式", subtitle: "选择适合当前场景的路由策略")
        HStack(spacing: 14) {
          ForEach(TVRouteMode.allCases, id: \.self) { mode in
            TVFocusButton(cornerRadius: 18, action: { routeMode = mode }) { focused in
              HStack(spacing: 13) {
                Image(systemName: mode.icon).font(.system(size: 24, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                  Text(mode.title).font(.system(size: 19, weight: .bold))
                  Text(mode.subtitle).font(.system(size: 13, weight: .medium)).opacity(0.62)
                }
                Spacer()
                if routeMode == mode { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)) }
              }
              .foregroundStyle(routeMode == mode ? Color.white : Color.white.opacity(0.78))
              .padding(.horizontal, 18)
              .frame(maxWidth: .infinity, minHeight: 82)
              .background(routeMode == mode ? TVTheme.primary.opacity(focused ? 1 : 0.78) : TVTheme.surfaceStrong)
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
          }
        }
      }
      .padding(24)
    }
  }

  private var routeCard: some View {
    TVFocusButton(cornerRadius: TVTheme.cardRadius, action: presentNodeSelector) { focused in
      HStack(spacing: 18) {
        ZStack {
          Circle().fill(TVTheme.primary.opacity(0.18))
          Image(systemName: "network").font(.system(size: 30, weight: .semibold)).foregroundStyle(TVTheme.primaryBright)
        }
        .frame(width: 68, height: 68)
        VStack(alignment: .leading, spacing: 4) {
          Text("当前线路").font(.system(size: 15, weight: .medium)).foregroundStyle(TVTheme.textSecondary)
          Text(selectedNodeName ?? "自动选择 · 最优节点").font(.system(size: 23, weight: .bold)).lineLimit(1)
          Text("按 Return 选择订阅线路").font(.system(size: 14)).foregroundStyle(TVTheme.textSecondary)
        }
        Spacer()
        if isLoadingNodes {
          ProgressView().controlSize(.small)
        } else {
          Image(systemName: focused ? "chevron.right.circle.fill" : "chevron.right.circle")
            .font(.system(size: 28)).foregroundStyle(focused ? TVTheme.focusRing : TVTheme.success)
        }
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: .infinity, minHeight: 118)
      .background(focused ? TVTheme.surfaceStrong : TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
    }
  }

  private var accountCard: some View {
    HStack(spacing: 18) {
      TVGlassCard {
        HStack(spacing: 16) {
          Image(systemName: "person.crop.circle.fill").font(.system(size: 42)).foregroundStyle(TVTheme.primaryBright)
          VStack(alignment: .leading, spacing: 3) {
            Text("当前账户").font(.system(size: 14)).foregroundStyle(TVTheme.textSecondary)
            Text(session.email ?? "已登录账户").font(.system(size: 18, weight: .semibold)).lineLimit(1)
          }
          Spacer()
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: 104)
      }

      TVFocusButton(cornerRadius: 22, action: { showLogoutConfirmation = true }) { focused in
        VStack(spacing: 8) {
          Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 27, weight: .semibold))
          Text("退出登录").font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(focused ? Color.white : Color.white.opacity(0.72))
        .frame(width: 142, height: 104)
        .background(focused ? Color.red.opacity(0.72) : TVTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      }
    }
  }

  private func sectionTitle(icon: String, title: String, subtitle: String) -> some View {
    HStack(spacing: 13) {
      Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(TVTheme.primaryBright)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 21, weight: .bold))
        Text(subtitle).font(.system(size: 14)).foregroundStyle(TVTheme.textSecondary)
      }
    }
  }

  private var currentNotice: TVNotice? {
    guard !notices.isEmpty else { return nil }
    return notices[min(noticeIndex, notices.count - 1)]
  }

  private var announcementSubtitle: String {
    if let notice = currentNotice {
      let text = plainText(notice.content)
      return text.isEmpty ? "按确认键查看公告详情" : text
    }
    return homeInfoError ?? "暂时没有新的服务公告"
  }

  private var subscriptionTitle: String {
    guard let summary = subscriptionSummary else {
      return isLoadingHomeInfo ? "正在获取套餐信息…" : "套餐信息暂不可用"
    }
    if let name = summary.planName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
      return name
    }
    if let id = summary.planID { return "当前套餐 · #\(id)" }
    return "当前套餐"
  }

  private var usageText: String {
    guard let summary = subscriptionSummary else { return "已用 --" }
    return "已用 \(formatBytes(summary.usedBytes)) / \(formatBytes(summary.transferLimit))"
  }

  private var remainingText: String {
    guard let summary = subscriptionSummary else { return "剩余 --" }
    return "剩余 \(formatBytes(summary.remainingBytes))"
  }

  private var expirationDate: Date? {
    guard let raw = subscriptionSummary?.expiredAt, raw > 0 else { return nil }
    let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
    return Date(timeIntervalSince1970: seconds)
  }

  private var expirationText: String {
    guard let date = expirationDate else { return "长期有效" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd 到期"
    return formatter.string(from: date)
  }

  private var expirationColor: Color {
    guard let date = expirationDate else { return TVTheme.success }
    return date.timeIntervalSinceNow < 7 * 86_400 ? Color.orange : TVTheme.success
  }

  private func plainText(_ source: String) -> String {
    let withoutTags = source.replacingOccurrences(
      of: "<[^>]+>", with: " ", options: .regularExpression
    )
    let decoded = withoutTags
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
    return decoded
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func formatBytes(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 GB" }
    let value = Double(bytes)
    let units: [(Double, String)] = [
      (1_099_511_627_776, "TB"),
      (1_073_741_824, "GB"),
      (1_048_576, "MB"),
      (1_024, "KB")
    ]
    for (divisor, unit) in units where value >= divisor {
      let amount = value / divisor
      return String(format: amount >= 100 ? "%.0f %@" : "%.1f %@", amount, unit)
    }
    return "\(bytes) B"
  }

  @MainActor
  private func loadHomeInfo(forceRefresh: Bool = false) async {
    if isDebugPreviewSession {
      notices = [
        TVNotice(id: 1, title: "欢迎使用快猫 Apple TV", content: "订阅公告会在这里自动轮播，按确认键可查看完整内容。"),
        TVNotice(id: 2, title: "线路维护通知", content: "部分线路将在凌晨进行短时维护，请优先选择自动线路。")
      ]
      subscriptionSummary = TVSubscriptionSummary(
        planID: 3,
        planName: "高速影音套餐",
        uploadedBytes: 4_800_000_000,
        downloadedBytes: 21_600_000_000,
        transferLimit: 107_374_182_400,
        expiredAt: Date().addingTimeInterval(32 * 86_400).timeIntervalSince1970
      )
      homeInfoError = nil
      return
    }
    if !forceRefresh, subscriptionSummary != nil || !notices.isEmpty { return }
    guard let token = session.token else {
      homeInfoError = "登录状态已失效，请重新登录"
      return
    }
    isLoadingHomeInfo = true
    homeInfoError = nil
    defer { isLoadingHomeInfo = false }
    do {
      let client = try await GatewayClient.configured()
      async let fetchedNotices = try? client.fetchNotices(token: token)
      async let fetchedSummary = try? client.fetchSubscriptionSummary(token: token)
      let (newNotices, newSummary) = await (fetchedNotices, fetchedSummary)
      if let newNotices {
        notices = newNotices
        noticeIndex = 0
      }
      if let newSummary {
        subscriptionSummary = newSummary
      }
      if newNotices == nil, newSummary == nil {
        homeInfoError = "公告与套餐信息暂时无法获取"
      }
    } catch {
      homeInfoError = error.localizedDescription
    }
  }

  private func toggleConnection() {
    guard !isConnecting else { return }
    errorMessage = nil
    if simulatorPreview {
      errorMessage = "模拟器不支持 VPN，请使用 Apple TV 真机测试"
      return
    }
    if connected {
      isConnecting = true
      VPNManager.shared.disconnect { _ in
        Task { @MainActor in connected = false; isConnecting = false }
      }
      return
    }
    guard let token = session.token else { return }
    isConnecting = true
    Task {
      do {
        let downloaded: String
        if let cachedSubscription {
          downloaded = cachedSubscription
        } else {
          let client = try await GatewayClient.configured()
          downloaded = try await client.downloadSubscription(token: token)
          cachedSubscription = downloaded
        }
        let selectedConfig = TVSubscriptionNodes.prioritizing(selectedNodeName, in: downloaded)
        let config = applyingRouteMode(to: selectedConfig)
        VPNManager.shared.connect(config: config) { error in
          Task { @MainActor in
            isConnecting = false
            connected = error == nil
            errorMessage = error
          }
        }
      } catch {
        isConnecting = false
        errorMessage = error.localizedDescription
      }
    }
  }

  private func presentNodeSelector() {
    showNodeSelector = true
    Task { await loadNodes(forceRefresh: false) }
  }

  @MainActor
  private func loadNodes(forceRefresh: Bool) async {
    if isDebugPreviewSession {
      nodes = ["香港 · 高速 01", "香港 · 高速 02", "日本 · 东京", "新加坡 · 优选", "美国 · 洛杉矶", "自动选择"]
        .map(TVProxyNode.init)
      nodeLoadError = nil
      return
    }
    if !forceRefresh, !nodes.isEmpty { return }
    guard let token = session.token else {
      nodeLoadError = "登录状态已失效，请重新登录"
      return
    }
    isLoadingNodes = true
    nodeLoadError = nil
    defer { isLoadingNodes = false }
    do {
      let client = try await GatewayClient.configured()
      let configuration = try await client.downloadSubscription(token: token)
      let parsed = TVSubscriptionNodes.parse(from: configuration)
      guard !parsed.isEmpty else {
        nodeLoadError = "订阅中没有可用线路"
        return
      }
      cachedSubscription = configuration
      nodes = parsed
      if let selectedNodeName, !parsed.contains(where: { $0.name == selectedNodeName }) {
        self.selectedNodeName = nil
      }
    } catch {
      nodeLoadError = error.localizedDescription
    }
  }

  private func applyingRouteMode(to config: String) -> String {
    let replacement = "mode: \(routeMode.rawValue)"
    guard let expression = try? NSRegularExpression(pattern: "(?m)^mode\\s*:\\s*.*$") else { return config }
    let range = NSRange(config.startIndex..<config.endIndex, in: config)
    if expression.firstMatch(in: config, range: range) != nil {
      return expression.stringByReplacingMatches(in: config, range: range, withTemplate: replacement)
    }
    return replacement + "\n" + config
  }
}
