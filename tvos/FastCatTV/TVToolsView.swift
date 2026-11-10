import CryptoKit
import SwiftUI

extension Notification.Name {
  static let tvUpdateAvailability = Notification.Name("fastcat.tv.updateAvailability")
}

struct TVToolsView: View {
  var startAbout = false
  let onLogout: () -> Void
  let onRulesChanged: () async throws -> Void
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var session: SessionStore
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @AppStorage(TVTheme.preferenceKey) private var dark = true
  @State private var page = "tools"
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
  @AppStorage("fastcat.tv.streaming.mode") private var streamMode = "full"
  @AppStorage("fastcat.tv.streaming.targets") private var savedStreamTargets = ""
  @State private var choosingTargets = false
  @State private var draftTargets: Set<String> = []
  @State private var streamNode: String?
  @State private var streamRegion: String?
  @State private var streamTotal = 0
  @State private var streamDate: Date?
  @StateObject private var network = TVStreamingNetworkMonitor()
  @State private var checkingName: String?
  @State private var checkingUpdate = false
  @State private var legalTerms = false
  @State private var legalURL: String?
  @Environment(\.scenePhase) private var scenePhase

  private var selectedTargets: Set<String> {
    savedStreamTargets.isEmpty
      ? Set(TVStreamingTargets.all.map(\.0)) : Set(savedStreamTargets.components(separatedBy: "|"))
  }
  private var activeTargets: [(String, String)] {
    TVStreamingTargets.all.filter { streamMode != "custom" || selectedTargets.contains($0.0) }
  }
  private var choicePresented: Bool { page == "language" || page == "theme" || choosingTargets }
  private var contentWidth: CGFloat {
    page == "tools" ? .infinity : tv(page == "streaming" ? 1040 : page == "about" ? 680 : 760)
  }
  var body: some View {
    TVDesignCanvas {
      ZStack {
        VStack(spacing: 0) {
          HStack(spacing: tv(16)) {
            TVFocusButton(action: back) { _ in
              MaterialIcon(glyph: .arrowBack, size: 24).frame(width: tv(48), height: tv(48))
            }
            Text(title).font(TVFont.medium(20))
            Spacer()
          }.padding(.horizontal, tv(8)).frame(height: tv(56)).background(TVTheme.surface)
          ScrollViewReader { reader in
            ScrollView {
              VStack(alignment: .leading, spacing: tv(page == "tools" ? 0 : 12)) {
                Color.clear.frame(height: 0).id("top")
                if let message { note(message) }
                pageContent
              }
              .frame(maxWidth: contentWidth)
              .padding(.horizontal, tv(page == "tools" ? 25 : 20))
              .padding(.top, tv(page == "tools" ? 16 : 20))
              .padding(.bottom, tv(24))
              .frame(maxWidth: .infinity)
            }.onChange(of: page) { _, _ in reader.scrollTo("top", anchor: .top) }
          }
        }.disabled(choicePresented)
        if choicePresented { choiceDialog }
      }.background(TVTheme.background).foregroundStyle(TVTheme.textPrimary)
    }
    .preferredColorScheme(TVTheme.scheme(mode: themeMode, legacyDark: dark))
    .onExitCommand(perform: back)
    .task {
      page = startAbout ? "about" : "tools"
      rules = TVUserRouteStore.load(scope: scope)
      await refreshUpdate()
    }
    .onDisappear { stopStreaming(showMessage: false) }
    .onChange(of: page) { old, _ in
      if old == "streaming" { stopStreaming(showMessage: false) }
      message = nil
    }
    .onChange(of: network.generation) { _, _ in
      if streamTask != nil || !streaming.isEmpty {
        stopStreaming(showMessage: false)
        streaming = [:]
        streamNode = nil
        streamRegion = nil
        message = text("网络已变化，请重新检测", "Network changed. Run the check again.")
      }
    }
    .onChange(of: scenePhase) { _, phase in if phase != .active { stopStreaming(showMessage: true) }
    }
    .onReceive(NotificationCenter.default.publisher(for: VPNManager.statusDidChangeNotification)) {
      _ in
      if !VPNManager.shared.isConnected && (streamTask != nil || !streaming.isEmpty) {
        stopStreaming(showMessage: false)
        streaming = [:]
        streamNode = nil
        streamRegion = nil
        message = text("连接已变化，请重新检测", "Connection changed. Run the check again.")
      }
    }
  }

  @ViewBuilder private var pageContent: some View {
    if page == "tools" || page == "language" || page == "theme" {
      row("语言", "Language", icon: "globe") { page = "language" }
      row("主题", "Theme", icon: "circle.lefthalf.filled") { page = "theme" }
      row("自启动", "Startup", icon: "power") { page = "startup" }
      row("自定义分流", "Custom routing", icon: "arrow.triangle.branch") { page = "routing" }
      row("流媒体检测", "Streaming check", icon: "play.tv") { page = "streaming" }
      row("关于", "About", icon: "info.circle", badge: update != nil) { page = "about" }
      Color.clear.frame(height: tv(20))
      row("退出登录", "Sign out", icon: "rectangle.portrait.and.arrow.right") {
        dismiss()
        onLogout()
      }
      row("注销账号", "Delete account", icon: "trash", danger: true) {
        page = "delete"
        deleteConfirmed = false
        code = ""
      }
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
          enabled: true, value: autoConnect
        ) { autoConnect.toggle() }
      }.background(TVTheme.surface).clipShape(RoundedRectangle(cornerRadius: tv(20)))
    } else if page == "about" {
      VStack(spacing: tv(4)) {
        TVBrandLogo().padding(tv(10)).frame(width: tv(88), height: tv(88)).background(
          TVTheme.primary.opacity(0.10)
        ).clipShape(RoundedRectangle(cornerRadius: tv(26)))
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
      .background(TVTheme.surface).clipShape(RoundedRectangle(cornerRadius: tv(20))).padding(
        .top, tv(12))
      HStack(spacing: tv(8)) {
        Spacer()
        smallButton(text("隐私政策", "Privacy Policy")) { openLegal(terms: false) }
        Text("|").foregroundStyle(TVTheme.textSecondary)
        smallButton(text("服务条款", "Terms of Service")) { openLegal(terms: true) }
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
    } else if page == "report" {
      note(
        text(
          "tvOS 没有通用剪贴板。用手机扫描二维码复制本次报告；报告不含出口 IP、账号或凭据。",
          "tvOS has no general clipboard. Scan with your phone to copy this report. It excludes exit IP, account details and credentials."
        ))
      TVQRCodeView(payload: streamReport).padding(tv(12)).background(.white).frame(
        width: tv(250), height: tv(250)
      ).frame(maxWidth: .infinity)
      Text(streamReport).font(TVFont.regular(14)).frame(maxWidth: .infinity, alignment: .leading)
        .focusable()
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
      row("取消", "Cancel", icon: "xmark") { page = "tools" }
      row("继续注销流程", "Continue deletion", icon: "trash", danger: true) { deleteConfirmed = true }
    } else {
      Text(session.email ?? "").font(TVFont.regular(14))
      TextField(text("6 位邮箱验证码", "6-digit email code"), text: $code).keyboardType(.numberPad)
        .onChange(of: code) { _, value in
          code = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
        }
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let remaining = max(0, Int(ceil(codeDeadline.timeIntervalSince(context.date))))
        row(
          remaining > 0 ? "\(remaining) 秒后重发" : "发送验证码",
          remaining > 0 ? "Resend in \(remaining)s" : "Send code", icon: "envelope"
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
      TextField(text("域名、IP 或 CIDR", "Domain, IP or CIDR"), text: $destination).disabled(busy)
      HStack {
        choiceButton(text("直连", "Direct"), selected: !proxy) { proxy = false }
        choiceButton(text("代理", "Proxy"), selected: proxy) { proxy = true }
        Spacer()
        smallButton(
          editingRuleID == nil ? text("添加", "Add") : text("保存", "Save"),
          disabled: destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy
        ) { saveRule() }
        if editingRuleID != nil {
          smallButton(text("取消编辑", "Cancel edit"), disabled: busy) {
            destination = ""
            editingRuleID = nil
          }
        }
      }.disabled(busy)
    }.padding(tv(12)).background(TVTheme.surface).clipShape(RoundedRectangle(cornerRadius: tv(20)))
    if rules.isEmpty { note(text("暂无自定义规则", "No custom rules")) }
    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
      VStack(alignment: .leading, spacing: tv(8)) {
        Text(rule.destination).font(TVFont.regular(16))
        Text(rule.proxy ? text("代理", "Proxy") : text("直连", "Direct")).font(TVFont.regular(12))
          .foregroundStyle(TVTheme.textSecondary)
        HStack {
          smallButton(text("编辑", "Edit"), disabled: busy) {
            destination = rule.destination
            proxy = rule.proxy
            editingRuleID = rule.id
          }
          smallButton(text("删除", "Delete"), disabled: busy, danger: true) {
            changeRules { $0.remove(at: index) }
          }
          Spacer()
          smallButton(text("上移", "Move up"), disabled: busy || index == 0) {
            changeRules { $0.insert($0.remove(at: index), at: index - 1) }
          }
          smallButton(text("下移", "Move down"), disabled: busy || index + 1 == rules.count) {
            changeRules { $0.insert($0.remove(at: index), at: index + 1) }
          }
        }
      }.padding(tv(12)).background(TVTheme.surface).clipShape(
        RoundedRectangle(cornerRadius: tv(16)))
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
          choiceButton(text("完整", "Full"), selected: streamMode == "full") {
            streamMode = "full"
            clearStreamResults()
          }
          choiceButton(text("自定义", "Custom"), selected: streamMode == "custom") {
            draftTargets = selectedTargets
            choosingTargets = true
          }
        }.disabled(busy)
        HStack {
          smallButton(
            busy
              ? text("检测中…", "Checking…")
              : streaming.isEmpty ? text("开始检测", "Start check") : text("重新检测", "Retest"),
            disabled: busy || !VPNManager.shared.isConnected
          ) { startStreaming() }
          if streamTask != nil {
            smallButton(text("停止", "Stop")) { stopStreaming(showMessage: true) }
          }
          smallButton(text("复制报告", "Copy report"), disabled: busy || streaming.isEmpty) {
            page = "report"
          }
          if let checkingName {
            ProgressView()
            Text(checkingName).font(TVFont.regular(14))
          }
        }
      }.padding(tv(16)).frame(maxWidth: .infinity, alignment: .leading).background(TVTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: tv(20)))
      if !VPNManager.shared.isConnected { note(text("请先连接 VPN", "Connect VPN first")) }
      if let streamNode {
        Text(text("检测概览", "Summary")).font(TVFont.medium(14))
        note(streamNode + " · " + (streamRegion ?? "—") + " · \(streaming.count)/\(streamTotal)")
      }
      if !streaming.isEmpty {
        Text(text("检测结果", "Results")).font(TVFont.medium(14))
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: tv(10)) {
          ForEach(TVStreamingTargets.all.filter { streaming[$0.0] != nil }, id: \.0) { name, _ in
            VStack(alignment: .leading, spacing: tv(8)) {
              Text(name).font(TVFont.medium(16))
              Text(streaming[name] ?? "—").font(TVFont.regular(14)).foregroundStyle(
                TVTheme.textSecondary)
            }.padding(tv(16)).frame(maxWidth: .infinity, alignment: .leading).background(
              TVTheme.surface
            ).clipShape(RoundedRectangle(cornerRadius: tv(16))).focusable()
          }
        }
      }
      note(
        text(
          "网页可访问不代表会员内容一定解锁；结果仅反映当前节点与当前网络。",
          "Web access does not prove entitlement or playback unlock. Results reflect the current node and network only."
        ))
    }
  }
  @ViewBuilder private var choiceDialog: some View {
    TVDialog(title: title, icon: nil) {
      if choosingTargets {
        ScrollView {
          VStack(spacing: tv(4)) {
            choiceButton(
              text("全选", "Select all"), selected: draftTargets.count == TVStreamingTargets.all.count
            ) {
              draftTargets =
                draftTargets.count == TVStreamingTargets.all.count
                ? [] : Set(TVStreamingTargets.all.map(\.0))
            }
            ForEach(TVStreamingTargets.all, id: \.0) { name, _ in
              choiceButton(name, selected: draftTargets.contains(name)) {
                if !draftTargets.insert(name).inserted { draftTargets.remove(name) }
              }
            }
          }
        }.frame(maxHeight: tv(280))
      } else if page == "language" {
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
      smallButton(text("取消", "Cancel")) {
        if choosingTargets { choosingTargets = false } else { page = "tools" }
      }
      if choosingTargets {
        smallButton(text("确定", "OK"), disabled: draftTargets.isEmpty) {
          savedStreamTargets = draftTargets.sorted().joined(separator: "|")
          streamMode = "custom"
          choosingTargets = false
          clearStreamResults()
        }
      }
    }
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
    case "report": return text("检测报告", "Check report")
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
    default: return .emailOutlined
    }
  }
  private func row(
    _ a: String, _ b: String, icon: String, badge: Bool = false, danger: Bool = false,
    loading: Bool = false, action: @escaping () -> Void
  ) -> some View {
    TVFocusButton(cornerRadius: tv(14), action: action) { _ in
      HStack(spacing: tv(16)) {
        ZStack(alignment: .topTrailing) {
          MaterialIcon(glyph: materialGlyph(icon), size: 22, color: TVTheme.textSecondary).frame(
            width: tv(24), height: tv(24))
          if badge {
            Circle().fill(.red).frame(width: tv(8), height: tv(8)).offset(x: tv(3), y: -tv(3))
          }
        }
        Text(text(a, b)).font(TVFont.regular(16)).foregroundStyle(
          danger ? TVTheme.danger : TVTheme.textPrimary)
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
  private func smallButton(
    _ title: String, disabled: Bool = false, danger: Bool = false, action: @escaping () -> Void
  ) -> some View {
    TVFocusButton(action: action) { _ in
      Text(title).font(TVFont.medium(14)).foregroundStyle(danger ? TVTheme.danger : TVTheme.primary)
        .padding(.horizontal, tv(16)).frame(minHeight: tv(44))
    }.disabled(disabled)
  }
  private func choiceButton(_ title: String, selected: Bool, action: @escaping () -> Void)
    -> some View
  {
    TVFocusButton(action: action) { _ in
      HStack(spacing: tv(12)) {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        Text(title).font(TVFont.regular(16))
        Spacer()
      }.foregroundStyle(selected ? TVTheme.primary : TVTheme.textPrimary).padding(tv(12)).frame(
        maxWidth: .infinity, minHeight: tv(48))
    }
  }
  private func switchRow(
    _ title: String, subtitle: String, enabled: Bool, value: Bool, action: @escaping () -> Void
  ) -> some View {
    TVFocusButton(action: action) { _ in
      HStack(spacing: tv(16)) {
        Image(systemName: "power").font(.system(size: tv(22))).frame(width: tv(24))
        VStack(alignment: .leading, spacing: tv(4)) {
          Text(title).font(TVFont.regular(16))
          Text(subtitle).font(TVFont.regular(14)).foregroundStyle(TVTheme.textSecondary)
        }
        Spacer()
        Capsule().fill(value ? TVTheme.primary : TVTheme.outline.opacity(0.5)).frame(
          width: tv(52), height: tv(32)
        ).overlay {
          Circle().fill(value ? TVTheme.onPrimary : TVTheme.surface).frame(
            width: tv(24), height: tv(24)
          ).offset(x: tv(value ? 10 : -10))
        }
        Text(value ? text("开启", "On") : text("关闭", "Off")).font(TVFont.regular(14))
      }.padding(tv(16)).frame(maxWidth: .infinity, minHeight: tv(72)).opacity(enabled ? 1 : 0.45)
    }.disabled(!enabled)
  }
  private func note(_ value: String) -> some View {
    Text(value).font(TVFont.regular(14)).foregroundStyle(TVTheme.textSecondary).fixedSize(
      horizontal: false, vertical: true
    ).padding(tv(12)).frame(maxWidth: .infinity, alignment: .leading).background(
      TVTheme.surfaceStrong
    ).clipShape(RoundedRectangle(cornerRadius: tv(8)))
  }
  private func back() {
    if choosingTargets {
      choosingTargets = false
      return
    }
    if page == "report" {
      page = "streaming"
    } else if page == "legal" {
      page = "about"
    } else if page == "tools" || (startAbout && page == "about") {
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
  private var streamReport: String {
    let formatter = ISO8601DateFormatter()
    var lines = [
      "FastCat streaming check", streamDate.map { formatter.string(from: $0) } ?? "",
      streamRegion.map { "Region: \($0)" } ?? "",
    ]
    for (name, _) in TVStreamingTargets.all {
      if let result = streaming[name] { lines.append(name + ": " + result) }
    }
    return lines.filter { !$0.isEmpty }.joined(separator: "\n")
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
    TVUserRouteStore.save(candidate, scope: scope)
    busy = true
    Task {
      defer { busy = false }
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
      streamNode = node
      let trace = await VPNManager.shared.streamingProbe(
        runID: id, node: node, url: "https://www.cloudflare.com/cdn-cgi/trace")
      guard !Task.isCancelled, session.token == owner else { return }
      if let body = trace?["body"] as? String,
        let range = body.range(of: "(?m)^loc=([A-Z]{2})$", options: .regularExpression)
      {
        streamRegion = String(body[range]).replacingOccurrences(of: "loc=", with: "")
      }
      for (name, url) in targets {
        checkingName = name
        guard !Task.isCancelled, session.token == owner, VPNManager.shared.isConnected else {
          break
        }
        let sameNode = await isSameStreamingNode(node)
        guard !Task.isCancelled, session.token == owner, runID == id else { break }
        guard sameNode else {
          message = text("节点已变化，请重新检测", "Node changed. Run the check again.")
          streaming = [:]
          streamNode = nil
          streamRegion = nil
          break
        }
        let result = await checkStreamingTarget(name: name, url: url, node: node, id: id)
        guard !Task.isCancelled, session.token == owner else { break }
        let stillSameNode = await isSameStreamingNode(node)
        guard !Task.isCancelled, session.token == owner, runID == id else { break }
        guard stillSameNode else {
          message = text("节点已变化，请重新检测", "Node changed. Run the check again.")
          streaming = [:]
          streamNode = nil
          streamRegion = nil
          break
        }
        streaming[name] = TVStreamingTargets.summary(result, chinese: zh, name: name)
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
