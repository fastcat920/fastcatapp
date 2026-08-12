import 'dart:io';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatAutoStartSettingsPage extends ConsumerWidget {
  const FastCatAutoStartSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appSetting = ref.watch(appSettingProvider);
    final supportsBootLaunch =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: Text(_isChinese(context) ? '自启动' : 'Startup'),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 32),
            children: [
              Card(
                margin: EdgeInsets.zero,
                elevation: XbUiCardStyle.elevation(context),
                shadowColor: XbUiCardStyle.shadowColor(context),
                color: XbUiCardStyle.background(context),
                shape: XbUiCardStyle.shape(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const _StartupIcon(Icons.power_outlined),
                      title: Text(l10n.autoLaunch),
                      subtitle: Text(
                        supportsBootLaunch
                            ? l10n.autoLaunchDesc
                            : (_isChinese(context)
                                ? '当前平台暂不支持开机启动'
                                : 'Not supported on this platform'),
                      ),
                      value: supportsBootLaunch && appSetting.autoLaunch,
                      onChanged: supportsBootLaunch
                          ? (value) =>
                              ref.read(appSettingProvider.notifier).updateState(
                                    (state) =>
                                        state.copyWith(autoLaunch: value),
                                  )
                          : null,
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.55),
                    ),
                    SwitchListTile(
                      secondary: const _StartupIcon(Icons.play_circle_outline),
                      title: Text(l10n.autoRun),
                      subtitle: Text(l10n.autoRunDesc),
                      value: appSetting.autoRun,
                      onChanged: (value) =>
                          ref.read(appSettingProvider.notifier).updateState(
                                (state) => state.copyWith(autoRun: value),
                              ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                child: Text(
                  _isChinese(context)
                      ? '自动运行表示应用启动后自动连接代理，与开机启动是两个独立选项。'
                      : 'Auto run connects the proxy after the app opens. It is independent of start on boot.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isChinese(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh';
}

class _StartupIcon extends StatelessWidget {
  const _StartupIcon(this.icon);

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
