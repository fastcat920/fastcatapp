import 'dart:io';

import 'package:fl_clash/xboard/features/diagnostics/services/native_network_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device baseline succeeds without initializing any proxy core',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = server.first.then((request) async {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });

    final result = await probeNativeNetwork(
      target: Uri.parse('http://127.0.0.1:${server.port}/generate_204'),
    );

    await received;
    expect(result.ok, isTrue);
    expect(result.elapsedMs, greaterThanOrEqualTo(0));
  });

  test('device baseline overrides the application-wide HTTP proxy setting',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = server.first.then((request) async {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });
    final baseOverrides = HttpOverrides.current;
    final result = await HttpOverrides.runZoned(
      () => probeNativeNetwork(
        target: Uri.parse('http://127.0.0.1:${server.port}/generate_204'),
      ),
      createHttpClient: (context) =>
          (baseOverrides?.createHttpClient(context) ??
              _DefaultHttpOverrides().createHttpClient(context))
            ..findProxy = (_) => 'PROXY 127.0.0.1:1',
    );

    await received;
    expect(result.ok, isTrue);
  });

  test('IP connectivity endpoint can require HTTP 200 without reading a body',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.statusCode = HttpStatus.ok;
      // Deliberately leave a body unfinished: only status headers are needed.
      request.response.write('127.0.0.1');
      request.response.flush();
    });

    final result = await probeNativeNetwork(
      target: Uri.parse('http://127.0.0.1:${server.port}/'),
      expectedStatus: HttpStatus.ok,
      timeout: const Duration(seconds: 1),
    );

    expect(result.ok, isTrue);
  });

  test('redirects do not turn captive-portal responses into successes',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requestCount = 0;
    server.listen((request) async {
      requestCount++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader, '/other');
      await request.response.close();
    });

    final result = await probeNativeNetwork(
      target: Uri.parse('http://127.0.0.1:${server.port}/generate_204'),
    );

    expect(result.ok, isFalse);
    expect(requestCount, 1);
  });

  test('unresponsive device baseline times out rather than stalling a report',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {});

    final result = await probeNativeNetwork(
      target: Uri.parse('http://127.0.0.1:${server.port}/generate_204'),
      timeout: const Duration(milliseconds: 50),
    );

    expect(result.ok, isFalse);
    expect(result.elapsedMs, lessThan(2000));
  });
}

class _DefaultHttpOverrides extends HttpOverrides {}
