import Foundation

/// Main app and extension agree on explicit mutation acknowledgements.
/// Empty/nil IPC is not success. Raw Mihomo's empty success is wrapped only by
/// the extension, which can distinguish an empty result from a missing pointer.
enum TVCoreProtocol {
  static func acknowledgement(error: String? = nil) -> Data {
    let value: [String: Any] = error.map { ["ok": false, "message": $0] } ?? ["ok": true]
    return (try? JSONSerialization.data(withJSONObject: value)) ?? Data()
  }

  static func isAcknowledged(_ response: String?) -> Bool {
    struct Reply: Decodable { let ok: Bool }
    guard let response, let data = response.data(using: .utf8),
          let value = try? JSONDecoder().decode(Reply.self, from: data) else { return false }
    return value.ok
  }
}

/// Provider callbacks can arrive after the local deadline. Complete once and
/// release the UI callback so a late response cannot finish a newer operation.
final class TVOnceReply {
  private let lock = NSLock()
  private var callback: ((String?) -> Void)?
  init(_ callback: @escaping (String?) -> Void) { self.callback = callback }
  func finish(_ value: String?) {
    lock.lock()
    let action = callback
    callback = nil
    lock.unlock()
    action?(value)
  }
}
