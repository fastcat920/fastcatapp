import 'dart:io';

import 'package:fl_clash/xboard/features/diagnostics/services/local_proxy_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the local proxy rather than resolving/connecting to the target',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = server.first.then((request) async {
      expect(request.requestedUri.host, 'unresolvable.invalid');
      request.response.statusCode = 204;
      await request.response.close();
    });
    final result = await probeLocalProxy(
      port: server.port,
      target: Uri.parse('http://unresolvable.invalid/generate_204'),
    );
    await received;
    expect(result.ok, isTrue);
  });

  test('does not fall back to DIRECT if local listener is missing', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);
    final result = await probeLocalProxy(
      port: port,
      target: Uri.parse('http://unresolvable.invalid/generate_204'),
      timeout: const Duration(milliseconds: 100),
    );
    expect(result.ok, isFalse);
  });

  test('closes the request on timeout and reports failure', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {});
    final result = await probeLocalProxy(
      port: server.port,
      target: Uri.parse('http://unresolvable.invalid/generate_204'),
      timeout: const Duration(milliseconds: 40),
    );
    expect(result.ok, isFalse);
  });
}
