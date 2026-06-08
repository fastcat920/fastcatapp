import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:fl_clash/views/config/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show dirname, join;

import 'developer.dart';
import 'logs.dart';
import 'theme.dart';

class ToolsView extends ConsumerStatefulWidget {
  const ToolsView({super.key});

  @override
  ConsumerState<ToolsView> createState() => _ToolboxViewState();
}

class _ToolboxViewState extends ConsumerState<ToolsView> {
  _buildNavigationMenuItem(NavigationItem navigationItem) {
    return ListItem.open(
      leading: navigationItem.icon,
      title: Text(Intl.message(navigationItem.label.name)),
      subtitle: navigationItem.description != null
          ? Text(Intl.message(navigationItem.description!))
          : null,
      delegate: OpenDelegate(
        title: Intl.message(navigationItem.label.name),
        widget: navigationItem.view,
      ),
    );
  }

  Widget _buildNavigationMenu(List<NavigationItem> navigationItems) {
    return Column(
      children: [
        for (final navigationItem in navigationItems) ...[
          _buildNavigationMenuItem(navigationItem),
          navigationItems.last != navigationItem
              ? const Divider(
                  height: 0,
                )
              : Container(),
        ]
      ],
    );
  }

  Widget _getOtherList(bool enableDeveloperMode, bool logCapture) {
    return generateSectionV2(
      title: appLocalizations.other,
      items: [
        if (logCapture) const _LogsItem(),
        if (enableDeveloperMode) _DeveloperItem(),
        _InfoItem(),
      ],
    );
  }

  Widget _getSettingList() {
    return generateSectionV2(
      title: appLocalizations.settings,
      items: [
        _LocaleItem(),
        _ThemeItem(),
        if (Platform.isWindows) _LoopbackItem(),
        _ConfigItem(),
        _SettingItem(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm2 = ref.watch(
      appSettingProvider.select(
        (state) =>
            (a: state.locale, b: state.developerMode, c: state.logCapture),
      ),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Consumer(
          builder: (_, ref, __) {
            final state = ref.watch(moreToolsSelectorStateProvider);
            if (state.navigationItems.isEmpty) {
              return Container();
            }
            return Column(
              children: [
                ListHeader(title: appLocalizations.more),
                SectionCard(
                  child: _buildNavigationMenu(state.navigationItems),
                ),
              ],
            );
          },
        ),
        _getSettingList(),
        _getOtherList(vm2.b, vm2.c),
      ],
    );
  }
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(Locale? locale) {
    if (locale == null) return appLocalizations.defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale =
        ref.watch(appSettingProvider.select((state) => state.locale));
    final subTitle = locale ?? appLocalizations.defaultText;
    final currentLocale = utils.getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: const Icon(Icons.language_outlined),
      title: Text(appLocalizations.language),
      subtitle: Text(Intl.message(subTitle)),
      delegate: OptionsDelegate(
        title: appLocalizations.language,
        options: [null, ...AppLocalizations.delegate.supportedLocales],
        onChanged: (Locale? locale) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(locale: locale?.toString()),
              );
        },
        textBuilder: (locale) => _getLocaleString(locale),
        value: currentLocale,
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.style),
      title: Text(appLocalizations.theme),
      subtitle: Text(appLocalizations.themeDesc),
      delegate: OpenDelegate(
        title: appLocalizations.theme,
        widget: const ThemeView(),
      ),
    );
  }
}

class _LoopbackItem extends StatelessWidget {
  const _LoopbackItem();

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: const Icon(Icons.lock),
      title: Text(appLocalizations.loopback),
      subtitle: Text(appLocalizations.loopbackDesc),
      onTap: () {
        final exePath =
            join(dirname(Platform.resolvedExecutable), "EnableLoopback.exe");
        if (!File(exePath).existsSync()) {
          globalState.showMessage(
            title: appLocalizations.loopback,
            message: TextSpan(text: "EnableLoopback.exe 未找到"),
          );
          return;
        }
        // EnableLoopback.exe 自带 highestAvailable UAC manifest，
        // 用 "open" verb 让 exe 自己处理提权，避免 "runas" 与 manifest 冲突
        final ok = windows?.launch(exePath) ?? false;
        if (!ok) {
          globalState.showMessage(
            title: appLocalizations.loopback,
            message: TextSpan(text: "启动失败，请检查系统权限设置"),
          );
        }
      },
    );
  }
}

class _ConfigItem extends StatelessWidget {
  const _ConfigItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.edit),
      title: Text(appLocalizations.basicConfig),
      subtitle: Text(appLocalizations.basicConfigDesc),
      delegate: OpenDelegate(
        title: appLocalizations.override,
        widget: const ConfigView(),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.settings),
      title: Text(appLocalizations.application),
      subtitle: Text(appLocalizations.applicationDesc),
      delegate: OpenDelegate(
        title: appLocalizations.application,
        widget: const ApplicationSettingView(),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.info),
      title: Text(appLocalizations.about),
      delegate: OpenDelegate(
        title: appLocalizations.about,
        widget: const AboutView(),
      ),
    );
  }
}

class _LogsItem extends StatelessWidget {
  const _LogsItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.list_alt_outlined),
      title: const Text('日志'),
      subtitle: const Text('日志捕获记录'),
      delegate: OpenDelegate(
        title: '日志',
        widget: const LogsView(),
      ),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem();

  @override
  Widget build(BuildContext context) {
    return ListItem.open(
      leading: const Icon(Icons.developer_board),
      title: Text(appLocalizations.developerMode),
      delegate: OpenDelegate(
        title: appLocalizations.developerMode,
        widget: const DeveloperView(),
      ),
    );
  }
}
