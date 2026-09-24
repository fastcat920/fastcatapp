import Foundation

actor TVRemoteConfigManager {
  static let shared = TVRemoteConfigManager()

  enum RemoteConfigError: LocalizedError {
    case noSources, unavailable

    var errorDescription: String? {
      switch self {
      case .noSources: return "共享 config.yaml 中没有可用的 OSS 配置源"
      case .unavailable: return "所有远程配置源均不可用"
      }
    }
  }

  private static let cachedConfigKey = "fastcat.tv.remote-config.v1"
  private var resolvedBaseURL: URL?

  func apiBaseURL() async throws -> URL {
    if let resolvedBaseURL { return resolvedBaseURL }
    let build = try TVBuildConfiguration.load()

    for source in try bundledSources() {
      do {
        let (data, response) = try await URLSession.shared.data(from: source)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
        let json = try decodeRemoteConfig(data, xorKey: build.xorKey)
        if let url = apiBaseURL(from: json) {
          UserDefaults.standard.set(data, forKey: Self.cachedConfigKey)
          resolvedBaseURL = url
          return url
        }
      } catch {
        NSLog("[TVRemoteConfig] source failed (%@): %@", source.host ?? "unknown", error.localizedDescription)
      }
    }

    if let cached = UserDefaults.standard.data(forKey: Self.cachedConfigKey),
       let json = try? decodeRemoteConfig(cached, xorKey: build.xorKey),
       let url = apiBaseURL(from: json) {
      resolvedBaseURL = url
      return url
    }
    if let fallback = build.fallbackAPIBaseURL {
      resolvedBaseURL = fallback
      return fallback
    }
    throw RemoteConfigError.unavailable
  }

  /// The same assets/config/config.yaml is embedded in both Flutter and tvOS.
  /// This focused parser reads only remote_config.sources[].url so adding a
  /// second native configuration file is unnecessary.
  private func bundledSources() throws -> [URL] {
    guard let file = Bundle.main.url(forResource: "config", withExtension: "yaml"),
          let yaml = try? String(contentsOf: file, encoding: .utf8) else {
      throw RemoteConfigError.noSources
    }

    var inRemoteConfig = false
    var inSources = false
    var remoteIndent = 0
    var sourcesIndent = 0
    var result: [URL] = []

    for rawLine in yaml.components(separatedBy: .newlines) {
      let content = rawLine.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
      let trimmed = content.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }
      let indent = content.prefix { $0 == " " }.count

      if trimmed == "remote_config:" {
        inRemoteConfig = true; inSources = false; remoteIndent = indent
        continue
      }
      if inRemoteConfig, indent <= remoteIndent { inRemoteConfig = false; inSources = false }
      guard inRemoteConfig else { continue }

      if trimmed == "sources:" {
        inSources = true; sourcesIndent = indent
        continue
      }
      if inSources, indent <= sourcesIndent { inSources = false }
      guard inSources, let range = trimmed.range(of: "url:") else { continue }

      var value = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
      if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
         (value.hasPrefix("'") && value.hasSuffix("'")) {
        value.removeFirst(); value.removeLast()
      }
      if let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
        result.append(url)
      }
    }
    guard !result.isEmpty else { throw RemoteConfigError.noSources }
    return result
  }

  private func decodeRemoteConfig(_ data: Data, xorKey: String) throws -> [String: Any] {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { return json }
    guard let encoded = String(data: data, encoding: .utf8),
          let encrypted = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      throw RemoteConfigError.unavailable
    }
    let key = Array(xorKey.utf8)
    guard !key.isEmpty else { throw RemoteConfigError.unavailable }
    let decrypted = Data(encrypted.enumerated().map { $0.element ^ key[$0.offset % key.count] })
    guard let json = try JSONSerialization.jsonObject(with: decrypted) as? [String: Any] else {
      throw RemoteConfigError.unavailable
    }
    return json
  }

  private func apiBaseURL(from json: [String: Any]) -> URL? {
    var gateways = json["gateway_urls"] as? [String] ?? []
    if gateways.isEmpty, let gateway = json["gateway_url"] as? String { gateways = [gateway] }
    if gateways.isEmpty { gateways = json["domains"] as? [String] ?? [] }
    let prefix = (json["api_prefix"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "/api/v1"

    for raw in gateways {
      let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      guard var components = URLComponents(string: normalized),
            ["https", "http"].contains(components.scheme?.lowercased() ?? "") else { continue }
      let cleanPrefix = prefix.hasPrefix("/") ? prefix : "/\(prefix)"
      if components.path.isEmpty || components.path == "/" { components.path = cleanPrefix }
      if let url = components.url { return url }
    }
    return nil
  }
}
