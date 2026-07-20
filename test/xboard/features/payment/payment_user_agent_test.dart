import 'package:fl_clash/xboard/features/payment/services/payment_user_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('payment gateway user agent', () {
    test('mobile platforms keep the native WebView user agent', () {
      expect(
        paymentGatewayUserAgentOverride(isMobilePlatform: true),
        isNull,
      );
    });

    test('desktop platforms retain the desktop Chrome override', () {
      final userAgent = paymentGatewayUserAgentOverride(
        isMobilePlatform: false,
      );

      expect(userAgent, desktopPaymentUserAgent);
      expect(userAgent, contains('Windows NT 10.0'));
      expect(userAgent, isNot(contains(' Mobile ')));
    });
  });
}
