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
  }

  init(planID: Int?, planName: String?, uploadedBytes: Int64, downloadedBytes: Int64, transferLimit: Int64, expiredAt: TimeInterval?) {
    self.planID = planID
    self.planName = planName
    self.uploadedBytes = uploadedBytes
    self.downloadedBytes = downloadedBytes
    self.transferLimit = transferLimit
    self.expiredAt = expiredAt
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
  }
}

struct GatewayClient {
  enum GatewayError: LocalizedError {
    case missingBaseURL, invalidResponse, unauthorized, server(String)
    var errorDescription: String? {
      switch self {
      case .missingBaseURL: return "未配置服务地址"
      case .invalidResponse: return "服务响应无效"
      case .unauthorized: return "登录状态已失效，请重新登录"
      case .server(let message): return message
      }
    }
  }

  private let baseURL: URL

  private init(baseURL: URL) {
    self.baseURL = baseURL
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

  /// The panel returns the per-user subscription URL after QR authorization.
  /// The profile itself is deliberately kept in memory and is passed only to
  /// the Packet Tunnel when a connection is started.
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
    return try FastCatSubscriptionDecoder.decode(
      config,
      configuration: buildConfiguration
    )
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
    if let authorization, !authorization.isEmpty {
      request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }
    if let body {
      request.httpBody = try JSONEncoder().encode(body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
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

  private func sendVoidRequest(path: String, method: String, body: AnyEncodable? = nil) async throws {
    var request = URLRequest(
      url: try endpointURL(path),
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 20
    )
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body {
      request.httpBody = try JSONEncoder().encode(body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw GatewayError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
      throw GatewayError.server("服务暂时不可用（\(http.statusCode)）")
    }
    guard !data.isEmpty,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    if let success = object["success"] as? Bool, !success {
      throw GatewayError.server((object["message"] ?? object["msg"] ?? "请求失败") as? String ?? "请求失败")
    }
    if let code = object["code"] as? Int, code != 0, code != 200 {
      throw GatewayError.server((object["message"] ?? object["msg"] ?? "请求失败") as? String ?? "请求失败")
    }
    if let value = object["data"] as? Bool, !value {
      throw GatewayError.server((object["message"] ?? object["msg"] ?? "请求失败") as? String ?? "请求失败")
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
