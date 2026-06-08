import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

class XbErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const XbErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  String _localizedMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final normalized = message.trim().toLowerCase();

    if (normalized.isEmpty) {
      return l10n.xboardUnknownErrorRetry;
    }

    // Common network/timeout/socket variants from backend or SDK.
    if (normalized.contains('timeout') || normalized.contains('timed out')) {
      return l10n.xboardConnectionTimeout;
    }

    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection refused') ||
        normalized.contains('unable to resolve host') ||
        normalized.contains('network error') ||
        normalized.contains('network request failed') ||
        normalized.contains('no internet') ||
        normalized.contains('offline') ||
        normalized.contains('无网络') ||
        normalized.contains('网络连接失败') ||
        normalized.contains('网络异常')) {
      return l10n.xboardNoInternetConnection;
    }

    if (normalized.contains('http') || normalized.contains('status code')) {
      return l10n.xboardNetworkConnectionFailed;
    }

    // Keep server/business error text when it's meaningful.
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).xboardLoadingFailed,
                style: XbUiText.sectionTitle(context)),
            const SizedBox(height: 6),
            Text(
              _localizedMessage(context),
              style: XbUiText.bodySmall(context),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).xboardRetry),
            ),
          ],
        ),
      ),
    );
  }
}
