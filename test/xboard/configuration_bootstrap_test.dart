import 'dart:async';
import 'package:fl_clash/xboard/adapter/initialization/configuration_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('early SDK consumer and startup await one config load', () async {
    var initialized = false;
    var ready = false;
    var loads = 0;
    final response = Completer<void>();
    final bootstrap = ConfigurationBootstrap(
      isInitialized: () => initialized,
      hasConfiguration: () => ready,
      initializeModule: () async {
        initialized = true;
      },
      refreshConfiguration: () async {
        loads++;
        await response.future;
        ready = true;
      },
    );
    final sdk = bootstrap.ensureReady();
    final startup = bootstrap.ensureReady(forceRefresh: true);
    expect(identical(sdk, startup), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(loads, 1);
    expect(ready, isFalse);
    response.complete();
    await Future.wait([sdk, startup]);
    await bootstrap.ensureReady();
    expect(loads, 1);
    await bootstrap.ensureReady(forceRefresh: true);
    expect(loads, 2);
  });

  test('failed config load can be retried and does not poison future reads',
      () async {
    var ready = false;
    var loads = 0;
    final bootstrap = ConfigurationBootstrap(
      isInitialized: () => true,
      hasConfiguration: () => ready,
      initializeModule: () async {},
      refreshConfiguration: () async {
        if (++loads == 1) throw StateError('offline');
        ready = true;
      },
    );
    await expectLater(bootstrap.ensureReady(), throwsStateError);
    await bootstrap.ensureReady();
    expect(loads, 2);
  });

  test('empty or stalled configuration does not silently become ready',
      () async {
    final bootstrap = ConfigurationBootstrap(
      isInitialized: () => true,
      hasConfiguration: () => false,
      initializeModule: () async {},
      refreshConfiguration: () async {},
    );
    await expectLater(bootstrap.ensureReady(), throwsStateError);
    final stalled = ConfigurationBootstrap(
      isInitialized: () => true,
      hasConfiguration: () => false,
      initializeModule: () async {},
      refreshConfiguration: () => Completer<void>().future,
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(stalled.ensureReady(), throwsA(isA<TimeoutException>()));
  });
}
