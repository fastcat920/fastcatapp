import Foundation

struct TVUpdateInfo: Equatable, Sendable {
  let latestVersion: String
  let updateURL: URL
  let releaseNotes: String
  let force: Bool
}

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
  private var resolvedConfig: [String: Any]?

  func apiBaseURL() async throws -> URL {
    if let resolvedBaseURL { return resolvedBaseURL }
    if let json = try? await remoteConfig(), let url = apiBaseURL(from: json) {
      resolvedBaseURL = url
      return url
    }
    let build = try TVBuildConfiguration.load()

    if let fallback = build.fallbackAPIBaseURL {
      resolvedBaseURL = fallback
      return fallback
    }
    throw RemoteConfigError.unavailable
  }

  /// Connectivity checks only consume already available configuration. They
  /// must not start an unbounded OSS fetch on every foreground/network event.
  func connectivityBaseURLs() -> [URL] {
    var result = resolvedConfig.map { apiBaseURLs(from: $0) } ?? []
    if result.isEmpty, let build = try? TVBuildConfiguration.load(),
       let cached = UserDefaults.standard.data(forKey: Self.cachedConfigKey),
       let json = try? decodeRemoteConfig(cached, xorKey: build.xorKey) {
      result = apiBaseURLs(from: json)
    }
    if let resolvedBaseURL, !result.contains(resolvedBaseURL) { result.insert(resolvedBaseURL, at: 0) }
    if result.isEmpty, let fallback = try? TVBuildConfiguration.load().fallbackAPIBaseURL {
      result = [fallback]
    }
    return result
  }

  func useHealthyGateway(_ url: URL) {
    guard connectivityBaseURLs().contains(url) else { return }
    resolvedBaseURL = url
  }

  func availableTVUpdate(language: TVLanguage) async -> TVUpdateInfo? {
    guard let json = try? await remoteConfig(),
          let update = json["update"] as? [String: Any] else { return nil }

    let legacy = (update["latest"] as? [String: Any])?["tvos"] as? [String: Any]
    let modernPlatforms = update["platforms"] as? [String: Any]
    let hasModernTVOS = modernPlatforms?.keys.contains("tvos") == true
    let modern = modernPlatforms?["tvos"] as? [String: Any]
    let selected = hasModernTVOS ? modern : legacy

    guard let platform = selected else { return nil }
    if hasModernTVOS, platform["enabled"] as? Bool == false { return nil }

    let latest = cleanString(platform["latest_version"] ?? platform["version"])
    let current = cleanString(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString"))
    guard !latest.isEmpty, isNewerVersion(current: current, latest: latest) else { return nil }

    let rawURL = cleanString(platform["url"])
    let appID = cleanString(platform["app_id"])
    let updateURL: URL?
    if !rawURL.isEmpty {
      updateURL = URL(string: rawURL)
    } else if !appID.isEmpty {
      let normalizedID = appID.hasPrefix("id") ? appID : "id\(appID)"
      updateURL = URL(string: "https://apps.apple.com/app/\(normalizedID)")
    } else {
      updateURL = nil
    }
    guard let updateURL,
          ["https", "http"].contains(updateURL.scheme?.lowercased() ?? "") else { return nil }

    let platformMin = cleanString(platform["min_supported_version"])
    let legacyMin = cleanString(update["min_version"])
    let minimum = platformMin.isEmpty ? legacyMin : platformMin
    let belowMinimum = !minimum.isEmpty && isNewerVersion(current: current, latest: minimum)
    let force = (platform["force"] as? Bool == true) || belowMinimum

    return TVUpdateInfo(
      latestVersion: latest,
      updateURL: updateURL,
      releaseNotes: localizedChangelog(
        platform["changelog"],
        fallback: update["changelog"],
        language: language
      ),
      force: force
    )
  }

  private func remoteConfig() async throws -> [String: Any] {
    if let resolvedConfig { return resolvedConfig }
    let build = try TVBuildConfiguration.load()

    for source in try bundledSources() {
      do {
        let (data, response) = try await URLSession.shared.data(from: source)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
        let json = try decodeRemoteConfig(data, xorKey: build.xorKey)
        if apiBaseURL(from: json) != nil {
          UserDefaults.standard.set(data, forKey: Self.cachedConfigKey)
          resolvedConfig = json
          return json
        }
      } catch {
        NSLog("[TVRemoteConfig] source failed (%@): %@", source.host ?? "unknown", error.localizedDescription)
      }
    }

    if let cached = UserDefaults.standard.data(forKey: Self.cachedConfigKey),
       let json = try? decodeRemoteConfig(cached, xorKey: build.xorKey),
       apiBaseURL(from: json) != nil {
      resolvedConfig = json
      return json
    }
    throw RemoteConfigError.unavailable
  }

  private func cleanString(_ value: Any?) -> String {
    (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private func localizedChangelog(
    _ value: Any?,
    fallback: Any?,
    language: TVLanguage
  ) -> String {
    if let map = value as? [String: Any] {
      let keys = language == .simplifiedChinese
        ? ["zh_CN", "zh-CN", "zh"] : ["en_US", "en-US", "en"]
      for key in keys {
        let text = cleanString(map[key])
        if !text.isEmpty { return text }
      }
      for candidate in map.values {
        let text = cleanString(candidate)
        if !text.isEmpty { return text }
      }
    } else {
      let text = cleanString(value)
      if !text.isEmpty { return text }
    }
    return cleanString(fallback)
  }

  private func isNewerVersion(current: String, latest: String) -> Bool {
    func components(_ value: String) -> [Int] {
      let normalized = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
        .components(separatedBy: CharacterSet(charactersIn: "+-"))[0]
      return normalized.split(separator: ".").map { Int($0) ?? 0 }
    }
    let currentParts = components(current)
    let latestParts = components(latest)
    for index in 0..<max(currentParts.count, latestParts.count, 3) {
      let currentValue = index < currentParts.count ? currentParts[index] : 0
      let latestValue = index < latestParts.count ? latestParts[index] : 0
      if latestValue != currentValue { return latestValue > currentValue }
    }
    return false
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
    apiBaseURLs(from: json).first
  }

  private func apiBaseURLs(from json: [String: Any]) -> [URL] {
    var gateways = json["gateway_urls"] as? [String] ?? []
    if gateways.isEmpty, let gateway = json["gateway_url"] as? String { gateways = [gateway] }
    if gateways.isEmpty { gateways = json["domains"] as? [String] ?? [] }
    let prefix = (json["api_prefix"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "/api/v1"

    var result: [URL] = []
    for raw in gateways {
      let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      guard var components = URLComponents(string: normalized),
            ["https", "http"].contains(components.scheme?.lowercased() ?? "") else { continue }
      let cleanPrefix = prefix.hasPrefix("/") ? prefix : "/\(prefix)"
      if components.path.isEmpty || components.path == "/" { components.path = cleanPrefix }
      if let url = components.url, !result.contains(url) { result.append(url) }
    }
    return result
  }
}
