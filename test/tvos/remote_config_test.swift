// Offline tests: production config manager + build configuration, no real OSS requests.
import Foundation
import CryptoKit

enum TVLanguage { case simplifiedChinese, english }

actor ConfigRequests {
  var count = 0
  func add() { count += 1 }
}

@main
struct RemoteConfigTests {
  static let clock = Date(timeIntervalSince1970: 1_790_000_000)
  static let xorKey = "test-config-key"
  static let signingKey = Curve25519.Signing.PrivateKey()
  static let normal = URL(string: "https://normal.invalid/config")!
  static let backup = URL(string: "https://backup.invalid/config")!
  static let emergency = URL(string: "https://emergency.invalid/config")!

  static func wire(_ version: String) throws -> Data {
    let plain = try JSONSerialization.data(withJSONObject: [
      "config_version": version, "domains": ["https://api.invalid"],
      "gateway_urls": ["https://gateway.invalid"],
    ])
    let key = Array(xorKey.utf8)
    let payload = Data(plain.enumerated().map { $0.element ^ key[$0.offset % key.count] }).base64EncodedString()
    return try JSONSerialization.data(withJSONObject: [
      "_format": "fastcat-config-v2", "algorithm": "Ed25519", "encoding": "xor+base64",
      "payload": payload, "signature": try signingKey.signature(for: Data(payload.utf8)).base64EncodedString(),
    ])
  }

  static func record(_ raw: Data, days: Int = 0) -> TVRemoteSelection {
    TVRemoteSelection(raw: raw, verifiedAt: clock.addingTimeInterval(Double(-days) * 86400), source: "fixture")
  }

  static func seed(_ records: [String: TVRemoteSelection], _ defaults: UserDefaults) throws {
    defaults.set(try JSONEncoder().encode(records), forKey: TVRemoteConfigManager.cacheKey)
  }

  static func manager(_ defaults: UserDefaults, publicKey: String? = nil, sources: [TVConfigSource] = [],
                      fetch: @escaping @Sendable (URL) async throws -> Data = { _ in throw URLError(.notConnectedToInternet) }) -> TVRemoteConfigManager {
    TVRemoteConfigManager(defaults: defaults, build: {
      TVBuildConfiguration(xorKey: xorKey, remoteConfigPublicKey: publicKey ?? signingKey.publicKey.rawRepresentation.base64EncodedString(),
        subscriptionFlag: "test", subscriptionKeys: [:], requireSubscriptionEncryption: true, fallbackAPIBaseURL: nil)
    }, sources: { sources }, fetch: fetch, now: { clock })
  }

  static func version(_ manager: TVRemoteConfigManager) async throws -> String {
    let result = try await manager.remoteConfig()
    return result["config_version"] as? String ?? ""
  }

  static func expectFailure(_ manager: TVRemoteConfigManager) async {
    do { _ = try await manager.remoteConfig(); fatalError("Expected invalid cache rejection") }
    catch {}
  }

  static func main() async throws {
    let suite = "fastcat-remote-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let one = try wire("1"), two = try wire("2"), three = try wire("3")
    let sources = [TVConfigSource(normal), TVConfigSource(backup), TVConfigSource(emergency, emergency: true)]
    let requests = ConfigRequests()
    let parallel = manager(defaults, sources: sources) { url in
      await requests.add()
      precondition(url != emergency, "Emergency must not race healthy normal sources")
      if url == backup { try await Task.sleep(nanoseconds: 20_000_000); return two }
      return one
    }
    async let first = parallel.refresh()
    async let second = parallel.refresh()
    _ = try await (first, second)
    let requestCount = await requests.count
    precondition(requestCount == 2, "Refresh must be coalesced")
    let selected = try await version(parallel)
    precondition(selected == "2")
    let rawCache = defaults.data(forKey: TVRemoteConfigManager.cacheKey)!
    let records = try JSONDecoder().decode([String: TVRemoteSelection].self, from: rawCache)
    precondition(records["current"]?.raw == two)
    precondition(!String(decoding: rawCache, as: UTF8.self).contains("gateway.invalid"))

    let refresh = manager(defaults, sources: [TVConfigSource(normal)]) { _ in three }
    _ = try await refresh.refresh()
    let rotated = try JSONDecoder().decode([String: TVRemoteSelection].self,
      from: defaults.data(forKey: TVRemoteConfigManager.cacheKey)!)
    precondition(rotated["current"]?.raw == three && rotated["previous"]?.raw == two)

    try seed(["current": record(three, days: 8)], defaults)
    let stale = manager(defaults)
    let offlineVersion = try await version(stale)
    let isStale = await stale.usingStaleCache
    let confirmed = await stale.remoteConfirmed
    precondition(offlineVersion == "3" && isStale && !confirmed)
    let persisted = try JSONDecoder().decode([String: TVRemoteSelection].self,
      from: defaults.data(forKey: TVRemoteConfigManager.cacheKey)!)
    precondition(persisted["current"]?.verifiedAt == record(three, days: 8).verifiedAt)
    let lower = manager(defaults, sources: [TVConfigSource(normal)]) { _ in two }
    let lowerConfirmed = try await lower.refresh()
    precondition(!lowerConfirmed)
    let equal = manager(defaults, sources: [TVConfigSource(normal)]) { _ in three }
    let equalConfirmed = try await equal.refresh()
    precondition(equalConfirmed)
    let renewed = try JSONDecoder().decode([String: TVRemoteSelection].self,
      from: defaults.data(forKey: TVRemoteConfigManager.cacheKey)!)
    precondition(renewed["current"]?.verifiedAt == clock)

    for age in [31, -1] {
      try seed(["current": record(three, days: age)], defaults)
      await expectFailure(manager(defaults))
    }
    try seed(["current": record(Data("corrupt".utf8)), "previous": record(two)], defaults)
    let fallbackVersion = try await version(manager(defaults))
    precondition(fallbackVersion == "2")
    _ = try await manager(defaults, sources: [TVConfigSource(normal)], fetch: { _ in three }).refresh()
    let repaired = try JSONDecoder().decode([String: TVRemoteSelection].self,
      from: defaults.data(forKey: TVRemoteConfigManager.cacheKey)!)
    precondition(repaired["previous"]?.raw == two)

    let key = Curve25519.Signing.PrivateKey()
    let payload = (try JSONSerialization.jsonObject(with: three) as! [String: String])["payload"]!
    let signature = try key.signature(for: Data(payload.utf8))
    var envelope = ["_format": "fastcat-config-v2", "algorithm": "Ed25519", "encoding": "xor+base64",
      "payload": payload, "signature": signature.base64EncodedString()]
    let signed = try JSONSerialization.data(withJSONObject: envelope)
    try seed(["current": record(signed)], defaults)
    let signedVersion = try await version(manager(defaults, publicKey: key.publicKey.rawRepresentation.base64EncodedString()))
    precondition(signedVersion == "3")
    await expectFailure(manager(defaults))
    envelope["payload"] = (try JSONSerialization.jsonObject(with: two) as! [String: String])["payload"]!
    try seed(["current": record(try JSONSerialization.data(withJSONObject: envelope))], defaults)
    await expectFailure(manager(defaults, publicKey: key.publicKey.rawRepresentation.base64EncodedString()))

    defaults.removeObject(forKey: TVRemoteConfigManager.cacheKey)
    defaults.set(three, forKey: "fastcat.tv.remote-config.v1")
    await expectFailure(manager(defaults))
    let emergencyManager = manager(defaults, sources: sources) { url in
      if url == emergency { return three }
      throw URLError(.notConnectedToInternet)
    }
    let emergencyVersion = try await version(emergencyManager)
    precondition(emergencyVersion == "3")
    precondition(defaults.data(forKey: "fastcat.tv.remote-config.v1") == nil)

    defaults.removeObject(forKey: TVRemoteConfigManager.cacheKey)
    let plain = try JSONSerialization.data(withJSONObject: ["domains": ["https://api.invalid"], "gateway_urls": ["https://gateway.invalid"]])
    await expectFailure(manager(defaults, sources: [TVConfigSource(normal)], fetch: { _ in plain }))
    precondition(defaults.data(forKey: TVRemoteConfigManager.cacheKey) == nil)
    var stripped = try JSONSerialization.jsonObject(with: three) as! [String: String]
    stripped.removeValue(forKey: "_format")
    var missingSignature = try JSONSerialization.jsonObject(with: three) as! [String: String]
    missingSignature.removeValue(forKey: "signature")
    var invalidAlgorithm = try JSONSerialization.jsonObject(with: three) as! [String: String]
    invalidAlgorithm["algorithm"] = "none"
    for raw in [Data(payload.utf8), try JSONSerialization.data(withJSONObject: stripped),
                try JSONSerialization.data(withJSONObject: missingSignature),
                try JSONSerialization.data(withJSONObject: invalidAlgorithm)] {
      defaults.removeObject(forKey: TVRemoteConfigManager.cacheKey)
      await expectFailure(manager(defaults, sources: [TVConfigSource(normal)], fetch: { _ in raw }))
      try seed(["current": record(raw)], defaults)
      await expectFailure(manager(defaults))
    }
    try seed(["current": record(three)], defaults)
    await expectFailure(manager(defaults, publicKey: ""))
    await expectFailure(manager(defaults, publicKey: "invalid"))
    let yaml = """
    remote_config:
      sources:
        - name: normal
          url: 'https://normal.invalid/config'
        - url: https://emergency.invalid/config
          is_emergency: true
        - url: https://your-oss.example.com/config
    """
    let parsed = try TVRemoteConfigManager.sources(from: yaml)
    precondition(parsed.count == 3 && !parsed[0].emergency && parsed[1].emergency && parsed[2].emergency)
    precondition(TVRemoteConfigManager.compareVersions("2.10", "2.9") > 0)
    print("PASS: remote config concurrency, versioning, emergency, cache rotation, expiry, signature replay, migration")
  }
}
