import Foundation

struct QRLoginChallenge: Decodable {
  let id: String
  let pollToken: String
  let qrData: String
  enum CodingKeys: String, CodingKey { case id; case pollToken = "poll_token"; case qrData = "qr_data" }
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

struct GatewayClient {
  enum GatewayError: LocalizedError {
    case missingBaseURL, invalidResponse, server(String)
    var errorDescription: String? {
      switch self {
      case .missingBaseURL: return "未配置服务地址"
      case .invalidResponse: return "服务响应无效"
      case .server(let message): return message
      }
    }
  }

  private let baseURL: URL

  init() throws {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "FastCatAPIBaseURL") as? String,
          !raw.isEmpty, !raw.contains("$") , let url = URL(string: raw) else {
      throw GatewayError.missingBaseURL
    }
    baseURL = url
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

  /// The panel returns the per-user subscription URL after QR authorization.
  /// The profile itself is deliberately kept in memory and is passed only to
  /// the Packet Tunnel when a connection is started.
  func downloadSubscription(token: String) async throws -> String {
    struct Subscription: Decodable { let subscribeURL: String?; enum CodingKeys: String, CodingKey { case subscribeURL = "subscribe_url" } }
    let info: Subscription = try await sendRequest(
      path: "/user/getSubscribe", method: "GET", body: nil, authorization: token
    )
    guard let rawURL = info.subscribeURL, let url = URL(string: rawURL) else {
      throw GatewayError.server("未获取到订阅链接")
    }
    var request = URLRequest(url: url)
    request.setValue("FastCatTV/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
          let config = String(data: data, encoding: .utf8), !config.isEmpty else {
      throw GatewayError.server("订阅下载失败")
    }
    return config
  }

  private func send<T: Decodable>(path: String) async throws -> T {
    try await sendRequest(path: path, method: "GET", body: nil)
  }

  private func send<T: Decodable, Body: Encodable>(path: String, method: String, body: Body) async throws -> T {
    try await sendRequest(path: path, method: method, body: AnyEncodable(body))
  }

  private func sendRequest<T: Decodable>(path: String, method: String, body: AnyEncodable?, authorization: String? = nil) async throws -> T {
    var request = URLRequest(url: baseURL.appending(path: path))
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
    guard (200..<300).contains(http.statusCode) else { throw GatewayError.server("服务暂时不可用（\(http.statusCode)）") }
    let envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
    guard let value = envelope.data else { throw GatewayError.server(envelope.message ?? "请求失败") }
    return value
  }
}

private struct APIEnvelope<T: Decodable>: Decodable { let data: T?; let message: String? }
private struct AnyEncodable: Encodable {
  private let encodeBody: (Encoder) throws -> Void
  init(_ value: some Encodable) { encodeBody = value.encode }
  func encode(to encoder: Encoder) throws { try encodeBody(encoder) }
}
