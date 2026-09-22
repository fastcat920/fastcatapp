import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  group('Catboard commerce models', () {
    test('parses unix and ISO dates', () {
      expect(parseCatboardDate(1700000000), isNotNull);
      expect(parseCatboardDate('2026-09-21T08:00:00Z')?.year, 2026);
      expect(parseCatboardDate(null), isNull);
    });

    test('uses the server order amount and payable amount', () {
      final preview = CatboardOrderPreview.fromJson({
        'original_amount': 10000,
        'surplus_amount': 252,
        'refund_amount': 52,
        'final_amount': 7000,
        'balance_amount': 2000,
        'payable_amount': 5000,
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

    test('parses exclusive promotion options from order preview', () {
      final preview = CatboardOrderPreview.fromJson({
        'original_amount': 2000,
        'coupon_discount': 500,
        'member_discount': 200,
        'final_amount': 1300,
        'payable_amount': 1300,
        'promotion_exclusive': true,
        'selected_promotion': {
          'key': 'coupon:123',
          'type': 'coupon',
          'coupon_id': 123,
          'discount_amount': 700,
          'final_amount': 1300,
          'recommended': true,
        },
        'promotion_options': [
          {
            'key': 'coupon:123',
            'type': 'coupon',
            'coupon_id': 123,
            'name': '新人首单券',
            'discount_amount': 700,
            'final_amount': 1300,
            'recommended': true,
          },
          {
            'key': 'standard',
            'type': 'standard',
            'member_discount': 200,
            'discount_amount': 200,
            'final_amount': 1800,
          },
        ],
      });

      expect(preview.promotionExclusive, isTrue);
      expect(preview.memberDiscount, 200);
      expect(preview.vipDiscount, 200);
      expect(preview.selectedPromotion?.couponId, 123);
      expect(preview.selectedPromotion?.recommended, isTrue);
      expect(preview.promotionOptions, hasLength(2));
      expect(preview.promotionOptions.last.type, 'standard');
    });

    test('parses a locked coupon order trade number', () {
      final coupon = CatboardCoupon.fromJson({
        'id': 12,
        'template_id': 3,
        'status': 'locked',
        'locked_trade_no': 'T20260922001',
        'template': {
          'id': 3,
          'name': '新人券',
          'discount_type': 'fixed',
          'discount_value': 500,
        },
      });

      expect(coupon.status, 'locked');
      expect(coupon.lockedTradeNo, 'T20260922001');
    });

    test('parses referral and unified ledger data', () {
      final program = CatboardReferralProgram.fromJson({
        'effective_invites': 3,
        'referral_revenue': 12000,
        'commission_rate': 15,
        'level': {'name': 'Silver'},
        'next_level': {
          'name': 'Gold',
          'reward': {
            'reward_type': 'balance',
            'reward_value': 500,
          },
        },
        'reward_restriction': {'policy': 'block_both'},
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
      expect(program.nextLevelReward?['reward_type'], 'balance');
      expect(program.nextLevelReward?['reward_value'], 500);
      expect(program.rewardRestrictionPolicy, 'block_both');
      final cachedProgram = CatboardReferralProgram.fromJson(program.toJson());
      expect(cachedProgram.effectiveInvites, 3);
      expect(cachedProgram.level?['name'], 'Silver');
      expect(cachedProgram.nextLevelReward?['reward_value'], 500);
      expect(cachedProgram.rewardRestrictionPolicy, 'block_both');
      expect(ledger.amount, 600);
      expect(ledger.balanceAfter, 1600);
    });

    test('masks invite email while preserving domain and local edges', () {
      expect(
        maskCatboardInviteEmail('exampleuser@gmail.com'),
        'ex***er@gmail.com',
      );
      expect(maskCatboardInviteEmail('abcd@test.com'), 'ab***cd@test.com');
      expect(maskCatboardInviteEmail('a@test.com'), 'a***@test.com');
      expect(maskCatboardInviteEmail('a***@test.com'), 'a***@test.com');
    });
  });
}
