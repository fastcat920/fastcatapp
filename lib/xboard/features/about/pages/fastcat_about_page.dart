import 'package:fl_clash/xboard/features/shared/widgets/tv_page_frame.dart';
import 'package:fl_clash/widgets/tv_back_button.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/logs/pages/fastcat_logs_page.dart';
import 'package:fl_clash/xboard/features/update_check/providers/update_check_provider.dart';
import 'package:fl_clash/xboard/features/update_check/widgets/update_dialog.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/legal_footer.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatAboutPage extends ConsumerWidget {
  const FastCatAboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final update = ref.watch(updateCheckProvider);
    final version = globalState.packageInfo.version;
    final configuredLocale = ref.watch(
      appSettingProvider.select((setting) => setting.locale),
    );
    final brandName = localizedAppNameForLocale(
      configuredLocale ?? Localizations.localeOf(context).toLanguageTag(),
    );
    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        leadingWidth: system.isTV ? 68 : null,
        leading: system.isTV ? const TVBackButton() : null,
        title: Text(l10n.about),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: TVPageFrame(
          child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: system.isTV ? double.infinity : 680),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: system.isTV
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverList.list(
                    children: [
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              'assets/images/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        brandName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'V$version',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      Card(
                        margin: system.isTV ? EdgeInsets.zero : null,
                        elevation: XbUiCardStyle.elevation(context),
                        shadowColor: XbUiCardStyle.shadowColor(context),
                        color: XbUiCardStyle.background(context),
                        shape: XbUiCardStyle.shape(context),
                        clipBehavior: system.isTV ? Clip.none : Clip.antiAlias,
                        child: Column(
                          children: [
                            Builder(builder: (context) {
                              final tile = ListTile(
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.system_update_outlined),
                                    if (update.hasUpdate)
                                      Positioned(
                                        right: -3,
                                        top: -3,
                                        child: Container(
                                          key: const Key('about_update_badge'),
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(l10n.checkUpdate),
                                trailing: update.isChecking
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right),
                                onTap: update.isChecking
                                    ? null
                                    : () => _checkUpdate(context, ref),
                              );
                              if (!system.isTV) return tile;
                              return TVFocusGroupRow(
                                  index: 0,
                                  count: 1,
                                  child: TVFocusable(
                                      borderRadius: BorderRadius.circular(20),
                                      onPressed: update.isChecking
                                          ? null
                                          : () => _checkUpdate(context, ref),
                                      child: ExcludeFocus(child: tile)));
                            }),
                            if (!system.isTV) ...[
                              Divider(
                                height: 1,
                                color: XbUiTokens.cardBorder(context),
                              ),
                              ListTile(
                                leading: const Icon(Icons.article_outlined),
                                title: Text(l10n.logs),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openLogs(context, ref),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FastCatLegalFooter(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  void _openLogs(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingProvider);
    if (!settings.logCapture || !settings.openLogs) {
      ref.read(appSettingProvider.notifier).updateState(
            (state) => state.copyWith(logCapture: true, openLogs: true),
          );
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FastCatLogsPage()),
    );
  }

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    await ref.read(updateCheckProvider.notifier).checkForUpdates(
          refreshRemoteConfig: true,
          interactive: true,
        );
    if (!context.mounted) return;
    final state = ref.read(updateCheckProvider);
    if (state.hasUpdate) {
      final dialogFuture = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(state: state),
      );
      final latestVersion = state.latestVersion?.trim() ?? '';
      if (!state.forceUpdate && latestVersion.isNotEmpty) {
        await ref.read(updateCacheServiceProvider).markOptionalVersionPrompted(
            state.build == null ? latestVersion : state.releaseIdentity);
      }
      await dialogFuture;
      return;
    }
    final text = state.error ?? AppLocalizations.of(context).checkUpdateError;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
