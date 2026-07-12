import 'package:fl_clash/xboard/features/latency/providers/latency_display_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyDelayDisplayDiscount', () {
    test('keeps raw delay when discount is absent or zero', () {
      expect(applyDelayDisplayDiscount(100, 0), 100);
    });

    test('discounts positive delay by percentage', () {
      expect(applyDelayDisplayDiscount(100, 30), 70);
      expect(applyDelayDisplayDiscount(201, 50), 100);
    });

    test('clamps percentage to the supported range', () {
      expect(applyDelayDisplayDiscount(100, -10), 100);
      expect(applyDelayDisplayDiscount(100, 100), 10);
    });

    test('keeps special delay states unchanged', () {
      expect(applyDelayDisplayDiscount(null, 30), isNull);
      expect(applyDelayDisplayDiscount(0, 30), 0);
      expect(applyDelayDisplayDiscount(-1, 30), -1);
    });

    test('never displays a positive delay below one millisecond', () {
      expect(applyDelayDisplayDiscount(1, 90), 1);
    });
  });
}
