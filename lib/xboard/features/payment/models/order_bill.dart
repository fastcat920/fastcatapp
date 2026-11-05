import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

/// A single interpretation of the current backend's locked order amounts.
///
/// Backend order amounts are stored in cents. In particular, `total_amount`
/// is the external-payment principal after balance has already been deducted.
class OrderBill {
  final double packageAmount;
  final double orderAmount;
  final double activityDiscount;
  final double couponDiscount;
  final double memberDiscount;
  final double discountAmount;
  final double refundAmount;
  final double surplusAmount;
  final double balanceUsed;
  final double payableAmount;
  final double? lockedHandlingFee;
  final double depositBonusAmount;
  final double? depositCreditedAmount;
  final bool isCommissionTransfer;
  final bool needExternalPayment;

  const OrderBill({
    required this.packageAmount,
    required this.orderAmount,
    required this.activityDiscount,
    required this.couponDiscount,
    required this.memberDiscount,
    required this.discountAmount,
    required this.refundAmount,
    required this.surplusAmount,
    required this.balanceUsed,
    required this.payableAmount,
    required this.lockedHandlingFee,
    required this.depositBonusAmount,
    required this.depositCreditedAmount,
    required this.isCommissionTransfer,
    required this.needExternalPayment,
  });

  factory OrderBill.resolve({
    required OrderModel? order,
    required DomainPlan? plan,
    required String? period,
    required double? originalPrice,
    required double? finalPrice,
    required double? previewDiscountAmount,
    required double? balanceUsed,
    required double? accountBalance,
  }) {
    final isDeposit = period == 'deposit' || order?.period == 'deposit';
    final planPrice = priceForOrderPeriod(plan, period);
    final backendTotalAmount = amountFromCents(order?.totalAmount);
    final backendBalanceAmount = amountFromCents(order?.balanceAmount);
    final surplus = amountFromCents(order?.surplusAmount);
    final refund = amountFromCents(order?.refundAmount);
    final backendDepositAmount = amountFromCents(order?.depositAmount);
    final backendCommissionAmount = amountFromCents(
      order?.actualCommissionBalance ?? order?.commissionBalance,
    );
    final totalDiscount = order != null
        ? amountFromCents(order.discountAmount)
        : (previewDiscountAmount ?? 0);
    final activityDiscount = amountFromCents(order?.flashSaleDiscountAmount);
    final couponDiscount = amountFromCents(order?.couponDiscountAmount);
    final memberDiscount = (totalDiscount - activityDiscount - couponDiscount)
        .clamp(0.0, double.infinity);
    final isCommissionTransfer =
        isDeposit && order?.depositSource == 'commission_transfer';

    final orderPackageFallback = backendTotalAmount + backendBalanceAmount;
    final depositPackageFallback = backendDepositAmount > 0
        ? backendDepositAmount
        : (orderPackageFallback + surplus > 0
            ? orderPackageFallback + surplus
            : backendCommissionAmount);
    final lockedPackageAmount =
        (orderPackageFallback + totalDiscount + surplus - refund)
            .clamp(0.0, double.infinity);
    final packageAmount = isDeposit
        ? (originalPrice ??
            (depositPackageFallback > 0 ? depositPackageFallback : 0.0))
        : (order != null && lockedPackageAmount > 0
            ? lockedPackageAmount
            : (planPrice ??
                originalPrice ??
                (orderPackageFallback > 0 ? orderPackageFallback : 0.0)));

    final computedBalance = order != null
        ? backendBalanceAmount
        : (balanceUsed != null && balanceUsed > 0
            ? balanceUsed
            : (accountBalance == null
                ? 0.0
                : (accountBalance > (finalPrice ?? packageAmount)
                    ? (finalPrice ?? packageAmount)
                    : accountBalance)));
    final payableAmount = order != null
        ? backendTotalAmount
        : ((finalPrice ?? packageAmount) - computedBalance)
            .clamp(0.0, double.infinity);
    final orderAmount =
        order != null ? orderPackageFallback : (finalPrice ?? packageAmount);

    return OrderBill(
      packageAmount: packageAmount,
      orderAmount: orderAmount,
      activityDiscount: activityDiscount,
      couponDiscount: couponDiscount,
      memberDiscount: memberDiscount,
      discountAmount: totalDiscount,
      refundAmount: refund,
      surplusAmount: surplus,
      balanceUsed: computedBalance,
      payableAmount: payableAmount,
      lockedHandlingFee: order?.handlingAmount == null
          ? null
          : amountFromCents(order?.handlingAmount),
      depositBonusAmount: amountFromCents(order?.depositBonusAmount),
      depositCreditedAmount: order?.depositCreditedAmount == null
          ? null
          : amountFromCents(order?.depositCreditedAmount),
      isCommissionTransfer: isCommissionTransfer,
      needExternalPayment: payableAmount > 0,
    );
  }
}

double? priceForOrderPeriod(DomainPlan? plan, String? period) {
  if (plan == null) return null;
  return switch (period) {
    'month_price' => plan.monthlyPrice,
    'quarter_price' => plan.quarterlyPrice,
    'half_year_price' => plan.halfYearlyPrice,
    'year_price' => plan.yearlyPrice,
    'two_year_price' => plan.twoYearPrice,
    'three_year_price' => plan.threeYearPrice,
    'onetime_price' => plan.onetimePrice,
    'reset_price' => plan.resetPrice,
    _ => null,
  };
}

double amountFromCents(double? amount) => (amount ?? 0) / 100;
