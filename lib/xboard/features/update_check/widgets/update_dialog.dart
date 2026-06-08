import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import '../models/update_check_state.dart';

class UpdateDialog extends ConsumerWidget {
  final UpdateCheckState state;
  const UpdateDialog({super.key, required this.state});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !state.forceUpdate,
      child: AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(context),
        title: Row(
          children: [
            Icon(
              state.forceUpdate ? Icons.warning : Icons.system_update,
              color: state.forceUpdate
                  ? XbUiStatusColor.error(context)
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.forceUpdate
                    ? appLocalizations
                        .updateCheckForceUpdate(state.latestVersion ?? '')
                    : appLocalizations
                        .updateCheckNewVersionFound(state.latestVersion ?? ''),
                style: TextStyle(
                  color:
                      state.forceUpdate ? XbUiStatusColor.error(context) : null,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8),
                border: isDark
                    ? null
                    : Border.all(color: XbUiTokens.cardBorderLight),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    appLocalizations
                        .updateCheckCurrentVersion(state.currentVersion ?? ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (state.releaseNotes != null &&
                state.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                appLocalizations.updateCheckReleaseNotes,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? theme.colorScheme.outline.withValues(alpha: 0.2)
                        : XbUiTokens.cardBorderLight,
                  ),
                  boxShadow: isDark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x0A1565C0),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Text(
                    state.releaseNotes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.4,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!state.forceUpdate)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: XbUiButton.outlinedNeutral(context),
              child: Text(appLocalizations.updateCheckUpdateLater),
            ),
          FilledButton.icon(
            onPressed: () {
              if (state.updateUrl != null) {
                _launchUrl(state.updateUrl!);
              }
              if (!state.forceUpdate) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: Text(state.forceUpdate
                ? appLocalizations.updateCheckMustUpdate
                : appLocalizations.updateCheckUpdateNow),
            style: state.forceUpdate
                ? XbUiButton.filledDanger(context)
                : XbUiButton.filledPrimary(context),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
