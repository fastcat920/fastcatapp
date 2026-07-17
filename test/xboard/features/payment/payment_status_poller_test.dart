import 'package:fl_clash/xboard/features/payment/services/payment_status_poller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('payment polling backoff', () {
    const initial = Duration(seconds: 4);

    test('uses the short interval during the first 30 seconds', () {
      expect(paymentPollingInterval(Duration.zero, initial), initial);
      expect(
        paymentPollingInterval(const Duration(seconds: 29), initial),
        initial,
      );
    });

    test('backs off after 30 seconds and again after two minutes', () {
      expect(
        paymentPollingInterval(const Duration(seconds: 30), initial),
        const Duration(seconds: 8),
      );
      expect(
        paymentPollingInterval(const Duration(minutes: 2), initial),
        const Duration(seconds: 15),
      );
    });
  });
}
