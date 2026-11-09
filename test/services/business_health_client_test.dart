import 'dart:io';
import 'package:fl_clash/services/business_health_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProxyOverrides extends HttpOverrides {
  _ProxyOverrides(this.port);
  final int port;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'PROXY 127.0.0.1:$port';
    return client;
  }
}

void main() {
  test(
      'business health follows the API proxy override for an unroutable target',
      () async {
    // A real local HTTP proxy receives the reserved documentation address;
    // forcing DIRECT here would fail rather than reach the proxy.
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => proxy.close(force: true));
    Uri? observed;
    proxy.listen((request) async {
      observed = request.uri;
      request.response.statusCode = HttpStatus.ok;
      request.response.write('{}');
      await request.response.close();
    });
    await HttpOverrides.runWithHttpOverrides(() async {
      final client = createBusinessHealthClient();
      try {
        final response = await (await client.getUrl(
          Uri.parse('http://192.0.2.1/api/v1/guest/comm/config'),
        ))
            .close()
            .timeout(const Duration(seconds: 2));
        await response.drain<void>();
        expect(response.statusCode, HttpStatus.ok);
        expect(observed?.host, '192.0.2.1');
        expect(observed?.path, '/api/v1/guest/comm/config');
      } finally {
        client.close(force: true);
      }
    }, _ProxyOverrides(proxy.port));
  });
}
