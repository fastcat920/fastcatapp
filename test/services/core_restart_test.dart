import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/clash/service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('messages during stop/start wait for the new core channel', () async {
    final stopGate = Completer<void>();
    final received = Completer<String>();
    Socket? peer;
    final service = ClashService.forTesting(
      bindServer: () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      launchCore: (port) async {
        peer =
            await Socket.connect(InternetAddress.loopbackIPv4, int.parse(port));
        peer!.cast<List<int>>().transform(utf8.decoder).listen((data) {
          if (!received.isCompleted) received.complete(data.trim());
        });
      },
      stopCore: () => stopGate.future,
    );
    addTearDown(() async {
      peer?.destroy();
      await service.destroy();
    });
    final restarted = service.reStart();
    final sent = service.sendMessage('init');
    stopGate.complete();
    await restarted;
    await sent;
    expect(await received.future.timeout(const Duration(seconds: 2)), 'init');
  });

  test('Helper-owned core is stopped and reconnects on every restart',
      () async {
    final events = <String>[];
    final peers = <Socket>[];
    late ClashService service;
    service = ClashService.forTesting(
      bindServer: () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      launchCore: (port) async {
        events.add('start');
        peers.add(await Socket.connect(
            InternetAddress.loopbackIPv4, int.parse(port)));
      },
      stopCore: () async {
        events.add('stop');
        for (final peer in peers) {
          peer.destroy();
        }
        peers.clear();
      },
    );
    addTearDown(service.destroy);
    await service.reStart();
    final first = await service.socketCompleter.future;
    expect(service.process, isNull); // Like a Helper-owned process.
    await service.reStart();
    final second = await service.socketCompleter.future;
    expect(identical(first, second), isFalse);
    expect(events, ['stop', 'start', 'stop', 'start']);
    expect(service.isStarting, isFalse);
  });

  test('concurrent restart callers wait for the actual channel together',
      () async {
    final launched = Completer<int>();
    var launches = 0;
    final service = ClashService.forTesting(
      bindServer: () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      launchCore: (port) async {
        launches++;
        launched.complete(int.parse(port));
      },
      stopCore: () async {},
    );
    addTearDown(service.destroy);
    final first = service.reStart();
    final second = service.reStart();
    expect(identical(first, second), isTrue);
    var finished = false;
    final watched = first.then((_) => finished = true);
    final port = await launched.future;
    expect(finished, isFalse);
    expect(service.isStarting, isTrue);
    final peer = await Socket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(peer.destroy);
    await watched;
    expect(finished, isTrue);
    expect(launches, 1);
  });

  test('no callback times out, cleans up, rejects late core, and allows retry',
      () async {
    var connect = false;
    var stops = 0;
    final peers = <Socket>[];
    final service = ClashService.forTesting(
      connectionTimeout: const Duration(milliseconds: 100),
      bindServer: () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      launchCore: (port) async {
        if (connect) {
          peers.add(await Socket.connect(
              InternetAddress.loopbackIPv4, int.parse(port)));
        }
      },
      stopCore: () async {
        stops++;
        for (final peer in peers) {
          peer.destroy();
        }
        peers.clear();
      },
    );
    addTearDown(service.destroy);
    await expectLater(service.reStart(), throwsA(isA<TimeoutException>()));
    expect(service.isStarting, isFalse);
    expect(stops, 2); // Before launch, then cleanup of failed attempt.
    final server = await service.serverCompleter.future;
    final latePeer =
        await Socket.connect(InternetAddress.loopbackIPv4, server.port);
    addTearDown(latePeer.destroy);
    await latePeer.drain<void>().timeout(const Duration(seconds: 2));
    connect = true;
    await service.reStart();
    expect(service.isStarting, isFalse);
    expect(stops, 3);
  });

  test('launch failure is propagated immediately and clears starting state',
      () async {
    final service = ClashService.forTesting(
      bindServer: () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      launchCore: (_) async => throw StateError('Core blocked'),
      stopCore: () async {},
    );
    addTearDown(service.destroy);
    await expectLater(service.reStart(), throwsStateError);
    expect(service.isStarting, isFalse);
  });
}
