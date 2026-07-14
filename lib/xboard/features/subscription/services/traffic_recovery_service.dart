import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/subscription/services/reset_traffic_order_flow.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

bool isNewPeriodEnabled(
  WidgetRef ref, {
  DomainSubscription? subscriptionInfo,
}) {
  return (subscriptionInfo ??
              ref.read(subscriptionInfoProvider) ??
              ref.read(xboardUserProvider).subscriptionInfo)
          ?.allowNewPeriod ==
      true;
}

Future<void> showTrafficRecoveryDialog({
  required BuildContext context,
  required WidgetRef ref,
  int? planId,
  DomainPlan? plan,
  DomainSubscription? subscriptionInfo,
}) async {
  if (isNewPeriodEnabled(ref, subscriptionInfo: subscriptionInfo)) {
    await showNewPeriodDialog(context: context, ref: ref);
    return;
  }
  await showResetTrafficOrderDialog(
    context: context,
    ref: ref,
    planId: planId,
    plan: plan,
  );
}

bool _isStartingNewPeriod = false;

Future<void> showNewPeriodDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await _NewPeriodConfirmDialog.show(context);
  if (confirmed != true || _isStartingNewPeriod) return;

  _isStartingNewPeriod = true;
  try {
    await XBoardSDK.instance.httpService
        .postRequest('/user/newPeriod', const {});
    await ref
        .read(xboardUserProvider.notifier)
        .refreshSubscriptionInfo(importProfile: true);
    if (context.mounted) {
      XBoardNotification.showSuccess(l10n.xboardNewPeriodSuccess);
    }
  } catch (e) {
    if (context.mounted) {
      XBoardNotification.showError(
        BackendMessageMapper.mapError(
          e,
          fallback: l10n.xboardNewPeriodFailed,
        ),
      );
    }
  } finally {
    _isStartingNewPeriod = false;
  }
}

class _NewPeriodConfirmDialog extends StatelessWidget {
  const _NewPeriodConfirmDialog();

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NewPeriodConfirmDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final actionColor = XbUiStatusColor.pendingByTheme(theme);
    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: actionColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.restart_alt, color: actionColor, size: 32),
      ),
      title: Text(
        l10n.xboardConfirmNewPeriod,
        style: XbUiText.sectionTitle(context).copyWith(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      content: Text(
        l10n.xboardNewPeriodConfirmContent,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
        textAlign: TextAlign.center,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: XbUiButton.outlinedNeutral(context).copyWith(
                  foregroundColor: WidgetStatePropertyAll(
                    theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                child: Text(l10n.cancel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: XbUiButton.filledPrimary(context).copyWith(
                  backgroundColor: WidgetStatePropertyAll(actionColor),
                ),
                child: Text(l10n.confirm),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
