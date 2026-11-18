import CryptoKit
import SwiftUI

extension Notification.Name {
  static let tvUpdateAvailability = Notification.Name("fastcat.tv.updateAvailability")
}

struct TVToolsView: View {
  var startAbout = false
  var startAccount = false
  var accountPlan: AnyView = AnyView(EmptyView())
  var onRefreshAccount: () async -> Void = {}
  let onLogout: () -> Void
  let onRulesChanged: () async throws -> Void
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var session: SessionStore
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @AppStorage(TVTheme.preferenceKey) private var dark = true
  @State private var page = "tools"
  @State private var controlFocus: String?
  @State private var accountRefreshing = false
  @State private var lastControl: [String: String] = [:]
  @State private var focusGeneration = UUID()
  @State private var showRoutingEditor = false
  @State private var destinationDraft = ""
  @FocusState private var codeFieldFocused: Bool
  @State private var toolsSelection: String?
  @AppStorage("fastcat.tv.logs.enabled") private var logsEnabled = false
  @State private var logs: [String] = []
  @State private var logTask: Task<Void, Never>?
  @State private var logGeneration = UUID()
  @State private var update: TVUpdateInfo?
  @State private var busy = false
  @State private var message: String?
  @State private var deleteConfirmed = false
  @State private var code = ""
  @State private var codeDeadline = Date.distantPast
  @State private var rules: [TVUserRoute] = []
  @State private var destination = ""
  @State private var proxy = false
  @State private var editingRuleID: UUID?
  @State private var streaming: [String: String] = [:]
  @State private var streamTask: Task<Void, Never>?
  @State private var runID = UUID().uuidString
  private var zh: Bool { TVLanguage.resolved(from: language) == .simplifiedChinese }
  private func text(_ a: String, _ b: String) -> String { tvText(a, b, language: language) }
  private var scope: String { session.email ?? session.token ?? "" }

  @AppStorage(TVTheme.modeKey) private var themeMode = "legacy"
  @AppStorage(TVStartupPolicy.preferenceKey) private var autoConnect = false
  @State private var streamNode: String?
  @State private var streamRegion: String?
  @State private var streamTotal = 0
  @State private var streamDate: Date?
  @StateObject private var network = TVStreamingNetworkMonitor()
  @State private var streamFocus: String?
  @State private var streamCache: TVStreamingCache?
  @State private var checkingName: String?
  @State private var checkingUpdate = false
  @State private var legalTerms = false
  @State private var legalURL: String?
  @Environment(\.scenePhase) private var scenePhase

  private var activeTargets: [(String, String)] { TVStreamingTargets.media }
  private var choicePresented: Bool { page == "language" || page == "theme" }
  private var safeHorizontalInset: CGFloat {
    tv(
      CGFloat(
        TVPageSpacing.horizontal(
          logicalWidth: Double(TVLayout.logicalSize(UIScreen.main.bounds.size).width))))
  }
  var body: some View {
    TVDesignCanvas {
      ZStack {
        VStack(spacing: 0) {
          HStack(spacing: tv(16)) {
            if page == "streaming" {
              TVDirectedButton(
                id: "back", requested: $streamFocus, onMove: moveStreaming, action: back
              ) { _ in
                MaterialIcon(glyph: .arrowBack, size: 24).frame(width: tv(48), height: tv(48))
                  .background(TVTheme.primary.opacity(0.10)).clipShape(
                    RoundedRectangle(cornerRadius: tv(12), style: .continuous))
              }
            } else {
              TVDirectedButton(
                id: "back", requested: $controlFocus, onMove: moveControl, action: back
              ) { _ in
                MaterialIcon(glyph: .arrowBack, size: 24).frame(width: tv(48), height: tv(48))
                  .background(TVTheme.primary.opacity(0.10)).clipShape(
                    RoundedRectangle(cornerRadius: tv(12), style: .continuous))
              }
            }
            Text(title).font(TVFont.medium(20))
            Spacer()
          }.padding(.horizontal, safeHorizontalInset).frame(height: tv(56)).background(
            TVTheme.surface)
          ScrollViewReader { reader in
            ScrollView {
              VStack(alignment: .leading, spacing: tv(page == "tools" ? 0 : 12)) {
                Color.clear.frame(height: 0).id("top")
                if let message { note(message) }
                pageContent
              }
              .frame(maxWidth: .infinity)
              .padding(.horizontal, safeHorizontalInset)
              .padding(.top, tv(CGFloat(TVPageSpacing.contentTop)))
              .padding(.bottom, tv(CGFloat(TVPageSpacing.bottom)))
              .frame(maxWidth: .infinity)
            }.onChange(of: page) { _, newPage in
              if newPage == "tools", let toolsSelection {
                reader.scrollTo("control." + toolsSelection, anchor: .center)
                controlFocus = toolsSelection
              } else {
                reader.scrollTo("top", anchor: .top)
              }
              focusPage()
            }.onChange(of: controlFocus) { _, id in
              guard page != "streaming", let id, id != "back" else { return }
              lastControl[page] = id
              withAnimation(.easeOut(duration: 0.12)) {
                reader.scrollTo("control." + id, anchor: .center)
              }
            }.onChange(of: streamFocus) { _, id in
              if page == "streaming", let id, id != "back" {
                withAnimation(.easeOut(duration: 0.12)) {
                  reader.scrollTo("stream." + id, anchor: .center)
                }
              }
            }
          }
        }.disabled(choicePresented)
        if choicePresented { choiceDialog }
      }.background(TVTheme.background).foregroundStyle(TVTheme.textPrimary)
    }
    .alert(text("编辑分流目标", "Edit routing destination"), isPresented: $showRoutingEditor) {
      TextField(text("域名、IP 或 CIDR", "Domain, IP or CIDR"), text: $destinationDraft)
        .textInputAutocapitalization(.never).autocorrectionDisabled()
      Button(text("取消", "Cancel"), role: .cancel) { controlFocus = "routing.input" }
      Button(text("确定", "Done")) {
        destination = destinationDraft
        controlFocus = "routing.input"
      }
    }
    .onExitCommand(perform: back)
    .task {
      page = startAccount ? "account" : startAbout ? "about" : "tools"
      rules = TVUserRouteStore.load(scope: scope)
      focusPage()
      await refreshUpdate()
    }
    .onDisappear {
      stopStreaming(showMessage: false)
      stopLogs()
    }
    .onChange(of: page) { old, _ in
      if old == "streaming" { stopStreaming(showMessage: false) }
      if old == "logs" { stopLogs() }
      if page == "logs" { startLogs() }
      message = nil
    }
    .onChange(of: controlRows) { _, _ in
      if page != "streaming", !choicePresented, let controlFocus, controlFocus != "back",
        !controlRows.flatMap({ $0 }).contains(controlFocus)
      {
        focusPage()
      }
    }
    .onChange(of: controlFocus) { _, id in
      if id == "delete.code" { codeFieldFocused = true }
    }
    .onChange(of: codeFieldFocused) { _, focused in if focused { controlFocus = "delete.code" } }
    .onChange(of: network.generation) { _, _ in
      if streamTask != nil || !streaming.isEmpty {
        stopStreaming(showMessage: false)
        streamCache = nil
        streaming = [:]
        streamNode = nil
        streamRegion = nil
        message = text("网络已变化，请重新检测", "Network changed. Run the check again.")
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        stopStreaming(showMessage: true)
        stopLogs()
      } else {
        if page == "logs" { startLogs() }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: VPNManager.statusDidChangeNotification)) {
      _ in
      if !VPNManager.shared.isConnected && (streamTask != nil || !streaming.isEmpty) {
        stopStreaming(showMessage: false)
        streamCache = nil
        streaming = [:]
        streamNode = nil
        streamRegion = nil
        message = text("连接已变化，请重新检测", "Connection changed. Run the check again.")
      }
    }
  }

  @ViewBuilder private var pageContent: some View {
    if page == "tools" || page == "language" || page == "theme" {
      sectionHeader(text("应用", "Application"))
      menuGroup {
        row(
          "语言", "Language", icon: "globe",
          subtitle: language == "system"
            ? text("跟随系统", "System") : TVLanguage(rawValue: language)?.displayName
        ) { page = "language" }
        menuDivider
        row(
          "主题", "Theme", icon: "circle.lefthalf.filled", subtitle: themeLabel
        ) { page = "theme" }
        menuDivider
        row(
          "自启动", "Startup", icon: "power",
          subtitle: text("启动与自动运行设置", "Startup and auto-run settings")
        ) { page = "startup" }
      }
      sectionHeader(text("网络", "Network"))
      menuGroup {
        row("自定义分流", "Custom routing", icon: "arrow.triangle.branch") {
          page = "routing"
        }
        menuDivider
        row("流媒体检测", "Streaming check", icon: "play.tv") {
          page = "streaming"
        }
      }
      sectionHeader(text("其他", "Other"))
      menuGroup { row("关于", "About", icon: "info.circle", badge: update != nil) { page = "about" } }
    } else if page == "account" {
      menuGroup {
        HStack(spacing: tv(16)) {
          MaterialIcon(glyph: .emailOutlined, size: 22, color: TVTheme.primary)
          VStack(alignment: .leading, spacing: tv(4)) {
            Text(text("邮箱", "Email")).font(TVFont.regular(16))
            Text(session.email ?? text("邮箱暂不可用", "Email unavailable")).font(TVFont.regular(14))
              .foregroundStyle(TVTheme.textSecondary)
          }
          Spacer()
        }.padding(tv(16))
      }
      TVDirectedButton(
        id: "account.plan", requested: $controlFocus, onMove: moveControl, cornerRadius: tv(20),
        action: {
          guard !accountRefreshing else { return }
          accountRefreshing = true
          Task {
            await onRefreshAccount()
            accountRefreshing = false
          }
        }
      ) { _ in
        accountPlan.overlay(alignment: .topTrailing) {
          if accountRefreshing { ProgressView().padding(tv(12)) }
        }
      }.padding(.top, tv(12))
      menuGroup {
        TVDirectedButton(
          id: "account.logout", requested: $controlFocus, onMove: moveControl, cornerRadius: tv(14),
          action: {
            dismiss()
            onLogout()
          }
        ) { _ in
          HStack {
            MaterialIcon(glyph: .logoutOutlined, size: 20)
            Text(text("退出登录", "Sign out")).font(TVFont.medium(14))
          }
          .frame(maxWidth: .infinity, minHeight: tv(48)).background(TVTheme.surfaceHighest)
          .clipShape(RoundedRectangle(cornerRadius: tv(14), style: .continuous))
        }.padding(tv(16))
      }.padding(.top, tv(24))
      HStack {
        Spacer()
        smallButton(text("注销账号", "Delete account"), danger: true, controlID: "account.delete") {
          page = "delete"
          deleteConfirmed = false
          code = ""
        }
        Spacer()
      }.padding(.top, tv(28))
    } else if page == "startup" {
      VStack(spacing: 0) {
        switchRow(
          text("开机启动", "Launch at startup"),
          subtitle: text("当前平台暂不支持开机启动", "Not supported on this platform"), enabled: false,
          value: false
        ) {}
        Divider().padding(.leading, tv(68))
        switchRow(
          text("自动运行", "Auto run"),
          subtitle: text("打开客户端时自动连接 VPN", "Connect VPN automatically when opening the app"),
          enabled: true, value: autoConnect, controlID: "startup.auto"
        ) { autoConnect.toggle() }
      }.background(TVTheme.surface).clipShape(
        RoundedRectangle(cornerRadius: tv(20), style: .continuous))
    } else if page == "about" {
      VStack(spacing: tv(4)) {
        TVBrandLogo().padding(tv(10)).frame(width: tv(88), height: tv(88)).background(
          TVTheme.primary.opacity(0.10)
        ).clipShape(RoundedRectangle(cornerRadius: tv(26), style: .continuous))
        Text(text("快猫", "FastCat")).font(TVFont.regular(24)).padding(.top, tv(8))
        Text(
          "V"
            + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
              ?? "")
        ).font(TVFont.regular(14))
      }.frame(maxWidth: .infinity)
      row(
        "检查更新", "Check for updates", icon: "arrow.clockwise", badge: update != nil,
        loading: checkingUpdate
      ) { checkUpdate(open: true) }
      .background(TVTheme.surface).clipShape(
        RoundedRectangle(cornerRadius: tv(20), style: .continuous)
      ).padding(
        .top, tv(12))
      if logsEnabled {
        menuGroup { row("日志", "Logs", icon: "doc.text") { page = "logs" } }
      }
      HStack(spacing: tv(8)) {
        Spacer()
        smallButton(text("隐私政策", "Privacy Policy"), controlID: "about.privacy") {
          openLegal(terms: false)
        }
        Text("|").foregroundStyle(TVTheme.textSecondary)
        smallButton(text("服务条款", "Terms of Service"), controlID: "about.terms") {
          openLegal(terms: true)
        }
        Spacer()
      }.padding(.top, tv(24))
      Text("© \(Calendar.current.component(.year,from:Date())) FastCat").font(TVFont.regular(12))
        .foregroundStyle(TVTheme.textSecondary).frame(maxWidth: .infinity)
    } else if page == "legal" {
      if let legalURL {
        TVQRCodeView(payload: legalURL).padding(tv(12)).background(.white).frame(
          width: tv(200), height: tv(200)
        ).frame(maxWidth: .infinity)
        note(text("用手机扫描二维码阅读完整内容", "Scan with your phone to read the full document"))
      } else {
        ProgressView().frame(maxWidth: .infinity)
      }
    } else if page == "logs" {
      HStack {
        smallButton(
          logTask == nil ? text("继续记录", "Resume") : text("暂停", "Pause"), controlID: "logs.toggle"
        ) {
          if logTask == nil { startLogs() } else { stopLogs() }
        }
        smallButton(text("清空日志", "Clear logs"), danger: true, controlID: "logs.clear") { logs = [] }
      }
      if logs.isEmpty {
        note(text("暂无日志，连接 VPN 后可记录核心运行日志", "No logs. Connect VPN to capture core runtime logs."))
      }
      ForEach(Array(logs.enumerated()), id: \.offset) { index, line in
        TVDirectedButton(
          id: "logs.line.\(index)", requested: $controlFocus, onMove: moveControl, action: {}
        ) { _ in
          Text(line).font(TVFont.regular(12)).foregroundStyle(TVTheme.textSecondary).frame(
            maxWidth: .infinity, alignment: .leading
          ).padding(tv(10)).background(TVTheme.surface)
        }
      }
    } else if page == "delete" {
      deletionContent
    } else if page == "routing" {
      routingContent
    } else if page == "streaming" {
      streamingContent
    }
  }

  @ViewBuilder private var deletionContent: some View {
    note(
      text(
        "注销会使所有设备退出登录，套餐、余额、佣金及订阅失效；此操作不可撤销。",
        "Deletion signs out all devices and invalidates plans, balance, commissions and subscriptions. This cannot be undone."
      ))
    if !deleteConfirmed {
      row("取消", "Cancel", icon: "xmark") { page = "account" }
      row("继续注销流程", "Continue deletion", icon: "trash", danger: true) { deleteConfirmed = true }
    } else {
      Text(session.email ?? "").font(TVFont.regular(14))
      TextField(text("6 位邮箱验证码", "6-digit email code"), text: $code).keyboardType(.numberPad)
        .focused($codeFieldFocused).id("control.delete.code").onMoveCommand {
          moveControl($0, "delete.code")
        }
        .onChange(of: code) { _, value in
          code = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
        }
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let remaining = max(0, Int(ceil(codeDeadline.timeIntervalSince(context.date))))
        row(
          remaining > 0 ? "\(remaining) 秒后重发" : "发送验证码",
          remaining > 0 ? "Resend in \(remaining)s" : "Send code", icon: "envelope",
          controlID: "delete.send"
        ) { sendDeletionCode() }.disabled(remaining > 0 || busy)
      }
      row("确认注销账号", "Delete account permanently", icon: "trash", danger: true) { deleteAccount() }
        .disabled(code.count != 6 || busy)
    }
  }
  @ViewBuilder private var routingContent: some View {
    note(
      text(
        "为域名和 IP 设置直连或代理；规则从上到下匹配，修改后立即生效。",
        "Set direct or proxy routes for domains and IPs. Rules match from top to bottom and changes apply immediately."
      ))
    VStack(spacing: tv(12)) {
      TVDirectedButton(id: "routing.input", requested: $controlFocus, onMove: moveControl) {
        destinationDraft = destination
        showRoutingEditor = true
      } label: { _ in
        Text(destination.isEmpty ? text("域名、IP 或 CIDR", "Domain, IP or CIDR") : destination)
          .font(TVFont.regular(14))
          .foregroundStyle(destination.isEmpty ? TVTheme.textSecondary : TVTheme.textPrimary)
          .lineLimit(1).truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, tv(14)).frame(height: tv(48))
          .background(TVTheme.inputFill)
          .clipShape(RoundedRectangle(cornerRadius: tv(12), style: .continuous))
      }.disabled(busy)
      HStack {
        choiceButton(text("直连", "Direct"), selected: !proxy, controlID: "routing.direct") {
          proxy = false
        }
        choiceButton(text("代理", "Proxy"), selected: proxy, controlID: "routing.proxy") {
          proxy = true
        }
        Spacer()
        smallButton(
          editingRuleID == nil ? text("添加", "Add") : text("保存", "Save"),
          disabled: destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy,
          controlID: "routing.save"
        ) { saveRule() }
        if editingRuleID != nil {
          smallButton(text("取消编辑", "Cancel edit"), disabled: busy, controlID: "routing.cancel") {
            destination = ""
            editingRuleID = nil
          }
        }
      }.disabled(busy)
    }.padding(tv(12)).background(TVTheme.surface).clipShape(
      RoundedRectangle(cornerRadius: tv(20), style: .continuous))
    if rules.isEmpty { note(text("暂无自定义规则", "No custom rules")) }
    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
      HStack(spacing: tv(12)) {
        VStack(alignment: .leading, spacing: tv(4)) {
          Text(rule.destination).font(TVFont.regular(16)).lineLimit(1).truncationMode(.middle)
          Text(rule.proxy ? text("代理", "Proxy") : text("直连", "Direct")).font(TVFont.regular(12))
            .foregroundStyle(TVTheme.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: tv(4)) {
          smallButton(
            text("编辑", "Edit"), disabled: busy, controlID: "rule.\(rule.id.uuidString).edit"
          ) {
            destination = rule.destination
            proxy = rule.proxy
            editingRuleID = rule.id
          }
          smallButton(
            text("删除", "Delete"), disabled: busy, danger: true,
            controlID: "rule.\(rule.id.uuidString).delete"
          ) { changeRules { $0.remove(at: index) } }
          smallButton(
            text("上移", "Move up"), disabled: busy || index == 0,
            controlID: "rule.\(rule.id.uuidString).up", focusableWhenDisabled: !busy
          ) {
            guard index > 0 else { return }
            changeRules { $0.insert($0.remove(at: index), at: index - 1) }
          }
          smallButton(
            text("下移", "Move down"), disabled: busy || index + 1 == rules.count,
            controlID: "rule.\(rule.id.uuidString).down", focusableWhenDisabled: !busy
          ) {
            guard index + 1 < rules.count else { return }
            changeRules { $0.insert($0.remove(at: index), at: index + 1) }
          }
        }.fixedSize(horizontal: true, vertical: false)
      }.padding(tv(12)).frame(maxWidth: .infinity).background(TVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: tv(16), style: .continuous))
    }
  }

  private var streamingContent: some View {
    VStack(alignment: .leading, spacing: tv(16)) {
      VStack(alignment: .leading, spacing: tv(14)) {
        Label(
          VPNManager.shared.isConnected ? text("已连接", "Connected") : text("未连接", "Disconnected"),
          systemImage: "circle.fill"
        ).font(TVFont.regular(14)).foregroundStyle(
          VPNManager.shared.isConnected ? TVTheme.success : TVTheme.warning)
        HStack {
          TVDirectedButton(
            id: "start", requested: $streamFocus, onMove: moveStreaming,
            action: { if !busy && VPNManager.shared.isConnected { startStreaming() } }
          ) { _ in
            HStack {
              MaterialIcon(glyph: .liveTV, size: 18, color: TVTheme.onPrimary)
              Text(
                busy
                  ? text("检测中…", "Checking…")
                  : streaming.isEmpty ? text("开始检测", "Start check") : text("重新检测", "Retest")
              ).font(TVFont.medium(14))
            }
            .padding(.horizontal, tv(16)).frame(minHeight: tv(44)).foregroundStyle(
              TVTheme.onPrimary
            ).background(TVTheme.primary).clipShape(
              RoundedRectangle(cornerRadius: tv(14), style: .continuous))
          }.id("stream.start").opacity(VPNManager.shared.isConnected ? 1 : 0.5)
          if streamTask != nil {
            TVDirectedButton(
              id: "stop", requested: $streamFocus, onMove: moveStreaming,
              action: { stopStreaming(showMessage: true) }
            ) { _ in Text(text("停止", "Stop")).font(TVFont.medium(14)).padding(tv(12)) }.id(
              "stream.stop")
          }
          if let checkingName {
            ProgressView()
            Text(checkingName).font(TVFont.regular(14))
          }
        }
      }.padding(tv(16)).frame(maxWidth: .infinity, alignment: .leading).background(TVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: tv(20), style: .continuous))
      if !VPNManager.shared.isConnected { note(text("请先连接 VPN", "Connect VPN first")) }
      if let streamNode {
        Text(text("检测概览", "Summary")).font(TVFont.medium(14))
        menuGroup {
          VStack(spacing: tv(8)) {
            summaryLine(text("当前节点", "Current node"), streamNode)
            summaryLine(text("出口地区", "Exit region"), streamRegion ?? "—")
            summaryLine(text("检测进度", "Progress"), "\(streaming.count)/\(streamTotal)")
            summaryLine(
              text("可用数量", "Accessible"),
              "\(streaming.values.filter {TVStreamingTargets.isAccessible($0)}.count)/\(streamTotal)"
            )
          }.padding(tv(14))
        }
      }
      if !streaming.isEmpty {
        Text(text("检测结果", "Results")).font(TVFont.medium(14))
        streamingGrid
      }
      note(
        text(
          "网页可访问不代表会员内容一定解锁；结果仅反映当前节点与当前网络。",
          "Web access does not prove entitlement or playback unlock. Results reflect the current node and network only."
        ))
    }
  }
  private var streamingNames: [String] {
    TVStreamingTargets.media.map(\.0).filter { streaming[$0] != nil }
  }
  private func moveStreaming(_ direction: MoveCommandDirection, _ id: String) {
    let key: String
    switch direction {
    case .up: key = "up"
    case .down: key = "down"
    case .left: key = "left"
    case .right: key = "right"
    @unknown default: return
    }
    if let next = TVStreamingNavigation.next(
      from: id, direction: key, names: streamingNames, canStop: streamTask != nil)
    {
      streamFocus = next
    }
  }
  private var streamingGrid: some View {
    // Ten bounded results stay mounted, including the toolbar and last row.
    VStack(spacing: tv(10)) {
      ForEach(Array(stride(from: 0, to: streamingNames.count, by: 2)), id: \.self) { start in
        HStack(spacing: tv(12)) {
          resultCard(streamingNames[start])
          if start + 1 < streamingNames.count {
            resultCard(streamingNames[start + 1])
          } else {
            Color.clear.frame(maxWidth: .infinity)
          }
        }
      }
    }
  }
  private func resultCard(_ name: String) -> some View {
    let outcome = streaming[name] ?? "—"
    let statusLabel = outcome.replacingOccurrences(
      of: " · [A-Z]{2}$", with: "", options: .regularExpression)
    let resultRegion =
      outcome.range(of: " · [A-Z]{2}$", options: .regularExpression) != nil
      ? String(outcome.suffix(2)) : (streamRegion ?? "—")
    let color =
      TVStreamingTargets.isFullyAccessible(outcome)
      ? TVTheme.success
      : outcome.localizedCaseInsensitiveContains("restricted") || outcome.contains("受限")
        || outcome.contains("拒绝") || outcome.localizedCaseInsensitiveContains("blocked")
        ? TVTheme.danger : TVTheme.warning
    return TVDirectedButton(
      id: "result:" + name, requested: $streamFocus, onMove: moveStreaming, cornerRadius: tv(16),
      action: {}
    ) { _ in
      HStack(spacing: tv(10)) {
        TVStreamingBrand(name: name).frame(width: tv(36), height: tv(36))
        VStack(alignment: .leading, spacing: tv(4)) {
          Text(name).font(TVFont.medium(14)).lineLimit(1)
          Text(resultRegion).font(TVFont.regular(12)).foregroundStyle(TVTheme.textSecondary)
        }
        Spacer(minLength: tv(8))
        Text(statusLabel).font(TVFont.medium(12)).foregroundStyle(color).lineLimit(2)
          .multilineTextAlignment(.trailing)
      }.padding(.horizontal, tv(12)).frame(maxWidth: .infinity, minHeight: tv(66)).contentShape(
        Rectangle()
      )
      .background(TVTheme.surface).clipShape(
        RoundedRectangle(cornerRadius: tv(16), style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: tv(16), style: .continuous).strokeBorder(
          TVTheme.stroke, lineWidth: tv(1))
      }
    }.id("stream.result:" + name)
  }
  @ViewBuilder private var choiceDialog: some View {
    TVDialog(title: title, icon: nil) {
      if page == "language" {
        VStack(spacing: tv(4)) {
          ForEach(TVLanguage.allCases, id: \.rawValue) { item in
            choiceButton(
              item == .system ? text("跟随系统", "System") : item.displayName,
              selected: language == item.rawValue
            ) {
              language = item.rawValue
              page = "tools"
              Task { await refreshUpdate() }
            }
          }
        }
      } else {
        VStack(spacing: tv(4)) {
          ForEach(["system", "light", "dark"], id: \.self) { mode in
            choiceButton(
              mode == "system"
                ? text("自动", "Auto") : mode == "light" ? text("浅色", "Light") : text("深色", "Dark"),
              selected: themeMode == mode
                || (themeMode == "legacy" && mode == (dark ? "dark" : "light"))
            ) {
              themeMode = mode
              if mode != "system" { dark = mode == "dark" }
              page = "tools"
            }
          }
        }
      }
    } actions: {
      smallButton(text("取消", "Cancel")) { page = "tools" }

    }
  }
  private var controlRows: [[String]] {
    if choicePresented { return [] }
    if busy { return [] }
    switch page {
    case "tools":
      return [
        ["row:Language"], ["row:Theme"], ["row:Startup"], ["row:Custom routing"],
        ["row:Streaming check"], ["row:About"],
      ]
    case "account": return [["account.plan"], ["account.logout"], ["account.delete"]]
    case "startup": return [["startup.auto"]]
    case "about":
      return (checkingUpdate ? [] : [["row:Check for updates"]])
        + (logsEnabled ? [["row:Logs"]] : []) + [["about.privacy", "about.terms"]]
    case "routing":
      var rows = [["routing.input"], ["routing.direct", "routing.proxy"]]
      var actions: [String] = []
      if !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        actions.append("routing.save")
      }
      if editingRuleID != nil { actions.append("routing.cancel") }
      if !actions.isEmpty { rows.append(actions) }
      for rule in rules { rows.append(TVRuleActions.identifiers(ruleID: rule.id.uuidString)) }
      return rows
    case "delete":
      if !deleteConfirmed { return [["row:Cancel"], ["row:Continue deletion"]] }
      var rows = [["delete.code"]]
      if codeDeadline <= Date() { rows.append(["delete.send"]) }
      if code.count == 6 { rows.append(["row:Delete account permanently"]) }
      return rows
    case "logs": return [["logs.toggle", "logs.clear"]] + logs.indices.map { ["logs.line.\($0)"] }
    default: return []
    }
  }
  private func focusPage() {
    let expected = page
    let generation = UUID()
    focusGeneration = generation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      guard page == expected, focusGeneration == generation, !choicePresented else { return }
      if page == "streaming" {
        streamFocus = "start"
        return
      }
      let ids = controlRows.flatMap { $0 }
      let remembered = page == "tools" ? toolsSelection : lastControl[page]
      controlFocus = remembered.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first ?? "back"
    }
  }
  private func moveControl(_ direction: MoveCommandDirection, _ id: String) {
    let key: String
    switch direction {
    case .up: key = "up"
    case .down: key = "down"
    case .left: key = "left"
    case .right: key = "right"
    @unknown default: return
    }
    if let next = TVToolsNavigation.next(from: id, direction: key, rows: controlRows) {
      controlFocus = next
    }
  }
  private var themeLabel: String {
    if themeMode == "system" { return text("自动", "Auto") }
    return (themeMode == "dark" || (themeMode == "legacy" && dark))
      ? text("深色", "Dark") : text("浅色", "Light")
  }
  private func sectionHeader(_ title: String) -> some View {
    Text(title).font(TVFont.medium(14)).foregroundStyle(TVTheme.textSecondary)
      .padding(.leading, tv(4)).padding(.top, tv(18)).padding(.bottom, tv(10)).frame(
        maxWidth: .infinity, alignment: .leading)
  }
  private var menuDivider: some View { Divider().padding(.leading, tv(68)) }
  private func menuGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0, content: content).frame(maxWidth: .infinity)
      .background {
        RoundedRectangle(cornerRadius: tv(20), style: .continuous).fill(TVTheme.surface)
          .overlay {
            RoundedRectangle(cornerRadius: tv(20), style: .continuous).strokeBorder(
              TVTheme.stroke, lineWidth: tv(1))
          }
      }
      .clipShape(RoundedRectangle(cornerRadius: tv(20), style: .continuous))
  }
  private func summaryLine(_ title: String, _ value: String) -> some View {
    HStack {
      Text(title).foregroundStyle(TVTheme.textSecondary)
      Spacer()
      Text(value)
    }.font(TVFont.regular(14))
  }
  private var title: String {
    switch page {
    case "about": return text("关于", "About")
    case "language": return text("语言", "Language")
    case "theme": return text("主题", "Theme")
    case "startup": return text("自启动", "Startup")
    case "routing": return text("自定义分流", "Custom routing")
    case "streaming": return text("流媒体检测", "Streaming check")
    case "delete": return text("注销账号", "Delete account")
    case "logs": return text("日志", "Logs")
    case "account": return text("我的账号", "My Account")
    case "legal":
      return legalTerms ? text("服务条款", "Terms of Service") : text("隐私政策", "Privacy Policy")
    default: return text("工具设置", "Tools & settings")
    }
  }
  private func materialGlyph(_ icon: String) -> MaterialGlyph {
    switch icon {
    case "globe": return .language
    case "circle.lefthalf.filled": return .brightnessSix
    case "power": return .powerSettingsNew
    case "arrow.triangle.branch": return .route
    case "play.tv": return .liveTV
    case "info.circle": return .infoOutlined
    case "rectangle.portrait.and.arrow.right": return .logout
    case "trash": return .deleteForever
    case "arrow.clockwise": return .systemUpdateOutlined
    case "doc.text": return .articleOutlined
    case "xmark": return .close
    default: return .emailOutlined
    }
  }
  private func row(
    _ a: String, _ b: String, icon: String, badge: Bool = false, danger: Bool = false,
    loading: Bool = false, subtitle: String? = nil, controlID: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    let identifier = controlID ?? "row:" + b
    return TVDirectedButton(
      id: identifier, requested: $controlFocus, onMove: moveControl, cornerRadius: tv(20),
      action: {
        if page == "tools" { toolsSelection = identifier }
        action()
      }
    ) { _ in
      HStack(spacing: tv(16)) {
        ZStack(alignment: .topTrailing) {
          MaterialIcon(glyph: materialGlyph(icon), size: 22, color: TVTheme.textSecondary).frame(
            width: tv(24), height: tv(24))
          if badge {
            Circle().fill(.red).frame(width: tv(8), height: tv(8)).offset(x: tv(3), y: -tv(3))
          }
        }
        VStack(alignment: .leading, spacing: tv(4)) {
          Text(text(a, b)).font(TVFont.regular(16)).foregroundStyle(
            danger ? TVTheme.danger : TVTheme.textPrimary)
          if let subtitle {
            Text(subtitle).font(TVFont.regular(14)).foregroundStyle(TVTheme.textSecondary)
          }
        }
        Spacer()
        if loading {
          ProgressView()
        } else {
          MaterialIcon(glyph: .chevronRight, size: 24, color: TVTheme.outline)
        }
      }.padding(.horizontal, tv(16)).padding(.vertical, tv(8)).frame(
        maxWidth: .infinity, minHeight: tv(56)
      ).contentShape(Rectangle())
    }.disabled(busy || loading)
  }
  @ViewBuilder private func smallButton(
    _ title: String, disabled: Bool = false, danger: Bool = false, controlID: String? = nil,
    focusableWhenDisabled: Bool = false, action: @escaping () -> Void
  ) -> some View {
    let activate: () -> Void = { if !disabled { action() } }
    let content = Text(title).font(TVFont.medium(14)).foregroundStyle(
      danger ? TVTheme.danger : TVTheme.primary
    )
    .padding(.horizontal, tv(16)).frame(minHeight: tv(44)).opacity(
      disabled && focusableWhenDisabled ? 0.45 : 1)
    if let controlID {
      TVDirectedButton(
        id: controlID, requested: $controlFocus, onMove: moveControl, action: activate
      ) { _ in content }.disabled(disabled && !focusableWhenDisabled)
    } else {
      TVFocusButton(action: activate) { _ in content }.disabled(disabled && !focusableWhenDisabled)
    }
  }
  @ViewBuilder private func choiceButton(
    _ title: String, selected: Bool, controlID: String? = nil, action: @escaping () -> Void
  ) -> some View {
    let content = HStack(spacing: tv(12)) {
      Image(systemName: selected ? "checkmark.circle.fill" : "circle")
      Text(title).font(TVFont.regular(16))
      Spacer()
    }
    .foregroundStyle(selected ? TVTheme.primary : TVTheme.textPrimary).padding(tv(12)).frame(
      maxWidth: .infinity, minHeight: tv(48))
    if let controlID {
      TVDirectedButton(id: controlID, requested: $controlFocus, onMove: moveControl, action: action)
      { _ in content }
    } else {
      TVFocusButton(action: action) { _ in content }
    }
  }
  @ViewBuilder private func switchRow(
    _ title: String, subtitle: String, enabled: Bool, value: Bool, controlID: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    let content = HStack(spacing: tv(16)) {
      Image(systemName: "power").font(.system(size: tv(22))).frame(width: tv(24))
      VStack(alignment: .leading, spacing: tv(4)) {
        Text(title).font(TVFont.regular(16))
        Text(subtitle).font(TVFont.regular(14)).foregroundStyle(TVTheme.textSecondary)
      }
      Spacer()
      Capsule().fill(value ? TVTheme.primary : TVTheme.outline.opacity(0.5)).frame(
        width: tv(52), height: tv(32)
      )
      .overlay {
        Circle().fill(value ? TVTheme.onPrimary : TVTheme.surface).frame(
          width: tv(24), height: tv(24)
        ).offset(x: tv(value ? 10 : -10))
      }
      Text(value ? text("开启", "On") : text("关闭", "Off")).font(TVFont.regular(14))
    }.padding(tv(16)).frame(maxWidth: .infinity, minHeight: tv(72)).opacity(enabled ? 1 : 0.45)
    if let controlID {
      TVDirectedButton(
        id: controlID, requested: $controlFocus, onMove: moveControl, cornerRadius: tv(20),
        action: action
      ) { _ in content }.disabled(!enabled)
    } else {
      TVFocusButton(cornerRadius: tv(20), action: action) { _ in content }
        .disabled(!enabled)
    }
  }
  private func note(_ value: String) -> some View {
    Text(value).font(TVFont.regular(14)).foregroundStyle(TVTheme.textSecondary).fixedSize(
      horizontal: false, vertical: true
    ).padding(tv(12)).frame(maxWidth: .infinity, alignment: .leading).background(
      TVTheme.surfaceStrong
    ).clipShape(RoundedRectangle(cornerRadius: tv(8)))
  }
  private func back() {
    if page == "logs" {
      page = "about"

    } else if page == "legal" {
      page = "about"
    } else if page == "delete" {
      page = "account"
    } else if page == "tools" || (startAbout && page == "about")
      || (startAccount && page == "account")
    {
      dismiss()
    } else {
      page = "tools"
    }
  }
  private func openLegal(terms: Bool) {
    legalTerms = terms
    legalURL = nil
    page = "legal"
    Task {
      let url = await TVRemoteConfigManager.shared.legalURL(terms: terms)
      if page == "legal" && legalTerms == terms { legalURL = url }
    }
  }
  private func saveRule() {
    changeRules { value in
      let rule = try TVUserRoute(destination: destination, proxy: proxy)
      guard !value.contains(where: { $0.id != editingRuleID && $0.destination == rule.destination })
      else { throw TVToolsError.invalidRule }
      if let id = editingRuleID, let index = value.firstIndex(where: { $0.id == id }) {
        var edited = rule
        edited.id = id
        value[index] = edited
      } else {
        value.append(rule)
      }
    }
  }
  private func startLogs() {
    guard logTask == nil, VPNManager.shared.isConnected else { return }
    let id = UUID()
    logGeneration = id
    let owner = session.token
    logTask = Task { @MainActor in
      defer { if logGeneration == id { logTask = nil } }
      let ack = await VPNManager.shared.logCommand("startLog")
      guard !Task.isCancelled, logGeneration == id, owner == session.token,
        TVCoreProtocol.isAcknowledged(ack)
      else {
        if logGeneration == id { logTask = nil }
        return
      }
      while !Task.isCancelled, logGeneration == id, owner == session.token,
        VPNManager.shared.isConnected, page == "logs",
        scenePhase == .active
      {
        if let raw = await VPNManager.shared.logCommand("drainLogs"), !Task.isCancelled,
          logGeneration == id
        {
          let additions = TVLogSanitizer.lines(raw)
          logs = Array((logs + additions).suffix(200))
        }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }
  private func stopLogs() {
    guard logTask != nil else { return }
    logTask?.cancel()
    logTask = nil
    logGeneration = UUID()
    Task { _ = await VPNManager.shared.logCommand("stopLog") }
  }
  private func clearStreamResults() {
    streaming = [:]
    streamNode = nil
    streamRegion = nil
    streamDate = nil
    message = nil
  }
  private func isSameStreamingNode(_ name: String) async -> Bool {
    guard !Task.isCancelled, VPNManager.shared.isConnected else { return false }
    let raw: String? = await withCheckedContinuation { c in
      VPNManager.shared.getProxies { c.resume(returning: $0) }
    }
    guard let raw else { return false }
    return TVSubscriptionNodes.liveSnapshot(
      from: raw, mode: UserDefaults.standard.string(forKey: "fastcat.tv.route-mode") ?? "rule")?
      .selectedName == name
  }
  private func stopStreaming(showMessage: Bool) {
    guard streamTask != nil else { return }
    streamTask?.cancel()
    streamTask = nil
    VPNManager.shared.cancelStreaming(runID: runID)
    runID = UUID().uuidString
    busy = false
    checkingName = nil
    if showMessage {
      message = text("检测已停止，保留已完成结果", "Check stopped. Completed results are retained.")
    }
  }
  private func refreshUpdate() async {
    update = await TVRemoteConfigManager.shared.availableTVUpdate(
      language: TVLanguage.resolved(from: language))
    NotificationCenter.default.post(name: .tvUpdateAvailability, object: update != nil)
  }
  private func checkUpdate(open: Bool) {
    guard !checkingUpdate else { return }
    checkingUpdate = true
    Task {
      defer { checkingUpdate = false }
      do {
        let online = try await TVRemoteConfigManager.shared.refresh()
        await refreshUpdate()
        guard page == "about" else { return }
        if update != nil && open {
          dismiss()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .tvRefreshRemoteConfiguration, object: nil)
          }
        } else {
          message =
            online
            ? text("当前已是最新版本", "You are up to date")
            : text(
              "无法确认最新版本，当前使用已校验的缓存配置",
              "Could not confirm the latest version. Using verified cached configuration.")
        }
      } catch {
        if page == "about" {
          message = text(
            "检查更新失败，请检查网络后重试", "Update check failed. Check your network and try again.")
        }
      }
    }
  }
  private func sendDeletionCode() {
    guard !busy, let token = session.token else { return }
    busy = true
    Task {
      defer { busy = false }
      do {
        let client = try await GatewayClient.configured()
        try await client.sendDeletionCode(token: token)
        guard session.token == token else { return }
        codeDeadline = Date().addingTimeInterval(60)
        message = text("验证码已发送", "Verification code sent")
      } catch { message = error.localizedDescription }
    }
  }
  private func deleteAccount() {
    guard !busy, let token = session.token else { return }
    busy = true
    Task {
      defer { busy = false }
      do {
        let client = try await GatewayClient.configured()
        try await client.deleteAccount(token: token, code: code)
        guard session.token == token else { return }
        TVUserRouteStore.save([], scope: scope)
        VPNManager.shared.disconnect { _ in }
        await GatewayClient.clearCachedSubscriptions()
        KeychainStore.delete(key: "saved-login-email")
        KeychainStore.delete(key: "saved-login-password")
        session.signOut()
        dismiss()
      } catch { message = error.localizedDescription }
    }
  }
  private func changeRules(_ mutate: (inout [TVUserRoute]) throws -> Void) {
    guard !busy else { return }
    var candidate = rules
    do { try mutate(&candidate) } catch {
      message = text("规则无效或目标已存在", "Invalid rule or duplicate destination")
      return
    }
    let old = rules
    let previousFocus = controlFocus
    let owner = session.token
    TVUserRouteStore.save(candidate, scope: scope)
    busy = true
    Task {
      defer {
        busy = false
        if page == "routing", session.token == owner {
          focusGeneration = UUID()
          DispatchQueue.main.async {
            guard page == "routing", session.token == owner, !busy else { return }
            let ids = controlRows.flatMap { $0 }
            controlFocus = previousFocus.flatMap { ids.contains($0) ? $0 : nil } ?? "routing.input"
          }
        }
      }
      do {
        try await onRulesChanged()
        rules = candidate
        destination = ""
        editingRuleID = nil
      } catch {
        TVUserRouteStore.save(old, scope: scope)
        do { try await onRulesChanged() } catch { VPNManager.shared.disconnect { _ in } }
        message = error.localizedDescription
      }
    }
  }
  private func checkStreamingTarget(name: String, url: String, node: String, id: String) async
    -> [String: Any]?
  {
    var endpoint = url
    var method = "GET"
    var body = ""
    var headers: [String: String] = [:]
    var timeout = 8000
    var size = 262144
    switch name {
    case "BBC iPlayer":
      endpoint =
        "https://open.live.bbc.co.uk/mediaselector/6/select/version/2.0/mediaset/pc/vpid/bbc_one_london/format/json/jsfunc/JS_callbacks0"
      timeout = 16000
    case "DAZN":
      endpoint = "https://startup.core.indazn.com/misl/v5/Startup"
      method = "POST"
      timeout = 12000
      body = String(
        decoding: try! JSONSerialization.data(
          withJSONObject: [
            "Version": "2", "LandingPageKey": "generic", "Languages": "zh-CN", "Platform": "web",
            "Manufacturer": "", "PromoCode": "", "PlatformAttributes": [:],
          ] as [String: Any]), as: UTF8.self)
      headers = [
        "Content-Type": "application/json", "Origin": "https://www.dazn.com",
        "Referer": "https://www.dazn.com/",
      ]
    case "YouTube Premium":
      headers = ["Accept-Language": "en-US,en;q=0.9"]
      timeout = 16000
      size = 1_048_576
    case "Prime Video":
      timeout = 18000
      size = 1_572_864
    case "ChatGPT":
      endpoint = "https://api.openai.com/compliance/cookie_requirements"
      headers = [
        "Authorization": "Bearer null", "Origin": "https://platform.openai.com",
        "Referer": "https://platform.openai.com/", "Accept": "application/json",
      ]
    case "Claude":
      endpoint = "https://api.anthropic.com/v1/messages"
      method = "POST"
      body = String(
        decoding: try! JSONSerialization.data(withJSONObject: [
          "model": "claude-sonnet-4-5", "max_tokens": 1,
          "messages": [["role": "user", "content": "test"]],
        ]), as: UTF8.self)
      headers = [
        "Content-Type": "application/json", "Anthropic-Version": "2023-06-01",
        "Accept": "application/json",
      ]
    default: break
    }
    func probe() -> AnyTVProbe {
      AnyTVProbe(
        runID: id, node: node, url: endpoint, method: method, body: body, headers: headers,
        timeout: timeout, size: size)
    }
    var result = await probe().execute()
    let error = (result?["error"] as? String ?? "").lowercased()
    if ["YouTube Premium", "Prime Video", "BBC iPlayer", "DAZN"].contains(name),
      result?["ok"] as? Bool != true,
      ["timeout", "deadline", "eof", "tls", "ssl", "connection reset", "broken pipe", "ws closed"]
        .contains(where: { error.contains($0) }), !Task.isCancelled
    {
      try? await Task.sleep(for: .milliseconds(400))
      if !Task.isCancelled { result = await probe().execute() }
    }
    guard !Task.isCancelled else { return nil }
    var auxURL: String?
    if name == "Netflix" { auxURL = "https://www.netflix.com/title/81280792" }
    if name == "BBC iPlayer" { auxURL = "https://www.bbc.co.uk/userinfo" }
    if name == "Crunchyroll" { auxURL = "https://c.evidon.com/geo/country.js" }
    if let auxURL {
      let aux = await VPNManager.shared.streamingProbe(runID: id, node: node, url: auxURL)
      result?["aux"] = aux
    }
    return result
  }

  private func startStreaming() {
    guard VPNManager.shared.isConnected, !busy else {
      message = text("请先连接 VPN", "Connect VPN first")
      return
    }
    let forceRefresh = !streaming.isEmpty
    let targets = activeTargets
    guard !targets.isEmpty else { return }
    busy = true
    streamDate = Date()
    streaming = [:]
    streamNode = nil
    streamRegion = nil
    streamTotal = targets.count
    message = nil
    runID = UUID().uuidString
    let owner = session.token
    let id = runID
    streamTask = Task { @MainActor in
      defer {
        if runID == id {
          busy = false
          streamTask = nil
          checkingName = nil
          if streamFocus == "stop" { streamFocus = "start" }
        }
      }
      guard
        let raw = await withCheckedContinuation({ c in
          VPNManager.shared.getProxies { c.resume(returning: $0) }
        }),
        let graph = TVSubscriptionNodes.liveSnapshot(
          from: raw, mode: UserDefaults.standard.string(forKey: "fastcat.tv.route-mode") ?? "rule"),
        let node = graph.selectedName
      else {
        message = text("无法读取当前节点", "Current node unavailable")
        return
      }
      guard !Task.isCancelled, session.token == owner, runID == id else { return }
      if !forceRefresh, let cache = streamCache,
        cache.matches(
          account: owner ?? "", node: node, network: network.generation, language: language)
      {
        streaming = cache.results
        streamRegion = cache.region
        streamDate = cache.created
        streamNode = node
        message = text("已显示 10 分钟内的缓存结果", "Showing results cached within 10 minutes")
        return
      }
      streamNode = node
      let trace = await VPNManager.shared.streamingProbe(
        runID: id, node: node, url: "https://www.cloudflare.com/cdn-cgi/trace")
      guard !Task.isCancelled, session.token == owner else { return }
      if let body = trace?["body"] as? String,
        let range = body.range(of: "(?m)^loc=([A-Z]{2})$", options: .regularExpression)
      {
        streamRegion = String(body[range]).replacingOccurrences(of: "loc=", with: "")
      }
      let generation = network.generation
      for start in stride(from: 0, to: targets.count, by: 3) {
        guard !Task.isCancelled, session.token == owner, VPNManager.shared.isConnected, runID == id
        else { break }
        let same = await isSameStreamingNode(node)
        guard !Task.isCancelled, runID == id else { break }
        guard same else {
          clearStreamResults()
          streamCache = nil
          message = text("节点已变化，请重新检测", "Node changed. Run the check again.")
          break
        }
        let batch = Array(targets[start..<min(start + 3, targets.count)])
        checkingName = batch.map(\.0).joined(separator: " / ")
        let outcomes = await withTaskGroup(
          of: (String, String).self, returning: [String: String].self
        ) { group in
          for (name, url) in batch {
            group.addTask { @MainActor in
              guard !Task.isCancelled else { return (name, "") }
              let raw = await checkStreamingTarget(name: name, url: url, node: node, id: id)
              return (name, TVStreamingTargets.summary(raw, chinese: zh, name: name))
            }
          }
          var values: [String: String] = [:]
          for await (name, outcome) in group { values[name] = outcome }
          return values
        }
        guard !Task.isCancelled, session.token == owner, runID == id else { break }
        let stillSame = await isSameStreamingNode(node)
        guard !Task.isCancelled, runID == id else { break }
        guard stillSame else {
          clearStreamResults()
          streamCache = nil
          message = text("节点已变化，请重新检测", "Node changed. Run the check again.")
          break
        }
        streaming.merge(outcomes) { _, new in new }
      }
      if !Task.isCancelled, runID == id, session.token == owner, streaming.count == targets.count {
        streamCache = TVStreamingCache(
          account: owner ?? "", node: node, network: generation, language: language,
          created: Date(), region: streamRegion, results: streaming)
      }

    }
  }
}

private struct AnyTVProbe {
  let runID: String
  let node: String
  let url: String
  let method: String
  let body: String
  let headers: [String: String]
  let timeout: Int
  let size: Int
  func execute() async -> [String: Any]? {
    await VPNManager.shared.streamingProbe(
      runID: runID, node: node, url: url, method: method, body: body, headers: headers,
      timeout: timeout, maxBodySize: size)
  }
}

private struct TVDirectedButton<Label: View>: View {
  let id: String
  @Binding var requested: String?
  var onMove: ((MoveCommandDirection, String) -> Void)? = nil
  var cornerRadius: CGFloat? = nil
  let action: () -> Void
  @ViewBuilder let label: (Bool) -> Label
  @FocusState private var focused: Bool
  private var button: some View {
    TVFocusButton(
      cornerRadius: cornerRadius ?? tv(12), focus: $focused,
      action: action,
      label: label
    )
    .id("control." + id)
    .onAppear { if requested == id { DispatchQueue.main.async { focused = true } } }
    .onChange(of: requested) { _, value in if value == id { focused = true } }
    .onChange(of: focused) { _, value in if value { requested = id } }
  }
  var body: some View {
    if let onMove { button.onMoveCommand { onMove($0, id) } } else { button }
  }
}
private struct TVStreamingBrand: View {
  let name: String
  @Environment(\.colorScheme) private var scheme
  private func brandColor(_ value: UInt32) -> Color {
    Color(
      red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
      blue: Double(value & 255) / 255)
  }
  private var color: Color {
    switch name {
    case "Netflix": return brandColor(0xE50914)
    case "YouTube Premium": return .red
    case "Disney+": return brandColor(scheme == .dark ? 0x8EA9FF : 0x113CCF)
    case "Prime Video": return brandColor(0x00A8E1)
    case "Max": return brandColor(scheme == .dark ? 0x8EA4FF : 0x002BE7)
    case "BBC iPlayer": return brandColor(0xFF4C98)
    case "Crunchyroll": return brandColor(0xF47521)
    default: return scheme == .dark ? .white : brandColor(0x111111)
    }
  }
  private var glyph: String? {
    [
      "Netflix": "\u{f1b2}",
      "YouTube Premium": "\u{f73d}",
      "Max": "\u{f109}",
      "Apple TV+": "\u{eac9}",
      "DAZN": "\u{eccf}",
      "Crunchyroll": "\u{ec9a}",
      "TikTok": "\u{f5cb}",
    ][name]
  }
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: tv(10)).fill(color.opacity(scheme == .dark ? 0.16 : 0.11))
      if let glyph {
        Text(glyph).font(.custom("SimpleIcons", fixedSize: tv(20))).foregroundStyle(color)
      } else {
        Text(name == "Disney+" ? "D+" : name == "BBC iPlayer" ? "BBC" : "▶").font(TVFont.medium(14))
          .foregroundStyle(color)
      }
    }
  }
}
