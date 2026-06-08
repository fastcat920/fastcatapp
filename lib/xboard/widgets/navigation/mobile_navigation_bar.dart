import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';

/// 移动端底部导航栏
class MobileNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final bool logCapture;

  const MobileNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.logCapture = false,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Material(
      color: isDark ? colorScheme.surface : Colors.white,
      child: Container(
        height: 68 + MediaQuery.paddingOf(context).bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        decoration: isDark
            ? null
            : const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFEEF0F4),
                    width: 1,
                  ),
                ),
              ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MobileNavItem(
              index: 0,
              selectedIndex: selectedIndex,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: appLocalizations.xboardHome,
              onTap: onDestinationSelected,
            ),
            _MobileNavItem(
              index: 1,
              selectedIndex: selectedIndex,
              icon: Icons.shopping_bag_outlined,
              selectedIcon: Icons.shopping_bag,
              label: appLocalizations.xboardPlans,
              onTap: onDestinationSelected,
            ),
            _MobileNavItem(
              index: 2,
              selectedIndex: selectedIndex,
              icon: Icons.group_add_outlined,
              selectedIcon: Icons.group_add,
              label: appLocalizations.invite,
              onTap: onDestinationSelected,
            ),
            _MobileNavItem(
              index: 3,
              selectedIndex: selectedIndex,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: appLocalizations.xboardMine,
              onTap: onDestinationSelected,
            ),
            if (logCapture)
              _MobileNavItem(
                index: 4,
                selectedIndex: selectedIndex,
                icon: Icons.list_alt_outlined,
                selectedIcon: Icons.list_alt,
                label: appLocalizations.logs,
                onTap: onDestinationSelected,
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final isSelected = index == selectedIndex;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(7),
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
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
