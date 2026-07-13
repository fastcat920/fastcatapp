import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/application_setting.dart';
import 'package:fl_clash/views/config/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/xboard/features/diagnostics/pages/diagnostics_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'developer.dart';
import 'logs.dart';
import 'theme.dart';

class ToolsView extends ConsumerStatefulWidget {
  const ToolsView({super.key});

  @override
  ConsumerState<ToolsView> createState() => _ToolboxViewState();
}

class _ToolboxViewState extends ConsumerState<ToolsView> {
  String _getPageLabelText(AppLocalizations l10n, PageLabel label) {
    return switch (label) {
      PageLabel.dashboard => l10n.dashboard,
      PageLabel.proxies => l10n.proxies,
      PageLabel.profiles => l10n.profiles,
      PageLabel.tools => l10n.tools,
      PageLabel.logs => l10n.logs,
      PageLabel.requests => l10n.requests,
      PageLabel.resources => l10n.resources,
      PageLabel.connections => l10n.connections,
      PageLabel.plans => l10n.plans,
      PageLabel.xboard => l10n.xboard,
      PageLabel.invite => l10n.invite,
      PageLabel.userCenter => l10n.userCenter,
    };
  }

  _buildNavigationMenuItem(
    AppLocalizations l10n,
    NavigationItem navigationItem,
  ) {
    final title = _getPageLabelText(l10n, navigationItem.label);
    return ListItem.open(
      leading: navigationItem.icon,
      title: Text(title),
      subtitle: navigationItem.description != null
          ? Text(Intl.message(navigationItem.description!))
          : null,
      delegate: OpenDelegate(
        title: title,
        widget: navigationItem.view,
      ),
    );
  }

  Widget _buildNavigationMenu(
    AppLocalizations l10n,
    List<NavigationItem> navigationItems,
  ) {
    return Column(
      children: [
        for (final navigationItem in navigationItems) ...[
          _buildNavigationMenuItem(l10n, navigationItem),
          navigationItems.last != navigationItem
              ? const Divider(
                  height: 0,
                )
              : Container(),
        ]
      ],
    );
  }

  Widget _getOtherList(
    AppLocalizations l10n,
    bool enableDeveloperMode,
    bool logCapture,
  ) {
    return generateSectionV2(
      title: l10n.other,
      items: [
        if (logCapture) const _LogsItem(),
        if (enableDeveloperMode) const _DeveloperItem(),
        const _DiagnosticsCenterItem(),
        const _InfoItem(),
      ],
    );
  }

  Widget _getSettingList(AppLocalizations l10n) {
    return generateSectionV2(
      title: l10n.settings,
      items: [
        const _LocaleItem(),
        const _ThemeItem(),
        const _ConfigItem(),
        const _SettingItem(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                ListHeader(title: l10n.more),
                SectionCard(
                  child: _buildNavigationMenu(l10n, state.navigationItems),
                ),
              ],
            );
          },
        ),
        _getSettingList(l10n),
        _getOtherList(l10n, vm2.b, vm2.c),
      ],
    );
  }
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(AppLocalizations l10n, Locale? locale) {
    return switch (locale?.toString()) {
      null => l10n.defaultText,
      'en' => l10n.en,
      'zh_CN' => l10n.zh_CN,
      _ => locale!.toLanguageTag(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale =
        ref.watch(appSettingProvider.select((state) => state.locale));
    final currentLocale = utils.getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: const Icon(Icons.language_outlined),
      title: Text(l10n.language),
      subtitle: Text(_getLocaleString(l10n, currentLocale)),
      delegate: OptionsDelegate(
        title: l10n.language,
        options: [null, ...AppLocalizations.delegate.supportedLocales],
        onChanged: (Locale? locale) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(locale: locale?.toString()),
              );
        },
        textBuilder: (locale) => _getLocaleString(l10n, locale),
        value: currentLocale,
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.style),
      title: Text(l10n.theme),
      subtitle: Text(l10n.themeDesc),
      delegate: OpenDelegate(
        title: l10n.theme,
        widget: const ThemeView(),
      ),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  const _ConfigItem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.edit),
      title: Text(l10n.basicConfig),
      subtitle: Text(l10n.basicConfigDesc),
      delegate: OpenDelegate(
        title: l10n.override,
        widget: const ConfigView(),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.settings),
      title: Text(l10n.application),
      subtitle: Text(l10n.applicationDesc),
      delegate: OpenDelegate(
        title: l10n.application,
        widget: const ApplicationSettingView(),
      ),
    );
  }
}

class _DiagnosticsCenterItem extends StatelessWidget {
  const _DiagnosticsCenterItem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.monitor_heart_outlined),
      title: Text(l10n.xboardDiagnosticsCenter),
      subtitle: Text(l10n.xboardDiagnosticsCenterSubtitle),
      delegate: OpenDelegate(
        title: l10n.xboardDiagnosticsCenter,
        widget: const DiagnosticsCenterPage(),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.info),
      title: Text(l10n.about),
      delegate: OpenDelegate(
        title: l10n.about,
        widget: const AboutView(),
      ),
    );
  }
}

class _LogsItem extends StatelessWidget {
  const _LogsItem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.list_alt_outlined),
      title: Text(l10n.logs),
      subtitle: Text(l10n.logsDesc),
      delegate: OpenDelegate(
        title: l10n.logs,
        widget: const LogsView(),
      ),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.developer_board),
      title: Text(l10n.developerMode),
      delegate: OpenDelegate(
        title: l10n.developerMode,
        widget: const DeveloperView(),
      ),
    );
  }
}
