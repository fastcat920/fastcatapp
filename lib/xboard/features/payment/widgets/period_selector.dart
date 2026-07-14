import 'package:flutter/material.dart';
import 'package:fl_clash/common/common.dart';
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
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        _buildGridLayout(context),
      ],
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final screenWidth = mediaSize.width;
    final baseWidth = 800.0; // 统一基准宽度
    final scaleFactor = (screenWidth / baseWidth).clamp(0.8, 1.5);

    // 与根菜单使用相同判断：左侧根菜单 4 列，底部根菜单 2 列。
    final useSideNavigation = mediaSize.width > mediaSize.height || system.isTV;
    final crossAxisCount = useSideNavigation ? 4 : 2;

    // 根据屏幕大小动态调整间距
    final spacing = (6 * scaleFactor).clamp(4.0, 12.0);

    // 根据屏幕大小动态调整宽高比
    final aspectRatio = (3.0 * scaleFactor).clamp(2.5, 3.5);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
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
          scaleFactor: scaleFactor,
        );
      },
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final Map<String, dynamic> period;
  final bool isSelected;
  final VoidCallback onTap;
  final int? couponType;
  final int? couponValue;
  final double scaleFactor;

  const _PeriodCard({
    required this.period,
    required this.isSelected,
    required this.onTap,
    this.couponType,
    this.couponValue,
    this.scaleFactor = 1.0,
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

    // 根据屏幕大小动态调整尺寸
    final padding = (6 * scaleFactor).clamp(4.0, 10.0);
    final borderRadius = isDark ? (8 * scaleFactor).clamp(6.0, 12.0) : 12.0;
    final iconSize = (14 * scaleFactor).clamp(12.0, 18.0);
    final labelFontSize = (11 * scaleFactor).clamp(10.0, 13.0);
    final priceFontSize = (13 * scaleFactor).clamp(12.0, 16.0);
    final originalPriceFontSize = (9 * scaleFactor).clamp(8.0, 11.0);
    final horizontalSpacing = (3 * scaleFactor).clamp(2.0, 5.0);
    final verticalSpacing = (3 * scaleFactor).clamp(2.0, 5.0);
    final priceSpacing = (4 * scaleFactor).clamp(3.0, 6.0);
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
                        fontWeight: FontWeight.bold,
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
                        fontWeight: FontWeight.bold,
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
                    fontWeight: FontWeight.bold,
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
