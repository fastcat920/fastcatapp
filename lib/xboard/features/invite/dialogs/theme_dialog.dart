import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

class ThemeDialog extends ConsumerWidget {
  const ThemeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode =
        ref.read(themeSettingProvider.select((state) => state.themeMode));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      title: Text(
        appLocalizations.selectTheme,
        style: XbUiText.sectionTitle(context),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeModeTile(
            value: ThemeMode.system,
            groupValue: currentThemeMode,
            activeColor: isDark ? null : theme.colorScheme.primary,
            icon: Icons.auto_mode,
            label: appLocalizations.auto,
            onChanged: (value) => _updateThemeMode(context, ref, value),
          ),
          _ThemeModeTile(
            value: ThemeMode.light,
            groupValue: currentThemeMode,
            activeColor: isDark ? null : theme.colorScheme.primary,
            icon: Icons.light_mode,
            label: appLocalizations.light,
            onChanged: (value) => _updateThemeMode(context, ref, value),
          ),
          _ThemeModeTile(
            value: ThemeMode.dark,
            groupValue: currentThemeMode,
            activeColor: isDark ? null : theme.colorScheme.primary,
            icon: Icons.dark_mode,
            label: appLocalizations.dark,
            onChanged: (value) => _updateThemeMode(context, ref, value),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: XbUiButton.outlinedNeutral(context),
          child: Text(appLocalizations.cancel),
        ),
      ],
    );
  }

  void _updateThemeMode(
    BuildContext context,
    WidgetRef ref,
    ThemeMode? value,
  ) {
    if (value == null) return;
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(themeMode: value),
        );
    Navigator.of(context).pop();
  }
}

class _ThemeModeTile extends StatelessWidget {
  final ThemeMode value;
  final ThemeMode groupValue;
  final Color? activeColor;
  final IconData icon;
  final String label;
  final ValueChanged<ThemeMode?> onChanged;

  const _ThemeModeTile({
    required this.value,
    required this.groupValue,
    required this.activeColor,
    required this.icon,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      activeColor: activeColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      value: value,
      // Keep the legacy RadioListTile API until CI moves past Flutter 3.27.
      // ignore: deprecated_member_use
      groupValue: groupValue,
      // ignore: deprecated_member_use
      onChanged: onChanged,
    );
  }
}
