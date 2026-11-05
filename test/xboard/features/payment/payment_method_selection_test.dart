import 'package:fl_clash/xboard/features/payment/utils/payment_method_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default, explicit, missing and unavailable selections', () {
    expect(resolvePaymentMethodId(['5', '2'], null), '5');
    expect(resolvePaymentMethodId(['5', '2'], ''), '5');
    expect(resolvePaymentMethodId(['5', '2'], '2'), '2');
    expect(resolvePaymentMethodId(['5', '2'], '9'), isNull);
    expect(resolvePaymentMethodId([], null), isNull);
    expect(resolvePaymentMethodId(['', ' ', '5'], null), '5');
  });
}
