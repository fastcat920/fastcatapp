import 'dart:async';

import 'package:fl_clash/services/live_core_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cold tunnel startup waits for real groups', () async {
    var calls = 0;
    final result = await waitForLiveCoreGroups<String>(
      read: () async => ++calls < 3 ? [] : ['live'],
      interval: const Duration(milliseconds: 1),
    );
    expect(result, ['live']);
    expect(calls, 3);
  });

  test('transient transport errors may recover within the deadline', () async {
    var calls = 0;
    expect(
      await waitForLiveCoreGroups<String>(
        read: () async {
          if (++calls == 1) throw StateError('tunnel starting');
          return ['live'];
        },
        interval: const Duration(milliseconds: 1),
      ),
      ['live'],
    );
  });

  test('a slow successful reply is retained within the overall budget',
      () async {
    var calls = 0;
    expect(
      await waitForLiveCoreGroups<String>(
        read: () async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return ['live'];
        },
        timeout: const Duration(seconds: 1),
      ),
      ['live'],
    );
    expect(calls, 1);
  });

  test('empty core does not pass even when UI has cached nodes', () async {
    await expectLater(
      waitForLiveCoreGroups<String>(
        read: () async => [],
        timeout: const Duration(milliseconds: 15),
        interval: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('unresponsive probe cannot multiply the overall time budget', () async {
    final pending = Completer<List<String>>();
    final watch = Stopwatch()..start();
    await expectLater(
      waitForLiveCoreGroups<String>(
        read: () => pending.future,
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    pending.complete(['too late']);
  });
}
