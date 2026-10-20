import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/payment/services/apple_checkout.dart';

void main() {
  test('HTTPS external checkout preserves opaque order parameters', () {
    const url = 'https://pay.example.test/order?id=123&signature=opaque';
    expect(appleCheckoutUri(url).toString(), url);
  });
  test(
      'unsafe schemes and embedded credentials are rejected without leaking URLs',
      () {
    for (final url in [
      'http://pay.example.test/secret',
      'javascript:secret',
      'alipays://secret',
      'https:///secret',
      'https://user:secret@example.test'
    ]) {
      try {
        appleCheckoutUri(url);
        fail('Accepted $url');
      } on FormatException catch (error) {
        expect(error.toString(), isNot(contains('secret')));
      }
    }
  });
}
