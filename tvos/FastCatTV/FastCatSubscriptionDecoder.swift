import CryptoKit
import Foundation

enum FastCatSubscriptionDecoder {
  enum DecodeError: LocalizedError {
    case plaintextRejected, unsupportedEnvelope, missingKey(String), authenticationFailed

    var errorDescription: String? {
      switch self {
      case .plaintextRejected: return "服务端未返回 FastCat 加密订阅，已拒绝明文降级。"
      case .unsupportedEnvelope: return "不支持的 FastCat 订阅协议版本或算法。"
      case .missingKey(let id): return "订阅密钥版本 \(id) 未包含在当前客户端中，请升级客户端。"
      case .authenticationFailed: return "订阅解密认证失败：密钥不匹配或响应已损坏。"
      }
    }
  }

  static func decode(_ responseBody: String, configuration: TVBuildConfiguration) throws -> String {
    let trimmed = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let raw = trimmed.data(using: .utf8),
          let envelope = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
      if !configuration.requireSubscriptionEncryption, looksLikeClashYAML(responseBody) { return responseBody }
      throw DecodeError.plaintextRejected
    }

    guard envelope["v"] as? Int == 1, envelope["alg"] as? String == "A256GCM",
          let kid = envelope["kid"] as? String, !kid.isEmpty,
          let timestamp = envelope["ts"] as? Int else { throw DecodeError.unsupportedEnvelope }
    guard let key = configuration.subscriptionKeys[kid] else { throw DecodeError.missingKey(kid) }
    guard key.count == 32,
          let nonce = decodeBase64(envelope["nonce"] as? String), nonce.count == 12,
          let ciphertext = decodeBase64(envelope["data"] as? String),
          let tag = decodeBase64(envelope["tag"] as? String), tag.count == 16 else {
      throw DecodeError.authenticationFailed
    }

    do {
      let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
      let aad = Data("fastcat-subscription|v1|\(kid)|\(timestamp)".utf8)
      let plaintext = try AES.GCM.open(sealedBox, using: SymmetricKey(data: key), authenticating: aad)
      guard let yaml = String(data: plaintext, encoding: .utf8), looksLikeClashYAML(yaml) else {
        throw DecodeError.authenticationFailed
      }
      return yaml
    } catch {
      throw DecodeError.authenticationFailed
    }
  }

  private static func decodeBase64(_ value: String?) -> Data? {
    guard var value, !value.isEmpty else { return nil }
    value += String(repeating: "=", count: (4 - value.count % 4) % 4)
    return Data(base64Encoded: value)
  }

  private static func looksLikeClashYAML(_ content: String) -> Bool {
    content.contains("proxies:") && content.contains("proxy-groups:")
  }
}
