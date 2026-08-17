import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/xboard/features/latency/services/mihomo_latency_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lowestSuccessfulDelay', () {
    Delay sample(int? value) => Delay(
          url: 'https://example.com/generate_204',
          name: 'node-a',
          value: value,
        );

    test('uses the lower successful measurement', () {
      expect(
        lowestSuccessfulDelay(
          [sample(86), sample(42)],
          url: sample(0).url,
          proxyName: sample(0).name,
        ).value,
        42,
      );
    });

    test('keeps a successful measurement when the other times out', () {
      expect(
        lowestSuccessfulDelay(
          [sample(-1), sample(64)],
          url: sample(0).url,
          proxyName: sample(0).name,
        ).value,
        64,
      );
    });

    test('reports timeout when both measurements fail', () {
      expect(
        lowestSuccessfulDelay(
          [sample(null), sample(-1)],
          url: sample(0).url,
          proxyName: sample(0).name,
        ).value,
        -1,
      );
    });
  });
}
