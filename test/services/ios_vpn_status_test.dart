import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/services/ios_vpn_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fastcat/vpn');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('restoration reads the existing connection without start or stop', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return {'status': 'connected', 'connectedAt': 123456789};
    });
    final snapshot = await const IosVpnStatusReader().restore();
    expect(snapshot['status'], 'connected');
    expect(snapshot['connectedAt'], 123456789);
    expect(calls, ['restoreState']);
  });
  test('system disconnected overrides any stale application state', () async {
    messenger.setMockMethodCallHandler(channel, (call) async =>
        call.method == 'isConnected' ? false : 'disconnected');
    const reader = IosVpnStatusReader();
    expect(await reader.isConnected(), isFalse);
    expect(await reader.state(), 'disconnected');
  });
  test('transitional system state is preserved', () async {
    messenger.setMockMethodCallHandler(channel, (call) async =>
        call.method == 'isConnected' ? false : 'recovering');
    expect(await const IosVpnStatusReader().state(), 'recovering');
  });
  test('missing response does not imply connected', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await const IosVpnStatusReader().isConnected(), isFalse);
    expect(await const IosVpnStatusReader().state(), 'disconnected');
  });
  test('hung status query has a bounded deadline', () async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    final reader = IosVpnStatusReader(timeout: const Duration(milliseconds: 20));
    await expectLater(reader.state(), throwsA(isA<TimeoutException>()));
    pending.complete(null);
  });
}
