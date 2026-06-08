import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 桌面端侧边导航栏
/// 导航项：主页 / 套餐 / 邀请 / 我的 [/ 日志（logCapture 开启时）]
class DesktopNavigationRail extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final bool logCapture;

  const DesktopNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.logCapture = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    // Material 祖先必须存在，否则 InkWell 的 Material.of 会抛出异常。
    // type.transparency 透明但仍提供 ink 涂层，视觉背景由内部 Container decoration 负责。
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surfaceContainer,
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ],
                )
              : null,
          color: isDark ? null : Colors.white,
          border: isDark
              ? null
              : const Border(
                  right: BorderSide(
                    color: Color(0xFFEEF0F4),
                    width: 1,
                  ),
                ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 导航项（含底部齿轮，统一均匀排列）
            Expanded(
              child: _buildNavigationItems(context, colorScheme, isDark),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ), // Container
    ); // Material
  }

  Widget _buildNavigationItems(
      BuildContext context, ColorScheme colorScheme, bool isDark) {
    final appLocalizations = AppLocalizations.of(context);

    Widget buildItem(
        int index, IconData icon, IconData selectedIcon, String label,
        {VoidCallback? onTap}) {
      final isSelected = onTap == null && index == selectedIndex;
      final itemChild = SizedBox(
        width: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                          .withValues(alpha: isDark ? 0.22 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      if (system.isTV) {
        return TVFocusable(
          onPressed: onTap ?? () => onDestinationSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: itemChild,
        );
      }

      return InkWell(
        onTap: onTap ?? () => onDestinationSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: itemChild,
      );
    }

    const inviteIdx = 2;
    const mineIdx = 3;
    const logsIdx = 4;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          buildItem(
              0, Icons.home_outlined, Icons.home, appLocalizations.xboardHome),
          buildItem(1, Icons.shopping_bag_outlined, Icons.shopping_bag,
              appLocalizations.xboardPlans),
          buildItem(inviteIdx, Icons.group_add_outlined, Icons.group_add,
              appLocalizations.invite),
          buildItem(mineIdx, Icons.person_outline, Icons.person,
              appLocalizations.xboardMine),
          if (logCapture)
            buildItem(logsIdx, Icons.list_alt_outlined, Icons.list_alt,
                appLocalizations.logs),
        ],
      ),
    );
  }
}
