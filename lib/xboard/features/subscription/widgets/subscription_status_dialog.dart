import 'dart:async';
import 'package:flutter/material.dart';
import '../services/subscription_status_service.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

class SubscriptionStatusDialog extends StatefulWidget {
  final SubscriptionStatusResult statusResult;
  final FutureOr<void> Function()? onPurchase;
  final FutureOr<void> Function()? onTrafficRecovery;
  final bool useNewPeriod;
  final FutureOr<void> Function()? onRefresh;
  const SubscriptionStatusDialog({
    super.key,
    required this.statusResult,
    this.onPurchase,
    this.onTrafficRecovery,
    this.useNewPeriod = false,
    this.onRefresh,
  });
  static Future<String?> show(
    BuildContext context,
    SubscriptionStatusResult statusResult, {
    FutureOr<void> Function()? onPurchase,
    FutureOr<void> Function()? onTrafficRecovery,
    bool useNewPeriod = false,
    FutureOr<void> Function()? onRefresh,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // 防止点击外部关闭
      builder: (context) => SubscriptionStatusDialog(
        statusResult: statusResult,
        onPurchase: onPurchase,
        onTrafficRecovery: onTrafficRecovery,
        useNewPeriod: useNewPeriod,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<SubscriptionStatusDialog> createState() =>
      _SubscriptionStatusDialogState();
}

class _SubscriptionStatusDialogState extends State<SubscriptionStatusDialog> {
  bool _isRefreshing = false;

  SubscriptionStatusResult get statusResult => widget.statusResult;
  FutureOr<void> Function()? get onPurchase => widget.onPurchase;
  FutureOr<void> Function()? get onTrafficRecovery => widget.onTrafficRecovery;
  FutureOr<void> Function()? get onRefresh => widget.onRefresh;
  bool get useNewPeriod => widget.useNewPeriod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      icon: _buildIcon(context),
      title: Text(
        _getTitle(context),
        style: XbUiText.sectionTitle(context).copyWith(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getContent(context),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
              textAlign: TextAlign.center,
            ),
            if (_shouldShowFeatureList()) ...[
              const SizedBox(height: 16),
              _buildFeatureList(context, isDark),
            ],
          ],
        ),
      ),
      actions: [
        // 使用Column实现竖排按钮，右对齐
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: _buildActions(context, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(BuildContext context) {
    final theme = Theme.of(context);
    Color iconColor;
    IconData iconData;
    Color backgroundColor;
    switch (statusResult.type) {
      case SubscriptionStatusType.noSubscription:
        iconColor = theme.colorScheme.primary;
        iconData = Icons.card_giftcard;
        backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.1);
        break;
      case SubscriptionStatusType.expired:
        iconColor = XbUiStatusColor.error(context);
        iconData = Icons.schedule;
        backgroundColor = XbUiStatusColor.error(context).withValues(alpha: 0.1);
        break;
      case SubscriptionStatusType.exhausted:
        iconColor = XbUiStatusColor.pending(context);
        iconData = Icons.data_usage;
        backgroundColor =
            XbUiStatusColor.pending(context).withValues(alpha: 0.1);
        break;
      default:
        iconColor = XbUiStatusColor.success(context);
        iconData = Icons.check_circle;
        backgroundColor =
            XbUiStatusColor.success(context).withValues(alpha: 0.1);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 32,
      ),
    );
  }

  String _getTitle(BuildContext context) {
    switch (statusResult.type) {
      case SubscriptionStatusType.noSubscription:
        return AppLocalizations.of(context).xboardNoAvailableSubscription;
      case SubscriptionStatusType.expired:
        return AppLocalizations.of(context).xboardSubscriptionHasExpired;
      case SubscriptionStatusType.exhausted:
        return AppLocalizations.of(context).xboardTrafficUsedUp;
      default:
        return AppLocalizations.of(context).xboardSubscriptionStatus;
    }
  }

  String _getContent(BuildContext context) {
    if (statusResult.type == SubscriptionStatusType.noSubscription) {
      return AppLocalizations.of(context).xboardPurchaseSubscriptionToUse;
    }
    if (statusResult.type == SubscriptionStatusType.exhausted && useNewPeriod) {
      return AppLocalizations.of(context).xboardNewPeriodTrafficExhaustedDetail;
    }
    return statusResult.getDetailMessage(context) ??
        statusResult.getMessage(context);
  }

  bool _shouldShowFeatureList() {
    return false;
  }

  Widget _buildFeatureList(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5)
            : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? null : Border.all(color: const Color(0xFFEEF0F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).xboardAfterPurchasingPlan,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: XbFontWeight.semibold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            context,
            Icons.speed,
            AppLocalizations.of(context).xboardHighSpeedNetwork,
            AppLocalizations.of(context).xboardEnjoyFastNetworkExperience,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            Icons.security,
            AppLocalizations.of(context).xboardSecureEncryption,
            AppLocalizations.of(context).xboardProtectNetworkPrivacy,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            Icons.public,
            AppLocalizations.of(context).xboardGlobalNodes,
            AppLocalizations.of(context).xboardConnectGlobalQualityNodes,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            Icons.support_agent,
            AppLocalizations.of(context).xboardProfessionalSupport,
            AppLocalizations.of(context).xboard24HourCustomerService,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: XbFontWeight.semibold,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context, bool isDark) {
    final actions = <Widget>[];
    if (statusResult.type == SubscriptionStatusType.expired ||
        statusResult.type == SubscriptionStatusType.exhausted) {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isRefreshing
                ? null
                : () async {
                    setState(() => _isRefreshing = true);
                    try {
                      await onRefresh?.call();
                      if (context.mounted) {
                        Navigator.of(context).pop('refresh');
                      }
                    } finally {
                      if (mounted) setState(() => _isRefreshing = false);
                    }
                  },
            style: XbUiButton.outlinedNeutral(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRefreshing) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(AppLocalizations.of(context).xboardRefreshStatus),
              ],
            ),
          ),
        ),
      );
      actions.add(const SizedBox(height: 8));
    }
    actions.add(
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed:
              _isRefreshing ? null : () => Navigator.of(context).pop('later'),
          style: XbUiButton.outlinedNeutral(context),
          child: Text(_getSecondaryButtonText(context)),
        ),
      ),
    );
    actions.add(const SizedBox(height: 8));
    if (statusResult.type == SubscriptionStatusType.exhausted) {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isRefreshing
                ? null
                : () {
                    Navigator.of(context).pop('reset_traffic');
                    onTrafficRecovery?.call();
                  },
            style: XbUiButton.filledPrimary(context).copyWith(
              backgroundColor:
                  WidgetStatePropertyAll(XbUiStatusColor.pending(context)),
            ),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: Text(
              useNewPeriod
                  ? AppLocalizations.of(context).xboardStartNewPeriod
                  : AppLocalizations.of(context).xboardResetTraffic,
            ),
          ),
        ),
      );
      actions.add(const SizedBox(height: 8));
    }
    if (statusResult.type != SubscriptionStatusType.exhausted) {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isRefreshing
                ? null
                : () {
                    Navigator.of(context).pop('purchase');
                    onPurchase?.call();
                  },
            style: XbUiButton.filledPrimary(context).copyWith(
              backgroundColor:
                  WidgetStatePropertyAll(_getPrimaryButtonColor(context)),
            ),
            child: Text(_getPrimaryButtonText(context)),
          ),
        ),
      );
    }
    return actions;
  }

  Color _getPrimaryButtonColor(BuildContext context) {
    switch (statusResult.type) {
      case SubscriptionStatusType.noSubscription:
        return Theme.of(context).colorScheme.primary;
      case SubscriptionStatusType.expired:
        return XbUiStatusColor.error(context);
      case SubscriptionStatusType.exhausted:
        return XbUiStatusColor.pending(context);
      default:
        return XbUiStatusColor.success(context);
    }
  }

  String _getPrimaryButtonText(BuildContext context) {
    switch (statusResult.type) {
      case SubscriptionStatusType.noSubscription:
        return AppLocalizations.of(context).xboardBuyPlan;
      case SubscriptionStatusType.expired:
        return AppLocalizations.of(context).xboardRenewPlan;
      case SubscriptionStatusType.exhausted:
        return AppLocalizations.of(context).xboardPurchaseTraffic;
      default:
        return AppLocalizations.of(context).xboardConfirmAction;
    }
  }

  String _getSecondaryButtonText(BuildContext context) {
    if (statusResult.type == SubscriptionStatusType.noSubscription) {
      return AppLocalizations.of(context).cancel;
    }
    return AppLocalizations.of(context).xboardHandleLater;
  }
}
