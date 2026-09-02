import 'package:fl_clash/xboard/features/payment/pages/order_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
