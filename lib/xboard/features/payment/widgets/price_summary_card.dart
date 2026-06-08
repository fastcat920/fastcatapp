import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import '../utils/price_calculator.dart';

/// 价格汇总卡片
class PriceSummaryCard extends StatelessWidget {
  final double originalPrice;
  final double? finalPrice;
  final double? discountAmount;
  final double? userBalance;

  const PriceSummaryCard({
    super.key,
    required this.originalPrice,
    this.finalPrice,
    this.discountAmount,
    this.userBalance,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final displayFinalPrice = finalPrice ?? originalPrice;
    final hasDiscount = discountAmount != null && discountAmount! > 0;
    final hasBalance = userBalance != null && userBalance! > 0;

    // 计算余额抵扣
    final balanceToUse = hasBalance
        ? (userBalance! > displayFinalPrice ? displayFinalPrice : userBalance!)
        : 0.0;
    final actualPayAmount = displayFinalPrice - balanceToUse;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.18)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A1565C0),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // 原价和优惠（如果有折扣）
          if (hasDiscount) ...[
            _PriceRow(
              label: l10n.xboardOriginalPrice,
              price: originalPrice,
              isStrikethrough: true,
            ),
            const SizedBox(height: 6),
            _PriceRow(
              label: l10n.xboardDiscountAmount,
              price: discountAmount!,
              isDiscount: true,
            ),
            const SizedBox(height: 6),
          ],

          // 优惠后价格（如果有折扣）
          if (hasDiscount) ...[
            _PriceRow(
              label: l10n.xboardDiscountedPrice,
              price: displayFinalPrice,
            ),
            Divider(
              height: 16,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ],

          // 实付金额（带余额抵扣信息）
          _FinalPriceRow(
            label: l10n.xboardPayableAmount,
            price: actualPayAmount,
            balanceDeducted: balanceToUse > 0 ? balanceToUse : null,
            remainingBalance: hasBalance && userBalance! > displayFinalPrice
                ? userBalance! - displayFinalPrice
                : null,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double price;
  final bool isStrikethrough;
  final bool isDiscount;

  const _PriceRow({
    required this.label,
    required this.price,
    this.isStrikethrough = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12, // 减小字体
            color: isDiscount ? Colors.green.shade700 : Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          isDiscount
              ? '-${PriceCalculator.formatPrice(price)}'
              : PriceCalculator.formatPrice(price),
          style: TextStyle(
            fontSize: 13, // 减小字体
            decoration: isStrikethrough ? TextDecoration.lineThrough : null,
            fontWeight: isDiscount ? FontWeight.w600 : null,
            color: isDiscount
                ? Colors.green.shade700
                : (isStrikethrough ? Colors.grey.shade500 : null),
          ),
        ),
      ],
    );
  }
}

class _FinalPriceRow extends StatelessWidget {
  final String label;
  final double price;
  final double? balanceDeducted;
  final double? remainingBalance;

  const _FinalPriceRow({
    required this.label,
    required this.price,
    this.balanceDeducted,
    this.remainingBalance,
  });

  @override
  Widget build(BuildContext context) {
    String? balanceInfo;
    if (balanceDeducted != null) {
      balanceInfo =
          '${AppLocalizations.of(context).xboardDeductedBalance} ${PriceCalculator.formatPrice(balanceDeducted!)}';
      if (remainingBalance != null) {
        balanceInfo +=
            '${AppLocalizations.of(context).xboardRemainingBalance} ${PriceCalculator.formatPrice(remainingBalance!)}';
      }
    }

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              PriceCalculator.formatPrice(price),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (balanceInfo != null) ...[
              const SizedBox(height: 2),
              Text(
                '($balanceInfo)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
