import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/services/runtime_task_runner.dart';

void main() {
  test('stop during pending work cannot resurrect an old connection', () async {
    final pending = Completer<void>();
    final runner = RuntimeTaskRunner(
        interval: const Duration(milliseconds: 5), onError: (_) {});
    addTearDown(runner.stop);
    var oldTail = 0;
    var newCalls = 0;
    runner.start([
      () => pending.future,
      () {
        oldTail++;
      }
    ]);
    runner.stop();
    runner.start([
      () {
        newCalls++;
      }
    ]);
    pending.complete();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(oldTail, 0);
    expect(newCalls, greaterThan(1));
    runner.stop();
    final stoppedAt = newCalls;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(newCalls, stoppedAt);
  });
  test(
      'task errors are observed and duplicate starts do not create extra loops',
      () async {
    final errors = <Object>[];
    final runner = RuntimeTaskRunner(
        interval: const Duration(days: 1), onError: errors.add);
    addTearDown(runner.stop);
    var calls = 0;
    void fail() {
      calls++;
      throw StateError('transport closed');
    }

    runner.start([fail]);
    runner.start([fail]);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(errors, hasLength(1));
  });
}
