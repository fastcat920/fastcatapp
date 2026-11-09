import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/services/desktop_shutdown.dart';

void main() {
  test('slow restoration completes before core stop or restart can proceed',
      () async {
    final gate = Completer<bool>();
    final events = <String>[];
    final operation = runOrderedDesktopShutdown(
        restoreRouting: () => gate.future,
        shutdownCore: () async {
          events.add('core');
        },
        destroyService: () async {
          events.add('service');
        });
    await Future<void>.delayed(const Duration(milliseconds: 750));
    expect(events, isEmpty);
    gate.complete(true);
    await operation;
    expect(events, ['core', 'service']);
  });
  test('restoration rejection preserves the serving core', () async {
    await expectLater(
        runOrderedDesktopShutdown(
            restoreRouting: () async => false,
            shutdownCore: () async => fail('must not stop'),
            destroyService: () async => fail('must not destroy')),
        throwsStateError);
  });
  test('failed core shutdown does not tear down its transport prematurely',
      () async {
    await expectLater(
        runOrderedDesktopShutdown(
            restoreRouting: () async => true,
            shutdownCore: () async => throw StateError('unresponsive'),
            destroyService: () async => fail('must not destroy')),
        throwsStateError);
  });
}
