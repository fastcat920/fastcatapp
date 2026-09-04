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
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatAboutPage extends ConsumerStatefulWidget {
  const FastCatAboutPage({super.key});

  @override
  ConsumerState<FastCatAboutPage> createState() => _FastCatAboutPageState();
}

class _FastCatAboutPageState extends ConsumerState<FastCatAboutPage> {
  int _logoTapCount = 0;
  DateTime? _lastLogoTapAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final update = ref.watch(updateCheckProvider);
    final version = globalState.packageInfo.version;
    final showLogs = ref.watch(
      appSettingProvider.select((setting) => setting.logCapture),
    );
    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: Text(l10n.about),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverList.list(
                    children: [
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _onLogoTap,
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
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localizedAppName,
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
                        elevation: XbUiCardStyle.elevation(context),
                        shadowColor: XbUiCardStyle.shadowColor(context),
                        color: XbUiCardStyle.background(context),
                        shape: XbUiCardStyle.shape(context),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            ListTile(
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
                            ),
                            if (showLogs) ...[
                              Divider(
                                height: 1,
                                color: XbUiTokens.cardBorder(context),
                              ),
                              ListTile(
                                leading: const Icon(Icons.article_outlined),
                                title: Text(l10n.logs),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const FastCatLogsPage(),
                                  ),
                                ),
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
      ),
    );
  }

  void _onLogoTap() {
    if (ref.read(appSettingProvider).logCapture) return;
    final now = DateTime.now();
    if (_lastLogoTapAt == null ||
        now.difference(_lastLogoTapAt!) > const Duration(seconds: 2)) {
      _logoTapCount = 0;
    }
    _lastLogoTapAt = now;
    _logoTapCount += 1;
    if (_logoTapCount < 5) return;

    _logoTapCount = 0;
    ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(logCapture: true, openLogs: true),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_logsEnabledLabel(context))),
    );
  }

  String _logsEnabledLabel(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh'
          ? '日志菜单已显示'
          : 'Logs menu enabled';

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
        builder: (_) => UpdateDialog(state: state),
      );
      final latestVersion = state.latestVersion?.trim() ?? '';
      if (!state.forceUpdate && latestVersion.isNotEmpty) {
        await ref
            .read(updateCacheServiceProvider)
            .markOptionalVersionPrompted(latestVersion);
      }
      await dialogFuture;
      return;
    }
    final text = state.error ?? AppLocalizations.of(context).checkUpdateError;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
