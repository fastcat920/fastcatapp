import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/src/adapters/v2board/v2board_order_adapter.dart';
import 'package:flutter_xboard_sdk/src/panels/xboard/models/xboard_order_models.dart';

void main() {
  test('V2Board adapter preserves the locked pricing breakdown', () {
    const source = Order(
      totalAmount: 1300,
      balanceAmount: 100,
      handlingAmount: 30,
      paymentId: '7',
      discountAmount: 500,
      flashSaleDiscountAmount: 0,
      couponDiscountAmount: 500,
    );

    final result = mapV2BoardOrder(source);

    expect(result.totalAmount, 1300);
    expect(result.balanceAmount, 100);
    expect(result.handlingAmount, 30);
    expect(result.paymentId, '7');
    expect(result.discountAmount, 500);
    expect(result.flashSaleDiscountAmount, 0);
    expect(result.couponDiscountAmount, 500);
  });
}
