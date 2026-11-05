import SwiftUI

@main
struct FastCatTVApp: App {
  @StateObject private var session = SessionStore()
  @AppStorage(TVTheme.preferenceKey) private var prefersDarkTheme = true
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @AppStorage("fastcat.apple.privacy-disclosure") private var privacyVersion = ""
  @State private var showPrivacy = false

  var body: some Scene {
    WindowGroup {
      Group {
        if privacyVersion == TVPrivacyNotice.version {
          RootView()
            .fullScreenCover(isPresented: $showPrivacy) {
              TVPrivacyNotice(reviewing: true) { showPrivacy = false }
            }
        } else {
          TVPrivacyNotice { privacyVersion = TVPrivacyNotice.version }
        }
      }
        .onReceive(NotificationCenter.default.publisher(for: .tvShowPrivacyNotice)) { _ in showPrivacy = true }
        .environmentObject(session)
        .preferredColorScheme(prefersDarkTheme ? .dark : .light)
        .environment(\.locale, TVLanguage.resolved(from: language).locale)
    }
  }
}

extension Notification.Name {
  static let tvShowPrivacyNotice = Notification.Name("fastcat.tv.showPrivacyNotice")
}

private struct TVPrivacyNotice: View {
  static let version = "2026-10-v1"
  var reviewing = false
  let onContinue: () -> Void
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @State private var showTerms = false
  @State private var declined = false

  private var policyURL: String {
    let key = showTerms ? "FastCatTermsOfServiceURL" : "FastCatPrivacyPolicyURL"
    let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    if let url = URL(string: raw), url.scheme == "https", url.host != nil { return raw }
    return showTerms ? "https://www.fastcat6.com/terms" : "https://www.fastcat6.com/privacy"
  }

  var body: some View {
    TVDesignCanvas {
      ZStack {
        TVTheme.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: tv(20)) {
          Text(tvText("VPN 数据使用说明", "VPN Data Use", language: language)).font(TVFont.medium(26))
          HStack(alignment: .top, spacing: tv(32)) {
            ScrollView {
              Text(tvText(
                "账号与设备：邮箱、账号标识、设备标识及设备信息用于登录、设备限制和会话管理。\n\n套餐信息：套餐及流量用量用于提供服务。\n\nVPN 流量：客户端与所选节点处理目标地址、DNS 查询和网络流量，以完成转发和分流。\n\n服务检测会联系配置中的业务与网关服务。详细的数据收集、保存、第三方处理和删除规则，请阅读隐私政策。",
                "Account and devices: Your email, account identifier, device identifier and device information support sign-in, device limits and session management.\n\nPlan information: Plan details and traffic usage support service delivery.\n\nVPN traffic: The client and selected server process destination addresses, DNS queries and network traffic to route your connections.\n\nService checks contact the configured business and gateway services. Read the Privacy Policy for collection, retention, third-party processing and deletion rules.", language: language))
                .font(TVFont.regular(17)).lineSpacing(tv(5)).frame(maxWidth: .infinity, alignment: .leading)
            }.focusable()
            VStack(spacing: tv(12)) {
              Text(tvText(showTerms ? "服务条款" : "隐私政策", showTerms ? "Terms of Service" : "Privacy Policy", language: language)).font(TVFont.medium(18))
              TVQRCodeView(payload: policyURL).padding(tv(12)).background(.white).frame(width: tv(200), height: tv(200))
              Text(tvText("用手机扫描二维码阅读完整内容", "Scan with your phone to read the full document", language: language)).font(TVFont.regular(13))
                .multilineTextAlignment(.center).frame(width: tv(220))
              TVFocusButton(cornerRadius: TVTheme.compactRadius, action: { showTerms.toggle() }) { _ in
                Text(tvText(showTerms ? "查看隐私政策" : "查看服务条款", showTerms ? "Privacy Policy" : "Terms of Service", language: language))
                  .font(TVFont.regular(15)).padding(tv(12))
              }
            }
          }
          if declined { Text(tvText("可以退出应用；继续前不会进入登录或连接界面。", "You may leave the app. Sign-in and connection screens remain unavailable until you continue.", language: language)).font(TVFont.regular(14)) }
          HStack(spacing: tv(20)) {
            TVFocusButton(cornerRadius: TVTheme.compactRadius, autofocus: true, action: onContinue) { _ in
              Text(tvText(reviewing ? "返回" : "我已了解，继续", reviewing ? "Back" : "I understand — Continue", language: language))
                .font(TVFont.medium(16)).padding(tv(16)).background(TVTheme.primary).foregroundStyle(.white)
            }
            if !reviewing {
              TVFocusButton(cornerRadius: TVTheme.compactRadius, action: { declined = true }) { _ in
                Text(tvText("暂不使用", "Not now", language: language)).font(TVFont.regular(16)).padding(tv(16))
              }
            }
            TVFocusButton(cornerRadius: TVTheme.compactRadius, action: {
              language = TVLanguage.resolved(from: language) == .simplifiedChinese ? "en" : "zh-CN"
            }) { _ in Text("中文 / English").font(TVFont.regular(16)).padding(tv(16)) }
          }
        }.padding(tv(44)).foregroundStyle(TVTheme.textPrimary)
      }
    }
    .onExitCommand { if reviewing { onContinue() } else { declined = true } }
  }
}

private struct RootView: View {
  @StateObject private var connectivity = TVServiceConnectivityMonitor.live()
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var session: SessionStore
  @Environment(\.openURL) private var openURL
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @State private var availableUpdate: TVUpdateInfo?
  @State private var refreshingConfig = false
  @State private var configRequestRunning = false
  @State private var refreshMessage: String?
  @FocusState private var updateActionFocused: Bool

  var body: some View {
    ZStack {
      Group {
        if session.isSignedIn {
          TVHomeView()
            .environmentObject(connectivity)
        } else {
          TVLoginView()
        }
      }
      .disabled(availableUpdate != nil || refreshingConfig || refreshMessage != nil)
      .allowsHitTesting(availableUpdate == nil && !refreshingConfig && refreshMessage == nil)

      if let availableUpdate { updateDialog(availableUpdate) }
      else if refreshingConfig || refreshMessage != nil {
        TVDialog(title: tvText("刷新配置", "Refresh configuration", language: language), icon: nil) {
          Text(refreshMessage ?? tvText("正在刷新配置并检查更新…", "Refreshing configuration and checking for updates…", language: language))
        } actions: {
          TVFocusButton(cornerRadius: TVTheme.compactRadius, autofocus: true, action: {
            // Allow dismissing the progress dialog without cancelling shared requests.
            refreshingConfig = false; refreshMessage = nil
          }) { _ in
            Text(tvText("确定", "OK", language: language))
              .font(TVFont.regular(14)).padding(.horizontal, tv(18)).frame(height: tv(48))
          }
        }
      }
    }
    .task {
      await session.restore()
      await checkForUpdates()
    }
    .task(id: "\(session.token ?? "")-\(scenePhase)") {
      connectivity.stop(reset: !session.isSignedIn)
      guard scenePhase == .active, session.isSignedIn else { return }
#if DEBUG
      if session.token == "preview-token" { return }
#endif
      connectivity.start()
      await session.maintainSession()
    }
    .onDisappear { connectivity.stop() }
    .onReceive(NotificationCenter.default.publisher(for: GatewayClient.serviceRequestFailed)) { _ in
      connectivity.requestCheck()
    }
    .onReceive(NotificationCenter.default.publisher(for: GatewayClient.serviceRequestSucceeded)) { _ in
      if connectivity.state.status != .online { connectivity.requestCheck() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .tvRefreshRemoteConfiguration)) { _ in
      Task { await refreshRemoteConfiguration() }
    }
    .onChange(of: language) { _, _ in
      Task { await checkForUpdates() }
    }
    .onChange(of: availableUpdate) { _, update in
      if update != nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
          updateActionFocused = true
        }
      } else {
        updateActionFocused = false
      }
    }
  }

  @MainActor
  private func refreshRemoteConfiguration() async {
    guard !configRequestRunning else { return }
    configRequestRunning = true
    refreshingConfig = true; refreshMessage = nil
    defer { refreshingConfig = false; configRequestRunning = false }
    do {
      let online = try await TVRemoteConfigManager.shared.refresh()
      await checkForUpdates()
      connectivity.requestCheck()
      if availableUpdate == nil {
        refreshMessage = online
          ? tvText("配置已刷新，未发现新版本。", "Configuration refreshed. No update found.", language: language)
          : tvText("未取得可替换的远程配置，继续使用已校验的本地缓存。", "No eligible remote configuration. Using the verified local cache.", language: language)
      }
    } catch {
      refreshMessage = tvText("配置刷新失败，请检查网络后重试。", "Configuration refresh failed. Check your network and try again.", language: language)
    }
  }

  @MainActor
  private func checkForUpdates() async {
    availableUpdate = await TVRemoteConfigManager.shared.availableTVUpdate(
      language: TVLanguage.resolved(from: language)
    )
  }

  private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.6.0"
  }

  private func updateDialog(_ update: TVUpdateInfo) -> some View {
    TVDialog(
      title: update.force
        ? tvText("必须更新到 V\(update.latestVersion)", "Update required · V\(update.latestVersion)", language: language)
        : tvText("发现新版本 V\(update.latestVersion)", "New version V\(update.latestVersion)", language: language),
      icon: nil
    ) {
      VStack(alignment: .leading, spacing: tv(12)) {
        Text(tvText("当前版本：V\(appVersion)", "Current version: V\(appVersion)", language: language))
          .foregroundStyle(TVTheme.textPrimary)
        if !update.releaseNotes.isEmpty {
          Text(tvText("更新内容", "What's new", language: language))
            .font(TVFont.medium(14))
            .foregroundStyle(TVTheme.textPrimary)
          Text(update.releaseNotes).lineSpacing(tv(4))
        }
      }
    } actions: {
      HStack(spacing: tv(10)) {
        if !update.force {
          TVFocusButton(cornerRadius: TVTheme.compactRadius, action: {
            availableUpdate = nil
          }) { _ in
            Text(tvText("稍后更新", "Later", language: language))
              .font(TVFont.regular(14))
              .padding(.horizontal, tv(18))
              .frame(height: tv(48))
              .background(TVTheme.surface)
              .clipShape(RoundedRectangle(cornerRadius: TVTheme.compactRadius, style: .continuous))
          }
        }
        TVFocusButton(
          cornerRadius: TVTheme.compactRadius,
          autofocus: true,
          focus: $updateActionFocused,
          action: {
            openURL(update.updateURL)
            if !update.force { availableUpdate = nil }
          }
        ) { _ in
          Text(tvText("立即更新", "Update now", language: language))
            .font(TVFont.regular(14))
            .foregroundStyle(.white)
            .padding(.horizontal, tv(18))
            .frame(height: tv(48))
            .background(update.force ? TVTheme.danger : TVTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: TVTheme.compactRadius, style: .continuous))
        }
      }
    }
  }
}
