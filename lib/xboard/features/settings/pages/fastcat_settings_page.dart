import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/about/pages/fastcat_about_page.dart';
import 'package:fl_clash/xboard/features/diagnostics/pages/diagnostics_center_page.dart';
import 'package:fl_clash/xboard/features/logs/pages/fastcat_logs_page.dart';
import 'package:fl_clash/xboard/features/settings/pages/fastcat_auto_start_settings_page.dart';
import 'package:fl_clash/xboard/features/settings/pages/fastcat_dns_settings_page.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/streaming_check/pages/streaming_check_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatSettingsPage extends ConsumerWidget {
  const FastCatSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appSetting = ref.watch(appSettingProvider);
    final theme = ref.watch(themeSettingProvider);

    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _header(context, l10n.application),
              _SettingsCard(
                children: [
                  _navigationTile(
                    context,
                    icon: Icons.language_outlined,
                    title: l10n.language,
                    subtitle: _languageLabel(appSetting.locale, l10n),
                    onTap: () => _chooseLanguage(context, ref),
                  ),
                  _navigationTile(
                    context,
                    icon: Icons.brightness_6_outlined,
                    title: l10n.theme,
                    subtitle: _themeLabel(theme.themeMode, l10n),
                    onTap: () => _chooseTheme(context, ref, theme.themeMode),
                  ),
                  _navigationTile(
                    context,
                    icon: Icons.power_settings_new_outlined,
                    title: l10n.xboardStartup,
                    subtitle: l10n.xboardStartupDescription,
                    onTap: () =>
                        _open(context, const FastCatAutoStartSettingsPage()),
                  ),
                ],
              ),
              _header(context, l10n.network),
              _SettingsCard(
                children: [
                  _navigationTile(
                    context,
                    icon: Icons.dns_outlined,
                    title: l10n.overrideDns,
                    subtitle: l10n.dnsDesc,
                    onTap: () => _open(context, const FastCatDnsSettingsPage()),
                  ),
                  _navigationTile(
                    context,
                    icon: Icons.monitor_heart_outlined,
                    title: l10n.xboardDiagnosticsCenter,
                    onTap: () => _open(context, const DiagnosticsCenterPage()),
                  ),
                  _navigationTile(
                    context,
                    icon: Icons.live_tv_outlined,
                    title: l10n.xboardStreamingCheck,
                    onTap: () => _open(context, const StreamingCheckPage()),
                  ),
                ],
              ),
              _header(context, l10n.other),
              _SettingsCard(
                children: [
                  _navigationTile(
                    context,
                    icon: Icons.article_outlined,
                    title: l10n.logs,
                    onTap: () => _open(context, const FastCatLogsPage()),
                  ),
                  _navigationTile(
                    context,
                    icon: Icons.info_outline,
                    title: l10n.about,
                    onTap: () => _open(context, const FastCatAboutPage()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(
          text,
          style: XbUiText.cardTitle(context).copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  Widget _navigationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      XbPointerCursor(
        child: ListTile(
          leading: _SettingsIcon(icon: icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: Icon(Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline),
          onTap: onTap,
        ),
      );

  String _languageLabel(String? locale, AppLocalizations l10n) {
    return switch (locale) {
      'zh_CN' || 'zh' => '简体中文',
      'en' => 'English',
      _ => l10n.system,
    };
  }

  String _themeLabel(ThemeMode mode, AppLocalizations l10n) => switch (mode) {
        ThemeMode.system => l10n.auto,
        ThemeMode.light => l10n.light,
        ThemeMode.dark => l10n.dark,
      };

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(appSettingProvider).locale ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(dialogContext),
        title: Text(l10n.language, style: XbUiText.sectionTitle(dialogContext)),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChoiceTile<String>(
                value: '',
                groupValue: current,
                title: l10n.system,
                subtitle: 'System',
                onSelected: (value) => Navigator.pop(dialogContext, value),
              ),
              _ChoiceTile<String>(
                value: 'zh_CN',
                groupValue: current,
                title: '简体中文',
                onSelected: (value) => Navigator.pop(dialogContext, value),
              ),
              _ChoiceTile<String>(
                value: 'en',
                groupValue: current,
                title: 'English',
                onSelected: (value) => Navigator.pop(dialogContext, value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (value == null) return;
    ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(locale: value.isEmpty ? null : value),
        );
  }

  Future<void> _chooseTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final value = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(dialogContext),
        title: Text(l10n.theme, style: XbUiText.sectionTitle(dialogContext)),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values
                .map(
                  (mode) => _ChoiceTile<ThemeMode>(
                    value: mode,
                    groupValue: current,
                    title: _themeLabel(mode, l10n),
                    onSelected: (value) => Navigator.pop(dialogContext, value),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (value == null) return;
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(themeMode: value),
        );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.onSelected,
    this.subtitle,
  });

  final T value;
  final T groupValue;
  final String title;
  final String? subtitle;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return XbPointerCursor(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        selectedTileColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        onTap: () => onSelected(value),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: XbUiCardStyle.elevation(context),
      shadowColor: XbUiCardStyle.shadowColor(context),
      color: XbUiCardStyle.background(context),
      shape: XbUiCardStyle.shape(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 68,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.55),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: 22,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
