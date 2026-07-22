import 'package:fl_clash/xboard/features/auth/utils/login_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('login password validation', () {
    test('rejects an empty password', () {
      expect(validateLoginPassword(''), LoginPasswordIssue.empty);
    });

    test('rejects a password shorter than eight characters', () {
      expect(validateLoginPassword('1234567'), LoginPasswordIssue.tooShort);
    });

    test('accepts a password with at least eight characters', () {
      expect(validateLoginPassword('12345678'), isNull);
    });
  });
}
