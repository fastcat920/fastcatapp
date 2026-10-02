import Foundation

@MainActor
final class SessionStore: ObservableObject {
  @Published private(set) var token: String?
  @Published private(set) var email: String?
  @Published var errorMessage: String?

  var isSignedIn: Bool { token?.isEmpty == false }

  func restore() async {
#if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-FastCatPreviewHome")
      || ProcessInfo.processInfo.environment["FASTCAT_PREVIEW_HOME"] == "1" {
      token = "preview-token"
      email = "preview@fastcat.tv"
      return
    }
#endif
    token = KeychainStore.read(key: "auth-token")
    email = KeychainStore.read(key: "account-email")
  }

  func signIn(token: String, email: String?) {
    KeychainStore.write(token, key: "auth-token")
    if let email, !email.isEmpty { KeychainStore.write(email, key: "account-email") }
    self.token = token
    self.email = email
    errorMessage = nil
  }

  func signOut() {
    KeychainStore.delete(key: "auth-token")
    KeychainStore.delete(key: "account-email")
    token = nil
    email = nil
  }

  /// Keep device leases and revocation behavior in sync with the Flutter client.
  func maintainSession() async {
    guard let currentToken = token, currentToken.contains("dg_") else { return }
    var failures = 0
    var strict = false
    while !Task.isCancelled && token == currentToken {
      do {
        let client = try await GatewayClient.configured()
        let policy = try await client.heartbeat(token: currentToken)
        guard !Task.isCancelled, token == currentToken else { return }
        strict = policy == "strict"
        failures = 0
      } catch GatewayClient.GatewayError.unauthorized {
        guard !Task.isCancelled, token == currentToken else { return }
        await withCheckedContinuation { continuation in
          VPNManager.shared.disconnect { _ in continuation.resume() }
        }
        guard token == currentToken else { return }
        await GatewayClient.clearCachedSubscriptions()
        signOut()
        return
      } catch {
        if Task.isCancelled { return }
        failures += 1
      }
      let seconds = strict ? (failures == 0 ? Int.random(in: 120...300) : 600)
        : (failures == 0 ? Int.random(in: 20...30) : min(120, 60 * failures))
      do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
    }
  }
}
