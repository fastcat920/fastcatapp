import 'package:fl_clash/xboard/features/payment/pages/order_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('final payment amount label', () {
    for (final chinese in [true, false]) {
      test('pending and optimistic orders show amount due ($chinese)', () {
        for (final status in [null, 0]) {
          expect(
            orderPaymentAmountLabel(status,
                paymentCompleted: false, chinese: chinese),
            chinese ? '还需支付' : 'Amount due',
          );
          expect(
            orderPaymentAmountLabel(status,
                paymentCompleted: true, chinese: chinese),
            chinese ? '实际支付' : 'Actual payment',
          );
        }
      });

      test('paid order states show actual payment ($chinese)', () {
        for (final status in [1, 3, 4]) {
          expect(
            orderPaymentAmountLabel(status,
                paymentCompleted: false, chinese: chinese),
            chinese ? '实际支付' : 'Actual payment',
          );
        }
      });

      test('canceled orders neither request payment nor claim paid ($chinese)',
          () {
        for (final completed in [true, false]) {
          expect(
            orderPaymentAmountLabel(2,
                paymentCompleted: completed, chinese: chinese),
            chinese ? '应付金额' : 'Payable amount',
          );
        }
      });
    }
  });

  test('optimistic payment completion hides pending actions', () {
    expect(
      isOrderPendingForDisplay(0, paymentCompleted: true),
      isFalse,
    );
  });

  test('backend pending status remains pending before payment completes', () {
    expect(
      isOrderPendingForDisplay(0, paymentCompleted: false),
      isTrue,
    );
  });

  test('completed backend status is not pending', () {
    expect(
      isOrderPendingForDisplay(3, paymentCompleted: false),
      isFalse,
    );
  });
}
