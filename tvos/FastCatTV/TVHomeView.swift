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

// Catboard stores rich notices as HTML fragments. Render the formatting using
// native SwiftUI text so the existing TV focus and link controls still work.
private final class TVNoticeMarkup: NSObject, XMLParserDelegate {
  private struct Format {
    var intent: InlinePresentationIntent = []
    var underline = false
    var color: Color?
  }

  private struct ListState {
    let ordered: Bool
    var next = 1
  }

  private var formats = [Format()]
  private var lists: [ListState] = []
  private var pendingNewline = false
  private var ignoredDepth = 0
  private var output = AttributedString()

  static func parse(_ source: String) -> AttributedString? {
    guard source.range(
      of: #"(?i)<(?:p|div|span|h[1-6]|ul|ol|li|br|hr|strong|b|em|i|u|s|a|img|font|table|blockquote|pre|code)(?=[\s/>])"#,
      options: .regularExpression
    ) != nil else { return nil }

    let fragment = source
      .replacingOccurrences(
        of: #"(?i)<(br|hr|img)(\b[^>]*?)(?<!/)>"#,
        with: "<$1$2/>", options: .regularExpression
      )
      .replacingOccurrences(of: "&nbsp;", with: "&#160;")
      .replacingOccurrences(
        of: #"&(?!amp;|lt;|gt;|quot;|apos;|#\d+;|#x[\da-fA-F]+;)"#,
        with: "&amp;", options: .regularExpression
      )
    let delegate = TVNoticeMarkup()
    let parser = XMLParser(data: Data("<notice>\(fragment)</notice>".utf8))
    parser.shouldResolveExternalEntities = false
    parser.delegate = delegate
    return parser.parse() ? delegate.output : nil
  }

  func parser(
    _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
    qualifiedName: String?, attributes: [String: String]
  ) {
    let tag = elementName.lowercased()
    var format = formats.last ?? Format()
    if ignoredDepth > 0 || ["script", "style", "iframe", "object", "template"].contains(tag) {
      ignoredDepth += 1
      formats.append(format)
      return
    }
    if ["strong", "b", "h1", "h2", "h3", "h4", "h5", "h6"].contains(tag) {
      format.intent.insert(.stronglyEmphasized)
    }
    if ["em", "i"].contains(tag) { format.intent.insert(.emphasized) }
    if ["s", "del"].contains(tag) { format.intent.insert(.strikethrough) }
    if tag == "u" { format.underline = true }

    if let style = attributes["style"],
      let range = style.range(of: #"(?i)(?:^|;)\s*color\s*:\s*[^;]+"#, options: .regularExpression),
      let value = style[range].split(separator: ":", maxSplits: 1).last
    {
      let color = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if color.lowercased() != "inherit", let parsed = Self.color(color) {
        format.color = parsed
      }
    }
    formats.append(format)
    switch tag {
    case "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre", "tr":
      pendingNewline = true
    case "br", "hr":
      output += AttributedString("\n")
      pendingNewline = false
    case "ol", "ul":
      lists.append(ListState(ordered: tag == "ol", next: Int(attributes["start"] ?? "") ?? 1))
    case "li":
      pendingNewline = true
      let marker: String
      if let last = lists.indices.last, lists[last].ordered {
        marker = "\(lists[last].next). "
        lists[last].next += 1
      } else {
        marker = "• "
      }
      append(String(repeating: "\u{00a0}", count: max(0, lists.count - 1) * 2) + marker)
    default:
      break
    }
  }

  func parser(
    _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
    qualifiedName: String?
  ) {
    _ = formats.popLast()
    if ignoredDepth > 0 {
      ignoredDepth -= 1
      return
    }
    switch elementName.lowercased() {
    case "ul", "ol":
      _ = lists.popLast()
      pendingNewline = true
    case "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote", "pre", "tr":
      pendingNewline = true
    case "td", "th":
      append(" ")
    default:
      break
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    guard ignoredDepth == 0 else { return }
    if pendingNewline && string.unicodeScalars.allSatisfy({ " \t\r\n".unicodeScalars.contains($0) }) { return }
    append(string)
  }

  private func append(_ text: String) {
    if pendingNewline && !output.characters.isEmpty && output.characters.last != "\n" {
      output += AttributedString("\n")
    }
    pendingNewline = false
    let format = formats.last ?? Format()
    var run = AttributedString(text)
    if !format.intent.isEmpty { run.inlinePresentationIntent = format.intent }
    if format.underline { run.underlineStyle = .single }
    if let color = format.color { run.foregroundColor = color }
    output += run
  }

  private static func color(_ source: String) -> Color? {
    if source.hasPrefix("#"), source.count == 7, let hex = UInt32(source.dropFirst(), radix: 16) {
      return Color(red: Double(hex >> 16) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    guard source.lowercased().hasPrefix("rgb("), source.hasSuffix(")") else { return nil }
    let components = source.dropFirst(4).dropLast().split(separator: ",", omittingEmptySubsequences: false)
    let channels = components.compactMap { UInt8($0.trimmingCharacters(in: .whitespaces)) }
    guard components.count == 3, channels.count == 3 else { return nil }
    return Color(red: Double(channels[0]) / 255, green: Double(channels[1]) / 255, blue: Double(channels[2]) / 255)
  }
}

struct TVHomeView: View {
  @EnvironmentObject private var session: SessionStore
  @EnvironmentObject private var connectivity: TVServiceConnectivityMonitor
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.scenePhase) private var scenePhase
  @State private var connected = false
  @State private var isConnecting = false
  @State private var isApplyingRouting = false
  @State private var routeMode: TVRouteMode = .rule
  private var prefersDarkTheme: Bool { colorScheme == .dark }
  @State private var didCheckAutoConnect = false
  @State private var autoConnectTask: Task<Void, Never>?
  @State private var autoConnectGeneration=UUID()
  @State private var autoConnectBackgrounded = false
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @AppStorage("fastcat.tv.route-mode") private var savedRouteMode = TVRouteMode.rule.rawValue
  @AppStorage("fastcat.tv.selected-node") private var savedSelectedNode = ""
  @State private var showTools = false
  @State private var toolsStartAbout = false
  @State private var toolsStartAccount = false
  @State private var hasTVUpdate = false
  @State private var errorMessage: String?
  @State private var initialLatencyFinished=false
  @State private var initialHomeReady=false
  @State private var initialLatencyTask:Task<Void,Never>?
  @State private var initialLatencyGeneration=UUID()
  @State private var selectionLatencyTask: Task<Void, Never>?
  @State private var foregroundLatencyTask: Task<Void, Never>?
  @State private var periodicLatencyTask: Task<Void, Never>?
  @State private var latencyLifecycleGeneration = 0
  @State private var preparingConnection = false
  @State private var connectionPhase: String?
  @State private var latencyDates: [String: Date] = [:]
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
  @State private var subscriptionForegroundGeneration = 0
  @State private var homeInfoError: String?
  @State private var showNoticeDetail = false
  @State private var noticeLinkURL: URL?
  @State private var noticeContentHeight: CGFloat = 0
  @State private var hasAssignedInitialHomeFocus = false
  @FocusState private var toolsButtonFocused:Bool
  @FocusState private var versionButtonFocused:Bool
  @FocusState private var accountButtonFocused:Bool
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
        let viewport = TVLayout.logicalSize(geometry.size)
        let designSize = CGSize(
          width: max(0, viewport.width - CGFloat(TVHomeFrame.horizontal * 2)),
          height: CGFloat(TVHomeFrame.contentHeight(Double(viewport.height))))
        let designBodyHeight = max(0, designSize.height - 64)
        let bodyHeight = tv(designBodyHeight)
        let isShort = designBodyHeight < 620
        let topInfoHeight: CGFloat = isShort ? tv(124) : tv(148)
        let horizontalPadding=tv(CGFloat(TVPageSpacing.horizontal(logicalWidth:Double(designSize.width))))
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
                onTestNode: { node in Task { await runLatencyTest(only: node.name) } },
                onSelect: { selectNode($0) }
              )
              .padding(.horizontal, horizontalPadding + tv(CGFloat(TVHomeFrame.horizontal)))
              .padding(.top, tv(CGFloat(TVHomeFrame.top)))
              .padding(.bottom, tv(CGFloat(TVHomeFrame.bottom) + 23))
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
              .frame(width: tv(designSize.width), height: tv(designSize.height))
              .padding(
                .init(
                  top: tv(CGFloat(TVHomeFrame.top)),
                  leading: tv(CGFloat(TVHomeFrame.horizontal)),
                  bottom: tv(CGFloat(TVHomeFrame.bottom)),
                  trailing: tv(CGFloat(TVHomeFrame.horizontal))))
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
        if initialHomeReady {
          scheduleAutoConnect()
          scheduleInitialLatency()
          startPeriodicLatency()
        }
        guard !hasAssignedInitialHomeFocus else { return }
        hasAssignedInitialHomeFocus = true
        focusModalButton { connectButtonFocused = true }
      }
      .task(id: session.token) {
        pauseLatency()
        initialLatencyFinished = false
        initialHomeReady = false
        guard session.token != nil else { return }
        routeMode = TVRouteMode(rawValue: savedRouteMode) ?? .rule
        selectedNodeName = savedSelectedNode.isEmpty ? nil : savedSelectedNode
        syncVPNStatus()
        initialHomeReady = true
        scheduleAutoConnect()
        scheduleInitialLatency()
        startPeriodicLatency()
      }
      .task(id: language) {
        #if DEBUG
          if ProcessInfo.processInfo.environment["FASTCAT_PREVIEW_NODES"] == "1" {
            showNodeSelector = true
            await loadNodes(forceRefresh: false)
          }
        #endif
        await loadHomeInfo(forceRefresh: true)

      }
      .fullScreenCover(isPresented: $showTools) {
        TVToolsView(
          startAbout: toolsStartAbout, startAccount: toolsStartAccount,
          accountPlan: AnyView(subscriptionInformationCard.frame(height: tv(148))),
          onRefreshAccount:{await refreshSubscriptionSummary()},
          onLogout: {
            logoutProtectedAtOpen=connectivity.state.protectsLogout
            logoutForceConfirmation=false;logoutError=nil
            showTools = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showLogoutConfirmation = true }
          }, onRulesChanged: { try await applyCustomRouting() }
        ).environmentObject(session)
      }
      .task {
        hasTVUpdate =
          await TVRemoteConfigManager.shared.availableTVUpdate(
            language: TVLanguage.resolved(from: language)) != nil
      }
      .onReceive(NotificationCenter.default.publisher(for: .tvUpdateAvailability)) { event in
        hasTVUpdate = event.object as? Bool ?? false
      }
      .onDisappear { pauseLatency() }
      .onReceive(NotificationCenter.default.publisher(for: VPNManager.statusDidChangeNotification))
    { notification in
      syncVPNStatus(notification.object as? String)
    }
      .onChange(of: connected) { _, _ in updateConnectivityProxy() }
      .onChange(of: scenePhase) { _, phase in
        subscriptionForegroundGeneration += 1
        if phase == .active {
          if autoConnectBackgrounded {didCheckAutoConnect=false;autoConnectBackgrounded=false}
          syncVPNStatus(refreshPlanOnResume: subscriptionForegroundGeneration)
          scheduleAutoConnect()
          resumeLatency()
        } else {
          if phase == .background {autoConnectBackgrounded=true}
          autoConnectTask?.cancel()
          pauseLatency()
        }
      }
      .onChange(of: selectedNodeName) { _,_ in updateConnectivityProxy();scheduleInitialLatency() }
      .onChange(of:nodes.map(\.name)) { _,names in if !names.isEmpty {scheduleInitialLatency()} }
      .onChange(of: selectedGroupName) { _, _ in updateConnectivityProxy() }
      .onChange(of: showConnectivityDetail) { _, presented in
        if presented {
          focusModalButton { connectivityCloseFocused = true }
        } else {
          connectivityCloseFocused = false
        }
      }
      .onChange(of: logoutForceConfirmation) { _, _ in
        focusModalButton { logoutCancelFocused = true }
      }
  }

  var body: some View {
    homeWithLifecycle
      .onChange(of:showTools) { _,presented in
        if !presented {
          DispatchQueue.main.asyncAfter(deadline:.now()+0.4) {
            guard !showTools,!showLogoutConfirmation,session.isSignedIn else {return}
            if toolsStartAccount {accountButtonFocused=true}
            else if toolsStartAbout {versionButtonFocused=true}
            else {toolsButtonFocused=true}
          }
        }
      }
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
        } else {
          noticeActionFocused = false
        }
      }
      .onChange(of: showLogoutConfirmation) { _, presented in
        if presented {
          focusModalButton { logoutCancelFocused = true }
        } else {
          logoutCancelFocused = false
        }
      }
      .onChange(of: subscriptionBlockMessage) { _, message in
        if message != nil {
          subscriptionActionError = nil
          focusModalButton { messageActionFocused = true }
        } else {
          messageActionFocused = false
        }
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
    showNoticeDetail || showLogoutConfirmation || showConnectivityDetail
      || subscriptionBlockMessage != nil || newPeriodState != nil
  }

  private func focusModalButton(_ action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: action)
  }

  private var header: some View {
    HStack(spacing: tv(9)) {
      TVBrandLogo()
        .frame(width: tv(34), height: tv(34))
        .clipShape(RoundedRectangle(cornerRadius: tv(8), style: .continuous))

      Text(tvText("快猫", "FastCat", language: language))
        .font(TVFont.bold(18))
        .foregroundStyle(TVTheme.textPrimary)

      Spacer()
      TVToolbarButton(
        title: tvText("工具设置", "Tools & settings", language: language),
        icon: .settingsOutlined,
        horizontalPadding: 18,
        cornerRadius: tv(14),
        height: 44,
        focus:$toolsButtonFocused,
        action: {
          toolsStartAbout = false
          toolsStartAccount = false
          showTools = true
        }
      )
      .overlay(alignment: .topTrailing) {
        if hasTVUpdate { Circle().fill(.red).frame(width: tv(8), height: tv(8)) }
      }
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
    TVFocusButton(
      cornerRadius: TVTheme.cardRadius,
      action: {
        if currentNotice != nil { showNoticeDetail = true }
      }
    ) { _ in
      ZStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: tv(10)) {
          HStack(spacing: tv(8)) {
            ZStack {
              Circle().fill(TVTheme.primary.opacity(0.12))
              MaterialIcon(glyph: .campaignOutlined, size: 15, color: TVTheme.primary)
            }
            .frame(width: tv(24), height: tv(24))
            Text(
              currentNotice?.title
                ?? (isLoadingHomeInfo
                  ? tvText("正在获取最新公告…", "Loading notices…", language: language)
                  : tvText("暂无公告", "No notices", language: language))
            )
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
    .accessibilityLabel(
      tvText("公告", "Notice", language: language) + ", "
        + (currentNotice?.title ?? tvText("暂无公告", "No notices", language: language)))
  }

  private var subscriptionInformationCard: some View {
    let progress = min(1, max(0, subscriptionSummary?.usageFraction ?? 0))
    let progressColor =
      progress >= 1 ? TVTheme.danger : progress >= 0.9 ? TVTheme.warning : TVTheme.primary
    return VStack(alignment: .leading, spacing: tv(0)) {
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
    .padding(.leading, tv(16)).padding(.trailing, tv(16)).padding(.top, tv(14)).padding(
      .bottom, tv(16)
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(TVTheme.surface)
    .clipShape(RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: TVTheme.cardRadius, style: .continuous).strokeBorder(
        TVTheme.stroke, lineWidth: tv(1))
    }
  }

  private var subscriptionCard: some View {
    return TVFocusButton(
      cornerRadius: TVTheme.cardRadius,
      action: {
        if !isRefreshingSubscription {
          Task { await refreshSubscriptionSummary() }
        }
      }
    ) { _ in
      subscriptionInformationCard
    }
    .shadow(color: prefersDarkTheme ? .clear : .black.opacity(0.08), radius: tv(16), y: tv(4))
    .frame(maxHeight: .infinity)
    .accessibilityLabel(
      tvText("套餐信息", "Plan information", language: language) + ", " + subscriptionTitle + ", "
        + remainingText)
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
        Text(
          isConnecting
            ? tvText("正在连接", "Connecting", language: language)
            : connected
              ? tvText("已连接", "Connected", language: language)
              : tvText("未连接", "Disconnected", language: language)
        )
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
    // size is already in native points; helpers below convert design units.
    // Normalize once to avoid scaling the power glyph twice.
    let designSize = size / tv(1)
    let iconSize = designSize * 0.34 * 0.75
    let labelSize = min(max(designSize * 0.07, 9), 12)
    return TVFocusButton(
      cornerRadius: size / 2, focus: $connectButtonFocused, action: toggleConnection
    ) { _ in
      ZStack {
        Circle().fill(connected ? TVTheme.primary.opacity(0.10) : .clear)
        Circle().fill(connected ? TVTheme.primary.opacity(0.10) : .clear)
          .frame(width: middleSize, height: middleSize)
        Circle()
          .fill(
            connected
              ? TVTheme.primary
              : (prefersDarkTheme
                ? Color(red: 58 / 255, green: 58 / 255, blue: 58 / 255)
                : Color(red: 240 / 255, green: 244 / 255, blue: 248 / 255))
          )
          .frame(width: innerSize, height: innerSize)
          .shadow(
            color: connected
              ? TVTheme.primary.opacity(prefersDarkTheme ? 0.36 : 0.30)
              : Color.black.opacity(prefersDarkTheme ? 0.30 : 0.10),
            radius: connected ? tv(18) : tv(12), y: tv(4))
        if isConnecting {
          VStack(spacing: tv(5)) {
            ProgressView().scaleEffect(0.8).tint(connected ? TVTheme.onPrimary : TVTheme.primary)
            Text(connectionPhase ?? tvText("正在连接", "Connecting", language: language)).font(
              TVFont.regular(labelSize))
          }
          .foregroundStyle(connected ? TVTheme.onPrimary : TVTheme.primary)
        } else {
          VStack(spacing: tv(min(max(designSize * 0.03, 2), 4))) {
            MaterialIcon(
              glyph: .powerSettingsNew, size: iconSize,
              color: connected
                ? TVTheme.onPrimary
                : (prefersDarkTheme
                  ? TVTheme.primary : Color(red: 69 / 255, green: 90 / 255, blue: 100 / 255)))
            if connected {
              TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(tvConnectionDuration(since: VPNManager.shared.connectedSince, now: context.date))
                  .font(TVFont.regular(labelSize))
                  .monospacedDigit()
                  .lineLimit(1)
                  .minimumScaleFactor(0.75)
                  .frame(maxWidth: innerSize * 0.85)
                  .foregroundStyle(TVTheme.onPrimary)
              }
            } else {
              Text(tvText("点击连接", "Tap to connect", language: language))
                .font(TVFont.regular(labelSize))
                .foregroundStyle(
                  prefersDarkTheme
                    ? TVTheme.primary : Color(red: 69 / 255, green: 90 / 255, blue: 100 / 255))
            }
          }
        }
      }
      .frame(width: size, height: size)
    }
    .buttonBorderShape(.circle)
    // Keep remote focus while busy; toggleConnection rejects repeat activation.
    .accessibilityLabel(
      connected
        ? tvText("断开 VPN", "Disconnect VPN", language: language)
        : tvText("连接 VPN", "Connect VPN", language: language))
  }

  private var connectionDetail: String {
    if let errorMessage { return errorMessage }
    if simulatorPreview {
      return tvText(
        "模拟器不支持 Packet Tunnel，仅供界面预览", "Packet Tunnel requires a real Apple TV", language: language)
    }
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
      Spacer(minLength: 0)
      routeCard.frame(height: nodeHeight)
      Spacer(minLength: 0)
      accountCard.frame(height: accountHeight)
      Spacer(minLength: 0)
      TVFocusButton(
        cornerRadius: TVTheme.compactRadius,
        focus:$versionButtonFocused,
        action: {
          toolsStartAbout = true
          toolsStartAccount = false
          showTools = true
        }
      ) { _ in
        HStack(spacing: tv(6)) {
          Text(tvText("当前版本：V\(appVersion)", "Current version: V\(appVersion)", language: language))
            .font(TVFont.regular(12))
            .foregroundStyle(TVTheme.textSecondary.opacity(0.72))
            .padding(.horizontal, tv(8))
            .padding(.vertical, tv(3))
          if hasTVUpdate { Circle().fill(.red).frame(width: tv(8), height: tv(8)) }
        }
      }
      .accessibilityHint(tvText("打开关于", "Open About", language: language))
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
              Text(
                mode == .rule
                  ? tvText("智能分流", "Smart routing", language: language)
                  : tvText("全局代理", "Global proxy", language: language)
              )
              .font(TVFont.medium(13))
              .foregroundStyle(
                routeMode == mode ? TVTheme.textPrimary : TVTheme.textPrimary.opacity(0.45)
              )
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(
                routeMode == mode
                  ? (prefersDarkTheme ? TVTheme.surfaceHighest : Color.white) : .clear
              )
              .clipShape(RoundedRectangle(cornerRadius: tv(16), style: .continuous))
              .shadow(
                color: routeMode == mode && !prefersDarkTheme ? .black.opacity(15 / 255) : .clear,
                radius: tv(6), y: tv(2))
            }
          }
        }
        .padding(tv(3))
        .frame(height: tv(44))
        .background(TVTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: tv(19), style: .continuous))
      }
      .padding(.leading, tv(18)).padding(.trailing, tv(18)).padding(.top, tv(12)).padding(
        .bottom, tv(10)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
  }

  private var routeCard: some View {
    TVFocusButton(
      cornerRadius: TVTheme.cardRadius, focus: $routeCardFocused, action: presentNodeSelector
    ) { _ in
      HStack(spacing: tv(12)) {
        ZStack {
          Circle().fill(TVTheme.primary.opacity(0.14))
          MaterialIcon(glyph: .language, size: 20, color: TVTheme.primary)
        }
        .frame(width: tv(40), height: tv(40))
        VStack(alignment: .leading, spacing: tv(2)) {
          Text(tvText("节点选择", "Node Selection", language: language)).font(TVFont.regular(12))
            .foregroundStyle(TVTheme.textSecondary)
          Text(routeDisplayName).font(TVFont.medium(14)).foregroundStyle(TVTheme.primary).lineLimit(
            1)
        }
        Spacer()
        TVLatencyIndicator(
          delay: nodes.first(where: { $0.name == selectedNodeName })?.delayMS,
          testing: selectedNodeName.map { testingNodeNames.contains($0) } ?? false)
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
    TVFocusButton(
      cornerRadius: TVTheme.cardRadius,
      focus:$accountButtonFocused,
      action: {
        toolsStartAbout = false
        toolsStartAccount = true
        showTools = true
        Task { await refreshSubscriptionSummary() }
      }
    ) { _ in
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
        MaterialIcon(glyph: .chevronRight, size: 24, color: TVTheme.textSecondary)
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

        Rectangle().fill(TVTheme.outline.opacity(colorScheme == .dark ? 0.20 : 0.10)).frame(
          height: tv(1))

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
              Text(
                tvText("使用手机扫描二维码打开链接", "Scan with your phone to open the link", language: language)
              )
              .font(TVFont.regular(14)).foregroundStyle(TVTheme.textSecondary)
              Text(noticeLinkURL.host ?? "")
                .font(TVFont.regular(12)).foregroundStyle(TVTheme.textSecondary)
            } else {
              Text(
                noticeRichText(
                  currentNotice?.content
                    ?? tvText("暂无公告内容", "No notice content", language: language))
              )
              .font(TVFont.regular(14))
              .foregroundStyle(TVTheme.textSecondary)
              .lineSpacing(tv(5.6))
              .frame(maxWidth: .infinity, alignment: .leading)
              ForEach(noticeLinks, id: \.url) { link in
                TVFocusButton(
                  cornerRadius: tv(12),
                  action: {
                    noticeLinkURL = link.url
                    noticeContentHeight = 0
                    focusModalButton { noticeActionFocused = true }
                  }
                ) { _ in
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
          TVFocusButton(
            cornerRadius: tv(12), autofocus: true, focus: $noticeActionFocused,
            action: {
              if noticeLinkURL != nil {
                noticeLinkURL = nil
                noticeContentHeight = 0
              } else {
                showNoticeDetail = false
              }
            }
          ) { _ in
            Text(
              noticeLinkURL == nil
                ? tvText("知道了", "Got it", language: language)
                : tvText("返回", "Back", language: language)
            )
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
          .strokeBorder(
            TVTheme.outline.opacity(colorScheme == .dark ? 0.30 : 0.10),
            lineWidth: colorScheme == .dark ? tv(1.5) : tv(1))
      }
      .shadow(
        color: .black.opacity(colorScheme == .dark ? 0.50 : 0.10),
        radius: colorScheme == .dark ? tv(30) : tv(20), y: tv(10)
      )
      .shadow(
        color: TVTheme.primary.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: tv(40), y: tv(5)
      )
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
        Text(
          logoutForceConfirmation
            ? tvText(
              "强制退出会清除本地登录状态和节点缓存，服务恢复前可能无法再次登录。确定继续吗？",
              "Forced sign out clears local sign-in state and cached nodes. You may not be able to sign in again until the service recovers. Continue?",
              language: language)
            : logoutProtectedAtOpen
              ? tvText(
                "当前服务连接异常，退出后可能暂时无法重新登录。建议保留当前登录状态，等待服务恢复。",
                "The service connection is currently unavailable. You may not be able to sign in again after signing out. We recommend staying signed in until the service recovers.",
                language: language)
              : tvText(
                "确定要退出当前账户吗？退出后需要重新登录。",
                "Are you sure you want to sign out? You will need to sign in again.",
                language: language))
        if let logoutError { Text(logoutError).foregroundStyle(TVTheme.danger) }
        if isLoggingOut { ProgressView() }
      }
    } actions: {
      HStack(spacing: tv(10)) {
        TVFocusButton(
          cornerRadius: TVTheme.compactRadius, autofocus: true, focus: $logoutCancelFocused,
          action: {
            dismissLogoutDialog()
          }
        ) { focused in
          Text(tvText("取消", "Cancel", language: language))
            .font(TVFont.regular(14))
            .padding(.horizontal, tv(18))
            .frame(height: tv(48))
            .background(TVTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TVTheme.compactRadius, style: .continuous))
        }
        TVFocusButton(
          cornerRadius: TVTheme.compactRadius,
          action: {
            guard !isLoggingOut else { return }
            if logoutProtectedAtOpen && !logoutForceConfirmation {
              logoutForceConfirmation = true
            } else {
              performLogout(force: logoutProtectedAtOpen)
            }
          }
        ) { focused in
          Text(
            logoutProtectedAtOpen
              ? tvText("仍然退出", "Sign out anyway", language: language)
              : tvText("退出", "Exit", language: language)
          )
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
    if logoutForceConfirmation {
      logoutForceConfirmation = false
    } else {
      showLogoutConfirmation = false
    }
  }

  private var connectivityDialog: some View {
    TVDialog(title: connectivity.state.title(language: language), icon: .networkCheck) {
      VStack(alignment: .leading, spacing: tv(10)) {
        Text(connectivity.state.detail(language: language))
        if let checkedAt = connectivity.state.checkedAt {
          Text(
            tvText("检测时间：", "Checked at: ", language: language)
              + checkedAt.formatted(date: .omitted, time: .standard))
        }
        if connectivity.isChecking { ProgressView() }
      }
    } actions: {
      HStack(spacing: tv(10)) {
        subscriptionDialogButton(
          tvText("关闭", "Close", language: language), focus: $connectivityCloseFocused,
          autofocus: true
        ) {
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
    connectivity.updateProxy(
      connected: connected,
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
          subscriptionDialogButton(
            tvText("开启新周期", "Start next traffic period", language: language), primary: true
          ) {
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
    TVFocusButton(
      cornerRadius: TVTheme.compactRadius, autofocus: autofocus, focus: focus, action: action
    ) { _ in
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
      return tvText(
        "开启新的流量周期失败，请稍后重试", "Could not start a new traffic period. Try again later.",
        language: language)
    case .success:
      return tvText("新的流量周期已开启", "The new traffic period has started", language: language)
    default:
      return tvText("确认开启下一个流量周期？", "Start the next traffic period?", language: language)
    }
  }

  private var newPeriodContent: String {
    if newPeriodState == .uncertain || (newPeriodState == .submitting && newPeriodNeedsCheck) {
      return tvText(
        "网络响应异常，暂时无法确认新的流量周期是否已开启。请检查结果，不要重复提交。",
        "The network response was interrupted, so the new traffic period cannot be confirmed yet. Check the result instead of submitting again.",
        language: language)
    }
    if let newPeriodError { return newPeriodError }
    if newPeriodState == .success { return newPeriodTitle }
    return tvText(
      "开启后将重置已使用流量，并扣除当前流量周期剩余的套餐时长。此操作无法撤销，是否继续？",
      "This resets used traffic and deducts the remaining duration of the current traffic period from your plan. This action cannot be undone. Continue?",
      language: language)
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
    if let homeInfoError {
      subscriptionActionError = homeInfoError
      return
    }
    if let reason = subscriptionBlockReason {
      subscriptionBlockMessage = reason
    } else {
      subscriptionBlockMessage = nil
    }
  }

  @MainActor
  private func runNewPeriod(checkOnly: Bool) async {
    guard newPeriodState != .submitting, let token = session.token else { return }
    guard !isDebugPreviewSession else { return }
    newPeriodState = .submitting
    newPeriodError = nil
    let client: GatewayClient
    do { client = try await GatewayClient.configured() } catch {
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
        } else {
          newPeriodState = .uncertain
        }
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
        newPeriodError = tvText(
          "当前套餐不支持开启新周期", "This plan does not allow starting a new traffic period.",
          language: language)
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
      let text = TVNoticeMarkup.parse(notice.content).map {
        String($0.characters)
          .replacingOccurrences(of: #"[\s\u00a0]+"#, with: " ", options: .regularExpression)
          .trimmingCharacters(in: .whitespacesAndNewlines)
      } ?? plainText(notice.content)
      return text.isEmpty
        ? tvText("按确认键查看公告详情", "Press Select to view details", language: language) : text
    }
    return homeInfoError
      ?? tvText("暂时没有新的服务公告", "There are no new service notices", language: language)
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
    guard let delay = nodes.first(where: { $0.name == selectedNodeName })?.delayMS, delay > 0 else {
      return nil
    }
    return delay
  }

  private var subscriptionBlockReason: String? {
    guard let summary = subscriptionSummary else { return nil }
    if let expiredAt = expirationDate, expiredAt <= Date() {
      return tvText("请续费后继续使用", "Please renew to continue using", language: language)
    }
    if summary.transferLimit > 0, summary.remainingBytes <= 0 {
      if summary.canStartNewPeriod {
        return tvText(
          "套餐流量已用完，可以提前开启下一个流量周期。",
          "Your plan traffic is used up. You can start the next traffic period early.",
          language: language)
      }
      return tvText(
        "套餐流量已用完，请重置流量或更换套餐", "Plan traffic has been used up, please reset traffic or change plan",
        language: language)
    }
    let hasPlanName =
      summary.planName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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
      return isLoadingHomeInfo
        ? tvText("正在获取套餐信息…", "Loading plan…", language: language)
        : tvText("套餐信息暂不可用", "Plan information unavailable", language: language)
    }
    if let name = summary.planName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
      return name
    }
    if let id = summary.planID {
      return tvText("当前套餐 · #\(id)", "Current Plan · #\(id)", language: language)
    }
    return tvText("当前套餐", "Current Plan", language: language)
  }

  private var usageText: String {
    guard let summary = subscriptionSummary else {
      return tvText("已用 --", "Used --", language: language)
    }
    return tvText(
      "已用 \(formatBytes(summary.usedBytes)) / \(formatBytes(summary.transferLimit))",
      "Used \(formatBytes(summary.usedBytes)) / \(formatBytes(summary.transferLimit))",
      language: language)
  }

  private var exactUsageText: String {
    guard let summary = subscriptionSummary else {
      return tvText("已用 -- / 总计 --", "Used -- / Total --", language: language)
    }
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
    return tvText(
      "于 \(formatted) 到期，距离到期还有 \(days) 天", "Expires on \(formatted), \(days) days remaining",
      language: language)
  }

  private var remainingText: String {
    guard let summary = subscriptionSummary else {
      return tvText("剩余 --", "Remaining --", language: language)
    }
    return tvText(
      "剩余 \(formatBytes(summary.remainingBytes))",
      "Remaining \(formatBytes(summary.remainingBytes))", language: language)
  }

  private var expirationDate: Date? {
    guard let raw = subscriptionSummary?.expiredAt, raw > 0 else { return nil }
    let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
    return Date(timeIntervalSince1970: seconds)
  }

  private var expirationText: String {
    guard let date = expirationDate else {
      return tvText("长期有效", "No expiration", language: language)
    }
    let formatter = DateFormatter()
    formatter.locale = TVLanguage.resolved(from: language).locale
    formatter.dateFormat =
      TVLanguage.resolved(from: language) == .simplifiedChinese
      ? "yyyy-MM-dd 到期" : "Expires yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private var expirationColor: Color {
    guard let date = expirationDate else { return TVTheme.textSecondary }
    if date <= Date() { return TVTheme.danger }
    return date.timeIntervalSinceNow < 7 * 86_400 ? TVTheme.warning : TVTheme.textSecondary
  }

  private func noticeRichText(_ source: String) -> AttributedString {
    if let richText = TVNoticeMarkup.parse(source) { return richText }
    let formatted =
      source
      .replacingOccurrences(
        of: "(?is)<(?:strong|b)\\b[^>]*>(.*?)</(?:strong|b)>", with: "**$1**",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: "(?is)<(?:em|i)\\b[^>]*>(.*?)</(?:em|i)>", with: "*$1*", options: .regularExpression)
    let text = plainText(formatted)
    return
      (try? AttributedString(
        markdown: text,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(text)
  }

  private var noticeLinks: [(title: String, url: URL)] {
    let source = currentNotice?.content ?? ""
    guard
      let pattern = try? NSRegularExpression(
        pattern: "(?is)<a\\b[^>]*href\\s*=\\s*[\"']([^\"']+)[\"'][^>]*>(.*?)</a>"
      )
    else { return [] }
    var seen: Set<URL> = []
    return pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap
    { match in
      guard let hrefRange = Range(match.range(at: 1), in: source),
        let titleRange = Range(match.range(at: 2), in: source),
        let url = URL(
          string: String(source[hrefRange]).replacingOccurrences(of: "&amp;", with: "&")),
        ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
        url.host != nil, url.user == nil, url.password == nil,
        seen.insert(url).inserted
      else { return nil }
      let title = plainText(String(source[titleRange]))
      return (title.isEmpty ? url.host ?? "" : title, url)
    }
  }

  private func plainText(_ source: String) -> String {
    let structured =
      source
      .replacingOccurrences(
        of: "(?is)<(script|style)[^>]*>.*?</\\1>", with: "", options: .regularExpression
      )
      .replacingOccurrences(
        of: "(?i)<br\\s*/?>|</(?:p|div|h[1-6]|ul|ol)>", with: "\n", options: .regularExpression
      )
      .replacingOccurrences(of: "(?i)<li[^>]*>", with: "\n• ", options: .regularExpression)
    let withoutTags = structured.replacingOccurrences(
      of: "<[^>]+>", with: " ", options: .regularExpression
    )
    let decoded =
      withoutTags
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
    return
      decoded
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
      (1_024, "KB"),
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
        TVNotice(id: 2, title: "线路维护通知", content: "部分线路将在凌晨进行短时维护，请优先选择自动线路。"),
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
      async let fetchedNotices = fetchOptionalHomeValue {
        try await client.fetchNotices(token: token)
      }
      async let fetchedSummary = fetchOptionalHomeValue {
        try await client.fetchSubscriptionSummary(token: token)
      }
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
        homeInfoError = tvText(
          "公告与套餐信息暂时无法获取", "Notices and plan information are temporarily unavailable",
          language: language)
      }
    } catch {
      if Task.isCancelled || session.token != token { return }
      if handleExpiredSession(error) { return }
      homeInfoError = error.localizedDescription
    }
  }

  private func fetchOptionalHomeValue<T>(_ fetch: () async throws -> T) async throws -> T? {
    do { return try await fetch() } catch GatewayClient.GatewayError.unauthorized {
      throw GatewayClient.GatewayError.unauthorized
    } catch is CancellationError { throw CancellationError() } catch { return nil }
  }

  @MainActor
  private func refreshSubscriptionSummary() async {
    guard !isRefreshingSubscription else { return }
    guard let token = session.token else {
      homeInfoError = tvText(
        "登录状态已失效，请重新登录", "Your session has expired. Sign in again.", language: language)
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
      let summary = try await client.fetchSubscriptionSummary(token: token)
      guard session.token == token else { return }
      subscriptionSummary = summary
      homeInfoError = nil
    } catch {
      guard session.token == token else { return }
      if handleExpiredSession(error) { return }
      homeInfoError = error.localizedDescription
    }
  }

  private func toggleConnection() {
    didCheckAutoConnect = true
    autoConnectTask?.cancel()
    guard !isConnecting, !isApplyingRouting, !isRefreshingNodes else { return }
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
    guard !isApplyingRouting, !isRefreshingNodes, !isConnecting else { return }
    showNodeSelector = false
    guard connected else {
      selectedNodeName = node.name
      savedSelectedNode = node.name
      scheduleSelectedLatency(node.name)
      return
    }
    isApplyingRouting = true
    let owner = session.token
    Task { @MainActor in
      defer { isApplyingRouting = false }
      do {
        let snapshot = try await TVProxyRouting.select(
          mode: routeMode.rawValue, node: node.name,
          read: { await liveProxies() },
          change: { await changeProxy(groupName: $0, proxyName: $1) })
        guard session.token == owner else { return }
        useSnapshot(snapshot)
        scheduleSelectedLatency(node.name)
      } catch {
        guard session.token == owner else { return }
        errorMessage = tvText(
          "线路切换未确认，请重试", "Node change was not confirmed. Please try again.", language: language)
      }
    }
  }

  @MainActor private func scheduleAutoConnect() {
    guard initialHomeReady, !didCheckAutoConnect, scenePhase == .active,
      autoConnectTask == nil || autoConnectTask!.isCancelled,
      UserDefaults.standard.bool(forKey: TVStartupPolicy.preferenceKey), !simulatorPreview else {return}
    let owner=session.token
    let generation=UUID();autoConnectGeneration=generation
    autoConnectTask=Task { @MainActor in
      defer {if autoConnectGeneration==generation {autoConnectTask=nil}}
      while !Task.isCancelled && scenePhase == .active && session.token == owner {
        guard session.isSignedIn else {return}
        let status:String=await withCheckedContinuation {continuation in
          VPNManager.shared.refreshStatus {continuation.resume(returning:$0)}
        }
        guard !Task.isCancelled, scenePhase == .active, session.token == owner,
          !didCheckAutoConnect, UserDefaults.standard.bool(forKey:TVStartupPolicy.preferenceKey) else {return}
        if status == "connected" {didCheckAutoConnect=true;syncVPNStatus(status);return}
        if status == "disconnected" && !isConnecting && !preparingConnection && !isApplyingRouting && !isTestingNodes {
          didCheckAutoConnect=true
          NSLog("[TVAutoConnect] starting once after readiness")
          await prepareAndConnect()
          return
        }
        do {try await Task.sleep(for:.milliseconds(500))} catch {return}
      }
    }
  }

  @MainActor
  private func pauseLatency() {
    latencyLifecycleGeneration += 1
    foregroundLatencyTask?.cancel()
    foregroundLatencyTask = nil
    periodicLatencyTask?.cancel()
    periodicLatencyTask = nil
    selectionLatencyTask?.cancel()
    initialLatencyTask?.cancel()
    testingNodeNames.removeAll()
  }

  @MainActor
  private func resumeLatency() {
    guard initialHomeReady, let owner = session.token else { return }
    foregroundLatencyTask?.cancel()
    let generation = latencyLifecycleGeneration
    foregroundLatencyTask = Task { @MainActor in
      defer {
        if latencyLifecycleGeneration == generation { foregroundLatencyTask = nil }
      }
      do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
      while !Task.isCancelled && scenePhase == .active && session.token == owner {
        for attempt in 0..<4 {
          guard !Task.isCancelled, scenePhase == .active, session.token == owner else { return }
          let statusBeforeProbe = VPNManager.shared.statusString
          let ready: Bool
          if isConnecting || preparingConnection || isApplyingRouting || isRefreshingNodes {
            ready = false
          } else if statusBeforeProbe == "disconnected" && !connected {
            ready = true // Disconnected tests use the isolated core.
          } else if VPNManager.shared.isTunnelRunning {
            let response = await liveProxies(timeout: 3)
            ready = response.flatMap {
              TVSubscriptionNodes.liveSnapshot(from: $0, mode: routeMode.rawValue)
            }?.nodes.isEmpty == false
          } else {
            ready = false
          }
          guard !Task.isCancelled, scenePhase == .active, session.token == owner else { return }
          if ready {
            startPeriodicLatency()
            if !initialLatencyFinished {
              scheduleInitialLatency(forceCurrent: true)
              return
            }
            while isTestingNodes {
              if let target = TVInitialLatencyPolicy.target(selected: selectedNodeName, names: nodes.map(\.name)),
                testingNodeNames.contains(target) { return }
              do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            guard !Task.isCancelled, scenePhase == .active, session.token == owner,
              let name = TVInitialLatencyPolicy.target(selected: selectedNodeName, names: nodes.map(\.name))
            else { return }
            await runLatencyTest(only: name)
            return
          }
          if attempt < 3 {
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
          }
        }
        do { try await Task.sleep(for: .seconds(15)) } catch { return }
      }
    }
  }

  @MainActor
  private func startPeriodicLatency() {
    guard scenePhase == .active, periodicLatencyTask == nil, let owner = session.token else { return }
    periodicLatencyTask = Task { @MainActor in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(600)) } catch { return }
        guard scenePhase == .active, session.token == owner else { return }
        if connected, let name = TVInitialLatencyPolicy.target(selected: selectedNodeName, names: nodes.map(\.name)),
          latencyDates[name].map({ Date().timeIntervalSince($0) >= 120 }) ?? true
        {
          await runLatencyTest(only: name)
        }
      }
    }
  }

  @MainActor private func scheduleInitialLatency(forceCurrent: Bool = false) {
    guard initialHomeReady,!initialLatencyFinished,scenePhase == .active,
      foregroundLatencyTask == nil || forceCurrent,
      initialLatencyTask==nil || initialLatencyTask!.isCancelled else {return}
    let generation=UUID();initialLatencyGeneration=generation
    guard let owner=session.token,!owner.isEmpty else {return}
    initialLatencyTask=Task { @MainActor in
      defer {if initialLatencyGeneration==generation {initialLatencyTask=nil}}
      // Bounded retries cover subscription/core readiness without making
      // announcement or account requests a prerequisite for the first probe.
      for attempt in 0..<3 {
        guard !Task.isCancelled, scenePhase == .active, session.token == owner else { return }
        if attempt > 0 {
          do { try await Task.sleep(for: .seconds(attempt * 2)) } catch { return }
        }
        while isTestingNodes || isRefreshingNodes || isLoadingNodes || isConnecting
          || preparingConnection || isApplyingRouting || autoConnectTask != nil {
          guard !Task.isCancelled, scenePhase == .active, session.token == owner else { return }
          do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
        }
        await loadNodes(forceRefresh: false)
        guard !Task.isCancelled, scenePhase == .active, session.token == owner else { return }
        guard let current = TVInitialLatencyPolicy.target(
          selected: selectedNodeName, names: nodes.map(\.name)) else {
          NSLog("[TVLatency] initial probe deferred: nodes unavailable attempt=%ld", attempt + 1)
          continue
        }
        let measured: Bool
        if !forceCurrent, let date = latencyDates[current], Date().timeIntervalSince(date) < 5 {
          measured = true
        } else {
          NSLog("[TVLatency] initial selected-node probe starting attempt=%ld", attempt + 1)
          measured = await runLatencyTest(only: current)
        }
        guard !Task.isCancelled, scenePhase == .active, session.token == owner else { return }
        guard measured else { continue }
        initialLatencyFinished = true
        NSLog("[TVLatency] initial selected-node probe completed")
        await runLatencyTest(excluding: [current])
        return
      }
      NSLog("[TVLatency] initial probe pending after bounded retries")
    }
  }

  private func scheduleSelectedLatency(_ name: String, force: Bool = false) {
    selectionLatencyTask?.cancel()
    selectionLatencyTask = Task { @MainActor in
      do { try await Task.sleep(for: force ? .seconds(2) : .milliseconds(800)) } catch { return }
      while isTestingNodes {
        if testingNodeNames.contains(name) { return }
        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
      }
      guard !Task.isCancelled, scenePhase == .active, selectedNodeName == name else { return }
      if !force, let last = latencyDates[name], Date().timeIntervalSince(last) < 120 { return }
      await runLatencyTest(only: name)
    }
  }

  @MainActor
  private func refreshNodesFromToolbar() async {
    guard !isRefreshingNodes, !isTestingNodes, !isApplyingRouting, !isConnecting else { return }
    isRefreshingNodes = true
    defer { isRefreshingNodes = false }
    await loadNodes(forceRefresh: true)
  }

  @MainActor
  @discardableResult
  private func runLatencyTest(only nodeName:String? = nil,excluding:Set<String> = []) async ->Bool {
    guard !Task.isCancelled, scenePhase == .active else {
      NSLog("[TVLatency] probe deferred: inactive or cancelled"); return false
    }
    let owner = session.token
    guard !isTestingNodes, !isRefreshingNodes, !nodes.isEmpty else {
      NSLog("[TVLatency] probe deferred: testing=%d refreshing=%d nodes=%ld", isTestingNodes, isRefreshingNodes, nodes.count)
      return false
    }
    let generation = latencyLifecycleGeneration
    let testedNames = nodes.map(\.name).filter {
      !excluding.contains($0) && (nodeName == nil || $0 == nodeName)
    }
    guard !testedNames.isEmpty else { return false }
    let targets = Set(testedNames)
    isTestingNodes = true
    testingNodeNames = targets
    defer {
      testingNodeNames.removeAll()
      isTestingNodes = false
    }

    if isDebugPreviewSession {
      do { try await Task.sleep(for: .milliseconds(450)) } catch { return false }
      guard generation == latencyLifecycleGeneration else { return false }
      nodes = nodes.enumerated().map { index, node in
        guard targets.contains(node.name) else { return node }
        latencyDates[node.name] = Date()
        return TVProxyNode(node.name, type: node.type, delayMS: 82 + index * 37)
      }
      return true
    }

    let useRunningTunnel = VPNManager.shared.isConnected
    // Running-tunnel probes need only a node and URL. A verified cached
    // subscription may refine the URL, but is never an IPC prerequisite.
    var source = cachedSubscription ?? ""
    if cachedSubscription == nil, let owner {
      do {
        var stored = try await GatewayClient.cachedSubscription(token: owner)
        if stored == nil, !useRunningTunnel {
          let client = try await GatewayClient.configured()
          stored = try await client.downloadSubscription(token: owner)
        }
        guard !Task.isCancelled, session.token == owner, generation == latencyLifecycleGeneration else { return false }
        if let stored { cachedSubscription = stored; source = stored }
      } catch {
        if !useRunningTunnel {
          NSLog("[TVLatency] probe deferred: subscription configuration unavailable")
          return false
        }
      }
    }
    let probeConfig: String
    if useRunningTunnel {
      probeConfig = "" // Existing tunnel configuration remains untouched.
    } else {
      guard !source.isEmpty else { return false }
      do {
        // Deliberately exclude applyingRouteMode / TVUserRouteStore: a named
        // proxy delay test does not depend on user traffic routing rules.
        probeConfig = try TVBuildConfiguration.load().runtimeConfiguration(source)
      } catch {
        NSLog("[TVLatency] probe deferred: isolated probe configuration invalid")
        nodeLoadError = error.localizedDescription
        return false
      }
    }
    NSLog("[TVLatency] probe path=%@", useRunningTunnel ? "running-tunnel" : "isolated-core")

    nodeLoadError = nil
    var receivedValidResult = false

    let testGroupName = selectedGroupName
    let clientTestURL = "https://www.gstatic.com/generate_204"
    let probeSource = source
    // Bound both IPC and core work; queued requests must not expire before
    // the provider has started measuring them.
    for start in stride(from: 0, to: testedNames.count, by: 4) {
      guard !Task.isCancelled, scenePhase == .active, session.token == owner, generation == latencyLifecycleGeneration else { break }
      let batch = testedNames[start..<min(start + 4, testedNames.count)]
      await withTaskGroup(of: (String, Int?, Bool).self) { group in
        for nodeName in batch {
          group.addTask {
            if useRunningTunnel {
              let targetURL = TVSubscriptionNodes.testURL(
                from: probeSource, node: nodeName, group: testGroupName, fallback: clientTestURL)
              let value = await testDelay(proxyName: nodeName, testURL: targetURL)
              return (nodeName, value, value != nil)
            }
            let value = await withCheckedContinuation { continuation in
              TVLatencyProbe.shared.test(
                config: probeConfig, proxyName: nodeName,
                testURL: TVSubscriptionNodes.testURL(
                  from: probeSource, node: nodeName, group: testGroupName, fallback: clientTestURL)
              ) {
                value, valid in
                continuation.resume(returning: (value, valid))
              }
            }
            return (nodeName, value.0, value.1)
          }
        }
        for await (nodeName, value, valid) in group {
          guard !Task.isCancelled, scenePhase == .active, session.token == owner, generation == latencyLifecycleGeneration else { continue }
          if valid {
            receivedValidResult = true
            NSLog("[TVLatency] probe response received success=%d", (value ?? -1) > 0)
            latencyDates[nodeName] = Date()
            nodes = nodes.map { node in
              node.name == nodeName ? TVProxyNode(node.name, type: node.type, delayMS: value) : node
            }
          } else {
            nodeLoadError = tvText(
              "测速核心未能就绪，请重试或更新客户端",
              "Latency core could not become ready. Please retry or update the app.",
              language: language)
          }
          testingNodeNames.remove(nodeName)
        }
      }
    }

    return receivedValidResult && !Task.isCancelled && scenePhase == .active
      && session.token == owner && generation == latencyLifecycleGeneration
  }

  private func changeRouteMode(to mode: TVRouteMode) {
    guard routeMode != mode, !isApplyingRouting, !isConnecting, !isRefreshingNodes else { return }
    let previous = routeMode
    guard connected else {
      routeMode = mode
      savedRouteMode = mode.rawValue
      selectedGroupName = nil
      updateConnectivityProxy()
      return
    }
    guard let selected = selectedNodeName ?? nodes.first?.name else { return }
    isApplyingRouting = true
    let owner = session.token
    Task { @MainActor in
      defer { isApplyingRouting = false }
      do {
        let snapshot = try await TVProxyRouting.changeMode(
          from: previous.rawValue, to: mode.rawValue, node: selected,
          read: { await liveProxies() },
          change: { await changeProxy(groupName: $0, proxyName: $1) },
          setMode: { value in
            await withCheckedContinuation { continuation in
              VPNManager.shared.updateMode(value) { continuation.resume(returning: $0) }
            }
          })
        guard session.token == owner else { return }
        routeMode = mode
        savedRouteMode = mode.rawValue
        useSnapshot(snapshot)
        errorMessage = nil
        updateConnectivityProxy()
      } catch {
        guard session.token == owner else { return }
        errorMessage = tvText(
          "代理模式切换未确认，请重试", "Proxy mode change was not confirmed. Please try again.",
          language: language)
      }
    }
  }

  private func syncVPNStatus(
    _ deliveredStatus: String? = nil,
    refreshPlanOnResume generation: Int? = nil
  ) {
    if let deliveredStatus {
      connected = deliveredStatus == "connected"
      isConnecting =
        preparingConnection || deliveredStatus == "connecting" || deliveredStatus == "disconnecting"
      updateConnectivityProxy()
      if connected { Task { await refreshLiveNodes() } }
      return
    }
    let owner = session.token
    VPNManager.shared.refreshStatus { status in
      Task { @MainActor in
        connected = status == "connected"
        isConnecting = preparingConnection || status == "connecting" || status == "disconnecting"
        updateConnectivityProxy()
        guard connected else { return }
        if let generation, generation == subscriptionForegroundGeneration,
          scenePhase == .active, let owner, session.token == owner
        {
          Task { @MainActor in
            guard generation == subscriptionForegroundGeneration, scenePhase == .active,
              session.token == owner, VPNManager.shared.statusString == "connected" else { return }
            await refreshSubscriptionSummary()
          }
        }
        await refreshLiveNodes()
      }
    }
  }

  private func performLogout(force: Bool = false) {
    guard !isLoggingOut else { return }
    guard force || !connectivity.state.protectsLogout else {
      logoutError = tvText(
        "网络状态已改变，请取消后重新确认退出。", "Network status changed. Cancel and confirm sign out again.",
        language: language)
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
    guard !preparingConnection, !isConnecting, !isApplyingRouting else { return }
    NSLog("[TVConnect] preparation started")
    preparingConnection = true
    isConnecting = true
    defer {
      preparingConnection = false
      isConnecting = false
      connectionPhase = nil
    }

    guard let token = session.token else {
      errorMessage = "登录状态已失效，请重新登录"
      return
    }
    let currentStatus: String = await withCheckedContinuation { continuation in
      VPNManager.shared.refreshStatus { continuation.resume(returning: $0) }
    }
    guard !Task.isCancelled, session.token == token else { return }
    if currentStatus == "connected" {
      syncVPNStatus(currentStatus)
      return
    }
    NSLog("[TVConnect] current status=%@", currentStatus)
    guard currentStatus == "disconnected" else {
      syncVPNStatus(currentStatus)
      return
    }
    connectionPhase = tvText("检查订阅", "Checking plan", language: language)
    await refreshSubscriptionSummary()
    guard session.token == token else { return }
    guard subscriptionSummary != nil else {
      errorMessage =
        homeInfoError
        ?? tvText(
          "无法确认订阅状态，请检查网络后重试", "Could not verify your plan. Check the network and retry.",
          language: language)
      return
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
      NSLog("[TVConnect] generating runtime configuration")
      let config = try applyingRouteMode(to: downloaded)
      NSLog("[TVConnect] runtime configuration ready")
      connectionPhase = tvText("核心回连", "Starting core", language: language)
      if let failure = await connectVPN(config: config) {
        errorMessage = failure
        connected = false
        return
      }
      connected = true
      connectionPhase = tvText("确认线路", "Checking node", language: language)
      if let failure = await applySelectedNodeIfNeeded(retries: 6) {
        VPNManager.shared.disconnect { _ in }
        connected = false
        errorMessage = failure
      } else {
        errorMessage = nil
      }
      await refreshLiveNodes(retries: 3)
      if connected, let name = selectedNodeName { scheduleSelectedLatency(name, force: true) }
    } catch {
      NSLog("[TVConnect] preparation failed type=%@ code=%ld", String(describing: type(of: error)), (error as NSError).code)
      if handleExpiredSession(error) { return }
      connected = false
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func loadNodes(forceRefresh: Bool) async {
    guard !isLoadingNodes else { return }
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
      if !forceRefresh, connected, await refreshLiveNodes(), !nodes.isEmpty { return }
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
        nodeLoadError = tvText(
          "订阅中没有可用线路", "No available nodes in this subscription", language: language)
        return
      }
      guard !Task.isCancelled, session.token == token else { return }
      if forceRefresh, VPNManager.shared.isTunnelRunning {
        let runtimeConfig = try applyingRouteMode(to: configuration)
        let failure: String? = await withCheckedContinuation { continuation in
          VPNManager.shared.sendConfigUpdate(runtimeConfig) {
            continuation.resume(returning: $0)
          }
        }
        guard session.token == token else { return }
        guard failure == nil,
          let response = await liveProxies(),
          let snapshot = TVSubscriptionNodes.liveSnapshot(from: response, mode: routeMode.rawValue),
          let target = snapshot.nodes.first(where: { $0.name == selectedNodeName })?.name
            ?? snapshot.nodes.first?.name
        else {
          VPNManager.shared.disconnect { _ in }
          connected = false
          nodeLoadError = tvText(
            "订阅应用未确认，已断开连接，请重试",
            "Subscription update was not confirmed. Disconnected; please try again.",
            language: language)
          return
        }
        do {
          let verified = try await TVProxyRouting.select(
            mode: routeMode.rawValue, node: target,
            read: { await liveProxies() },
            change: { await changeProxy(groupName: $0, proxyName: $1) })
          guard session.token == token else { return }
          cachedSubscription = configuration
          useSnapshot(verified)
          return
        } catch {
          VPNManager.shared.disconnect { _ in }
          connected = false
          nodeLoadError = tvText(
            "订阅线路应用失败，已断开连接，请重试",
            "Updated nodes could not be applied. Disconnected; please try again.",
            language: language)
          return
        }
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
      guard !Task.isCancelled, session.token == token else { return }
      if handleExpiredSession(error) { return }
      nodeLoadError = error.localizedDescription
    }
  }

  @discardableResult
  @MainActor
  private func refreshLiveNodes(retries: Int = 1) async -> Bool {
    guard !isApplyingRouting, !isRefreshingNodes else { return false }
    for attempt in 0..<max(1, retries) {
      if let response = await liveProxies(),
        let snapshot = TVSubscriptionNodes.liveSnapshot(from: response, mode: routeMode.rawValue),
        !snapshot.nodes.isEmpty
      {
        selectedGroupName = snapshot.groupName
        nodes = snapshot.nodes
        if let liveSelection = snapshot.selectedName,
          liveSelection != "DIRECT", liveSelection != "REJECT"
        {
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

  @MainActor
  private func useSnapshot(_ snapshot: TVProxySnapshot) {
    selectedGroupName = snapshot.groupName
    nodes = snapshot.nodes
    selectedNodeName = snapshot.selectedName
    savedSelectedNode = snapshot.selectedName ?? ""
    nodeLoadError = nil
  }

  private func applySelectedNodeIfNeeded(retries: Int = 1) async -> String? {
    for attempt in 0..<max(1, retries) {
      if let response = await liveProxies(),
        let snapshot = TVSubscriptionNodes.liveSnapshot(from: response, mode: routeMode.rawValue),
        let target = snapshot.nodes.first(where: { $0.name == selectedNodeName })?.name
          ?? snapshot.nodes.first?.name
      {
        do {
          let verified = try await TVProxyRouting.select(
            mode: routeMode.rawValue, node: target, read: { await liveProxies() },
            change: { await changeProxy(groupName: $0, proxyName: $1) })
          await MainActor.run { useSnapshot(verified) }
          return nil
        } catch {}
      }
      if attempt + 1 < retries {
        try? await Task.sleep(for: .milliseconds(350))
      }
    }
    return tvText(
      "未确认可用线路，请重试", "No usable node was confirmed. Please try again.", language: language)
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

  private func testDelay(proxyName: String, testURL: String) async -> Int? {
    await withCheckedContinuation { continuation in
      VPNManager.shared.testDelay(proxyName: proxyName, testURL: testURL) {
        continuation.resume(returning: $0)
      }
    }
  }

  private func liveProxies(timeout: TimeInterval? = nil) async -> String? {
    await withCheckedContinuation { continuation in
      VPNManager.shared.getProxies(timeout: timeout) { continuation.resume(returning: $0) }
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

  @MainActor
  private func applyCustomRouting() async throws {
    guard connected, let source = cachedSubscription else { return }
    let config = try applyingRouteMode(to: source)
    let failure: String? = await withCheckedContinuation { c in
      VPNManager.shared.sendConfigUpdate(config) { c.resume(returning: $0) }
    }
    if let failure { throw GatewayClient.GatewayError.server(failure) }
    if let failure = await applySelectedNodeIfNeeded(retries: 3) {
      throw GatewayClient.GatewayError.server(failure)
    }
  }

  private func applyingRouteMode(to source: String) throws -> String {
    let group = TVSubscriptionNodes.preferredGroupName(from: source, mode: "rule") ?? ""
    let scoped = try TVUserRouteStore.runtime(
      source, scope: session.email ?? session.token ?? "", group: group)
    let config = try TVBuildConfiguration.load().runtimeConfiguration(scoped)
    let replacement = "mode: \(routeMode.rawValue)"
    guard let expression = try? NSRegularExpression(pattern: "(?m)^mode\\s*:\\s*.*$") else {
      return config
    }
    let range = NSRange(config.startIndex..<config.endIndex, in: config)
    if expression.firstMatch(in: config, range: range) != nil {
      return expression.stringByReplacingMatches(
        in: config, range: range, withTemplate: replacement)
    }
    return replacement + "\n" + config
  }
}
