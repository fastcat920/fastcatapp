import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/clash/ios.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fastcat/clash');
  final messenger = binding.defaultBinaryMessenger;
  late ClashIOS core;

  void respond(Object? response) {
    messenger.setMockMethodCallHandler(channel, (_) async => response);
  }

  setUp(() => core = ClashIOS());
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('native bridge preserves nil instead of inventing an acknowledgement',
      () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final handler = source.substring(
      source.indexOf('clashChannel.setMethodCallHandler'),
      source.indexOf('// ── VPN status event channel'),
    );
    expect(handler, contains('result(response)'));
    expect(handler, isNot(contains('response ?? ""')));
    expect(
        handler, contains('call.method == "_updateConfig", response == nil'));
  });

  test('decodes the native JSON proxy map with live selections intact',
      () async {
    final proxies = {
      'GLOBAL': {
        'type': 'Selector',
        'now': 'subscription',
        'all': ['DIRECT', 'subscription'],
      },
      'subscription': {
        'type': 'Selector',
        'now': 'node-2',
        'all': ['node-1', 'node-2'],
      },
    };
    respond(json.encode(proxies));
    expect(await core.getProxies(), proxies);
    respond(proxies);
    expect(await core.getProxies(), proxies);
  });

  test('decodes native JSON booleans without treating strings as truthy',
      () async {
    respond('true');
    expect(await core.isInit, isTrue);
    respond('false');
    expect(await core.isInit, isFalse);
    respond(true);
    expect(await core.isInit, isTrue);
    for (final invalid in ['1', '"true"', '{}', 'not JSON']) {
      respond(invalid);
      expect(await core.isInit, isFalse);
    }
  });

  test('wraps raw native configuration objects as a successful Result',
      () async {
    final config = <String, dynamic>{
      'mixed-port': 7890,
      'proxies': [
        {'name': 'node-1', 'type': 'vless'},
      ],
    };
    respond(json.encode(config));
    final parsed = await core.getConfigContent('input');
    expect(parsed.isSuccess, isTrue);
    expect(parsed.data, config);
    respond(config);
    expect((await core.getConfig('path')).data, config);
  });

  test('unavailable and invalid optional queries preserve safe fallbacks',
      () async {
    for (final unavailable in [null, '', '[]', 'null', 'bad JSON']) {
      respond(unavailable);
      expect(await core.getProxies(), isEmpty);
      expect(await core.isInit, isFalse);
      final parsed = await core.getConfigContent('input');
      expect(parsed.isError, isTrue);
      expect(parsed.message, 'CORE_METHOD_UNAVAILABLE:getConfigContent');
      // This older query has an explicit compatibility default.
      expect((await core.getConfig('path')).data, isEmpty);
    }
  });

  test('JSON String replies are not double-decoded', () async {
    const reply = '{"download":12,"upload":3}';
    respond(reply);
    expect(await core.getTraffic(), reply);
  });

  for (final method in [
    ActionMethod.setupConfig,
    ActionMethod.updateConfig,
    ActionMethod.validateConfig,
    ActionMethod.changeProxy,
    ActionMethod.updateGeoData,
    ActionMethod.sideLoadExternalProvider,
    ActionMethod.updateExternalProvider,
    ActionMethod.checkGeoData,
  ]) {
    test('${method.name} distinguishes no reply from empty acknowledgement',
        () async {
      respond(null);
      await expectLater(core.invoke<String>(method: method), throwsStateError);
      respond('');
      expect(await core.invoke<String>(method: method), '');
      respond('configuration rejected');
      expect(
          await core.invoke<String>(method: method), 'configuration rejected');
      respond(<String, dynamic>{});
      await expectLater(
          core.invoke<String>(method: method), throwsA(isA<FormatException>()));
    });
  }

  test('native transport errors are not swallowed for mutations', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'TUNNEL_UNAVAILABLE');
    });
    await expectLater(core.invoke<String>(method: ActionMethod.changeProxy),
        throwsA(isA<PlatformException>()));
    expect(await core.getProxies(), isEmpty);
  });

  test('deadline throws for mutations and keeps query timeout callbacks',
      () async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    try {
      await expectLater(
        core.invoke<String>(
            method: ActionMethod.changeProxy,
            timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      expect(
        await core.invoke<Map>(
            method: ActionMethod.getProxies,
            timeout: const Duration(milliseconds: 10)),
        isEmpty,
      );
      expect(
        await core.invoke<String>(
          method: ActionMethod.getMemory,
          timeout: const Duration(milliseconds: 10),
          onTimeout: () => 'unavailable',
        ),
        'unavailable',
      );
    } finally {
      pending.complete(null);
    }
  });
}
