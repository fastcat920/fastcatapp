import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/ios_configuration_reload.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fastcat/clash');
  final messenger = binding.defaultBinaryMessenger;
  final params = SetupParams(
    config: {
      'mixed-port': 7890,
      'tun': {'enable': true, 'stack': 'mixed'},
      'dns': {
        'enable': false,
        'default-nameserver': ['119.29.29.29'],
      },
      'proxy-providers': {
        'subscription': {
          'type': 'http',
          'url': 'https://test.invalid/subscription?token=example',
          'path': '/main-app/private/cache.yaml',
        },
      },
      'rule': ['MATCH,subscription'],
    },
    selectedMap: {'subscription': 'node-2'},
    testUrl: 'https://test.invalid/204',
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends real SetupParams with selections, sandbox paths and deadline',
      () async {
    MethodCall? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call;
      return 'ok';
    });
    final before = DateTime.now().millisecondsSinceEpoch;
    await reloadIosTunnelConfiguration(json.encode(params));
    final after = DateTime.now().millisecondsSinceEpoch;
    expect(sent!.method, '_updateConfig');
    final payload = json.decode(sent!.arguments as String) as Map;
    expect(payload['selected-map'], params.selectedMap);
    expect(payload['test-url'], params.testUrl);
    expect(payload['deadlineUnixMs'],
        inInclusiveRange(before + 30000, after + 30000));
    final profile = payload['config'] as Map;
    expect(profile['rule'], ['MATCH,subscription']);
    expect(profile['tun']['enable'], isFalse);
    expect(profile['tun']['stack'], 'mixed');
    expect(profile['dns']['enable'], isTrue);
    expect(profile['dns']['listen'], '127.0.0.1:6053');
    expect(profile['dns']['default-nameserver'], ['119.29.29.29']);
    expect(profile['allow-lan'], isTrue);
    expect(profile['bind-address'], '*');
    expect(profile['proxy-providers']['subscription']['path'],
        startsWith('providers/proxy-providers/'));
    expect(params.config['tun']['enable'], isTrue);
  });

  test('supplies optional DNS and TUN sections without changing the wire shape',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final payload = json.decode(call.arguments as String) as Map;
      expect(payload['config']['dns']['enable'], isTrue);
      expect(payload['config']['tun']['enable'], isFalse);
      return '';
    });
    await reloadIosTunnelConfiguration(json.encode(const SetupParams(
      config: {'mixed-port': 7890},
      selectedMap: {},
      testUrl: '',
    )));
  });

  for (final response in [
    null,
    'error: invalid config',
    'invalid character',
    'error: mixed-port unavailable after configuration update'
  ]) {
    test('rejects absent or unsuccessful acknowledgement: $response', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => response);
      await expectLater(
          reloadIosTunnelConfiguration(json.encode(params)), throwsStateError);
    });
  }

  test('native unavailable errors propagate and a later retry can succeed',
      () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'TUNNEL_UNAVAILABLE');
    });
    await expectLater(reloadIosTunnelConfiguration(json.encode(params)),
        throwsA(isA<PlatformException>()));
    messenger.setMockMethodCallHandler(channel, (_) async => 'ok');
    await reloadIosTunnelConfiguration(json.encode(params));
  });

  test('missing reply times out instead of leaving the operation pending',
      () async {
    final reply = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (_) => reply.future);
    try {
      await expectLater(
        reloadIosTunnelConfiguration(json.encode(params),
            timeout: const Duration(milliseconds: 15)),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      reply.complete('ok');
    }
  });

  test('rejects raw startup profiles and malformed config before IPC',
      () async {
    var sent = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      sent = true;
      return 'ok';
    });
    for (final input in [
      {'mixed-port': 7890},
      {'config': <String, dynamic>{}},
      {
        'config': {'tun': true}
      },
      {
        'config': {'dns': 'invalid'}
      },
    ]) {
      await expectLater(reloadIosTunnelConfiguration(json.encode(input)),
          throwsA(isA<FormatException>()));
    }
    expect(sent, isFalse);
  });

  test('native reload validates core reply and port before acknowledging', () {
    final source =
        File('ios/PacketTunnel/PacketTunnelProvider.swift').readAsStringSync();
    final reload = source.substring(
        source.indexOf('private func handleUpdateConfig'),
        source.indexOf('// MARK: - Network settings'));
    expect(reload, contains('guard let resultCStr = ClashCore_invoke'));
    expect(reload, isNot(contains('?? "ok"')));
    expect(reload, contains('guard mixedPort > 0 else'));
    expect(reload, contains('setTunnelNetworkSettings'));
    expect(reload, contains('error.map { "error:'));
  });
}
