import Combine
import Foundation

/// One owner for QR lifetime. Cancellation is best effort at the transport;
/// the generation check is what prevents late approvals signing in an old QR.
@MainActor
final class TVQRLoginCoordinator: ObservableObject {
  struct Transport {
    var create: () async throws -> QRLoginChallenge
    var poll: (QRLoginChallenge) async throws -> QRLoginResponse
    var cancel: (QRLoginChallenge) async throws -> Void
    var acknowledge: (QRLoginChallenge, String) async throws -> Void

    static var live: Transport {
      Transport(
        create: { try await GatewayClient.configured().createQRSession() },
        poll: { try await GatewayClient.configured().pollQRSession($0) },
        cancel: { try await GatewayClient.configured().cancelQRSession($0) },
        acknowledge: { try await GatewayClient.configured().acknowledgeQRSession($0, deliveryID: $1) })
    }
  }

  @Published private(set) var challenge: QRLoginChallenge?
  @Published private(set) var remainingSeconds = 0
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?
  private var generation: UInt64 = 0
  private var active = false
  private var completed = false
  private var lastRefreshAt: Date?
  private var pollTask: Task<Void, Never>?
  private var countdownTask: Task<Void, Never>?
  private var onAuthenticated: ((String, String?) -> Void)?
  private let transport: Transport
  private let now: () -> Date
  private let pause: (TimeInterval) async throws -> Void

  init(transport: Transport = .live, now: @escaping () -> Date = Date.init,
       pause: @escaping (TimeInterval) async throws -> Void = {
         try await Task.sleep(nanoseconds: UInt64(max(0, $0) * 1_000_000_000))
       }) {
    self.transport = transport
    self.now = now
    self.pause = pause
  }

  var isExpired: Bool { challenge != nil && remainingSeconds <= 0 }

  func activate(onAuthenticated: @escaping (String, String?) -> Void) async {
    self.onAuthenticated = onAuthenticated
    guard !active else { return }
    active = true
    completed = false
    await refresh(userInitiated: false)
  }

  func deactivate() {
    generation &+= 1
    active = false
    isLoading = false
    pollTask?.cancel()
    countdownTask?.cancel()
    if let challenge, !completed { discard(challenge) }
    challenge = nil
    remainingSeconds = 0
    onAuthenticated = nil
  }

  func refresh(userInitiated: Bool) async {
    guard active, !isLoading, !completed else { return }
    if userInitiated, let lastRefreshAt, now().timeIntervalSince(lastRefreshAt) < 5, !isExpired { return }
    generation &+= 1
    let owner = generation
    pollTask?.cancel()
    countdownTask?.cancel()
    if let previous = challenge { discard(previous) }
    challenge = nil
    remainingSeconds = 0
    isLoading = true
    errorMessage = nil
    defer { if owner == generation { isLoading = false } }
    do {
      let value = try await transport.create()
      guard isCurrent(owner), !Task.isCancelled else { discard(value); return }
      guard value.expiresAt > now() else { throw GatewayClient.GatewayError.invalidResponse }
      challenge = value
      lastRefreshAt = now()
      remainingSeconds = secondsLeft(value)
      countdownTask = Task { [weak self] in await self?.countdown(value, owner: owner) }
      pollTask = Task { [weak self] in await self?.poll(value, owner: owner) }
    } catch {
      guard isCurrent(owner), !Task.isCancelled else { return }
      errorMessage = text("二维码加载失败，请刷新重试", "Could not load the QR code. Please refresh and try again.")
    }
  }

  private func isCurrent(_ owner: UInt64) -> Bool { active && !completed && generation == owner }
  private func secondsLeft(_ challenge: QRLoginChallenge) -> Int {
    max(0, Int(ceil(challenge.expiresAt.timeIntervalSince(now()))))
  }

  private func countdown(_ value: QRLoginChallenge, owner: UInt64) async {
    while isCurrent(owner), !Task.isCancelled {
      remainingSeconds = secondsLeft(value)
      if remainingSeconds == 0 { pollTask?.cancel(); return }
      do { try await pause(1) } catch { return }
    }
  }

  private func poll(_ value: QRLoginChallenge, owner: UInt64) async {
    var failures = 0
    // Each iteration awaits the previous poll, so requests never overlap for
    // one challenge. A superseded request may finish, but can never publish.
    while isCurrent(owner), !Task.isCancelled, secondsLeft(value) > 0 {
      do {
        let response = try await transport.poll(value)
        guard isCurrent(owner), !Task.isCancelled, secondsLeft(value) > 0 else { return }
        failures = 0
        errorMessage = nil
        switch response.status {
        case "expired", "cancelled", "consumed", "failed":
          remainingSeconds = 0
          countdownTask?.cancel()
          return
        case "approved":
          guard let login = response.login,
                let token = login.authData ?? login.token, !token.isEmpty,
                !value.deliveryACK || response.deliveryID?.isEmpty == false else {
            throw GatewayClient.GatewayError.invalidResponse
          }
          completed = true
          countdownTask?.cancel()
          // Persist/sign in before ACK. A lost ACK must never undo login.
          onAuthenticated?(token, login.email)
          if value.deliveryACK, let deliveryID = response.deliveryID {
            let acknowledge = transport.acknowledge
            Task {
              for _ in 0..<2 {
                do { try await acknowledge(value, deliveryID); return }
                catch { if Task.isCancelled { return } }
              }
            }
          }
          return
        case "pending", "authorizing": break
        default: throw GatewayClient.GatewayError.invalidResponse
        }
      } catch {
        guard isCurrent(owner), !Task.isCancelled, secondsLeft(value) > 0 else { return }
        failures += 1
        guard Self.isTransient(error), failures <= 3 else {
          errorMessage = text("扫码状态获取失败，请刷新二维码", "Could not check sign-in status. Please refresh the QR code.")
          return
        }
      }
      do { try await pause(failures == 0 ? 2 : TimeInterval(failures)) }
      catch { return }
    }
  }

  private static func isTransient(_ error: Error) -> Bool {
    if case GatewayClient.GatewayError.temporarilyUnavailable = error { return true }
    guard let value = error as? URLError else { return false }
    return [.timedOut, .networkConnectionLost, .notConnectedToInternet,
            .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains(value.code)
  }

  private func discard(_ value: QRLoginChallenge) {
    let cancel = transport.cancel
    Task { try? await cancel(value) } // HTTP cancel is bounded to 3 seconds.
  }

  private func text(_ chinese: String, _ english: String) -> String {
    tvText(chinese, english, language: UserDefaults.standard.string(forKey: TVLanguage.preferenceKey) ?? "system")
  }
}
