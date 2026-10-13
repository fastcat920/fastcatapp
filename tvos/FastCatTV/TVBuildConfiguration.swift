import Foundation

/// Build-time values injected by Xcode/CI. None of these values are maintained
/// in Swift source; Info.plist only contains $(BUILD_SETTING) placeholders.
struct TVBuildConfiguration {
  enum ConfigurationError: LocalizedError {
    case missing(String)
    case invalidRuntimeConfiguration

    var errorDescription: String? {
      let preferred = UserDefaults.standard.string(forKey: "fastcat.tv.language") ?? "system"
      let chinese = preferred == "zh-CN" || (preferred == "system" && Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true)
      switch self {
      case .missing(let name): return chinese ? "构建配置缺少 \(name)" : "Missing build configuration: \(name)"
      case .invalidRuntimeConfiguration:
        return chinese ? "订阅包含无效的运行配置，请刷新订阅" : "The subscription contains invalid runtime settings. Please refresh it."
      }
    }
  }

  let xorKey: String
  let remoteConfigPublicKey: String
  let subscriptionFlag: String
  let subscriptionKeys: [String: Data]
  let requireSubscriptionEncryption: Bool
  let fallbackAPIBaseURL: URL?
  var currentSubscriptionKeyID: String = ""

  /// Only the transient app → extension payload contains these cache keys.
  /// Never pass this result to the subscription cache or VPN preferences.
  func runtimeConfiguration(_ yaml: String) throws -> String {
    guard !currentSubscriptionKeyID.isEmpty,
          subscriptionKeys[currentSubscriptionKeyID]?.count == 32 else {
      throw ConfigurationError.missing("FastCatKeyCurrent")
    }
    let value: [String: Any] = [
      "currentKeyId": currentSubscriptionKeyID,
      "keys": subscriptionKeys.mapValues { $0.base64EncodedString() },
    ]
    let json = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    // Reject a remote attempt to supply the client-only control field. Do not
    // retain a second ambiguous YAML key or silently trust downloaded key data.
    guard !yaml.components(separatedBy: .newlines).contains(where: {
      $0.hasPrefix("fastcat-provider-cache:") || $0.hasPrefix("\"fastcat-provider-cache\":") || $0.hasPrefix("'fastcat-provider-cache':")
    }) else { throw ConfigurationError.invalidRuntimeConfiguration }
    return yaml + "\nfastcat-provider-cache: " + String(decoding: json, as: UTF8.self) + "\n"
  }

  static func load(bundle: Bundle = .main) throws -> TVBuildConfiguration {
    let xorKey = try requiredString("FastCatXORKey", bundle: bundle)
    let currentID = string("FastCatKeyCurrentID", bundle: bundle)
    let currentKey = string("FastCatKeyCurrent", bundle: bundle)
    let nextID = string("FastCatKeyNextID", bundle: bundle)
    let nextKey = string("FastCatKeyNext", bundle: bundle)

    var keys: [String: Data] = [:]
    if !currentID.isEmpty, let data = Data(base64Encoded: currentKey) { keys[currentID] = data }
    if !nextID.isEmpty, let data = Data(base64Encoded: nextKey) { keys[nextID] = data }

    let fallback = string("FastCatAPIBaseURL", bundle: bundle)
    return TVBuildConfiguration(
      xorKey: xorKey,
      remoteConfigPublicKey: try requiredString("FastCatRemoteConfigPublicKey", bundle: bundle),
      subscriptionFlag: string("FastCatSubscriptionFlag", bundle: bundle).nonEmpty ?? "fastcat-v1",
      subscriptionKeys: keys,
      requireSubscriptionEncryption: bool("FastCatRequireEncryption", bundle: bundle, default: true),
      fallbackAPIBaseURL: fallback.contains("$") ? nil : URL(string: fallback),
      currentSubscriptionKeyID: currentID
    )
  }

  private static func requiredString(_ key: String, bundle: Bundle) throws -> String {
    guard let value = string(key, bundle: bundle).nonEmpty, !value.contains("$(") else {
      throw ConfigurationError.missing(key)
    }
    return value
  }

  private static func string(_ key: String, bundle: Bundle) -> String {
    (bundle.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private static func bool(_ key: String, bundle: Bundle, default defaultValue: Bool) -> Bool {
    if let value = bundle.object(forInfoDictionaryKey: key) as? Bool { return value }
    switch string(key, bundle: bundle).lowercased() {
    case "yes", "true", "1": return true
    case "no", "false", "0": return false
    default: return defaultValue
    }
  }
}

private extension String {
  var nonEmpty: String? { isEmpty ? nil : self }
}
