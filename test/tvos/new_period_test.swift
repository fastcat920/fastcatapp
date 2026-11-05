// Standalone, offline regression tests against the production GatewayClient.
// Run on macOS:
// swiftc tvos/FastCatTV/GatewayClient.swift test/tvos/new_period_test.swift -o /tmp/fastcat-new-period-tests
// /tmp/fastcat-new-period-tests
import Foundation

// Unrelated app dependencies are stubbed. No Keychain, config, or cache is used.
enum TVLanguage {
  case simplifiedChinese, english
  static let preferenceKey = "fastcat.test.language"
  static func resolved(from _: String) -> TVLanguage { .english }
}
func tvText(_ chinese: String, _ english: String, language: String) -> String { english }
enum KeychainStore {
  static func read(key: String) -> String? { nil }
  static func write(_ value: String, key: String) { fatalError("Unexpected Keychain write") }
}
struct TVBuildConfiguration {
  let subscriptionFlag = "test"
  static func load() throws -> TVBuildConfiguration { fatalError("Unexpected config access") }
}
enum FastCatSubscriptionDecoder {
  static func decode(_ text: String, configuration: TVBuildConfiguration) throws -> String {
    fatalError("Unexpected subscription decryption")
  }
}
actor TVRemoteConfigManager {
  static let shared = TVRemoteConfigManager()
  func apiBaseURL() throws -> URL { URL(string: "https://fastcat-test.invalid/api/v1")! }
}

final class MockPaymentFreeAPI: URLProtocol {
  static var status = 200
  static var body = "{\"data\":true}"
  static var timeout = false
  static var requests = 0

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.requests += 1
    precondition(request.url?.host == "fastcat-test.invalid")
    precondition(request.url?.path == "/api/v1/user/newPeriod")
    precondition(request.httpMethod == "POST")
    precondition(request.value(forHTTPHeaderField: "Authorization") == "fake-test-token")
    precondition(request.value(forHTTPHeaderField: "Accept-Language") == "en-US")
    if Self.timeout {
      client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
      return
    }
    let response = HTTPURLResponse(url: request.url!, statusCode: Self.status,
      httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

@main
struct NewPeriodTests {
  static func summary(_ extra: [String: Any] = [:]) throws -> TVSubscriptionSummary {
    var json: [String: Any] = ["plan_id": 1, "u": 40, "d": 60,
      "transfer_enable": 100, "allow_new_period": 1,
      "expired_at": 4_000_000_000, "next_reset_at": 3_000_000_000, "reset_day": 10]
    json.merge(extra) { _, new in new }
    return try JSONDecoder().decode(TVSubscriptionSummary.self,
      from: JSONSerialization.data(withJSONObject: json))
  }

  static func main() async throws {
    let before = try summary()
    precondition(before.canStartNewPeriod)
    for flag: Any in [true, 1, "1", "true"] {
      let value = try summary(["allow_new_period": flag])
      precondition(value.canStartNewPeriod)
    }
    for flag: Any in [false, 0, "0", "false", NSNull()] {
      let value = try summary(["allow_new_period": flag])
      precondition(!value.canStartNewPeriod)
    }
    for patch: [String: Any] in [["expired_at": 1], ["d": 0], ["transfer_enable": 0]] {
      let value = try summary(patch)
      precondition(!value.canStartNewPeriod)
    }
    precondition(!before.hasAdvancedPeriod(since: before))
    for patch: [String: Any] in [["d": 0], ["expired_at": 3_900_000_000],
                               ["next_reset_at": 3_100_000_000], ["reset_day": 15]] {
      let value = try summary(patch)
      precondition(value.hasAdvancedPeriod(since: before))
    }
    let missing = try summary(["u": NSNull(), "d": NSNull(), "expired_at": NSNull(),
                              "next_reset_at": NSNull(), "reset_day": NSNull()])
    precondition(!missing.hasAdvancedPeriod(since: before))
    let changedPlan = try summary(["plan_id": 2, "d": 0])
    precondition(!changedPlan.hasAdvancedPeriod(since: before))

    URLProtocol.registerClass(MockPaymentFreeAPI.self)
    defer { URLProtocol.unregisterClass(MockPaymentFreeAPI.self) }
    let client = try await GatewayClient.configured()
    for (status, body, expected) in [
      (200, "{\"data\":true}", "success"),
      (200, "{\"success\":true}", "success"),
      (200, "{\"code\":200}", "success"),
      (200, "{\"data\":false,\"message\":\"not allowed\"}", "rejected"),
      (200, "{\"code\":400,\"message\":\"not allowed\"}", "rejected"),
      (200, "", "uncertain"),
      (200, "<html>not an API response</html>", "uncertain"),
      (200, "{}", "uncertain"),
      (500, "{\"message\":\"server error\"}", "uncertain"),
      (408, "{}", "uncertain"),
      (200, "{\"code\":500}", "uncertain"),
      (401, "{}", "unauthorized"),
      (403, "{}", "rejected"),
    ] {
      MockPaymentFreeAPI.status = status
      MockPaymentFreeAPI.body = body
      MockPaymentFreeAPI.requests = 0
      var actual = "success"
      do { try await client.startNewPeriod(token: "fake-test-token") }
      catch GatewayClient.GatewayError.unauthorized { actual = "unauthorized" }
      catch GatewayClient.GatewayError.server { actual = "rejected" }
      catch GatewayClient.GatewayError.invalidResponse { actual = "uncertain" }
      precondition(actual == expected, "Unexpected outcome for \(status) / \(body): \(actual)")
      precondition(MockPaymentFreeAPI.requests == 1, "Must never retry the mutation")
    }
    MockPaymentFreeAPI.timeout = true
    MockPaymentFreeAPI.requests = 0
    do {
      try await client.startNewPeriod(token: "fake-test-token")
      fatalError("Expected timeout")
    } catch let error as URLError { precondition(error.code == .timedOut) }
    precondition(MockPaymentFreeAPI.requests == 1)
    print("PASS: eligibility, period comparison, authenticated POST, 14 response/timeout cases; no real network or payment.")
  }
}
