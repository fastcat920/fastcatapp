import SwiftUI

private enum TVRouteMode: String, CaseIterable {
  case rule
  case global

  var title: String { self == .rule ? "智能分流" : "全局代理" }
  var subtitle: String { self == .rule ? "按规则自动分流" : "全部流量走代理" }
  var icon: String { self == .rule ? "point.3.connected.trianglepath.dotted" : "globe.asia.australia.fill" }
}

struct TVHomeView: View {
  @EnvironmentObject private var session: SessionStore
  @State private var connected = false
  @State private var isConnecting = false
  @State private var routeMode: TVRouteMode = .rule
  @AppStorage(TVTheme.preferenceKey) private var prefersDarkTheme = true
  @AppStorage("fastcat.tv.route-mode") private var savedRouteMode = TVRouteMode.rule.rawValue
  @AppStorage("fastcat.tv.selected-node") private var savedSelectedNode = ""
  @State private var errorMessage: String?
  @State private var showLogoutConfirmation = false
  @State private var isLoggingOut = false
  @State private var subscriptionBlockMessage: String?
  @State private var showNodeSelector = false
  @State private var nodes: [TVProxyNode] = []
  @State private var selectedNodeName: String?
  @State private var selectedGroupName: String?
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
      TVTheme.background.ignoresSafeArea()

      if showNodeSelector {
        TVNodeSelectorView(
          nodes: nodes,
          selectedName: selectedNodeName,
          isLoading: isLoadingNodes,
          errorMessage: nodeLoadError,
          onClose: { showNodeSelector = false },
          onRefresh: { Task { await loadNodes(forceRefresh: true) } },
          onSelect: { selectNode($0) }
        )
      } else {
        VStack(spacing: 20) {
          header
          serviceBanner
          mainDashboard
        }
        .padding(.horizontal, 72)
        .padding(.vertical, 32)
      }
    }
    .alert("退出登录？", isPresented: $showLogoutConfirmation) {
      Button("取消", role: .cancel) {}
      Button("退出登录", role: .destructive) { performLogout() }
    } message: {
      Text("确定要退出当前账户吗？退出后将断开 VPN，并需要重新登录。")
    }
    .alert("暂时无法连接", isPresented: Binding(
      get: { subscriptionBlockMessage != nil },
      set: { if !$0 { subscriptionBlockMessage = nil } }
    )) {
      Button("知道了", role: .cancel) { subscriptionBlockMessage = nil }
    } message: {
      Text(subscriptionBlockMessage ?? "请检查套餐状态后重试")
    }
    .alert(currentNotice?.title ?? "公告", isPresented: $showNoticeDetail) {
      Button("知道了", role: .cancel) {}
    } message: {
      Text(currentNotice.map { plainText($0.content) } ?? "暂无公告内容")
    }
    .task {
      routeMode = TVRouteMode(rawValue: savedRouteMode) ?? .rule
      selectedNodeName = savedSelectedNode.isEmpty ? nil : savedSelectedNode
      syncVPNStatus()
#if DEBUG
      if ProcessInfo.processInfo.environment["FASTCAT_PREVIEW_NODES"] == "1" {
        showNodeSelector = true
        await loadNodes(forceRefresh: false)
      }
#endif
      await loadHomeInfo()
    }
    .onReceive(NotificationCenter.default.publisher(for: VPNManager.statusDidChangeNotification)) { notification in
      syncVPNStatus(notification.object as? String)
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
        RoundedRectangle(cornerRadius: 13, style: .continuous).fill(TVTheme.primary)
        Image(systemName: "bolt.shield.fill")
          .font(.system(size: 25, weight: .semibold))
          .foregroundStyle(TVTheme.onPrimary)
      }
      .frame(width: 52, height: 52)

      Text("快猫")
        .font(.system(size: 30, weight: .bold))
        .foregroundStyle(TVTheme.textPrimary)

      Spacer()

      TVFocusButton(cornerRadius: 16, action: { prefersDarkTheme.toggle() }) { focused in
        HStack(spacing: 10) {
          Image(systemName: prefersDarkTheme ? "sun.max" : "moon")
          Text("切换主题")
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(TVTheme.primaryBright)
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(focused ? TVTheme.surfaceStrong : TVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    }
    .frame(height: 64)
  }

  private var serviceBanner: some View {
    Group {
      if connected {
        subscriptionCard
      } else {
        announcementCard
      }
    }
    .frame(maxWidth: .infinity)
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
              Capsule().fill(TVTheme.stroke)
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
    GeometryReader { geometry in
      let spacing: CGFloat = 24
      let availableWidth = max(0, geometry.size.width - spacing)
      HStack(spacing: spacing) {
        connectionPanel.frame(width: availableWidth * 5 / 11)
        controlsPanel.frame(width: availableWidth * 6 / 11)
      }
    }
    .frame(minHeight: 500)
  }

  private var connectionPanel: some View {
    TVGlassCard {
      VStack(spacing: 16) {
        Spacer(minLength: 12)
        connectButton
        VStack(spacing: 6) {
          Text(isConnecting ? "正在连接" : connected ? "已连接" : "未连接")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(connected ? TVTheme.success : TVTheme.textPrimary)
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
          ProgressView().controlSize(.large).tint(TVTheme.onPrimary).scaleEffect(1.5)
        } else {
          Image(systemName: "power")
            .font(.system(size: 82, weight: .medium))
            .foregroundStyle(connected ? TVTheme.onPrimary : TVTheme.primaryBright)
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
    VStack(spacing: 16) {
      modeCard
      routeCard
      accountCard
    }
    .frame(minHeight: 500)
  }

  private var modeCard: some View {
    TVGlassCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 10) {
          Image(systemName: "arrow.triangle.branch")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(TVTheme.primaryBright)
          Text("代理模式").font(.system(size: 20, weight: .bold))
        }
        HStack(spacing: 8) {
          ForEach(TVRouteMode.allCases, id: \.self) { mode in
            TVFocusButton(cornerRadius: 16, action: { changeRouteMode(to: mode) }) { focused in
              HStack(spacing: 10) {
                Image(systemName: mode.icon).font(.system(size: 20, weight: .semibold))
                Text(mode.title).font(.system(size: 18, weight: .bold))
                if routeMode == mode { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)) }
              }
              .foregroundStyle(routeMode == mode ? TVTheme.onPrimary : TVTheme.textPrimary)
              .padding(.horizontal, 18)
              .frame(maxWidth: .infinity, minHeight: 64)
              .background(routeMode == mode ? TVTheme.primary.opacity(focused ? 1 : 0.78) : TVTheme.surfaceStrong)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
          }
        }
      }
      .padding(22)
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
          Text("节点选择").font(.system(size: 15, weight: .medium)).foregroundStyle(TVTheme.textSecondary)
          Text(routeDisplayName).font(.system(size: 23, weight: .bold)).lineLimit(1)
          Text("按确认键选择订阅线路").font(.system(size: 14)).foregroundStyle(TVTheme.textSecondary)
        }
        Spacer()
        if let delay = selectedNodeDelay {
          Text("\(delay)ms")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(delay < 500 ? TVTheme.success : Color.orange)
        }
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
            Text("我的账号").font(.system(size: 14)).foregroundStyle(TVTheme.textSecondary)
            Text(session.email ?? "已登录账户").font(.system(size: 18, weight: .semibold)).lineLimit(1)
          }
          Spacer()
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: 104)
      }

      TVFocusButton(cornerRadius: 22, action: { if !isLoggingOut { showLogoutConfirmation = true } }) { focused in
        HStack(spacing: 10) {
          if isLoggingOut {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 23, weight: .semibold))
          }
          Text("退出登录").font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(focused ? TVTheme.onPrimary : TVTheme.danger)
        .frame(width: 172, height: 104)
        .background(focused ? TVTheme.danger : TVTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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

  private var routeDisplayName: String {
    if isLoadingNodes { return "正在加载线路…" }
    if let nodeLoadError, nodes.isEmpty { return nodeLoadError }
    return selectedNodeName ?? "自动选择 · 最优节点"
  }

  private var selectedNodeDelay: Int? {
    guard let selectedNodeName else { return nil }
    return nodes.first(where: { $0.name == selectedNodeName })?.delayMS
  }

  private var subscriptionBlockReason: String? {
    guard let summary = subscriptionSummary else { return nil }
    if let expiredAt = expirationDate, expiredAt <= Date() {
      return "当前套餐已过期，请续费后再连接"
    }
    if summary.transferLimit > 0, summary.remainingBytes <= 0 {
      return "当前套餐流量已用完，请恢复流量后再连接"
    }
    let hasPlanName = summary.planName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    if (summary.planID ?? 0) <= 0, !hasPlanName, summary.transferLimit <= 0 {
      return "当前账号暂无可用套餐"
    }
    return nil
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
      if handleExpiredSession(error) { return }
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
        Task { @MainActor in
          connected = false
          isConnecting = false
        }
      }
      return
    }
    Task { await prepareAndConnect() }
  }

  private func presentNodeSelector() {
    if let reason = subscriptionBlockReason {
      subscriptionBlockMessage = reason
      return
    }
    showNodeSelector = true
    Task { await loadNodes(forceRefresh: false) }
  }

  private func selectNode(_ node: TVProxyNode) {
    selectedNodeName = node.name
    savedSelectedNode = node.name
    showNodeSelector = false
    guard connected else { return }
    Task {
      if let failure = await applySelectedNodeIfNeeded() {
        await MainActor.run { errorMessage = "线路切换失败：\(failure)" }
      } else {
        await refreshLiveNodes()
      }
    }
  }

  private func changeRouteMode(to mode: TVRouteMode) {
    guard routeMode != mode else { return }
    let previous = routeMode
    routeMode = mode
    savedRouteMode = mode.rawValue
    selectedGroupName = nil
    guard connected else { return }

    VPNManager.shared.updateMode(mode.rawValue) { failure in
      Task { @MainActor in
        if let failure {
          routeMode = previous
          savedRouteMode = previous.rawValue
          errorMessage = "代理模式切换失败：\(failure)"
        } else {
          errorMessage = nil
          await refreshLiveNodes()
        }
      }
    }
  }

  private func syncVPNStatus(_ deliveredStatus: String? = nil) {
    if let deliveredStatus {
      connected = deliveredStatus == "connected"
      isConnecting = deliveredStatus == "connecting" || deliveredStatus == "disconnecting"
      if connected { Task { await refreshLiveNodes() } }
      return
    }
    VPNManager.shared.refreshStatus { status in
      Task { @MainActor in
        connected = status == "connected"
        isConnecting = status == "connecting" || status == "disconnecting"
        if connected { await refreshLiveNodes() }
      }
    }
  }

  private func performLogout() {
    guard !isLoggingOut else { return }
    isLoggingOut = true
    VPNManager.shared.disconnect { _ in
      Task { @MainActor in
        savedSelectedNode = ""
        savedRouteMode = TVRouteMode.rule.rawValue
        cachedSubscription = nil
        nodes = []
        selectedNodeName = nil
        selectedGroupName = nil
        connected = false
        isLoggingOut = false
        session.signOut()
      }
    }
  }

  @MainActor
  private func prepareAndConnect() async {
    guard let token = session.token else {
      errorMessage = "登录状态已失效，请重新登录"
      return
    }
    if subscriptionSummary == nil {
      await loadHomeInfo(forceRefresh: true)
    }
    if let reason = subscriptionBlockReason {
      subscriptionBlockMessage = reason
      return
    }

    isConnecting = true
    defer { isConnecting = false }
    do {
      let downloaded: String
      if let cachedSubscription {
        downloaded = cachedSubscription
      } else {
        let client = try await GatewayClient.configured()
        downloaded = try await client.downloadSubscription(token: token)
        cachedSubscription = downloaded
      }
      let config = applyingRouteMode(to: downloaded)
      if let failure = await connectVPN(config: config) {
        errorMessage = failure
        connected = false
        return
      }
      connected = true
      if let failure = await applySelectedNodeIfNeeded(retries: 6) {
        errorMessage = "VPN 已连接，但线路切换失败：\(failure)"
      } else {
        errorMessage = nil
      }
      await refreshLiveNodes(retries: 3)
    } catch {
      if handleExpiredSession(error) { return }
      connected = false
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func loadNodes(forceRefresh: Bool) async {
    if isDebugPreviewSession {
      nodes = ["香港 · 高速 01", "香港 · 高速 02", "日本 · 东京", "新加坡 · 优选", "美国 · 洛杉矶", "自动选择"]
        .map { TVProxyNode($0) }
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
      if connected, await refreshLiveNodes(), !nodes.isEmpty { return }
      let client = try await GatewayClient.configured()
      let configuration = try await client.downloadSubscription(token: token)
      let parsed = TVSubscriptionNodes.parse(from: configuration)
      guard !parsed.isEmpty else {
        nodeLoadError = "订阅中没有可用线路"
        return
      }
      cachedSubscription = configuration
      nodes = parsed
      selectedGroupName = TVSubscriptionNodes.preferredGroupName(
        from: configuration,
        mode: routeMode.rawValue
      )
      if let selectedNodeName, !parsed.contains(where: { $0.name == selectedNodeName }) {
        self.selectedNodeName = nil
        savedSelectedNode = ""
      }
    } catch {
      if handleExpiredSession(error) { return }
      nodeLoadError = error.localizedDescription
    }
  }

  @discardableResult
  @MainActor
  private func refreshLiveNodes(retries: Int = 1) async -> Bool {
    for attempt in 0..<max(1, retries) {
      if let response = await liveProxies(),
         let snapshot = TVSubscriptionNodes.liveSnapshot(from: response, mode: routeMode.rawValue),
         !snapshot.nodes.isEmpty {
        selectedGroupName = snapshot.groupName
        nodes = snapshot.nodes
        if let liveSelection = snapshot.selectedName,
           liveSelection != "DIRECT", liveSelection != "REJECT" {
          selectedNodeName = liveSelection
          savedSelectedNode = liveSelection
        }
        nodeLoadError = nil
        return true
      }
      if attempt + 1 < retries {
        try? await Task.sleep(for: .milliseconds(350))
      }
    }
    return false
  }

  private func applySelectedNodeIfNeeded(retries: Int = 1) async -> String? {
    guard let selectedNodeName, !selectedNodeName.isEmpty else { return nil }
    for attempt in 0..<max(1, retries) {
      if selectedGroupName == nil, let response = await liveProxies(),
         let snapshot = TVSubscriptionNodes.liveSnapshot(from: response, mode: routeMode.rawValue) {
        await MainActor.run { selectedGroupName = snapshot.groupName }
      }
      if let selectedGroupName {
        let failure = await changeProxy(groupName: selectedGroupName, proxyName: selectedNodeName)
        if failure == nil { return nil }
        if attempt + 1 == retries { return failure }
      }
      if attempt + 1 < retries {
        try? await Task.sleep(for: .milliseconds(350))
      }
    }
    return "未找到可切换的代理组"
  }

  private func connectVPN(config: String) async -> String? {
    await withCheckedContinuation { continuation in
      VPNManager.shared.connect(config: config) { continuation.resume(returning: $0) }
    }
  }

  private func liveProxies() async -> String? {
    await withCheckedContinuation { continuation in
      VPNManager.shared.getProxies { continuation.resume(returning: $0) }
    }
  }

  private func changeProxy(groupName: String, proxyName: String) async -> String? {
    await withCheckedContinuation { continuation in
      VPNManager.shared.changeProxy(groupName: groupName, proxyName: proxyName) {
        continuation.resume(returning: $0)
      }
    }
  }

  @MainActor
  private func handleExpiredSession(_ error: Error) -> Bool {
    guard case GatewayClient.GatewayError.unauthorized = error else { return false }
    VPNManager.shared.disconnect { _ in
      Task { @MainActor in session.signOut() }
    }
    return true
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
