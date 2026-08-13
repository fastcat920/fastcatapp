import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SensitiveMasker.maskText', () {
    test('masks a plain domain and port in core logs', () {
      const input =
          '[UDP] dial fastcat.wang:40101 connect error: context canceled';

      final masked = SensitiveMasker.maskText(input);

      expect(masked, isNot(contains('fastcat.wang')));
      expect(masked, isNot(contains('40101')));
      expect(masked, contains('[redacted-port]'));
      expect(masked, contains('connect error: context canceled'));
    });

    test('masks a plain IP and port without hiding the error reason', () {
      const input = 'dial 203.0.113.7:443: i/o timeout';

      final masked = SensitiveMasker.maskText(input);

      expect(masked, isNot(contains('203.0.113.7')));
      expect(masked, isNot(contains(':443')));
      expect(masked, contains('i/o timeout'));
    });
  });
}
