import SwiftUI

struct TVHomeView: View {
  @EnvironmentObject private var session: SessionStore
  @State private var connected = false
  @State private var isConnecting = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: 32) {
        Spacer()
        Image(systemName: connected ? "checkmark.shield.fill" : "shield.lefthalf.filled")
          .font(.system(size: 120)).foregroundStyle(connected ? .green : .blue)
        Text(connected ? "已连接" : "未连接").font(.system(size: 48, weight: .bold))
        if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.title3) }
        Button(connected ? "断开连接" : "连接代理", action: toggleConnection)
          .buttonStyle(.borderedProminent).disabled(isConnecting)
        Spacer()
      }
      .navigationTitle("快猫")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu(session.email ?? "账户") { Button("退出登录", role: .destructive, action: session.signOut) }
        }
      }
    }
  }

  private func toggleConnection() {
    if connected {
      VPNManager.shared.disconnect { _ in
        Task { @MainActor in connected = false; isConnecting = false }
      }
      return
    }
    guard let token = session.token else { return }
    isConnecting = true; errorMessage = nil
    Task {
      do {
        let config = try await GatewayClient().downloadSubscription(token: token)
        VPNManager.shared.connect(config: config) { error in
          Task { @MainActor in
            isConnecting = false
            connected = error == nil
            errorMessage = error
          }
        }
      } catch {
        isConnecting = false; errorMessage = error.localizedDescription
      }
    }
  }
}
