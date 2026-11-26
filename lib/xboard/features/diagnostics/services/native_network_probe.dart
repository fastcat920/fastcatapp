import 'dart:async';
import 'dart:io';

/// A baseline that does not call Mihomo or use the system HTTP proxy.
/// This deliberately does NOT claim to bypass VPN/TUN routes or system DNS.
/// Only status and duration are retained; no response body or headers are read.
Future<({bool ok, int elapsedMs, int? statusCode, bool timedOut})>
    probeNativeNetwork({
  required Uri target,
  int expectedStatus = HttpStatus.noContent,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final clock = Stopwatch()..start();
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..findProxy = (_) => 'DIRECT';
  try {
    return await (() async {
      final request = await client.getUrl(target);
      request.followRedirects = false;
      final response = await request.close();
      return (
        ok: response.statusCode == expectedStatus,
        elapsedMs: clock.elapsedMilliseconds,
        statusCode: response.statusCode,
        timedOut: false,
      );
    })()
        .timeout(timeout);
  } catch (error) {
    return (
      ok: false,
      elapsedMs: clock.elapsedMilliseconds,
      statusCode: null,
      timedOut: error is TimeoutException,
    );
  } finally {
    client.close(force: true);
  }
}
