import 'package:fl_clash/xboard/features/payment/models/order_bill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  group('OrderBill', () {
    test('parses locked payment and discount fields from order details', () {
      final order = OrderModel.fromJson({
        'payment_id': 7,
        'flash_sale_discount_amount': 100,
        'coupon_discount_amount': 250,
        'discount_amount': 450,
      });

      expect(order.paymentId, '7');
      expect(order.flashSaleDiscountAmount, 100);
      expect(order.couponDiscountAmount, 250);
      expect(order.discountAmount, 450);
    });

    test('uses the current backend fields to rebuild a locked bill', () {
      const order = OrderModel(
        period: 'month_price',
        totalAmount: 1098,
        balanceAmount: 300,
        discountAmount: 450,
        flashSaleDiscountAmount: 100,
        couponDiscountAmount: 250,
        surplusAmount: 252,
        refundAmount: 52,
        handlingAmount: 35,
      );

      final bill = OrderBill.resolve(
        order: order,
        plan: null,
        period: order.period,
        originalPrice: null,
        finalPrice: null,
        previewDiscountAmount: null,
        balanceUsed: null,
        accountBalance: null,
      );

      expect(bill.packageAmount, 20.48);
      expect(bill.activityDiscount, 1);
      expect(bill.couponDiscount, 2.5);
      expect(bill.memberDiscount, 1);
      expect(bill.surplusAmount, 2.52);
      expect(bill.refundAmount, 0.52);
      expect(bill.orderAmount, 13.98);
      expect(bill.balanceUsed, 3);
      expect(bill.payableAmount, 10.98);
      expect(bill.lockedHandlingFee, 0.35);
    });

    test('keeps a balance-only order locked to zero external payment', () {
      const order = OrderModel(
        period: 'month_price',
        totalAmount: 0,
        balanceAmount: 1400,
        discountAmount: 500,
        couponDiscountAmount: 500,
      );

      final bill = OrderBill.resolve(
        order: order,
        plan: null,
        period: order.period,
        originalPrice: null,
        finalPrice: null,
        previewDiscountAmount: null,
        balanceUsed: null,
        accountBalance: null,
      );

      expect(bill.packageAmount, 19);
      expect(bill.orderAmount, 14);
      expect(bill.balanceUsed, 14);
      expect(bill.payableAmount, 0);
      expect(bill.needExternalPayment, isFalse);
    });

    test('never exposes a negative member discount', () {
      const order = OrderModel(
        period: 'month_price',
        totalAmount: 1000,
        discountAmount: 200,
        flashSaleDiscountAmount: 150,
        couponDiscountAmount: 100,
      );

      final bill = OrderBill.resolve(
        order: order,
        plan: null,
        period: order.period,
        originalPrice: null,
        finalPrice: null,
        previewDiscountAmount: null,
        balanceUsed: null,
        accountBalance: null,
      );

      expect(bill.memberDiscount, 0);
    });
  });
}
