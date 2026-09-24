import Foundation

/// Build-time values injected by Xcode/CI. None of these values are maintained
/// in Swift source; Info.plist only contains $(BUILD_SETTING) placeholders.
struct TVBuildConfiguration {
  enum ConfigurationError: LocalizedError {
    case missing(String)

    var errorDescription: String? {
      switch self {
      case .missing(let name): return "构建配置缺少 \(name)"
      }
    }
  }

  let xorKey: String
  let subscriptionFlag: String
  let subscriptionKeys: [String: Data]
  let requireSubscriptionEncryption: Bool
  let fallbackAPIBaseURL: URL?

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
      subscriptionFlag: string("FastCatSubscriptionFlag", bundle: bundle).nonEmpty ?? "fastcat-v1",
      subscriptionKeys: keys,
      requireSubscriptionEncryption: bool("FastCatRequireEncryption", bundle: bundle, default: true),
      fallbackAPIBaseURL: fallback.contains("$") ? nil : URL(string: fallback)
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
