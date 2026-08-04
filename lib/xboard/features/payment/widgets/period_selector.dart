import 'package:fl_clash/xboard/features/shared/styles/font_weights.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import '../utils/price_calculator.dart';

/// 周期选择器
class PeriodSelector extends StatelessWidget {
  final List<Map<String, dynamic>> periods;
  final String? selectedPeriod;
  final Function(String) onPeriodSelected;
  final int? couponType;
  final int? couponValue;

  const PeriodSelector({
    super.key,
    required this.periods,
    required this.selectedPeriod,
    required this.onPeriodSelected,
    this.couponType,
    this.couponValue,
  });

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            AppLocalizations.of(context).xboardSelectPaymentPeriod,
            style: TextStyle(
              fontSize: 15,
              fontWeight: XbFontWeight.semibold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        _buildGridLayout(context),
      ],
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _columnCountForWidth(constraints.maxWidth);
        const spacing = 12.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 80,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: periods.length,
          itemBuilder: (context, index) {
            final period = periods[index];
            final isSelected = selectedPeriod == period['period'];
            return _PeriodCard(
              period: period,
              isSelected: isSelected,
              onTap: () => onPeriodSelected(period['period']),
              couponType: couponType,
              couponValue: couponValue,
            );
          },
        );
      },
    );
  }

  int _columnCountForWidth(double width) {
    if (width >= 840) return 4;
    if (width >= 560) return 3;
    if (width >= 320) return 2;
    return 1;
  }
}

class _PeriodCard extends StatelessWidget {
  final Map<String, dynamic> period;
  final bool isSelected;
  final VoidCallback onTap;
  final int? couponType;
  final int? couponValue;

  const _PeriodCard({
    required this.period,
    required this.isSelected,
    required this.onTap,
    this.couponType,
    this.couponValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final periodPrice = period['price']?.toDouble() ?? 0.0;
    final displayPrice = isSelected && couponType != null
        ? PriceCalculator.calculateFinalPrice(
            periodPrice,
            couponType,
            couponValue,
          )
        : periodPrice;

    final hasDiscount =
        isSelected && couponType != null && displayPrice < periodPrice;

    // 卡片尺寸由实际内容区宽度决定列数，高度保持稳定，避免平板横屏裁切。
    const padding = 8.0;
    const borderRadius = 12.0;
    const iconSize = 16.0;
    const labelFontSize = 13.0;
    const priceFontSize = 15.0;
    const originalPriceFontSize = 10.0;
    const horizontalSpacing = 4.0;
    const verticalSpacing = 4.0;
    const priceSpacing = 4.0;
    final selectedForeground =
        isDark ? const Color(0xFF1F2937) : colorScheme.onPrimary;
    final unselectedForeground =
        isDark ? colorScheme.onSurface : Colors.grey.shade800;
    final mutedForeground = isDark
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.72)
        : Colors.grey.shade400;
    final cardColor = isSelected
        ? colorScheme.primary
        : (isDark ? colorScheme.surfaceContainerLow : Colors.white);
    final borderColor = isSelected
        ? colorScheme.primary
        : (isDark
            ? colorScheme.outline.withValues(alpha: 0.18)
            : const Color(0xFFEEF0F4));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: isDark ? 4 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : (isDark
                    ? null
                    : [
                        const BoxShadow(
                          color: Color(0x0A1565C0),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 第一行：图标 + 周期名称
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? selectedForeground : mutedForeground,
                    size: iconSize,
                  ),
                  SizedBox(width: horizontalSpacing),
                  Flexible(
                    child: Text(
                      period['label'],
                      style: TextStyle(
                        fontSize: labelFontSize,
                        fontWeight: XbFontWeight.bold,
                        color: isSelected
                            ? selectedForeground
                            : unselectedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              SizedBox(height: verticalSpacing),
              // 第二行：价格（有折扣时显示原价+折扣价，否则只显示价格）
              if (hasDiscount)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      PriceCalculator.formatPrice(periodPrice),
                      style: TextStyle(
                        fontSize: originalPriceFontSize,
                        decoration: TextDecoration.lineThrough,
                        decorationColor:
                            selectedForeground.withValues(alpha: 0.62),
                        color: selectedForeground.withValues(alpha: 0.62),
                      ),
                    ),
                    SizedBox(width: priceSpacing),
                    Text(
                      PriceCalculator.formatPrice(displayPrice),
                      style: TextStyle(
                        fontSize: priceFontSize,
                        fontWeight: XbFontWeight.bold,
                        color: selectedForeground,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  PriceCalculator.formatPrice(periodPrice),
                  style: TextStyle(
                    fontSize: priceFontSize,
                    fontWeight: XbFontWeight.bold,
                    color:
                        isSelected ? selectedForeground : colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
