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
          RadioListTile<ThemeMode>(
            activeColor: isDark ? null : theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                const Icon(Icons.auto_mode),
                const SizedBox(width: 8),
                Text(appLocalizations.auto),
              ],
            ),
            value: ThemeMode.system,
            groupValue: currentThemeMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith(themeMode: value),
                    );
                Navigator.of(context).pop();
              }
            },
          ),
          RadioListTile<ThemeMode>(
            activeColor: isDark ? null : theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                const Icon(Icons.light_mode),
                const SizedBox(width: 8),
                Text(appLocalizations.light),
              ],
            ),
            value: ThemeMode.light,
            groupValue: currentThemeMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith(themeMode: value),
                    );
                Navigator.of(context).pop();
              }
            },
          ),
          RadioListTile<ThemeMode>(
            activeColor: isDark ? null : theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                const Icon(Icons.dark_mode),
                const SizedBox(width: 8),
                Text(appLocalizations.dark),
              ],
            ),
            value: ThemeMode.dark,
            groupValue: currentThemeMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith(themeMode: value),
                    );
                Navigator.of(context).pop();
              }
            },
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
}
