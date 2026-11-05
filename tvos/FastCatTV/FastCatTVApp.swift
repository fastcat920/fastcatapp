import SwiftUI

@main
struct FastCatTVApp: App {
  @StateObject private var session = SessionStore()
  @AppStorage(TVTheme.preferenceKey) private var prefersDarkTheme = true
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(session)
        .preferredColorScheme(prefersDarkTheme ? .dark : .light)
        .environment(\.locale, TVLanguage.resolved(from: language).locale)
    }
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
