import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnresponsiveCore extends ClashHandlerInterface {
  Action? sent;
  Object? sendError;
  bool acknowledge = false;
  @override
  Future<bool> preload() async => true;

  @override
  Future<void> sendMessage(String message) async {
    sent = Action.fromJson(json.decode(message));
    if (sendError != null) throw sendError!;
    if (acknowledge) {
      await handleResult(
          ActionResult(method: sent!.method, id: sent!.id, data: ''));
    }
  }

  @override
  void reStart() {}

  @override
  bool destroy() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unacknowledged config throws instead of returning success', () async {
    final core = _UnresponsiveCore();
    await expectLater(
      core.setupConfig(
        const SetupParams(config: {}, selectedMap: {}, testUrl: ''),
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(core.callbackCompleterMap, isEmpty);
    final payload = json.decode(core.sent!.data as String) as Map;
    expect(payload['deadlineUnixMs'], isA<int>());
  });

  for (final method in [
    ActionMethod.updateConfig,
    ActionMethod.changeProxy,
    ActionMethod.updateGeoData,
    ActionMethod.updateExternalProvider,
    ActionMethod.checkGeoData,
  ]) {
    test('${method.name} requires an acknowledgement', () async {
      final core = _UnresponsiveCore();
      await expectLater(
        core.invoke<String>(
            method: method, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      expect(core.callbackCompleterMap, isEmpty);
      await core.handleResult(
          ActionResult(id: core.sent!.id, method: method, data: 'late'));
      expect(core.callbackCompleterMap, isEmpty);
    });
  }

  test('transport errors surface immediately and release callbacks', () async {
    final core = _UnresponsiveCore()..sendError = StateError('closed channel');
    await expectLater(core.invoke<String>(method: ActionMethod.updateConfig),
        throwsStateError);
    expect(core.callbackCompleterMap, isEmpty);
  });

  test('explicit empty acknowledgement still succeeds and cleans up', () async {
    final core = _UnresponsiveCore()..acknowledge = true;
    expect(await core.invoke<String>(method: ActionMethod.updateConfig), '');
    expect(core.callbackCompleterMap, isEmpty);
  });

  test('incremental configuration carries the native commit deadline',
      () async {
    final core = _UnresponsiveCore()..acknowledge = true;
    final before = DateTime.now();
    await core.updateConfig(const UpdateParams(
      tun: Tun(),
      mixedPort: 7890,
      allowLan: false,
      findProcessMode: FindProcessMode.off,
      mode: Mode.rule,
      logLevel: LogLevel.info,
      ipv6: false,
      tcpConcurrent: true,
      externalController: ExternalControllerStatus.close,
      unifiedDelay: true,
    ));
    final payload = json.decode(core.sent!.data as String) as Map;
    expect(
        payload['deadlineUnixMs'], greaterThan(before.millisecondsSinceEpoch));
    expect(
        payload['deadlineUnixMs'],
        lessThanOrEqualTo(DateTime.now()
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch));
    expect(payload['mixed-port'], 7890);
    expect(payload['mode'], 'rule');
  });

  test('optional query retains its explicit compatibility fallback', () async {
    final core = _UnresponsiveCore();
    expect(
        await core.invoke<String>(
            method: ActionMethod.getMemory,
            timeout: const Duration(milliseconds: 10),
            defaultValue: 'unknown'),
        'unknown');
    expect(core.callbackCompleterMap, isEmpty);
  });
}
