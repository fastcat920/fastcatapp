import Foundation

// No production gateway, keychain or subscription store is accessed.
enum TVLanguage {
  case simplifiedChinese, english
  static let preferenceKey = "fastcat.test.language"
  static func resolved(from _: String) -> TVLanguage { .english }
}
func tvText(_ chinese: String, _ english: String, language: String) -> String { english }
enum KeychainStore {
  static func read(key: String) -> String? { "test-device" }
  static func write(_ value: String, key: String) { }
}
struct TVBuildConfiguration {
  let subscriptionFlag = "test"
  static func load() throws -> TVBuildConfiguration { fatalError("Unexpected config read") }
}
enum FastCatSubscriptionDecoder {
  static func decode(_ value: String, configuration: TVBuildConfiguration) throws -> String { fatalError("Unexpected cache read") }
}
actor TVRemoteConfigManager {
  static let shared = TVRemoteConfigManager()
  func apiBaseURL() throws -> URL { URL(string: "https://qr-test.invalid/api/v1")! }
}

@MainActor
final class Pending<T> {
  var waiting = false
  private var continuation: CheckedContinuation<T, Error>?
  func get() async throws -> T {
    try await withCheckedThrowingContinuation { continuation = $0; waiting = true }
  }
  func finish(_ value: T) { continuation?.resume(returning: value); continuation = nil }
}

final class QRMockAPI: URLProtocol {
  static var requests: [URLRequest] = []
  static var body = "{}"
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    precondition(request.url?.host == "qr-test.invalid", "No external requests")
    Self.requests.append(request)
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() { }
}

@main
struct TVQRLoginTests {
  static func challenge(_ id: String, ack: Bool = false, expires: Date = Date().addingTimeInterval(60)) throws -> QRLoginChallenge {
    let json: [String: Any] = ["id": id, "poll_token": "qpt_test", "qr_data": "fastcat://login/qr?challenge=\(id)",
      "expires_at": expires.timeIntervalSince1970, "delivery_ack": ack]
    return try JSONDecoder().decode(QRLoginChallenge.self, from: JSONSerialization.data(withJSONObject: json))
  }
  static func approved(_ token: String, delivery: String? = nil) throws -> QRLoginResponse {
    var json: [String: Any] = ["status": "approved", "login": ["token": token]]
    if let delivery { json["delivery_id"] = delivery }
    return try JSONDecoder().decode(QRLoginResponse.self, from: JSONSerialization.data(withJSONObject: json))
  }
  @MainActor static func until(_ condition: () -> Bool) async throws {
    for _ in 0..<1000 {
      if condition() { return }
      try await Task.sleep(nanoseconds: 1_000_000)
    }
    fatalError("Timed out waiting for isolated test state")
  }

  @MainActor static func main() async throws {
    let legacyJSON = "{\"id\":\"old\",\"poll_token\":\"secret\",\"qr_data\":\"fastcat://login/qr?challenge=old\",\"expires_at\":\"2099-01-01T00:00:00Z\"}"
    let legacy = try JSONDecoder().decode(QRLoginChallenge.self, from: Data(legacyJSON.utf8))
    precondition(!legacy.deliveryACK)
    for broken in [legacyJSON.replacingOccurrences(of: "2099-01-01T00:00:00Z", with: "bad-date"),
                   legacyJSON.replacingOccurrences(of: "challenge=old", with: "challenge=another")] {
      do { _ = try JSONDecoder().decode(QRLoginChallenge.self, from: Data(broken.utf8)); fatalError("Bad QR must fail closed") }
      catch { }
    }

    // Expired refresh: the old request deliberately ignores cancellation and
    // completes after the replacement approval. Only the new token may win.
    let oldPoll = Pending<QRLoginResponse>()
    var time = Date()
    let first = try challenge("first", expires: time.addingTimeInterval(2))
    let second = try challenge("second", ack: true, expires: time.addingTimeInterval(60))
    var creates = 0
    var tokens: [String] = []
    var ackAttempts = 0
    let coordinator = TVQRLoginCoordinator(transport: .init(create: {
      creates += 1; return creates == 1 ? first : second
    }, poll: { item in
      if item.id == "first" { return try await oldPoll.get() }
      return try approved("new-token", delivery: "receipt")
    }, cancel: { _ in throw URLError(.timedOut) }, acknowledge: { item, id in
      precondition(tokens == ["new-token"], "Persist before ACK")
      precondition(item.id == "second" && id == "receipt")
      ackAttempts += 1
      throw URLError(.timedOut)
    }), now: { time })
    await coordinator.activate { token, _ in tokens.append(token) }
    try await until { oldPoll.waiting }
    time = time.addingTimeInterval(6)
    await coordinator.refresh(userInitiated: true)
    try await until { tokens.count == 1 && ackAttempts == 2 }
    oldPoll.finish(try approved("old-token"))
    try await Task.sleep(nanoseconds: 10_000_000)
    precondition(tokens == ["new-token"] && coordinator.challenge?.id == "second")
    coordinator.deactivate()

    // Disappearing/account mode invalidates create before its response arrives.
    let createGate = Pending<QRLoginChallenge>()
    var discarded = 0
    let hidden = TVQRLoginCoordinator(transport: .init(create: { try await createGate.get() },
      poll: { _ in fatalError("Hidden QR must not poll") }, cancel: { _ in discarded += 1 },
      acknowledge: { _, _ in fatalError("Hidden QR must not ACK") }))
    let activation = Task { await hidden.activate { _, _ in fatalError("Hidden QR must not sign in") } }
    try await until { createGate.waiting }
    hidden.deactivate()
    createGate.finish(second)
    await activation.value
    try await until { discarded == 1 }
    precondition(hidden.challenge == nil && !hidden.isLoading)

    // Transient polls retry sequentially; legacy server requires no ACK.
    var polls = 0
    var inFlight = 0
    var maxInFlight = 0
    var legacySignedIn = false
    let retry = TVQRLoginCoordinator(transport: .init(create: { legacy }, poll: { _ in
      inFlight += 1; maxInFlight = max(maxInFlight, inFlight)
      defer { inFlight -= 1 }
      polls += 1
      if polls < 3 { throw URLError(.networkConnectionLost) }
      return try approved("legacy-token")
    }, cancel: { _ in }, acknowledge: { _, _ in fatalError("Legacy must not ACK") }),
      pause: { _ in try await Task.sleep(nanoseconds: 1_000_000) })
    await retry.activate { token, _ in precondition(token == "legacy-token"); legacySignedIn = true }
    try await until { legacySignedIn }
    precondition(polls == 3 && maxInFlight == 1)
    retry.deactivate()

    // Opted-in response without receipt must not authenticate.
    let missing = TVQRLoginCoordinator(transport: .init(create: { second }, poll: { _ in try approved("bad") },
      cancel: { _ in }, acknowledge: { _, _ in fatalError("Missing receipt") }))
    await missing.activate { _, _ in fatalError("No receipt must not authenticate") }
    try await until { missing.errorMessage != nil }
    missing.deactivate()

    // Exercise the production HTTP bridge against only an in-process protocol.
    URLProtocol.registerClass(QRMockAPI.self)
    defer { URLProtocol.unregisterClass(QRMockAPI.self) }
    let api = try await GatewayClient.configured()
    QRMockAPI.body = "{\"data\":\(legacyJSON)}"
    let fromOldServer = try await api.createQRSession()
    precondition(!fromOldServer.deliveryACK)
    let createRequest = QRMockAPI.requests.last!
    let createBody: Data
    if let data = createRequest.httpBody { createBody = data }
    else {
      let stream = createRequest.httpBodyStream!
      stream.open(); defer { stream.close() }
      var bytes = [UInt8](repeating: 0, count: 4096)
      let size = stream.read(&bytes, maxLength: bytes.count)
      createBody = Data(bytes.prefix(max(0, size)))
    }
    let payload = try JSONSerialization.jsonObject(with: createBody) as! [String: Any]
    precondition(payload["delivery_ack"] as? Bool == true)
    QRMockAPI.body = "{\"success\":true,\"data\":{\"status\":\"consumed\"}}"
    try await api.acknowledgeQRSession(second, deliveryID: "receipt")
    let ack = QRMockAPI.requests.last!
    precondition(ack.url?.path == "/api/v1/auth/qr/sessions/second/ack" && ack.httpMethod == "POST")
    precondition(ack.timeoutInterval == 3)
    let requestCount = QRMockAPI.requests.count
    try await api.acknowledgeQRSession(fromOldServer, deliveryID: "ignored")
    precondition(QRMockAPI.requests.count == requestCount)
    print("PASS: QR legacy negotiation, generation isolation, expired refresh, failed cancel, sequential retry, ACK ordering and bounded HTTP bridge")
  }
}
