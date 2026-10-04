import SwiftUI

private enum TVRouteMode: String, CaseIterable {
  case rule
  case global
}

private enum TVNewPeriodState {
  case confirmation, submitting, uncertain, failure, success
}

private struct NoticeContentHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

struct TVHomeView: View {
  @EnvironmentObject private var session: SessionStore
  @EnvironmentObject private var connectivity: TVServiceConnectivityMonitor
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.scenePhase) private var scenePhase
  @State private var connected = false
  @State private var isConnecting = false
  @State private var routeMode: TVRouteMode = .rule
  @AppStorage(TVTheme.preferenceKey) private var prefersDarkTheme = true
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @AppStorage("fastcat.tv.route-mode") private var savedRouteMode = TVRouteMode.rule.rawValue
  @AppStorage("fastcat.tv.selected-node") private var savedSelectedNode = ""
  @State private var errorMessage: String?
  @State private var showLogoutConfirmation = false
  @State private var isLoggingOut = false
  @State private var logoutProtectedAtOpen = false
  @State private var logoutForceConfirmation = false
  @State private var logoutError: String?
  @State private var showConnectivityDetail = false
  @State private var subscriptionBlockMessage: String?
  @State private var subscriptionActionError: String?
  @State private var newPeriodState: TVNewPeriodState?
  @State private var newPeriodError: String?
  @State private var newPeriodBaseline: TVSubscriptionSummary?
  @State private var newPeriodNeedsCheck = false
  @State private var showNodeSelector = false
  @State private var nodes: [TVProxyNode] = []
  @State private var selectedNodeName: String?
  @State private var selectedGroupName: String?
  @State private var isLoadingNodes = false
  @State private var isRefreshingNodes = false
  @State private var isTestingNodes = false
  @State private var testingNodeNames: Set<String> = []
  @State private var nodeLoadError: String?
  @State private var cachedSubscription: String?
  @State private var notices: [TVNotice] = []
  @State private var noticeIndex = 0
  @State private var subscriptionSummary: TVSubscriptionSummary?
  @State private var isLoadingHomeInfo = false
  @State private var isRefreshingSubscription = false
  @State private var homeInfoError: String?
  @State private var showNoticeDetail = false
  @State private var noticeLinkURL: URL?
  @State private var noticeContentHeight: CGFloat = 0
  @State private var hasAssignedInitialHomeFocus = false
  @FocusState private var connectButtonFocused: Bool
  @FocusState private var routeCardFocused: Bool
  @FocusState private var noticeActionFocused: Bool
  @FocusState private var logoutCancelFocused: Bool
  @FocusState private var messageActionFocused: Bool
  @FocusState private var newPeriodCancelFocused: Bool
  @FocusState private var connectivityCloseFocused: Bool

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

  private var homeCanvas: some View {
    TVDesignCanvas {
      GeometryReader { geometry in
        let bodyHeight = max(0, geometry.size.height - tv(64))
        let isShort = bodyHeight < tv(620)
        let topInfoHeight: CGFloat = isShort ? tv(124) : tv(148)
        let horizontalPadding: CGFloat = geometry.size.width >= tv(1400) ? tv(33) : tv(25)
        let mainHeight = max(0, bodyHeight - tv(19) - topInfoHeight - tv(16) - tv(23))

        ZStack {
          TVTheme.background

          Group {
            if showNodeSelector {
              TVNodeSelectorView(
                nodes: nodes,
                selectedName: selectedNodeName,
                routeMode: routeMode.rawValue,
                isLoading: isLoadingNodes,
                isRefreshing: isRefreshingNodes,
                isTesting: isTestingNodes,
                testingNodeNames: testingNodeNames,
                errorMessage: nodeLoadError,
                onClose: { showNodeSelector = false },
                onRefresh: { Task { await refreshNodesFromToolbar() } },
                onTest: { Task { await runLatencyTest() } },
                onSelect: { selectNode($0) }
              )
            } else {
              VStack(spacing: tv(0)) {
                header
                  .padding(.horizontal, tv(25))
                  .frame(height: tv(64))
                VStack(spacing: tv(16)) {
                  serviceBanner.frame(height: topInfoHeight)
                  mainDashboard(isShort: isShort).frame(height: mainHeight)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, tv(19))
                .padding(.bottom, tv(23))
              }
            }
          }
          .disabled(isModalPresented)
          .allowsHitTesting(!isModalPresented)

          if showNoticeDetail {
            noticeDialog
          } else if showLogoutConfirmation {
            logoutDialog
          } else if showConnectivityDetail {
            connectivityDialog
          } else if newPeriodState != nil {
            newPeriodDialog
          } else if let subscriptionBlockMessage {
            messageDialog(subscriptionBlockMessage)
          }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
    }
  }

  private var homeWithLifecycle: some View {
    homeCanvas
    .onAppear {
      guard !hasAssignedInitialHomeFocus else { return }
      hasAssignedInitialHomeFocus = true
      focusModalButton { connectButtonFocused = true }
    }
    .task(id: language) {
      routeMode = TVRouteMode(rawValue: savedRouteMode) ?? .rule
      selectedNodeName = savedSelectedNode.isEmpty ? nil : savedSelectedNode
      syncVPNStatus()
#if DEBUG
      if ProcessInfo.processInfo.environment["FASTCAT_PREVIEW_NODES"] == "1" {
        showNodeSelector = true
        await loadNodes(forceRefresh: false)
      }
#endif
      await loadHomeInfo(forceRefresh: true)
    }
    .onReceive(NotificationCenter.default.publisher(for: VPNManager.statusDidChangeNotification)) { notification in
      syncVPNStatus(notification.object as? String)
    }
    .onChange(of: connected) { _, _ in updateConnectivityProxy() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { syncVPNStatus() }
    }
    .onChange(of: selectedNodeName) { _, _ in updateConnectivityProxy() }
    .onChange(of: selectedGroupName) { _, _ in updateConnectivityProxy() }
    .onChange(of: showConnectivityDetail) { _, presented in
      if presented { focusModalButton { connectivityCloseFocused = true } }
      else { connectivityCloseFocused = false }
    }
    .onChange(of: logoutForceConfirmation) { _, _ in
      focusModalButton { logoutCancelFocused = true }
    }
  }

  var body: some View {
    homeWithLifecycle
    .onChange(of: showNodeSelector) { _, presented in
      if presented {
        connectButtonFocused = false
        routeCardFocused = false
      } else {
        focusModalButton {
          connectButtonFocused = false
          routeCardFocused = true
        }
      }
    }
    .onChange(of: showNoticeDetail) { _, presented in
      if presented {
        noticeContentHeight = 0
        noticeLinkURL = nil
        focusModalButton { noticeActionFocused = true }
      }
      else { noticeActionFocused = false }
    }
    .onChange(of: showLogoutConfirmation) { _, presented in
      if presented { focusModalButton { logoutCancelFocused = true } }
      else { logoutCancelFocused = false }
    }
    .onChange(of: subscriptionBlockMessage) { _, message in
      if message != nil {
        subscriptionActionError = nil
        focusModalButton { messageActionFocused = true }
      }
      else { messageActionFocused = false }
    }
    .onChange(of: newPeriodState) { _, state in
      if state != nil {
        messageActionFocused = false
        focusModalButton { newPeriodCancelFocused = true }
      } else {
        newPeriodCancelFocused = false
        if subscriptionBlockMessage != nil { focusModalButton { messageActionFocused = true } }
      }
    }
    .task(id: notices.count) {
      guard notices.count > 1 else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        guard !Task.isCancelled else { return }
        await MainActor.run {
          withAnimation(.easeOut(duration: 0.32)) {
            noticeIndex = (noticeIndex + 1) % notices.count
          }
        }
      }
    }
  }

  private var isModalPresented: Bool {
    showNoticeDetail || showLogoutConfirmation || showConnectivityDetail || subscriptionBlockMessage != nil || newPeriodState != nil
  }

  private func focusModalButton(_ action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: action)
  }

  private var header: some View {
    HStack(spacing: tv(9)) {
      TVBrandLogo()
        .frame(width: tv(30), height: tv(30))
        .clipShape(RoundedRectangle(cornerRadius: tv(8), style: .continuous))

      Text(tvText("快猫", "FastCat", language: language))
        .font(TVFont.medium(16))
        .foregroundStyle(TVTheme.textPrimary)

      if connectivity.state.showBadge {
        TVFocusButton(cornerRadius: tv(14), action: { showConnectivityDetail = true }) { _ in
          HStack(spacing: tv(5)) {
            MaterialIcon(glyph: connectivity.state.cause == .noNetwork ? .wifiOff : .networkCheck,
                         size: 14, color: TVTheme.warning)
            Text(connectivity.state.title(language: language))
              .font(TVFont.medium(11)).foregroundStyle(TVTheme.warning).lineLimit(1)
          }
          .padding(.horizontal, tv(10)).frame(height: tv(32))
          .background(TVTheme.warning.opacity(0.10))
          .clipShape(RoundedRectangle(cornerRadius: tv(14), style: .continuous))
        }
        .accessibilityLabel(connectivity.state.title(language: language))
      }

      Spacer()
      TVToolbarButton(
        title: tvText("切换主题", "Switch Theme", language: language),
        icon: prefersDarkTheme ? .lightModeOutlined : .darkModeOutlined,
        horizontalPadding: 18,
        cornerRadius: tv(14),
        height: 44,
        action: { prefersDarkTheme.toggle() }
      )
    }
  }

  private var serviceBanner: some View {
    Group {
      if connected {
        subscriptionCard
      } else {
        announcementCard
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var announcementCard: some View {
    TVFocusButton(cornerRadius: TVTheme.cardRadius, action: {
      if currentNotice != nil { showNoticeDetail = true }
    }) { _ in
      ZStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: tv(10)) {
          HStack(spacing: tv(8)) {
            ZStack {
              Circle().fill(TVTheme.primary.opacity(0.12))
              MaterialIcon(glyph: .campaignOutlined, size: 15, color: TVTheme.primary)
            }
            .frame(width: tv(24), height: tv(24))
            Text(currentNotice?.title ?? (isLoadingHomeInfo ? tvText("正在获取最新公告…", "Loading notices…", language: language) : tvText("暂无公告", "No notices", language: language)))
              .font(TVFont.medium(14))
              .foregroundStyle(TVTheme.textPrimary)
              .lineLimit(1)
            Spacer()
            if let date = noticeDateText {
              Text(date).font(TVFont.medium(12)).foregroundStyle(TVTheme.textSecondary)
            } else if isLoadingHomeInfo {
              ProgressView().scaleEffect(0.8).tint(TVTheme.primary)
            }
          }
          Text(announcementSubtitle)
            .font(TVFont.regular(12))
            .foregroundStyle(TVTheme.textSecondary)
            .lineSpacing(tv(5.4))
            .lineLimit(3)
        }
        .padding(.horizontal, tv(16))
        .padding(.vertical, tv(12))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        if notices.count > 1 {
          HStack(spacing: tv(6)) {
            ForEach(notices.indices, id: \.self) { index in
              Capsule()
                .fill(index == noticeIndex ? TVTheme.primary : TVTheme.outline.opacity(0.28))
                .frame(width: index == noticeIndex ? tv(18) : tv(6), height: tv(6))
            }
          }
          .padding(.bottom, tv(8))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous)
          .stroke(TVTheme.stroke, lineWidth: tv(1))
      }
    }
    .frame(maxHeight: .infinity)
    .shadow(color: prefersDarkTheme ? .clear : .black.opacity(0.08), radius: tv(16), y: tv(4))
    .accessibilityLabel(tvText("公告", "Notice", language: language) + ", " + (currentNotice?.title ?? tvText("暂无公告", "No notices", language: language)))
  }

  private var subscriptionCard: some View {
    let progress = min(1, max(0, subscriptionSummary?.usageFraction ?? 0))
    let progressColor = progress >= 1 ? TVTheme.danger : progress >= 0.9 ? TVTheme.warning : TVTheme.primary
    return TVFocusButton(cornerRadius: TVTheme.cardRadius, action: {
      if !isRefreshingSubscription {
        Task { await refreshSubscriptionSummary() }
      }
    }) { _ in
      VStack(alignment: .leading, spacing: tv(0)) {
        HStack(spacing: tv(8)) {
          Text(subscriptionTitle).font(TVFont.medium(14)).lineLimit(1)
          Spacer()
          if isRefreshingSubscription {
            ProgressView().scaleEffect(0.8).tint(TVTheme.primary)
          }
        }
        if expirationDate != nil {
          Spacer().frame(height: tv(5))
          Text(exactExpirationText)
            .font(TVFont.regular(12))
            .foregroundStyle(expirationColor)
            .lineLimit(1)
        }
        Spacer().frame(height: tv(12))
        HStack(spacing: tv(8)) {
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule().fill(TVTheme.surfaceHighest.opacity(0.60))
              Capsule().fill(progressColor).frame(width: proxy.size.width * progress)
            }
          }
          .frame(height: tv(6))
          Text(progressPercentText)
            .font(TVFont.medium(12))
            .foregroundStyle(progressColor)
        }
        Spacer().frame(height: tv(6))
        Text(exactUsageText)
          .font(TVFont.medium(12))
          .foregroundStyle(progress >= 0.9 ? progressColor : TVTheme.textPrimary)
      }
      .padding(.leading, tv(16)).padding(.trailing, tv(16)).padding(.top, tv(14)).padding(.bottom, tv(16))
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
      .overlay { RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous).strokeBorder(TVTheme.stroke, lineWidth: tv(1)) }
    }
    .shadow(color: prefersDarkTheme ? .clear : .black.opacity(0.08), radius: tv(16), y: tv(4))
    .frame(maxHeight: .infinity)
    .accessibilityLabel(tvText("套餐信息", "Plan information", language: language) + ", " + subscriptionTitle + ", " + remainingText)
  }

  private func mainDashboard(isShort: Bool) -> some View {
    GeometryReader { geometry in
      let spacing: CGFloat = tv(18)
      let availableWidth = max(0, geometry.size.width - spacing)
      HStack(spacing: spacing) {
        connectionPanel(connectButtonSize: isShort ? tv(150) : tv(188))
          .frame(width: availableWidth * 5 / 11)
        controlsPanel(isShort: isShort)
          .frame(width: availableWidth * 6 / 11)
      }
    }
  }

  private func connectionPanel(connectButtonSize: CGFloat) -> some View {
    TVGlassCard {
      VStack(spacing: tv(0)) {
        ZStack {
          connectButton(size: connectButtonSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        Spacer().frame(height: tv(6))
        Text(isConnecting ? tvText("正在连接", "Connecting", language: language) : connected ? tvText("已连接", "Connected", language: language) : tvText("未连接", "Disconnected", language: language))
          .font(TVFont.medium(14))
          .foregroundStyle(connected ? TVTheme.success : TVTheme.textPrimary)
          .frame(height: tv(40))
      }
      .padding(.horizontal, tv(24))
      .padding(.vertical, tv(18))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func connectButton(size: CGFloat) -> some View {
    let middleSize = size * 0.89
    let innerSize = size * 0.75
    let iconSize = size * 0.34 * 0.75
    let labelSize = min(max(size * 0.07, 9), 12)
    return TVFocusButton(cornerRadius: size / 2, focus: $connectButtonFocused, action: toggleConnection) { _ in
      ZStack {
        Circle().fill(connected ? TVTheme.primary.opacity(0.10) : .clear)
        Circle().fill(connected ? TVTheme.primary.opacity(0.10) : .clear)
          .frame(width: middleSize, height: middleSize)
        Circle()
          .fill(connected ? TVTheme.primary : (prefersDarkTheme ? Color(red: 58/255, green: 58/255, blue: 58/255) : Color(red: 240/255, green: 244/255, blue: 248/255)))
          .frame(width: innerSize, height: innerSize)
          .shadow(color: connected ? TVTheme.primary.opacity(prefersDarkTheme ? 0.36 : 0.30) : Color.black.opacity(prefersDarkTheme ? 0.30 : 0.10), radius: connected ? tv(18) : tv(12), y: tv(4))
        if isConnecting {
          VStack(spacing: tv(5)) {
            ProgressView().scaleEffect(0.8).tint(connected ? TVTheme.onPrimary : TVTheme.primary)
            Text(tvText("正在连接", "Connecting", language: language)).font(TVFont.regular(labelSize))
          }
          .foregroundStyle(connected ? TVTheme.onPrimary : TVTheme.primary)
        } else {
          VStack(spacing: tv(4)) {
            MaterialIcon(glyph: .powerSettingsNew, size: iconSize, color: connected ? TVTheme.onPrimary : (prefersDarkTheme ? TVTheme.primary : Color(red: 69/255, green: 90/255, blue: 100/255)))
            Text(connected ? tvText("已连接", "Connected", language: language) : tvText("点击连接", "Tap to connect", language: language))
              .font(TVFont.regular(labelSize))
              .foregroundStyle(connected ? TVTheme.onPrimary : (prefersDarkTheme ? TVTheme.primary : Color(red: 69/255, green: 90/255, blue: 100/255)))
          }
        }
      }
      .frame(width: size, height: size)
    }
    .buttonBorderShape(.circle)
    // Keep remote focus while busy; toggleConnection rejects repeat activation.
    .accessibilityLabel(connected ? tvText("断开 VPN", "Disconnect VPN", language: language) : tvText("连接 VPN", "Connect VPN", language: language))
  }

  private var connectionDetail: String {
    if let errorMessage { return errorMessage }
    if simulatorPreview { return tvText("模拟器不支持 Packet Tunnel，仅供界面预览", "Packet Tunnel requires a real Apple TV", language: language) }
    return connected
      ? tvText("流量正在通过加密隧道传输", "Traffic is protected by the encrypted tunnel", language: language)
      : tvText("按遥控器确认键开始连接", "Press Select to connect", language: language)
  }

  private func controlsPanel(isShort: Bool) -> some View {
    let modeHeight: CGFloat = isShort ? tv(96) : tv(116)
    let nodeHeight: CGFloat = isShort ? tv(62) : tv(72)
    let accountHeight: CGFloat = isShort ? tv(70) : tv(82)
    return VStack(spacing: tv(0)) {
      modeCard.frame(height: modeHeight)
      Spacer(minLength: tv(10))
      routeCard.frame(height: nodeHeight)
      Spacer(minLength: tv(10))
      accountCard.frame(height: accountHeight)
      Spacer(minLength: tv(10))
      Text(tvText("当前版本：V\(appVersion)", "Current version: V\(appVersion)", language: language))
        .font(TVFont.regular(12))
        .foregroundStyle(TVTheme.textSecondary.opacity(0.72))
        .frame(maxWidth: .infinity, minHeight: tv(20), maxHeight: tv(20))
    }
    .frame(maxHeight: .infinity)
  }

  private var modeCard: some View {
    TVGlassCard {
      VStack(alignment: .leading, spacing: tv(8)) {
        HStack(spacing: tv(9)) {
          MaterialIcon(glyph: .altRoute, size: 20, color: TVTheme.primary)
          Text(tvText("代理模式", "Proxy Mode", language: language)).font(TVFont.medium(14))
        }
        HStack(spacing: tv(0)) {
          ForEach(TVRouteMode.allCases, id: \.self) { mode in
            TVFocusButton(cornerRadius: tv(16), action: { changeRouteMode(to: mode) }) { _ in
              Text(mode == .rule ? tvText("智能分流", "Smart routing", language: language) : tvText("全局代理", "Global proxy", language: language))
                .font(TVFont.medium(13))
                .foregroundStyle(routeMode == mode ? TVTheme.textPrimary : TVTheme.textPrimary.opacity(0.45))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(routeMode == mode ? (prefersDarkTheme ? TVTheme.surfaceHighest : Color.white) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: tv(16), style: .continuous))
                .shadow(color: routeMode == mode && !prefersDarkTheme ? .black.opacity(15/255) : .clear, radius: tv(6), y: tv(2))
            }
          }
        }
        .padding(tv(3))
        .frame(height: tv(44))
        .background(TVTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: tv(19), style: .continuous))
      }
      .padding(.leading, tv(18)).padding(.trailing, tv(18)).padding(.top, tv(12)).padding(.bottom, tv(10))
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
  }

  private var routeCard: some View {
    TVFocusButton(cornerRadius: TVTheme.cardRadius, focus: $routeCardFocused, action: presentNodeSelector) { _ in
      HStack(spacing: tv(12)) {
        ZStack {
          Circle().fill(TVTheme.primary.opacity(0.14))
          MaterialIcon(glyph: .language, size: 20, color: TVTheme.primary)
        }
        .frame(width: tv(40), height: tv(40))
        VStack(alignment: .leading, spacing: tv(2)) {
          Text(tvText("节点选择", "Node Selection", language: language)).font(TVFont.regular(12)).foregroundStyle(TVTheme.textSecondary)
          Text(routeDisplayName).font(TVFont.medium(14)).foregroundStyle(TVTheme.primary).lineLimit(1)
        }
        Spacer()
        if let delay = selectedNodeDelay {
          Text("\(delay)ms")
            .font(TVFont.medium(11))
            .foregroundStyle(delay < 500 ? TVTheme.success : TVTheme.warning)
        }
        if isLoadingNodes {
          ProgressView().scaleEffect(0.8)
        } else {
          MaterialIcon(glyph: .chevronRight, size: 22, color: TVTheme.textSecondary)
        }
      }
      .padding(.horizontal, tv(16))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous)
          .strokeBorder(TVTheme.stroke, lineWidth: tv(1))
      }
    }
    .shadow(color: prefersDarkTheme ? .clear : .black.opacity(0.08), radius: tv(14), y: tv(4))
  }

  private var accountCard: some View {
    TVFocusButton(cornerRadius: TVTheme.cardRadius, action: {
      if !isLoggingOut {
        logoutProtectedAtOpen = connectivity.state.protectsLogout
        logoutForceConfirmation = false
        logoutError = nil
        showLogoutConfirmation = true
      }
    }) { _ in
      HStack(spacing: tv(13)) {
        ZStack {
          Circle().fill(TVTheme.primary.opacity(0.14))
          MaterialIcon(glyph: .personOutline, size: 24, color: TVTheme.primary)
        }
        .frame(width: tv(44), height: tv(44))
        VStack(alignment: .leading, spacing: tv(2)) {
          Text(tvText("我的账号", "My Account", language: language))
            .font(TVFont.regular(12))
            .foregroundStyle(TVTheme.textSecondary)
          Text(session.email ?? tvText("已登录账户", "Signed-in account", language: language))
            .font(TVFont.medium(14))
            .lineLimit(1)
        }
        Spacer(minLength: tv(16))
        Rectangle()
          .fill(TVTheme.stroke)
          .frame(width: tv(1), height: tv(32))
        HStack(spacing: tv(8)) {
          if isLoggingOut {
            ProgressView().scaleEffect(0.8)
          } else {
            MaterialIcon(glyph: .logoutOutlined, size: 18, color: TVTheme.textSecondary)
          }
          Text(tvText("退出登录", "Sign out", language: language)).font(TVFont.regular(14))
        }
        .foregroundStyle(TVTheme.textSecondary)
      }
      .padding(.horizontal, tv(18))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous)
          .strokeBorder(TVTheme.stroke, lineWidth: tv(1))
      }
    }
    .shadow(color: prefersDarkTheme ? .clear : .black.opacity(0.08), radius: tv(14), y: tv(4))
    .disabled(isLoggingOut)
  }

  private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.6.0"
  }

  private var noticeDialog: some View {
    ZStack {
      Color.black.opacity(0.54).ignoresSafeArea()
      VStack(spacing: tv(0)) {
        HStack {
          Text(currentNotice?.title ?? tvText("公告", "Notice", language: language))
            .font(TVFont.medium(16))
            .foregroundStyle(TVTheme.textPrimary)
            .lineLimit(2)
          Spacer()
        }
        .padding(.horizontal, tv(16))
        .padding(.vertical, tv(16))
        .background(colorScheme == .dark ? TVTheme.surfaceStrong : TVTheme.surface)

        Rectangle().fill(TVTheme.outline.opacity(colorScheme == .dark ? 0.20 : 0.10)).frame(height: tv(1))

        ScrollView {
          VStack(alignment: .leading, spacing: tv(12)) {
            if let date = noticeDateText {
              Text(date)
                .font(TVFont.regular(12))
                .foregroundStyle(TVTheme.textPrimary.opacity(0.50))
            }
            if let noticeLinkURL {
              TVQRCodeView(payload: noticeLinkURL.absoluteString)
                .frame(width: tv(180), height: tv(180))
                .padding(tv(12)).background(.white)
                .frame(maxWidth: .infinity)
              Text(tvText("使用手机扫描二维码打开链接", "Scan with your phone to open the link", language: language))
                .font(TVFont.regular(14)).foregroundStyle(TVTheme.textSecondary)
              Text(noticeLinkURL.host ?? "")
                .font(TVFont.regular(12)).foregroundStyle(TVTheme.textSecondary)
            } else {
            Text(noticeRichText(currentNotice?.content ?? tvText("暂无公告内容", "No notice content", language: language)))
              .font(TVFont.regular(14))
              .foregroundStyle(TVTheme.textSecondary)
              .lineSpacing(tv(5.6))
              .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(noticeLinks, id: \.url) { link in
              TVFocusButton(cornerRadius: tv(12), action: {
                noticeLinkURL = link.url
                noticeContentHeight = 0
                focusModalButton { noticeActionFocused = true }
              }) { _ in
                Text(link.title).font(TVFont.regular(14))
                  .foregroundStyle(TVTheme.primary).padding(tv(10))
              }
            }
            }
          }
          .padding(tv(20))
          .background {
            GeometryReader { proxy in
              Color.clear.preference(
                key: NoticeContentHeightPreferenceKey.self,
                value: proxy.size.height
              )
            }
          }
        }
        .frame(height: min(max(noticeContentHeight, tv(1)), tv(360)))
        .onPreferenceChange(NoticeContentHeightPreferenceKey.self) { height in
          noticeContentHeight = height
        }

        Rectangle().fill(TVTheme.outline.opacity(0.12)).frame(height: tv(1))

        HStack {
          Spacer()
          TVFocusButton(cornerRadius: tv(12), autofocus: true, focus: $noticeActionFocused, action: {
            if noticeLinkURL != nil { noticeLinkURL = nil; noticeContentHeight = 0 }
            else { showNoticeDetail = false }
          }) { _ in
            Text(noticeLinkURL == nil ? tvText("知道了", "Got it", language: language) : tvText("返回", "Back", language: language))
              .font(TVFont.regular(14))
              .foregroundStyle(TVTheme.onPrimary)
              .padding(.horizontal, tv(24))
              .frame(height: tv(44))
              .background(TVTheme.primary)
              .clipShape(RoundedRectangle(cornerRadius: tv(12), style: .continuous))
          }
        }
        .padding(.leading, tv(16))
        .padding(.trailing, tv(16))
        .padding(.top, tv(12))
        .padding(.bottom, tv(16))
        .background(colorScheme == .dark ? TVTheme.surfaceStrong : TVTheme.surface)
      }
      .frame(width: tv(560))
      .background(colorScheme == .dark ? TVTheme.surfaceHighest : TVTheme.surface)
      .clipShape(RoundedRectangle(cornerRadius: tv(24), style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: tv(24), style: .continuous)
          .strokeBorder(TVTheme.outline.opacity(colorScheme == .dark ? 0.30 : 0.10), lineWidth: colorScheme == .dark ? tv(1.5) : tv(1))
      }
      .shadow(color: .black.opacity(colorScheme == .dark ? 0.50 : 0.10), radius: colorScheme == .dark ? tv(30) : tv(20), y: tv(10))
      .shadow(color: TVTheme.primary.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: tv(40), y: tv(5))
    }
    .transition(.opacity)
  }

  private var logoutDialog: some View {
    TVDialog(
      title: logoutForceConfirmation
        ? tvText("确认强制退出", "Confirm forced sign out", language: language)
        : logoutProtectedAtOpen
          ? tvText("登录保护已开启", "Sign-in protection enabled", language: language)
          : tvText("确认退出", "Confirm sign out", language: language),
      icon: nil
    ) {
      VStack(alignment: .leading, spacing: tv(10)) {
        Text(logoutForceConfirmation
          ? tvText("强制退出会清除本地登录状态和节点缓存，服务恢复前可能无法再次登录。确定继续吗？", "Forced sign out clears local sign-in state and cached nodes. You may not be able to sign in again until the service recovers. Continue?", language: language)
          : logoutProtectedAtOpen
            ? tvText("当前服务连接异常，退出后可能暂时无法重新登录。建议保留当前登录状态，等待服务恢复。", "The service connection is currently unavailable. You may not be able to sign in again after signing out. We recommend staying signed in until the service recovers.", language: language)
            : tvText("确定要退出当前账户吗？退出后需要重新登录。", "Are you sure you want to sign out? You will need to sign in again.", language: language))
        if let logoutError { Text(logoutError).foregroundStyle(TVTheme.danger) }
        if isLoggingOut { ProgressView() }
      }
    } actions: {
      HStack(spacing: tv(10)) {
        TVFocusButton(cornerRadius: TVTheme.compactRadius, autofocus: true, focus: $logoutCancelFocused, action: {
          dismissLogoutDialog()
        }) { focused in
          Text(tvText("取消", "Cancel", language: language))
            .font(TVFont.regular(14))
            .padding(.horizontal, tv(18))
            .frame(height: tv(48))
            .background(TVTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TVTheme.compactRadius, style: .continuous))
        }
        TVFocusButton(cornerRadius: TVTheme.compactRadius, action: {
          guard !isLoggingOut else { return }
          if logoutProtectedAtOpen && !logoutForceConfirmation {
            logoutForceConfirmation = true
          } else { performLogout(force: logoutProtectedAtOpen) }
        }) { focused in
          Text(logoutProtectedAtOpen
            ? tvText("仍然退出", "Sign out anyway", language: language)
            : tvText("退出", "Exit", language: language))
            .font(TVFont.regular(14))
            .foregroundStyle(.white)
            .padding(.horizontal, tv(18))
            .frame(height: tv(48))
            .background(TVTheme.danger)
            .clipShape(RoundedRectangle(cornerRadius: TVTheme.compactRadius, style: .continuous))
        }
      }
      .opacity(isLoggingOut ? 0.6 : 1)
    }
    .onExitCommand { dismissLogoutDialog() }
  }

  private func dismissLogoutDialog() {
    guard !isLoggingOut else { return }
    if logoutForceConfirmation { logoutForceConfirmation = false }
    else { showLogoutConfirmation = false }
  }

  private var connectivityDialog: some View {
    TVDialog(title: connectivity.state.title(language: language), icon: .networkCheck) {
      VStack(alignment: .leading, spacing: tv(10)) {
        Text(connectivity.state.detail(language: language))
        if let checkedAt = connectivity.state.checkedAt {
          Text(tvText("检测时间：", "Checked at: ", language: language) + checkedAt.formatted(date: .omitted, time: .standard))
        }
        if connectivity.isChecking { ProgressView() }
      }
    } actions: {
      HStack(spacing: tv(10)) {
        subscriptionDialogButton(tvText("关闭", "Close", language: language), focus: $connectivityCloseFocused, autofocus: true) {
          showConnectivityDetail = false
        }
        subscriptionDialogButton(tvText("重新检测", "Check again", language: language), primary: true) {
          connectivity.requestCheck()
        }
      }
    }
    .onExitCommand { showConnectivityDetail = false }
  }

  private func updateConnectivityProxy() {
    connectivity.updateProxy(connected: connected,
      name: routeMode == .global ? "GLOBAL" : (selectedGroupName ?? selectedNodeName),
      selectionID: "\(routeMode.rawValue):\(selectedNodeName ?? "")")
  }

  private func messageDialog(_ message: String) -> some View {
    TVDialog(
      title: subscriptionBlockTitle,
      icon: nil
    ) {
      VStack(alignment: .leading, spacing: tv(10)) {
        Text(subscriptionBlockReason ?? message)
        if let subscriptionActionError {
          Text(subscriptionActionError).foregroundStyle(TVTheme.danger)
        }
      }
    } actions: {
      VStack(spacing: tv(8)) {
        if hasRecoverableSubscriptionBlock {
          subscriptionDialogButton(tvText("刷新状态", "Refresh status", language: language)) {
            guard !isRefreshingSubscription else { return }
            Task { await refreshBlockedSubscription() }
          }
        }
        subscriptionDialogButton(
          hasRecoverableSubscriptionBlock
            ? tvText("稍后处理", "Handle later", language: language)
            : tvText("取消", "Cancel", language: language),
          focus: $messageActionFocused, autofocus: true
        ) {
          guard !isRefreshingSubscription else { return }
          subscriptionBlockMessage = nil
        }
        if subscriptionSummary?.canStartNewPeriod == true || newPeriodNeedsCheck {
          subscriptionDialogButton(tvText("开启新周期", "Start next traffic period", language: language), primary: true) {
            guard !isRefreshingSubscription else { return }
            newPeriodError = nil
            newPeriodState = newPeriodNeedsCheck ? .uncertain : .confirmation
          }
        }
      }
      .opacity(isRefreshingSubscription ? 0.6 : 1)
    }
    .onExitCommand {
      if !isRefreshingSubscription { subscriptionBlockMessage = nil }
    }
  }

  private var hasRecoverableSubscriptionBlock: Bool {
    if let expiredAt = expirationDate, expiredAt <= Date() { return true }
    guard let summary = subscriptionSummary else { return false }
    return summary.transferLimit > 0 && summary.remainingBytes == 0
  }

  private func subscriptionDialogButton(
    _ title: String, primary: Bool = false,
    focus: FocusState<Bool>.Binding? = nil, autofocus: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    TVFocusButton(cornerRadius: TVTheme.compactRadius, autofocus: autofocus, focus: focus, action: action) { _ in
      Text(title)
        .font(TVFont.regular(14))
        .foregroundStyle(primary ? .white : TVTheme.textPrimary)
        .padding(.horizontal, tv(18))
        .frame(maxWidth: .infinity)
        .frame(height: tv(48))
        .background(primary ? TVTheme.primary : TVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: TVTheme.compactRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: TVTheme.compactRadius, style: .continuous)
            .strokeBorder(TVTheme.stroke, lineWidth: tv(1))
        }
    }
  }

  private var newPeriodDialog: some View {
    TVDialog(title: newPeriodTitle, icon: nil) {
      VStack(alignment: .leading, spacing: tv(12)) {
        if newPeriodState == .submitting { ProgressView() }
        Text(newPeriodContent)
      }
    } actions: {
      HStack(spacing: tv(10)) {
        subscriptionDialogButton(
          newPeriodState == .success
            ? tvText("确定", "Confirm", language: language)
            : tvText("取消", "Cancel", language: language),
          focus: $newPeriodCancelFocused, autofocus: true
        ) { dismissNewPeriodDialog() }
        if newPeriodState != .success {
          subscriptionDialogButton(
            newPeriodNeedsCheck
              ? tvText("检查状态", "Check status", language: language)
              : tvText("确定", "Confirm", language: language), primary: true
          ) {
            guard newPeriodState != .submitting else { return }
            Task { await runNewPeriod(checkOnly: newPeriodNeedsCheck) }
          }
        }
      }
      .opacity(newPeriodState == .submitting ? 0.6 : 1)
    }
    .onExitCommand { dismissNewPeriodDialog() }
  }

  private var newPeriodTitle: String {
    switch newPeriodState {
    case .submitting:
      return newPeriodNeedsCheck
        ? tvText("正在检查操作结果", "Checking the operation result", language: language)
        : tvText("正在开启新的流量周期", "Starting the new traffic period", language: language)
    case .uncertain:
      return tvText("暂时无法确认操作结果", "Unable to confirm the result", language: language)
    case .failure:
      return tvText("开启新的流量周期失败，请稍后重试", "Could not start a new traffic period. Try again later.", language: language)
    case .success:
      return tvText("新的流量周期已开启", "The new traffic period has started", language: language)
    default:
      return tvText("确认开启下一个流量周期？", "Start the next traffic period?", language: language)
    }
  }

  private var newPeriodContent: String {
    if newPeriodState == .uncertain || (newPeriodState == .submitting && newPeriodNeedsCheck) {
      return tvText("网络响应异常，暂时无法确认新的流量周期是否已开启。请检查结果，不要重复提交。", "The network response was interrupted, so the new traffic period cannot be confirmed yet. Check the result instead of submitting again.", language: language)
    }
    if let newPeriodError { return newPeriodError }
    if newPeriodState == .success { return newPeriodTitle }
    return tvText("开启后将重置已使用流量，并扣除当前流量周期剩余的套餐时长。此操作无法撤销，是否继续？", "This resets used traffic and deducts the remaining duration of the current traffic period from your plan. This action cannot be undone. Continue?", language: language)
  }

  private func dismissNewPeriodDialog() {
    guard newPeriodState != .submitting else { return }
    if newPeriodState == .success { subscriptionBlockMessage = nil }
    newPeriodState = nil
  }

  @MainActor
  private func refreshBlockedSubscription() async {
    subscriptionActionError = nil
    await refreshSubscriptionSummary()
    if let homeInfoError { subscriptionActionError = homeInfoError; return }
    if let reason = subscriptionBlockReason { subscriptionBlockMessage = reason }
    else { subscriptionBlockMessage = nil }
  }

  @MainActor
  private func runNewPeriod(checkOnly: Bool) async {
    guard newPeriodState != .submitting, let token = session.token else { return }
    guard !isDebugPreviewSession else { return }
    newPeriodState = .submitting
    newPeriodError = nil
    let client: GatewayClient
    do { client = try await GatewayClient.configured() }
    catch {
      newPeriodError = error.localizedDescription
      newPeriodState = checkOnly ? .uncertain : .failure
      return
    }
    if checkOnly {
      do {
        let latest = try await client.fetchSubscriptionSummary(token: token)
        subscriptionSummary = latest
        if let baseline = newPeriodBaseline, latest.hasAdvancedPeriod(since: baseline) {
          await completeNewPeriod()
        } else { newPeriodState = .uncertain }
      } catch {
        if handleExpiredSession(error) { return }
        newPeriodState = .uncertain
      }
      return
    }

    // Revalidate permission immediately before the irreversible operation.
    do {
      let latest = try await client.fetchSubscriptionSummary(token: token)
      subscriptionSummary = latest
      guard latest.canStartNewPeriod else {
        newPeriodError = tvText("当前套餐不支持开启新周期", "This plan does not allow starting a new traffic period.", language: language)
        newPeriodState = .failure
        return
      }
      newPeriodBaseline = latest
    } catch {
      if handleExpiredSession(error) { return }
      newPeriodError = error.localizedDescription
      newPeriodState = .failure
      return
    }
    do {
      try await client.startNewPeriod(token: token)
    } catch {
      if handleExpiredSession(error) { return }
      if case GatewayClient.GatewayError.server(let message) = error {
        newPeriodError = message
        newPeriodState = .failure
      } else {
        // Keep this lock even when the dialog is dismissed/reopened.
        newPeriodNeedsCheck = true
        newPeriodState = .uncertain
      }
      return
    }
    await completeNewPeriod()
  }

  @MainActor
  private func completeNewPeriod() async {
    newPeriodNeedsCheck = false
    newPeriodBaseline = nil
    // Acknowledged success must never turn into a retry of the POST if refresh fails.
    await GatewayClient.clearCachedSubscriptions()
    cachedSubscription = nil
    await refreshSubscriptionSummary()
    newPeriodError = homeInfoError
    newPeriodState = .success
  }

  private var currentNotice: TVNotice? {
    guard !notices.isEmpty else { return nil }
    return notices[min(noticeIndex, notices.count - 1)]
  }

  private var noticeDateText: String? {
    guard let timestamp = currentNotice?.createdAt else { return nil }
    let value = timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date(timeIntervalSince1970: value))
  }

  private var announcementSubtitle: String {
    if let notice = currentNotice {
      let text = plainText(notice.content)
      return text.isEmpty ? tvText("按确认键查看公告详情", "Press Select to view details", language: language) : text
    }
    return homeInfoError ?? tvText("暂时没有新的服务公告", "There are no new service notices", language: language)
  }

  private var routeDisplayName: String {
    if isLoadingNodes { return tvText("正在加载线路…", "Loading nodes…", language: language) }
    if let nodeLoadError, nodes.isEmpty { return nodeLoadError }
    if let selectedNodeName { return selectedNodeName }
    if let selectedGroupName, !selectedGroupName.isEmpty { return selectedGroupName }
    return tvText("自动选择", "Auto Select", language: language)
  }

  private var selectedNodeDelay: Int? {
    guard let selectedNodeName else { return nil }
    guard let delay = nodes.first(where: { $0.name == selectedNodeName })?.delayMS, delay > 0 else { return nil }
    return delay
  }

  private var subscriptionBlockReason: String? {
    guard let summary = subscriptionSummary else { return nil }
    if let expiredAt = expirationDate, expiredAt <= Date() {
      return tvText("请续费后继续使用", "Please renew to continue using", language: language)
    }
    if summary.transferLimit > 0, summary.remainingBytes <= 0 {
      if summary.canStartNewPeriod {
        return tvText("套餐流量已用完，可以提前开启下一个流量周期。", "Your plan traffic is used up. You can start the next traffic period early.", language: language)
      }
      return tvText("套餐流量已用完，请重置流量或更换套餐", "Plan traffic has been used up, please reset traffic or change plan", language: language)
    }
    let hasPlanName = summary.planName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    if (summary.planID ?? 0) <= 0, !hasPlanName, summary.transferLimit <= 0 {
      return tvText("请购买套餐后使用", "Please purchase a subscription to use", language: language)
    }
    return nil
  }

  private var subscriptionBlockTitle: String {
    guard let summary = subscriptionSummary else {
      return tvText("无可用套餐", "No available subscription", language: language)
    }
    if let expiredAt = expirationDate, expiredAt <= Date() {
      return tvText("订阅已过期", "Subscription has expired", language: language)
    }
    if summary.transferLimit > 0, summary.remainingBytes <= 0 {
      return tvText("流量已用完", "Traffic used up", language: language)
    }
    return tvText("无可用套餐", "No available subscription", language: language)
  }

  private var subscriptionTitle: String {
    guard let summary = subscriptionSummary else {
      return isLoadingHomeInfo ? tvText("正在获取套餐信息…", "Loading plan…", language: language) : tvText("套餐信息暂不可用", "Plan information unavailable", language: language)
    }
    if let name = summary.planName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
      return name
    }
    if let id = summary.planID { return tvText("当前套餐 · #\(id)", "Current Plan · #\(id)", language: language) }
    return tvText("当前套餐", "Current Plan", language: language)
  }

  private var usageText: String {
    guard let summary = subscriptionSummary else { return tvText("已用 --", "Used --", language: language) }
    return tvText("已用 \(formatBytes(summary.usedBytes)) / \(formatBytes(summary.transferLimit))", "Used \(formatBytes(summary.usedBytes)) / \(formatBytes(summary.transferLimit))", language: language)
  }

  private var exactUsageText: String {
    guard let summary = subscriptionSummary else { return tvText("已用 -- / 总计 --", "Used -- / Total --", language: language) }
    return tvText(
      "已用 \(formatBytes(summary.usedBytes)) / 总计 \(formatBytes(summary.transferLimit))",
      "Used \(formatBytes(summary.usedBytes)) / Total \(formatBytes(summary.transferLimit))",
      language: language
    )
  }

  private var progressPercentText: String {
    let percent = (subscriptionSummary?.usageFraction ?? 0) * 100
    if percent >= 100 || percent.rounded() == percent { return "\(Int(percent.rounded()))%" }
    return String(format: "%.1f%%", percent)
  }

  private var exactExpirationText: String {
    guard let date = expirationDate else { return "" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd HH:mm"
    let formatted = formatter.string(from: date)
    if date <= Date() {
      return tvText("已于 \(formatted) 到期", "Expired on \(formatted)", language: language)
    }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let target = calendar.startOfDay(for: date)
    let days = max(0, calendar.dateComponents([.day], from: today, to: target).day ?? 0)
    return tvText("于 \(formatted) 到期，距离到期还有 \(days) 天", "Expires on \(formatted), \(days) days remaining", language: language)
  }

  private var remainingText: String {
    guard let summary = subscriptionSummary else { return tvText("剩余 --", "Remaining --", language: language) }
    return tvText("剩余 \(formatBytes(summary.remainingBytes))", "Remaining \(formatBytes(summary.remainingBytes))", language: language)
  }

  private var expirationDate: Date? {
    guard let raw = subscriptionSummary?.expiredAt, raw > 0 else { return nil }
    let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
    return Date(timeIntervalSince1970: seconds)
  }

  private var expirationText: String {
    guard let date = expirationDate else { return tvText("长期有效", "No expiration", language: language) }
    let formatter = DateFormatter()
    formatter.locale = TVLanguage.resolved(from: language).locale
    formatter.dateFormat = TVLanguage.resolved(from: language) == .simplifiedChinese ? "yyyy-MM-dd 到期" : "Expires yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private var expirationColor: Color {
    guard let date = expirationDate else { return TVTheme.textSecondary }
    if date <= Date() { return TVTheme.danger }
    return date.timeIntervalSinceNow < 7 * 86_400 ? TVTheme.warning : TVTheme.textSecondary
  }

  private func noticeRichText(_ source: String) -> AttributedString {
    let formatted = source
      .replacingOccurrences(of: "(?is)<(?:strong|b)\\b[^>]*>(.*?)</(?:strong|b)>", with: "**$1**", options: .regularExpression)
      .replacingOccurrences(of: "(?is)<(?:em|i)\\b[^>]*>(.*?)</(?:em|i)>", with: "*$1*", options: .regularExpression)
    let text = plainText(formatted)
    return (try? AttributedString(markdown: text,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
  }

  private var noticeLinks: [(title: String, url: URL)] {
    let source = currentNotice?.content ?? ""
    guard let pattern = try? NSRegularExpression(
      pattern: "(?is)<a\\b[^>]*href\\s*=\\s*[\"']([^\"']+)[\"'][^>]*>(.*?)</a>"
    ) else { return [] }
    var seen: Set<URL> = []
    return pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
      guard let hrefRange = Range(match.range(at: 1), in: source),
            let titleRange = Range(match.range(at: 2), in: source),
            let url = URL(string: String(source[hrefRange]).replacingOccurrences(of: "&amp;", with: "&")),
            ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil, url.user == nil, url.password == nil,
            seen.insert(url).inserted else { return nil }
      let title = plainText(String(source[titleRange]))
      return (title.isEmpty ? url.host ?? "" : title, url)
    }
  }

  private func plainText(_ source: String) -> String {
    let structured = source
      .replacingOccurrences(of: "(?is)<(script|style)[^>]*>.*?</\\1>", with: "", options: .regularExpression)
      .replacingOccurrences(of: "(?i)<br\\s*/?>|</(?:p|div|h[1-6]|ul|ol)>", with: "\n", options: .regularExpression)
      .replacingOccurrences(of: "(?i)<li[^>]*>", with: "\n• ", options: .regularExpression)
    let withoutTags = structured.replacingOccurrences(
      of: "<[^>]+>", with: " ", options: .regularExpression
    )
    let decoded = withoutTags
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
    return decoded
      .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
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
      async let fetchedNotices = fetchOptionalHomeValue { try await client.fetchNotices(token: token) }
      async let fetchedSummary = fetchOptionalHomeValue { try await client.fetchSubscriptionSummary(token: token) }
      let (newNotices, newSummary) = try await (fetchedNotices, fetchedSummary)
      try Task.checkCancellation()
      guard session.token == token else { return }
      if let newNotices {
        notices = newNotices
        noticeIndex = 0
      }
      if let newSummary {
        subscriptionSummary = newSummary
      }
      if newNotices == nil, newSummary == nil {
        homeInfoError = tvText("公告与套餐信息暂时无法获取", "Notices and plan information are temporarily unavailable", language: language)
      }
    } catch {
      if Task.isCancelled || session.token != token { return }
      if handleExpiredSession(error) { return }
      homeInfoError = error.localizedDescription
    }
  }

  private func fetchOptionalHomeValue<T>(_ fetch: () async throws -> T) async throws -> T? {
    do { return try await fetch() }
    catch GatewayClient.GatewayError.unauthorized { throw GatewayClient.GatewayError.unauthorized }
    catch is CancellationError { throw CancellationError() }
    catch { return nil }
  }

  @MainActor
  private func refreshSubscriptionSummary() async {
    guard !isRefreshingSubscription else { return }
    guard let token = session.token else {
      homeInfoError = tvText("登录状态已失效，请重新登录", "Your session has expired. Sign in again.", language: language)
      return
    }
    if isDebugPreviewSession {
      await loadHomeInfo(forceRefresh: true)
      return
    }

    isRefreshingSubscription = true
    defer { isRefreshingSubscription = false }
    do {
      let client = try await GatewayClient.configured()
      subscriptionSummary = try await client.fetchSubscriptionSummary(token: token)
      homeInfoError = nil
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

  @MainActor
  private func refreshNodesFromToolbar() async {
    guard !isRefreshingNodes, !isTestingNodes else { return }
    isRefreshingNodes = true
    defer { isRefreshingNodes = false }
    await loadNodes(forceRefresh: true)
  }

  @MainActor
  private func runLatencyTest() async {
    guard !isTestingNodes, !isRefreshingNodes, !nodes.isEmpty else { return }

    if isDebugPreviewSession {
      isTestingNodes = true
      testingNodeNames = Set(nodes.map(\.name))
      try? await Task.sleep(for: .milliseconds(450))
      nodes = nodes.enumerated().map { index, node in
        TVProxyNode(node.name, type: node.type, delayMS: 82 + index * 37)
      }
      testingNodeNames.removeAll()
      isTestingNodes = false
      return
    }

    if !VPNManager.shared.isTunnelRunning {
      if cachedSubscription == nil { await loadNodes(forceRefresh: false) }
      guard let cachedSubscription else {
        nodeLoadError = tvText("订阅中没有可用线路", "No available nodes in this subscription", language: language)
        return
      }
      let failure = await ensureTunnelRunning(config: applyingRouteMode(to: cachedSubscription))
      guard failure == nil else {
        nodeLoadError = failure
        return
      }
    }

    isTestingNodes = true
    let testedNames = nodes.map(\.name)
    testingNodeNames = Set(testedNames)
    let startedAt = ContinuousClock.now

    await withTaskGroup(of: (String, Int).self) { group in
      for nodeName in testedNames {
        group.addTask {
          let value = await testDelay(proxyName: nodeName) ?? -1
          return (nodeName, value)
        }
      }
      for await (nodeName, value) in group {
        nodes = nodes.map { node in
          node.name == nodeName ? TVProxyNode(node.name, type: node.type, delayMS: value) : node
        }
        testingNodeNames.remove(nodeName)
      }
    }

    let elapsed = startedAt.duration(to: .now)
    if elapsed < .milliseconds(200) {
      try? await Task.sleep(for: .milliseconds(200) - elapsed)
    }
    testingNodeNames.removeAll()
    isTestingNodes = false
  }

  private func changeRouteMode(to mode: TVRouteMode) {
    guard routeMode != mode else { return }
    let previous = routeMode
    routeMode = mode
    savedRouteMode = mode.rawValue
    updateConnectivityProxy()
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
      updateConnectivityProxy()
      if connected { Task { await refreshLiveNodes() } }
      return
    }
    VPNManager.shared.refreshStatus { status in
      Task { @MainActor in
        connected = status == "connected"
        isConnecting = status == "connecting" || status == "disconnecting"
        updateConnectivityProxy()
        if connected { await refreshLiveNodes() }
      }
    }
  }

  private func performLogout(force: Bool = false) {
    guard !isLoggingOut else { return }
    guard force || !connectivity.state.protectsLogout else {
      logoutError = tvText("网络状态已改变，请取消后重新确认退出。", "Network status changed. Cancel and confirm sign out again.", language: language)
      return
    }
    isLoggingOut = true
    VPNManager.shared.disconnect { _ in
      Task { @MainActor in
        await GatewayClient.clearCachedSubscriptions()
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
    guard !isConnecting else { return }
    isConnecting = true
    defer { isConnecting = false }

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

    do {
      let downloaded: String
      if let cachedSubscription {
        downloaded = cachedSubscription
      } else if let cached = try await GatewayClient.cachedSubscription(token: token) {
        downloaded = cached
        cachedSubscription = cached
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
      selectedGroupName = tvText("自动选择", "Auto Select", language: language)
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
      let configuration: String
      var cached = cachedSubscription
      if !forceRefresh, cached == nil {
        cached = try await GatewayClient.cachedSubscription(token: token)
      }
      if !forceRefresh, let cached {
        configuration = cached
      } else {
        let client = try await GatewayClient.configured()
        configuration = try await client.downloadSubscription(token: token)
      }
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

  private func ensureTunnelRunning(config: String) async -> String? {
    await withCheckedContinuation { continuation in
      VPNManager.shared.ensureTunnelRunning(config: config) { continuation.resume(returning: $0) }
    }
  }

  private func testDelay(proxyName: String) async -> Int? {
    await withCheckedContinuation { continuation in
      VPNManager.shared.testDelay(proxyName: proxyName) { continuation.resume(returning: $0) }
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
      Task { @MainActor in
        await GatewayClient.clearCachedSubscriptions()
        session.signOut()
      }
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
