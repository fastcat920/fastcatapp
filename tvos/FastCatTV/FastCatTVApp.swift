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
  @EnvironmentObject private var session: SessionStore

  var body: some View {
    Group {
      if session.isSignedIn {
        TVHomeView()
      } else {
        TVLoginView()
      }
    }
    .task { await session.restore() }
  }
}
