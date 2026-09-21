import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  group('Catboard commerce models', () {
    test('parses unix and ISO dates', () {
      expect(parseCatboardDate(1700000000), isNotNull);
      expect(parseCatboardDate('2026-09-21T08:00:00Z')?.year, 2026);
      expect(parseCatboardDate(null), isNull);
    });

    test('falls back to final amount minus balance', () {
      final preview = CatboardOrderPreview.fromJson({
        'original_amount': 10000,
        'surplus_amount': 252,
        'refund_amount': 52,
        'final_amount': 7000,
        'balance_amount': 2000,
        'available_coupons': <dynamic>[],
        'unavailable_coupons': <dynamic>[],
      });

      expect(preview.payableAmount, 5000);
      expect(preview.balanceAmount, 2000);
      expect(preview.surplusAmount, 252);
      expect(preview.refundAmount, 52);
    });

    test('parses the locked payment fee from an order', () {
      final order = OrderModel.fromJson({
        'trade_no': 'T20260921001',
        'total_amount': 1098,
        'balance_amount': 300,
        'handling_amount': 35,
      });

      expect(order.totalAmount, 1098);
      expect(order.balanceAmount, 300);
      expect(order.handlingAmount, 35);
    });

    test('parses referral and unified ledger data', () {
      final program = CatboardReferralProgram.fromJson({
        'effective_invites': 3,
        'referral_revenue': 12000,
        'commission_rate': 15,
        'level': {'name': 'Silver'},
      });
      final ledger = CatboardLedgerEntry.fromJson({
        'id': 8,
        'type': 'commission_income',
        'amount': 600,
        'balance_after': 1600,
        'status': 'completed',
      });

      expect(program.effectiveInvites, 3);
      expect(program.level?['name'], 'Silver');
      expect(ledger.amount, 600);
      expect(ledger.balanceAfter, 1600);
    });
  });
}
