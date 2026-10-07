import 'dart:async';
import 'package:fl_clash/common/single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recreated pages share one repair and can retry after completion',
      () async {
    final flight = SingleFlight<String?>();
    final gate = Completer<String?>();
    var calls = 0;
    final first = flight.run(() {
      calls++;
      return gate.future;
    });
    final second = flight.run(() async {
      calls++;
      return 'duplicate';
    });
    expect(identical(first, second), true);
    expect(flight.isRunning, true);
    gate.complete(null);
    expect(await first, null);
    expect(await second, null);
    expect(calls, 1);
    expect(flight.isRunning, false);
    expect(await flight.run(() async => 'retry'), 'retry');
  });

  test('failed repair releases the shared flight', () async {
    final flight = SingleFlight<void>();
    await expectLater(
        flight.run(() async => throw StateError('failed')), throwsStateError);
    expect(flight.isRunning, false);
    await flight.run(() async {});
  });
}
