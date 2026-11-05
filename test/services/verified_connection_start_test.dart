import 'dart:async';

import 'package:fl_clash/services/verified_connection_start.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not publish connected until live validation completes', () async {
    final verified = Completer<void>();
    final events = <String>[];
    final operation = runVerifiedConnectionStart(
      start: () async {
        events.add('start');
        return true;
      },
      verify: () async {
        events.add('verify');
        await verified.future;
      },
      commit: () => events.add('connected'),
      rollback: () async => events.add('rollback'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, ['start', 'verify']);
    verified.complete();
    expect(await operation, isTrue);
    expect(events, ['start', 'verify', 'connected']);
  });

  for (final failure in [
    'start throws',
    'start rejects',
    'empty groups',
    'port'
  ]) {
    test('$failure rolls back before releasing operation', () async {
      final stop = Completer<void>();
      var committed = false;
      var rollbacks = 0;
      var finished = false;
      final operation = runVerifiedConnectionStart(
        start: () async {
          if (failure == 'start throws') throw StateError(failure);
          return failure != 'start rejects';
        },
        verify: () async => throw StateError(failure),
        commit: () => committed = true,
        rollback: () async {
          rollbacks++;
          await stop.future;
        },
      );
      final checked = failure == 'start rejects'
          ? expectLater(operation, completion(isFalse))
          : expectLater(operation, throwsStateError);
      unawaited(checked.then((_) => finished = true));
      await Future<void>.delayed(Duration.zero);
      expect(committed, isFalse);
      expect(rollbacks, 1);
      expect(finished, isFalse);
      stop.complete();
      await checked;
    });
  }
}
