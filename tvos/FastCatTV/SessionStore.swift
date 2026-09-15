import Foundation

@MainActor
final class SessionStore: ObservableObject {
  @Published private(set) var token: String?
  @Published private(set) var email: String?
  @Published var errorMessage: String?

  var isSignedIn: Bool { token?.isEmpty == false }

  func restore() async {
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
}
