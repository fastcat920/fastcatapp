import SwiftUI

@main
struct FastCatTVApp: App {
  @StateObject private var session = SessionStore()
  @AppStorage(TVTheme.preferenceKey) private var prefersDarkTheme = true

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(session)
        .preferredColorScheme(prefersDarkTheme ? .dark : .light)
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
