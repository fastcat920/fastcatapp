import 'package:fl_clash/xboard/features/invite/utils/withdraw_amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses withdrawal yuan as exact integer cents', () {
    for (final entry in {
      '100': 10000,
      '100.50': 10050,
      '0.01': 1,
      '1.15': 115,
      ' 12.3 ': 1230,
      '100.': 10000,
    }.entries) {
      expect(parseWithdrawAmountInCents(entry.key), entry.value);
    }
  });
  test('rejects empty, zero, negative, excessive precision and invalid values',
      () {
    for (final value in [
      '',
      ' ',
      '0',
      '0.00',
      '-1',
      '1.001',
      '1e2',
      'NaN',
      'Infinity',
      '1,000',
      '1.2.3',
      '99999999999999999999999999999999999',
    ]) {
      expect(parseWithdrawAmountInCents(value), isNull, reason: value);
    }
  });
}
