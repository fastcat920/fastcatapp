import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/latency/services/latency_epoch.dart';

void main() {
  test('results spanning a connection change remain invalid after recovery', () {
    final epochs = LatencyEpoch();
    final offline = epochs.capture();
    expect(epochs.accepts(offline), isTrue);
    epochs.invalidate();
    final connected = epochs.capture();
    expect(epochs.accepts(offline), isFalse);
    expect(epochs.accepts(connected), isTrue);
    epochs.invalidate();
    expect(epochs.accepts(offline), isFalse);
    expect(epochs.accepts(connected), isFalse);
  });
}
