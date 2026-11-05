import 'dart:io';

/// Exercise the local listener and the core's current routing, not a named
/// node's URLTest. No DIRECT fallback, response body capture or relaxed TLS.
Future<({bool ok, int elapsedMs})> probeLocalProxy({
  required int port,
  required Uri target,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (port < 1 || port > 65535) return (ok: false, elapsedMs: 0);
  final clock = Stopwatch()..start();
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..findProxy = (_) => 'PROXY 127.0.0.1:$port';
  try {
    return await (() async {
      final request = await client.getUrl(target);
      request.followRedirects = false;
      final response = await request.close();
      return (
        ok: response.statusCode == 204,
        elapsedMs: clock.elapsedMilliseconds
      );
    })()
        .timeout(timeout);
  } catch (_) {
    return (ok: false, elapsedMs: clock.elapsedMilliseconds);
  } finally {
    client.close(force: true);
  }
}
