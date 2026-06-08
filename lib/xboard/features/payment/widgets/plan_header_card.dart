import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import '../utils/price_calculator.dart';

/// 套餐信息头部卡片
class PlanHeaderCard extends StatelessWidget {
  final DomainPlan plan;

  const PlanHeaderCard({
    super.key,
    required this.plan,
  });

  String _getTrafficDisplay(BuildContext context) {
    if (plan.transferQuota == 0) {
      return AppLocalizations.of(context).xboardUnlimited;
    }
    return PriceCalculator.formatTraffic(plan.transferQuota.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final iconBgColor = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.32 : 0.18,
    );
    final iconColor =
        isDark ? theme.colorScheme.onSurface : theme.colorScheme.primary;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : theme.colorScheme.primary.withValues(alpha: 0.96);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(
          alpha: isDark ? 0.24 : 0.12,
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.38 : 0.28,
          ),
        ),
        borderRadius: BorderRadius.circular(isDark ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : theme.colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: isDark ? 4 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左边：大图标（占两行高度）
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.workspace_premium,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          // 右边：上下两行
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 套餐名 + 流量，左右分布
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildCompactInfo(
                      context,
                      Icons.cloud_download_outlined,
                      _getTrafficDisplay(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final chipBg = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.24 : 0.14,
    );
    final infoTextColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.88)
        : theme.colorScheme.primary.withValues(alpha: 0.90);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: infoTextColor, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: infoTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
