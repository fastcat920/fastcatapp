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
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var session: SessionStore
  @Environment(\.openURL) private var openURL
  @AppStorage(TVLanguage.preferenceKey) private var language = TVLanguage.system.rawValue
  @State private var availableUpdate: TVUpdateInfo?
  @FocusState private var updateActionFocused: Bool

  var body: some View {
    ZStack {
      Group {
        if session.isSignedIn {
          TVHomeView()
        } else {
          TVLoginView()
        }
      }
      .disabled(availableUpdate != nil)
      .allowsHitTesting(availableUpdate == nil)

      if let availableUpdate { updateDialog(availableUpdate) }
    }
    .task {
      await session.restore()
      await checkForUpdates()
    }
    .task(id: "\(session.token ?? "")-\(scenePhase)") {
      if scenePhase == .active { await session.maintainSession() }
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
