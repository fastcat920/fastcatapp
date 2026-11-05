import CryptoKit
import Foundation

extension Notification.Name {
  static let tvRefreshRemoteConfiguration = Notification.Name("fastcat.tv.refreshRemoteConfiguration")
}

struct TVUpdateInfo: Equatable, Sendable {
  let latestVersion: String
  let updateURL: URL
  let releaseNotes: String
  let force: Bool
}

struct TVConfigSource: Sendable {
  let url: URL
  let emergency: Bool
  init(_ url: URL, emergency: Bool = false) { self.url = url; self.emergency = emergency }
}

struct TVRemoteSelection: Codable, Sendable {
  let raw: Data
  let verifiedAt: Date
  let source: String
  var cached: Bool = false
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

  static let cacheKey = "fastcat.tv.remote-config.raw.v2"
  static let freshAge: TimeInterval = 7 * 86400
  static let maxAge: TimeInterval = 30 * 86400
  private let defaults: UserDefaults
  private let buildProvider: () throws -> TVBuildConfiguration
  private let sourceProvider: (() throws -> [TVConfigSource])?
  private let fetch: @Sendable (URL) async throws -> Data
  private let now: () -> Date
  private var inFlight: Task<TVRemoteSelection, Error>?
  private var refreshID = UUID()
  private var resolvedSelection: TVRemoteSelection?
  private var checkedAt: Date?
  private(set) var remoteConfirmed = false
  private(set) var usingStaleCache = false

  init(defaults: UserDefaults = .standard,
       build: @escaping () throws -> TVBuildConfiguration = { try TVBuildConfiguration.load() },
       sources: (() throws -> [TVConfigSource])? = nil,
       fetch: @escaping @Sendable (URL) async throws -> Data = { try await TVRemoteConfigManager.download($0) },
       now: @escaping () -> Date = Date.init) {
    self.defaults = defaults; self.buildProvider = build
    self.sourceProvider = sources; self.fetch = fetch; self.now = now
  }

  static func download(_ url: URL) async throws -> Data {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 10
    configuration.timeoutIntervalForResource = 10
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
      throw RemoteConfigError.unavailable
    }
    return data
  }
  private var resolvedBaseURL: URL?
  private var resolvedConfig: [String: Any]?

  func apiBaseURL() async throws -> URL {
    if let json = try? await remoteConfig(), let url = apiBaseURL(from: json) {
      if let active = resolvedBaseURL, apiBaseURLs(from: json).contains(active) { return active }
      resolvedBaseURL = url
      return url
    }
    let build = try buildProvider()

    if let fallback = build.fallbackAPIBaseURL {
      resolvedBaseURL = fallback
      return fallback
    }
    throw RemoteConfigError.unavailable
  }

  /// Connectivity checks only consume already available configuration. They
  /// must not start an unbounded OSS fetch on every foreground/network event.
  func connectivityBaseURLs() -> [URL] {
    // Do not revive an expired disk or memory configuration during health checks.
    let memoryValid = resolvedSelection.map { validAge($0.verifiedAt) } ?? false
    var result = memoryValid ? resolvedConfig.map { apiBaseURLs(from: $0) } ?? [] : []
    if result.isEmpty, let cached = loadCache(), let json = try? decode(cached.raw) {
      result = apiBaseURLs(from: json)
    }
    if let active = resolvedBaseURL, result.contains(active) {
      result.removeAll { $0 == active }; result.insert(active, at: 0)
    }
    if result.isEmpty, let fallback = try? buildProvider().fallbackAPIBaseURL {
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
    let force = remoteConfirmed && ((platform["force"] as? Bool == true) || belowMinimum)

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

  /// Explicit refresh never returns solely because an in-memory value exists.
  /// Returns false when only a previously verified disk snapshot was available.
  @discardableResult
  func refresh() async throws -> Bool {
    _ = try await remoteConfig(forceRefresh: true)
    return remoteConfirmed
  }

  func remoteConfig(forceRefresh: Bool = false) async throws -> [String: Any] {
    if !forceRefresh, let checkedAt, now().timeIntervalSince(checkedAt) >= 0,
       now().timeIntervalSince(checkedAt) < 300,
       let record = resolvedSelection, validAge(record.verifiedAt), let resolvedConfig {
      return resolvedConfig
    }
    let task: Task<TVRemoteSelection, Error>
    if let running = inFlight { task = running }
    else {
      remoteConfirmed = false
      refreshID = UUID()
      task = Task { try await self.selectConfiguration() }
      inFlight = task
    }
    let id = refreshID
    do {
      let record = try await task.value
      let json = try decode(record.raw)
      guard id == refreshID else { return resolvedConfig ?? json }
      resolvedSelection = record; resolvedConfig = json; checkedAt = now()
      remoteConfirmed = !record.cached
      usingStaleCache = record.cached && now().timeIntervalSince(record.verifiedAt) > Self.freshAge
      if let active = resolvedBaseURL, !apiBaseURLs(from: json).contains(active) { resolvedBaseURL = nil }
      inFlight = nil
      return json
    } catch {
      guard id == refreshID else { throw error }
      inFlight = nil; remoteConfirmed = false
      // Never keep serving expired in-memory configuration after a failed refresh.
      if let record = resolvedSelection, !validAge(record.verifiedAt) {
        resolvedSelection = nil; resolvedConfig = nil; resolvedBaseURL = nil
      }
      throw error
    }
  }

  private func decode(_ data: Data) throws -> [String: Any] {
    let json = try decodeRemoteConfig(data, build: buildProvider())
    // Match Flutter: both a business route and a gateway route must be present.
    let business = (json["domains"] as? [String]) ??
      ((json["panels"] as? [String: Any])?.values.flatMap { value -> [String] in
        (value as? [[String: Any]])?.compactMap { $0["url"] as? String } ?? []
      } ?? [])
    let gateways = (json["gateway_urls"] as? [String] ?? []) +
      ((json["gateway_url"] as? String).map { [$0] } ?? [])
    func valid(_ raw: String) -> Bool {
      guard let u = URL(string: raw), let host = u.host, !host.isEmpty else { return false }
      return ["https", "http"].contains(u.scheme?.lowercased() ?? "")
    }
    guard business.contains(where: valid), gateways.contains(where: valid) else {
      throw RemoteConfigError.unavailable
    }
    return json
  }

  private func version(_ record: TVRemoteSelection) -> String {
    guard let json = try? decode(record.raw) else { return "" }
    return json["config_version"].map { String(describing: $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
  }

  static func compareVersions(_ a: String, _ b: String) -> Int {
    if a == b { return 0 }
    if a.isEmpty { return -1 }; if b.isEmpty { return 1 }
    let lhs = a.components(separatedBy: ".").map(Int.init)
    let rhs = b.components(separatedBy: ".").map(Int.init)
    if lhs.allSatisfy({ $0 != nil }), rhs.allSatisfy({ $0 != nil }) {
      for i in 0..<max(lhs.count, rhs.count) {
        let x = i < lhs.count ? lhs[i]! : 0, y = i < rhs.count ? rhs[i]! : 0
        if x != y { return x < y ? -1 : 1 }
      }
      return 0
    }
    return a < b ? -1 : 1
  }

  private func newer(_ left: TVRemoteSelection?, _ right: TVRemoteSelection?) -> TVRemoteSelection? {
    guard let left else { return right }; guard let right else { return left }
    return Self.compareVersions(version(left), version(right)) > 0 ? left : right
  }

  private func validAge(_ date: Date) -> Bool {
    let age = now().timeIntervalSince(date)
    return age >= 0 && age <= Self.maxAge
  }

  private func cacheable(_ data: Data) -> Bool {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
    return json["_format"] as? String == "fastcat-config-v2"
  }

  private func cacheRecords() -> [String: TVRemoteSelection] {
    guard let data = defaults.data(forKey: Self.cacheKey),
          let records = try? JSONDecoder().decode([String: TVRemoteSelection].self, from: data) else { return [:] }
    return records
  }

  private func validatedCache(_ record: TVRemoteSelection?) -> TVRemoteSelection? {
    guard var record, validAge(record.verifiedAt), cacheable(record.raw),
          (try? decode(record.raw)) != nil else { return nil }
    record.cached = true
    return record
  }

  private func loadCache() -> TVRemoteSelection? {
    let records = cacheRecords()
    // Untimestamped v1 caches are not promoted to "fresh"; fetch once online.
    return newer(validatedCache(records["previous"]), validatedCache(records["current"]))
  }

  private func persist(_ record: TVRemoteSelection) {
    guard cacheable(record.raw) else { return }
    let records = cacheRecords()
    var next = ["current": record]
    if let current = validatedCache(records["current"]), current.raw != record.raw {
      next["previous"] = current
    } else if let previous = validatedCache(records["previous"]) { next["previous"] = previous }
    if let data = try? JSONEncoder().encode(next) {
      defaults.set(data, forKey: Self.cacheKey)
      defaults.removeObject(forKey: "fastcat.tv.remote-config.v1")
    }
  }

  private func selectConfiguration() async throws -> TVRemoteSelection {
    var sources = try sourceProvider?() ?? bundledSources()
    if let preferred = defaults.string(forKey: "fastcat.tv.config.last-source"),
       let index = sources.firstIndex(where: { $0.url.absoluteString == preferred }) {
      sources.insert(sources.remove(at: index), at: 0)
    }
    let cached = loadCache()
    let normal = sources.filter { !$0.emergency }
    var live = await fetchGroup(normal)
    if live == nil, let first = normal.first { live = await fetchGroup([first]) }
    if live == nil { live = await fetchGroup(sources.filter { $0.emergency }) }
    guard let selected = newer(cached, live) else { throw RemoteConfigError.unavailable }
    if !selected.cached {
      persist(selected)
      defaults.set(selected.source, forKey: "fastcat.tv.config.last-source")
    }
    return selected
  }

  private struct FetchEvent: Sendable {
    let source: TVConfigSource?
    let data: Data?
  }

  private func fetchGroup(_ sources: [TVConfigSource]) async -> TVRemoteSelection? {
    guard !sources.isEmpty else { return nil }
    let fetch = self.fetch
    return await withTaskGroup(of: FetchEvent.self) { group in
      for source in sources {
        group.addTask {
          let data = try? await fetch(source.url)
          return FetchEvent(source: source, data: data)
        }
      }
      var best: TVRemoteSelection?
      var pending = sources.count
      var windowStarted = false
      while let event = await group.next() {
        guard let source = event.source else { break } // settlement deadline
        pending -= 1
        if let data = event.data, (try? decode(data)) != nil {
          let candidate = TVRemoteSelection(raw: data, verifiedAt: now(), source: source.url.absoluteString)
          best = newer(candidate, best)
          if pending == 0 { break }
          if !windowStarted {
            windowStarted = true
            group.addTask {
              try? await Task.sleep(nanoseconds: 350_000_000)
              return FetchEvent(source: nil, data: nil)
            }
          }
        }
        if best != nil && pending == 0 { break }
      }
      group.cancelAll()
      return best
    }
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
  /// Reads source URLs and emergency flags; no second native config is needed.
  private func bundledSources() throws -> [TVConfigSource] {
    let yaml = Bundle.main.url(forResource: "config", withExtension: "yaml")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    return try Self.sources(from: yaml)
  }

  static func sources(from yaml: String) throws -> [TVConfigSource] {

    var inRemoteConfig = false
    var inSources = false
    var remoteIndent = 0
    var sourcesIndent = 0
    var result: [TVConfigSource] = []
    var pendingURL: URL?
    var pendingEmergency = false
    func flush() {
      if let url = pendingURL { result.append(TVConfigSource(url, emergency: pendingEmergency)) }
      pendingURL = nil; pendingEmergency = false
    }

    for rawLine in yaml.components(separatedBy: .newlines) {
      let content = rawLine.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
      let trimmed = content.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }
      let indent = content.prefix { $0 == " " }.count

      if trimmed == "remote_config:" {
        inRemoteConfig = true; inSources = false; remoteIndent = indent
        continue
      }
      if inRemoteConfig, indent <= remoteIndent { flush(); inRemoteConfig = false; inSources = false }
      guard inRemoteConfig else { continue }

      if trimmed == "sources:" {
        inSources = true; sourcesIndent = indent
        continue
      }
      if inSources, indent <= sourcesIndent { flush(); inSources = false }
      guard inSources else { continue }
      if trimmed.hasPrefix("- ") { flush() }
      let field = trimmed.hasPrefix("- ") ? String(trimmed.dropFirst(2)) : trimmed
      if field.hasPrefix("is_emergency:") {
        pendingEmergency = field.dropFirst("is_emergency:".count).trimmingCharacters(in: .whitespaces) == "true"
        continue
      }
      guard field.hasPrefix("url:"), let range = trimmed.range(of: "url:") else { continue }

      var value = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
      if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
         (value.hasPrefix("'") && value.hasSuffix("'")) {
        value.removeFirst(); value.removeLast()
      }
      if let url = URL(string: value), let host = url.host, !host.isEmpty,
         !host.hasSuffix(".example.com"),
         ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
        pendingURL = url
      }
    }
    flush()
    // Same emergency endpoint as Flutter's builtinOssUrl; never race it with normal sources.
    let encoded = "DhUHBBBbWxZVVQ4WEhNOUEYMAwZfV0dNWk8XVkEfBxFeExYAGl5IWQkUXRkaEBdVXUQCTxAbDk4XWEYfDBIcGg=="
    let key = Array("fastcat921fastcat921".utf8)
    if let bytes = Data(base64Encoded: encoded),
       let raw = String(data: Data(bytes.enumerated().map { $0.element ^ key[$0.offset % key.count] }), encoding: .utf8),
       let url = URL(string: raw), !result.contains(where: { $0.url == url }) {
      result.append(TVConfigSource(url, emergency: true))
    }
    guard !result.isEmpty else { throw RemoteConfigError.noSources }
    return result
  }

  private func decodeRemoteConfig(_ data: Data, build: TVBuildConfiguration) throws -> [String: Any] {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          json["_format"] as? String == "fastcat-config-v2",
          json["algorithm"] as? String == "Ed25519",
          json["encoding"] as? String == "xor+base64",
          let payload = json["payload"] as? String,
          let signatureText = json["signature"] as? String,
          let publicKeyData = Data(base64Encoded: build.remoteConfigPublicKey),
          let signature = Data(base64Encoded: signatureText),
          let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData),
          publicKey.isValidSignature(signature, for: Data(payload.utf8)) else {
      throw RemoteConfigError.unavailable
    }
    return try decodeXORPayload(payload, xorKey: build.xorKey)
  }

  private func decodeXORPayload(_ encoded: String, xorKey: String) throws -> [String: Any] {
    guard let encrypted = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)) else {
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
