import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/l10n/l10n.dart';

class TunIntroductionDialog extends StatelessWidget {
  const TunIntroductionDialog({super.key});
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 防止点击外部关闭
      builder: (context) => const TunIntroductionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.shield,
          color: Colors.green.shade600,
          size: 32,
        ),
      ),
      title: Text(
        l10n.xboardTunModeTitle,
        style: XbUiText.sectionTitle(context).copyWith(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.xboardTunModeDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              Icons.network_check,
              l10n.xboardTunAllTraffic,
              l10n.xboardTunAllTrafficDescription,
              isDark,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              context,
              Icons.security,
              l10n.xboardTunTransparentProxy,
              l10n.xboardTunTransparentProxyDescription,
              isDark,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              context,
              Icons.speed,
              l10n.xboardTunPerformance,
              l10n.xboardTunPerformanceDescription,
              isDark,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5)
                    : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
                border:
                    isDark ? null : Border.all(color: const Color(0xFFEEF0F4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.xboardTunRecommendedUsage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: XbFontWeight.semibold,
                              color: Colors.amber.shade700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• ${l10n.xboardTunRuleRecommendation}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.8),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• ${l10n.xboardTunGlobalRecommendation}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: XbUiButton.outlinedNeutral(context).copyWith(
            foregroundColor: isDark
                ? null
                : WidgetStatePropertyAll(
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
          ),
          child: Text(l10n.xboardMaybeLater),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: XbUiButton.filledPrimary(context).copyWith(
            backgroundColor: WidgetStatePropertyAll(Colors.green.shade600),
          ),
          child: Text(l10n.xboardEnableTun),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? null : Border.all(color: const Color(0xFFEEF0F4)),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 20,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: XbFontWeight.semibold,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
