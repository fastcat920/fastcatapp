import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
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
        'TUN 模式',
        style: XbUiText.sectionTitle(context).copyWith(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TUN 模式是一种高级网络代理技术，通过虚拟网络接口实现更完整的流量代理。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              Icons.network_check,
              '全流量代理',
              '捕获所有应用的网络流量，无需单独配置',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              context,
              Icons.security,
              '透明代理',
              '应用无感知的代理模式，兼容性更好',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              context,
              Icons.speed,
              '性能优化',
              '减少代理层级，提升网络访问速度',
              isDark,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
                border: isDark ? null : Border.all(color: const Color(0xFFEEF0F4)),
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
                        '推荐使用方式',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 日常使用：规则 + TUN（智能分流，性能最佳）',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• 备用方案：全局 + TUN（如规则模式异常时使用）',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
          child: const Text('稍后再说'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: XbUiButton.filledPrimary(context).copyWith(
            backgroundColor: WidgetStatePropertyAll(Colors.green.shade600),
          ),
          child: const Text('开启 TUN'),
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
        boxShadow: isDark ? null : const [
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
