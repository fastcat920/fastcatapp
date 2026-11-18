import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/xboard/features/update_check/models/update_artifact.dart';
import 'package:fl_clash/xboard/features/update_check/services/update_download_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final payload = [0x50, 0x4b, 3, 4, ...List.generate(4096, (i) => i % 256)];
  late Directory directory;
  late HttpServer server;
  late UpdateDownloadService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fastcat-update-test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    service =
        UpdateDownloadService(directory: directory, allowHttpForTests: true);
  });
  tearDown(() async {
    service.cancel();
    service.dispose();
    await server.close(force: true);
    await directory.delete(recursive: true);
  });
  UpdateArtifact artifact({String? hash, List<String> mirrors = const []}) =>
      UpdateArtifact(
          url: 'http://127.0.0.1:${server.port}/app.apk',
          sha256: hash ?? sha256.convert(payload).toString(),
          type: 'apk',
          size: payload.length,
          mirrors: mirrors);

  test('publishes only a verified installer and reuses verified cache',
      () async {
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response.add(payload);
      await request.response.close();
    });
    final file = await service.start(artifact());
    expect(await file!.readAsBytes(), payload);
    expect(service.state.phase, UpdatePhase.ready);
    await service.start(artifact());
    expect(requests, 1);
  });
  test('resumes partial bytes with a matching content range', () async {
    final a = artifact();
    await File('${directory.path}/${a.sha256}.apk.part')
        .writeAsBytes(payload.take(100).toList());
    server.listen((request) async {
      expect(request.headers.value('range'), 'bytes=100-');
      request.response.statusCode = 206;
      request.response.headers.set(
          'content-range', 'bytes 100-${payload.length - 1}/${payload.length}');
      request.response.add(payload.skip(100).toList());
      await request.response.close();
    });
    expect(await (await service.start(a))!.readAsBytes(), payload);
  });
  test('server ignoring range restarts instead of appending', () async {
    final a = artifact();
    await File('${directory.path}/${a.sha256}.apk.part')
        .writeAsBytes(payload.take(100).toList());
    server.listen((request) async {
      request.response.add(payload);
      await request.response.close();
    });
    expect(await (await service.start(a))!.readAsBytes(), payload);
  });
  test('416 completed partial is verified before becoming ready', () async {
    final a = artifact();
    await File('${directory.path}/${a.sha256}.apk.part').writeAsBytes(payload);
    server.listen((request) async {
      request.response.statusCode = 416;
      await request.response.close();
    });
    expect(await service.start(a), isNotNull);
    expect(service.state.phase, UpdatePhase.ready);
  });
  test('HTML response cannot become an installer', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write('<html>login</html>');
      await request.response.close();
    });
    expect(await service.start(artifact()), isNull);
    expect(service.state.error, 'not_installer');
  });
  test('wrong hash is rejected and corrupt partial is removed', () async {
    server.listen((request) async {
      request.response.add(payload);
      await request.response.close();
    });
    final a = artifact(hash: '0' * 64);
    expect(await service.start(a), isNull);
    expect(service.state.error, 'integrity');
    expect(
        await File('${directory.path}/${a.sha256}.apk.part').exists(), isFalse);
  });
  test('bad range offset cannot corrupt saved progress', () async {
    final a = artifact();
    final part = File('${directory.path}/${a.sha256}.apk.part');
    await part.writeAsBytes(payload.take(100).toList());
    server.listen((request) async {
      request.response.statusCode = 206;
      request.response.headers
          .set('content-range', 'bytes 0-99/${payload.length}');
      request.response.add(payload.take(100).toList());
      await request.response.close();
    });
    expect(await service.start(a), isNull);
    expect(service.state.error, 'range');
    expect(await part.length(), 100);
  });
  test('redirect target is checked and credentials are refused', () async {
    server.listen((request) async {
      request.response.statusCode = 302;
      request.response.headers
          .set('location', 'http://user:password@127.0.0.1:${server.port}/bad');
      await request.response.close();
    });
    expect(await service.start(artifact()), isNull);
    expect(service.state.error, 'unsafe_url');
  });
  test('production transport rejects HTTP before sending a request', () async {
    final strict = UpdateDownloadService(directory: directory);
    expect(await strict.start(artifact()), isNull);
    expect(strict.state.error, 'unsafe_url');
    strict.dispose();
  });
  test('cancellation leaves resumable bytes and prevents duplicate jobs',
      () async {
    final received = Completer<void>();
    server.listen((request) async {
      request.response.contentLength = payload.length;
      request.response.add(payload.take(100).toList());
      await request.response.flush();
      if (!received.isCompleted) received.complete();
    });
    final running = service.start(artifact());
    await received.future;
    expect(await service.start(artifact()), isNull);
    service.cancel();
    expect(await running, isNull);
    expect(service.state.phase, UpdatePhase.paused);
  });
}
