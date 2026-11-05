import CryptoKit
import Foundation

struct QRLoginChallenge: Decodable {
  let id: String
  let pollToken: String
  let qrData: String
  let expiresAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case pollToken = "poll_token"
    case qrData = "qr_data"
    case expiresAt = "expires_at"
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    pollToken = try values.decode(String.self, forKey: .pollToken)
    qrData = try values.decode(String.self, forKey: .qrData)
    if let raw = try? values.decode(String.self, forKey: .expiresAt) {
      let formatter = ISO8601DateFormatter()
      let standard = formatter.date(from: raw)
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      expiresAt = standard ?? formatter.date(from: raw) ?? Date().addingTimeInterval(120)
    } else if let seconds = values.flexibleDouble(forKey: .expiresAt) {
      expiresAt = Date(timeIntervalSince1970: seconds > 10_000_000_000 ? seconds / 1_000 : seconds)
    } else {
      expiresAt = Date().addingTimeInterval(120)
    }
  }
}

struct QRLoginResponse: Decodable {
  let status: String
  let login: LoginPayload?
  struct LoginPayload: Decodable {
    let authData: String?
    let token: String?
    let email: String?
    enum CodingKeys: String, CodingKey { case authData = "auth_data", token, email }
  }
}

struct TVLoginCredentials: Decodable {
  let authData: String?
  let token: String?
  let email: String?
  enum CodingKeys: String, CodingKey { case authData = "auth_data", token, email }
}

struct TVGuestConfig: Decodable {
  let requiresEmailVerification: Bool
  let requiresInviteCode: Bool

  private enum CodingKeys: String, CodingKey {
    case requiresEmailVerification = "is_email_verify"
    case requiresInviteCode = "is_invite_force"
  }

  init(requiresEmailVerification: Bool, requiresInviteCode: Bool) {
    self.requiresEmailVerification = requiresEmailVerification
    self.requiresInviteCode = requiresInviteCode
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    requiresEmailVerification = values.flexibleBool(forKey: .requiresEmailVerification) ?? false
    requiresInviteCode = values.flexibleBool(forKey: .requiresInviteCode) ?? false
  }
}

struct TVNotice: Decodable, Identifiable {
  let id: Int
  let title: String
  let content: String
  let isVisible: Bool
  let createdAt: TimeInterval?

  private enum CodingKeys: String, CodingKey {
    case id, title, content, show
    case createdAt = "created_at"
  }

  init(id: Int, title: String, content: String, isVisible: Bool = true, createdAt: TimeInterval? = nil) {
    self.id = id
    self.title = title
    self.content = content
    self.isVisible = isVisible
    self.createdAt = createdAt
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = values.flexibleInt(forKey: .id) ?? 0
    title = (try? values.decode(String.self, forKey: .title)) ?? "公告"
    content = (try? values.decode(String.self, forKey: .content)) ?? ""
    if let flag = try? values.decode(Bool.self, forKey: .show) {
      isVisible = flag
    } else {
      isVisible = (values.flexibleInt(forKey: .show) ?? 1) == 1
    }
    createdAt = values.flexibleDouble(forKey: .createdAt)
  }
}

struct TVSubscriptionSummary: Decodable {
  let planID: Int?
  let planName: String?
  let uploadedBytes: Int64
  let downloadedBytes: Int64
  let transferLimit: Int64
  let expiredAt: TimeInterval?
  let allowNewPeriod: Bool
  let nextResetAt: TimeInterval?
  let resetDay: Int?
  private let hasUsageCounters: Bool

  var canStartNewPeriod: Bool {
    let expiry = expiredAt.map { $0 > 10_000_000_000 ? $0 / 1000 : $0 }
    return allowNewPeriod && transferLimit > 0 && remainingBytes == 0
      && (expiry == nil || expiry == 0 || expiry! > Date().timeIntervalSince1970)
  }

  func hasAdvancedPeriod(since before: TVSubscriptionSummary) -> Bool {
    guard planID == before.planID else { return false }
    if hasUsageCounters && before.hasUsageCounters && usedBytes < before.usedBytes { return true }
    if let old = before.expiredAt, let new = expiredAt, old != new { return true }
    if let old = before.nextResetAt, let new = nextResetAt, old != new { return true }
    if let old = before.resetDay, let new = resetDay, old != new { return true }
    return false
  }

  var usedBytes: Int64 { max(0, uploadedBytes + downloadedBytes) }
  var remainingBytes: Int64 { max(0, transferLimit - usedBytes) }
  var usageFraction: Double {
    guard transferLimit > 0 else { return 0 }
    return min(1, max(0, Double(usedBytes) / Double(transferLimit)))
  }

  private struct Plan: Decodable {
    let name: String?
  }

  private enum CodingKeys: String, CodingKey {
    case plan
    case planID = "plan_id"
    case planName = "plan_name"
    case uploadedBytes = "u"
    case downloadedBytes = "d"
    case transferLimit = "transfer_enable"
    case expiredAt = "expired_at"
    case allowNewPeriod = "allow_new_period"
    case nextResetAt = "next_reset_at"
    case resetDay = "reset_day"
  }

  init(planID: Int?, planName: String?, uploadedBytes: Int64, downloadedBytes: Int64, transferLimit: Int64, expiredAt: TimeInterval?, allowNewPeriod: Bool = false, nextResetAt: TimeInterval? = nil, resetDay: Int? = nil) {
    self.planID = planID
    self.planName = planName
    self.uploadedBytes = uploadedBytes
    self.downloadedBytes = downloadedBytes
    self.transferLimit = transferLimit
    self.expiredAt = expiredAt
    self.allowNewPeriod = allowNewPeriod
    self.nextResetAt = nextResetAt
    self.resetDay = resetDay
    self.hasUsageCounters = true
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    planID = values.flexibleInt(forKey: .planID)
    let nestedPlan = try? values.decode(Plan.self, forKey: .plan)
    planName = (try? values.decode(String.self, forKey: .planName)) ?? nestedPlan?.name
    uploadedBytes = Int64(values.flexibleDouble(forKey: .uploadedBytes) ?? 0)
    downloadedBytes = Int64(values.flexibleDouble(forKey: .downloadedBytes) ?? 0)
    transferLimit = Int64(values.flexibleDouble(forKey: .transferLimit) ?? 0)
    expiredAt = values.flexibleDouble(forKey: .expiredAt)
    allowNewPeriod = values.flexibleBool(forKey: .allowNewPeriod) ?? false
    nextResetAt = values.flexibleDouble(forKey: .nextResetAt)
    resetDay = values.flexibleInt(forKey: .resetDay)
    hasUsageCounters = values.flexibleDouble(forKey: .uploadedBytes) != nil
      && values.flexibleDouble(forKey: .downloadedBytes) != nil
  }
}

struct GatewayClient {
  static let serviceRequestFailed = Notification.Name("fastcat.service.requestFailed")
  static let serviceRequestSucceeded = Notification.Name("fastcat.service.requestSucceeded")
  enum GatewayError: LocalizedError {
    case missingBaseURL, invalidResponse, unauthorized, server(String)
    var errorDescription: String? {
      let language = UserDefaults.standard.string(forKey: TVLanguage.preferenceKey) ?? "system"
      switch self {
      case .missingBaseURL: return tvText("未配置服务地址", "Service address is not configured", language: language)
      case .invalidResponse: return tvText("服务响应无效", "Invalid server response", language: language)
      case .unauthorized: return tvText("登录状态已失效，请重新登录", "Your session has expired. Please sign in again.", language: language)
      case .server(let message): return message
      }
    }
  }

  private let baseURL: URL
  private let contentLanguage: String

  private init(baseURL: URL) {
    self.baseURL = baseURL
    let language = UserDefaults.standard.string(forKey: TVLanguage.preferenceKey) ?? "system"
    contentLanguage = TVLanguage.resolved(from: language) == .simplifiedChinese ? "zh-CN" : "en-US"
  }

  static func configured() async throws -> GatewayClient {
    GatewayClient(baseURL: try await TVRemoteConfigManager.shared.apiBaseURL())
  }

  func createQRSession() async throws -> QRLoginChallenge {
    struct Request: Encodable { let device_id: String; let device_name: String; let platform: String; let app_version: String; let build_number: String }
    let id = KeychainStore.read(key: "device-id") ?? "fastcat-" + UUID().uuidString.lowercased()
    KeychainStore.write(id, key: "device-id")
    let bundle = Bundle.main
    let request = Request(device_id: id, device_name: "Apple TV", platform: "tvos", app_version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0", build_number: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
    return try await send(path: "/auth/qr/sessions", method: "POST", body: request)
  }

  func pollQRSession(_ challenge: QRLoginChallenge) async throws -> QRLoginResponse {
    let token = challenge.pollToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    return try await send(path: "/auth/qr/sessions/\(challenge.id)?poll_token=\(token)")
  }

  func cancelQRSession(_ challenge: QRLoginChallenge) async throws {
    let token = challenge.pollToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    try await sendVoidRequest(
      path: "/auth/qr/sessions/\(challenge.id)?poll_token=\(token)",
      method: "DELETE"
    )
  }

  func fetchGuestConfig() async throws -> TVGuestConfig {
    try await send(path: "/guest/comm/config")
  }

  func sendEmailVerification(to email: String) async throws {
    struct Request: Encodable { let email: String }
    try await sendVoidOrEnvelope(path: "/passport/comm/sendEmailVerify", body: Request(email: email))
  }

  func register(
    email: String,
    password: String,
    emailCode: String?,
    inviteCode: String?
  ) async throws {
    struct Request: Encodable {
      let email: String
      let password: String
      let email_code: String?
      let invite_code: String?
    }
    try await sendVoidOrEnvelope(
      path: "/passport/auth/register",
      body: Request(email: email, password: password, email_code: emailCode, invite_code: inviteCode)
    )
  }

  func resetPassword(email: String, password: String, emailCode: String) async throws {
    struct Request: Encodable { let email: String; let password: String; let email_code: String }
    try await sendVoidOrEnvelope(
      path: "/passport/auth/forget",
      body: Request(email: email, password: password, email_code: emailCode)
    )
  }

  func login(email: String, password: String) async throws -> TVLoginCredentials {
    struct Request: Encodable {
      let email: String
      let password: String
      let device_id: String
      let device_name: String
      let platform: String
      let app_version: String
      let build_number: String
      let os_version: String
    }
    let id = KeychainStore.read(key: "device-id") ?? "fastcat-" + UUID().uuidString.lowercased()
    KeychainStore.write(id, key: "device-id")
    let bundle = Bundle.main
    let request = Request(
      email: email,
      password: password,
      device_id: id,
      device_name: "Apple TV",
      platform: "tvos",
      app_version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
      build_number: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
      os_version: ProcessInfo.processInfo.operatingSystemVersionString
    )
    let result: TVLoginCredentials = try await send(
      path: "/passport/auth/login",
      method: "POST",
      body: request
    )
    guard result.authData?.isEmpty == false || result.token?.isEmpty == false else {
      throw GatewayError.server("邮箱或密码错误")
    }
    return result
  }

  /// Returns a locally cached subscription after authenticating and decrypting
  /// its server envelope entirely in memory.
  static func cachedSubscription(token: String) async throws -> String? {
    let buildConfiguration = try TVBuildConfiguration.load()
    return try await TVSubscriptionCache.shared.read(
      token: token,
      configuration: buildConfiguration
    )
  }

  static func clearCachedSubscriptions() async {
    await TVSubscriptionCache.shared.clearAll()
  }

  /// The panel returns the per-user subscription URL after authorization. The
  /// original authenticated envelope is cached; plaintext remains in memory.
  func downloadSubscription(token: String) async throws -> String {
    struct Subscription: Decodable { let subscribeURL: String?; enum CodingKeys: String, CodingKey { case subscribeURL = "subscribe_url" } }
    let info: Subscription = try await sendRequest(
      path: "/user/getSubscribe", method: "GET", body: nil, authorization: token
    )
    guard let rawURL = info.subscribeURL, var components = URLComponents(string: rawURL) else {
      throw GatewayError.server("未获取到订阅链接")
    }
    let buildConfiguration = try TVBuildConfiguration.load()
    var queryItems = components.queryItems ?? []
    queryItems.removeAll { $0.name == "flag" }
    queryItems.append(URLQueryItem(name: "flag", value: buildConfiguration.subscriptionFlag))
    components.queryItems = queryItems
    guard let url = components.url else { throw GatewayError.server("订阅链接无效") }
    var request = URLRequest(url: url)
    request.setValue("FastCat 3.5.9 · Windows", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
          let config = String(data: data, encoding: .utf8), !config.isEmpty else {
      throw GatewayError.server("订阅下载失败")
    }
    let plaintext = try FastCatSubscriptionDecoder.decode(
      config,
      configuration: buildConfiguration
    )
    try await TVSubscriptionCache.shared.write(envelope: config, token: token)
    return plaintext
  }

  func fetchNotices(token: String) async throws -> [TVNotice] {
    let collection: TVNoticeCollection = try await sendRequest(
      path: "/user/notice/fetch", method: "GET", body: nil, authorization: token
    )
    return collection.items.filter(\.isVisible)
  }

  func fetchSubscriptionSummary(token: String) async throws -> TVSubscriptionSummary {
    try await sendRequest(
      path: "/user/getSubscribe", method: "GET", body: nil, authorization: token
    )
  }

  /// Changes the existing entitlement; does not create an order or checkout.
  /// This POST is deliberately never retried automatically.
  func startNewPeriod(token: String) async throws {
    try await sendVoidRequest(
      path: "/user/newPeriod", method: "POST",
      body: AnyEncodable([String: String]()), authorization: token,
      requireAcknowledgement: true
    )
  }

  func heartbeat(token: String) async throws -> String? {
    struct Status: Decodable { let device_policy: String? }
    let status: Status = try await sendRequest(
      path: "/user/devices/heartbeat", method: "POST",
      body: AnyEncodable([String: String]()), authorization: token
    )
    return status.device_policy
  }

  private func send<T: Decodable>(path: String) async throws -> T {
    try await sendRequest(path: path, method: "GET", body: nil)
  }

  private func send<T: Decodable, Body: Encodable>(path: String, method: String, body: Body) async throws -> T {
    try await sendRequest(path: path, method: method, body: AnyEncodable(body))
  }

  private func sendRequest<T: Decodable>(path: String, method: String, body: AnyEncodable?, authorization: String? = nil) async throws -> T {
    var request = URLRequest(
      url: try endpointURL(path),
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 20
    )
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(contentLanguage, forHTTPHeaderField: "Accept-Language")
    request.setValue(contentLanguage, forHTTPHeaderField: "X-Locale")
    if let authorization, !authorization.isEmpty {
      request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }
    if let body {
      request.httpBody = try JSONEncoder().encode(body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await performBusinessRequest(request)
    guard let http = response as? HTTPURLResponse else { throw GatewayError.invalidResponse }
    if http.statusCode == 401 { throw GatewayError.unauthorized }
    guard (200..<300).contains(http.statusCode) else { throw GatewayError.server("服务暂时不可用（\(http.statusCode)）") }
    let envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
    guard let value = envelope.data else { throw GatewayError.server(envelope.message ?? "请求失败") }
    return value
  }

  private func sendVoidOrEnvelope<Body: Encodable>(path: String, body: Body) async throws {
    try await sendVoidRequest(path: path, method: "POST", body: AnyEncodable(body))
  }

  private func performBusinessRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
    do {
      let result = try await URLSession.shared.data(for: request)
      if let response = result.1 as? HTTPURLResponse {
        if (200..<300).contains(response.statusCode) {
          NotificationCenter.default.post(name: Self.serviceRequestSucceeded, object: nil)
        } else if response.statusCode >= 500 {
          NotificationCenter.default.post(name: Self.serviceRequestFailed, object: nil)
        }
      }
      return result
    } catch {
      if (error as? URLError)?.code != .cancelled {
        NotificationCenter.default.post(name: Self.serviceRequestFailed, object: nil)
      }
      throw error
    }
  }

  private func sendVoidRequest(path: String, method: String, body: AnyEncodable? = nil, authorization: String? = nil, requireAcknowledgement: Bool = false) async throws {
    var request = URLRequest(
      url: try endpointURL(path),
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 20
    )
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(contentLanguage, forHTTPHeaderField: "Accept-Language")
    request.setValue(contentLanguage, forHTTPHeaderField: "X-Locale")
    if let authorization {
      request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }
    if let body {
      request.httpBody = try JSONEncoder().encode(body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await performBusinessRequest(request)
    guard let http = response as? HTTPURLResponse else { throw GatewayError.invalidResponse }
    if http.statusCode == 401 { throw GatewayError.unauthorized }
    // A server error might occur after an irreversible mutation was applied.
    if requireAcknowledgement && (http.statusCode >= 500 || http.statusCode == 408) {
      throw GatewayError.invalidResponse
    }
    guard (200..<300).contains(http.statusCode) else {
      throw GatewayError.server("服务暂时不可用（\(http.statusCode)）")
    }
    guard !data.isEmpty,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      if requireAcknowledgement { throw GatewayError.invalidResponse }
      return
    }
    if let success = object["success"] as? Bool, !success {
      throw GatewayError.server((object["message"] ?? object["msg"] ?? "请求失败") as? String ?? "请求失败")
    }
    if let code = object["code"] as? Int, code != 0, code != 200 {
      if requireAcknowledgement && (code >= 500 || code == 408) { throw GatewayError.invalidResponse }
      throw GatewayError.server((object["message"] ?? object["msg"] ?? "请求失败") as? String ?? "请求失败")
    }
    if let value = object["data"] as? Bool, !value {
      throw GatewayError.server((object["message"] ?? object["msg"] ?? "请求失败") as? String ?? "请求失败")
    }
    if requireAcknowledgement {
      let code = object["code"] as? Int
      guard object["data"] as? Bool == true || object["success"] as? Bool == true || code == 0 || code == 200 else {
        throw GatewayError.invalidResponse
      }
    }
  }

  /// `URL.appending(path:)` percent-encodes `?`, which turns poll_token into
  /// part of the route and makes every QR poll return 404. Preserve an already
  /// encoded query while appending only the route to the configured API base.
  private func endpointURL(_ endpoint: String) throws -> URL {
    let parts = endpoint.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      throw GatewayError.missingBaseURL
    }
    let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let endpointPath = String(parts[0]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    components.path = "/" + [basePath, endpointPath].filter { !$0.isEmpty }.joined(separator: "/")
    components.percentEncodedQuery = parts.count == 2 ? String(parts[1]) : nil
    guard let url = components.url else { throw GatewayError.invalidResponse }
    return url
  }
}

private actor TVSubscriptionCache {
  static let shared = TVSubscriptionCache()

  private let fileManager = FileManager.default

  func read(token: String, configuration: TVBuildConfiguration) throws -> String? {
    let paths = try cachePaths(token: token)
    var currentError: Error?
    for url in [paths.current, paths.previous, paths.older] {
      guard fileManager.fileExists(atPath: url.path) else { continue }
      do {
        let envelope = try String(contentsOf: url, encoding: .utf8)
        let plaintext = try FastCatSubscriptionDecoder.decode(
          envelope,
          configuration: configuration
        )
        if url != paths.current {
          try? restoreFallback(from: url, paths: paths)
        }
        return plaintext
      } catch {
        currentError = currentError ?? error
      }
    }
    if let currentError { throw currentError }
    return nil
  }

  func write(envelope: String, token: String) throws {
    let paths = try cachePaths(token: token)
    try fileManager.createDirectory(
      at: paths.directory,
      withIntermediateDirectories: true
    )
    if fileManager.fileExists(atPath: paths.staging.path) {
      try fileManager.removeItem(at: paths.staging)
    }
    try Data(envelope.utf8).write(to: paths.staging, options: .atomic)
    do {
      if fileManager.fileExists(atPath: paths.older.path) {
        try fileManager.removeItem(at: paths.older)
      }
      if fileManager.fileExists(atPath: paths.previous.path) {
        try fileManager.moveItem(at: paths.previous, to: paths.older)
      }
      if fileManager.fileExists(atPath: paths.current.path) {
        try fileManager.moveItem(at: paths.current, to: paths.previous)
      }
      try fileManager.moveItem(at: paths.staging, to: paths.current)
      try? pruneOtherTokenDirectories(keeping: paths.directory)
    } catch {
      if !fileManager.fileExists(atPath: paths.current.path),
         fileManager.fileExists(atPath: paths.previous.path) {
        try? fileManager.copyItem(at: paths.previous, to: paths.current)
      }
      throw error
    }
  }

  func clearAll() {
    guard let root = try? cacheRoot(), fileManager.fileExists(atPath: root.path) else { return }
    try? fileManager.removeItem(at: root)
  }

  private func restoreFallback(from fallback: URL, paths: CachePaths) throws {
    if fileManager.fileExists(atPath: paths.current.path) {
      try fileManager.removeItem(at: paths.current)
    }
    try fileManager.copyItem(at: fallback, to: paths.current)
  }

  private func pruneOtherTokenDirectories(keeping retainedDirectory: URL) throws {
    let root = try cacheRoot()
    guard fileManager.fileExists(atPath: root.path) else { return }
    let entries = try fileManager.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    for entry in entries where entry.standardizedFileURL != retainedDirectory.standardizedFileURL {
      let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
      guard values.isDirectory == true else { continue }
      try fileManager.removeItem(at: entry)
    }
  }

  private func cachePaths(token: String) throws -> CachePaths {
    let digest = SHA256.hash(data: Data(token.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
    let directory = try cacheRoot().appendingPathComponent(digest, isDirectory: true)
    return CachePaths(
      directory: directory,
      current: directory.appendingPathComponent("current.fcat"),
      previous: directory.appendingPathComponent("previous.fcat"),
      older: directory.appendingPathComponent("previous-2.fcat"),
      staging: directory.appendingPathComponent("current.fcat.new")
    )
  }

  private func cacheRoot() throws -> URL {
    let support = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    return support.appendingPathComponent("FastCat/Subscriptions", isDirectory: true)
  }

  private struct CachePaths {
    let directory: URL
    let current: URL
    let previous: URL
    let older: URL
    let staging: URL
  }
}

private struct APIEnvelope<T: Decodable>: Decodable { let data: T?; let message: String? }

private struct TVNoticeCollection: Decodable {
  let items: [TVNotice]

  private enum CodingKeys: String, CodingKey { case data, notices, items, list, records }

  init(from decoder: Decoder) throws {
    if let array = try? decoder.singleValueContainer().decode([TVNotice].self) {
      items = array
      return
    }
    let values = try decoder.container(keyedBy: CodingKeys.self)
    for key in [CodingKeys.data, .notices, .items, .list, .records] {
      if let array = try? values.decode([TVNotice].self, forKey: key) {
        items = array
        return
      }
    }
    items = []
  }
}

private extension KeyedDecodingContainer {
  func flexibleInt(forKey key: Key) -> Int? {
    if let value = try? decode(Int.self, forKey: key) { return value }
    if let value = try? decode(Double.self, forKey: key) { return Int(value) }
    if let value = try? decode(String.self, forKey: key) { return Int(value) }
    return nil
  }

  func flexibleDouble(forKey key: Key) -> Double? {
    if let value = try? decode(Double.self, forKey: key) { return value }
    if let value = try? decode(Int64.self, forKey: key) { return Double(value) }
    if let value = try? decode(String.self, forKey: key) { return Double(value) }
    return nil
  }

  func flexibleBool(forKey key: Key) -> Bool? {
    if let value = try? decode(Bool.self, forKey: key) { return value }
    if let value = try? decode(Int.self, forKey: key) { return value != 0 }
    if let value = try? decode(String.self, forKey: key) {
      return ["1", "true", "yes", "on"].contains(value.lowercased())
    }
    return nil
  }
}

private struct AnyEncodable: Encodable {
  private let encodeBody: (Encoder) throws -> Void
  init(_ value: some Encodable) { encodeBody = value.encode }
  func encode(to encoder: Encoder) throws { try encodeBody(encoder) }
}
