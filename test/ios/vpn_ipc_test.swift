import Foundation

@main
struct VPNIPCTests {
  static func main() throws {
    for response: String? in [nil, "error: invalid config", "invalid character", "true"] {
      precondition(!IOSVPNIPC.isAcknowledged(response))
    }
    precondition(IOSVPNIPC.isAcknowledged(""))
    precondition(IOSVPNIPC.isAcknowledged("ok"))

    // Parsing and applying are asynchronous: neither request may report success
    // before the extension actually replies, and startup YAML must not be sent
    // unchanged to the JSON SetupParams reload operation.
    var requests: [(String, String?)] = []
    var callbacks: [(String?) -> Void] = []
    var results: [String?] = []
    IOSVPNIPC.applyProfile("mixed-port: 7890", send: { method, data, reply in
      requests.append((method, data))
      callbacks.append(reply)
    }, completion: { results.append($0) })
    precondition(requests.count == 1 && requests[0].0 == "getConfigContent")
    precondition(requests[0].1 == "mixed-port: 7890" && results.isEmpty)
    callbacks[0]("{\"mixed-port\":7890,\"dns\":{\"enable\":true}}")
    precondition(requests.count == 2 && requests[1].0 == "_updateConfig")
    precondition(results.isEmpty)
    let payload = try JSONSerialization.jsonObject(with: Data(requests[1].1!.utf8)) as! [String: Any]
    precondition((payload["config"] as? [String: Any])?["mixed-port"] as? Int == 7890)
    let remaining = (payload["deadlineUnixMs"] as! NSNumber).doubleValue / 1000 - Date().timeIntervalSince1970
    precondition(remaining > 25 && remaining <= 30)
    callbacks[1]("")
    precondition(results.count == 1 && results[0] == nil)

    for parseReply: String? in [nil, "", "invalid yaml", "{}", "[]"] {
      var sent = 0
      var failed = false
      IOSVPNIPC.applyProfile("bad", send: { _, _, callback in
        sent += 1
        callback(parseReply)
      }, completion: { failed = $0 != nil })
      precondition(sent == 1 && failed)
    }
    for updateReply: String? in [nil, "error: invalid config", "invalid character"] {
      var failed = false
      IOSVPNIPC.applyProfile("mixed-port: 7890", send: { method, _, callback in
        callback(method == "getConfigContent" ? "{\"mixed-port\":7890}" : updateReply)
      }, completion: { failed = $0 != nil })
      precondition(failed)
    }
    var emptyFailed = false
    IOSVPNIPC.applyProfile("  \n", send: { _, _, _ in
      preconditionFailure("Empty config must not reach the extension")
    }, completion: { emptyFailed = $0 != nil })
    precondition(emptyFailed)

    // Timeout wins once; a late successful reply cannot flip failure to success.
    var timeoutResults: [String?] = []
    let timedOut = IOSVPNReply { timeoutResults.append($0) }
    timedOut.finish(nil)
    timedOut.finish("ok")
    precondition(timeoutResults.count == 1 && timeoutResults[0] == nil)
    var successResults: [String?] = []
    let succeeded = IOSVPNReply { successResults.append($0) }
    succeeded.finish("ok")
    succeeded.finish(nil)
    succeeded.finish("error")
    precondition(successResults.count == 1 && successResults[0] == "ok")

    print("iOS VPN IPC acknowledgement tests passed")
  }
}
