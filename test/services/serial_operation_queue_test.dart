import 'dart:async';

import 'package:fl_clash/common/serial_operation_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rollback waits for the failed application; later retry still runs',
      () async {
    final queue = SerialOperationQueue();
    final gate = Completer<void>();
    final events = <String>[];
    final failed = queue.run(() async {
      events.add('apply');
      await gate.future;
      events.add('apply settled');
      throw StateError('rejected');
    });
    final checked = expectLater(failed, throwsStateError);
    final restore = queue.run(() async => events.add('restore previous'));
    await Future<void>.delayed(Duration.zero);
    expect(events, ['apply']);
    gate.complete();
    await checked;
    await restore;
    await queue.run(() async => events.add('retry'));
    expect(events, ['apply', 'apply settled', 'restore previous', 'retry']);
  });
}
