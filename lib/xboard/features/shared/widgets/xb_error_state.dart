import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

class XbErrorState extends StatelessWidget {
  final Object? message;
  final VoidCallback onRetry;
  final bool compact;

  const XbErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  String _localizedMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final normalized = message?.toString().trim().toLowerCase() ?? '';

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

    // Loading surfaces never expose backend HTML, exception types, paths, or
    // stack traces. HTTP failures and unsupported endpoints use one generic
    // retry message; diagnostics remain available in logs.
    return l10n.xboardUnknownErrorRetry;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: compact ? 36 : 56, color: theme.colorScheme.error),
              SizedBox(height: compact ? 8 : 12),
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
              SizedBox(height: compact ? 12 : 16),
              compact
                  ? TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context).xboardRetry),
                    )
                  : FilledButton(
                      onPressed: onRetry,
                      child: Text(AppLocalizations.of(context).xboardRetry),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
