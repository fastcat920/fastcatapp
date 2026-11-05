import 'package:fl_clash/xboard/features/auth/services/qr_login_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts only opaque challenge IDs', () {
    expect(QrLoginService.parse('fastcat://login/qr?challenge=qr_abc-123').id,
        'qr_abc-123');
    for (final id in ['../devices', 'a?b=c', 'a/b', '', 'a#b']) {
      expect(
          () => QrLoginService.parse(
              'fastcat://login/qr?challenge=${Uri.encodeQueryComponent(id)}'),
          throwsFormatException);
    }
  });
  test('cannot approve arbitrary URLs through QR sign-in', () {
    expect(() => QrLoginService.parse('https://example.com/login'),
        throwsFormatException);
  });
}
