import 'dart:async';

import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/pages/order_detail_page.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';

Future<void> showResetTrafficOrderDialog({
  required BuildContext context,
  required WidgetRef ref,
  int? planId,
  DomainPlan? plan,
}) async {
  final l10n = AppLocalizations.of(context);
  final resolvedPlanId = _normalizePlanId(plan?.id) ??
      _normalizePlanId(planId) ??
      _normalizePlanId(ref.read(subscriptionInfoProvider)?.planId) ??
      _normalizePlanId(ref.read(userInfoProvider)?.planId) ??
      _normalizePlanId(ref.read(xboardUserProvider).subscriptionInfo?.planId);

  if (resolvedPlanId == null) {
    XBoardNotification.showError(l10n.xboardPlanNotFound);
    return;
  }

  final tradeNoFuture = _createResetTrafficOrder(
    ref: ref,
    planId: resolvedPlanId,
  );
  final planFuture = _resolveResetTrafficPlan(
    ref: ref,
    planId: resolvedPlanId,
    plan: plan,
  );

  final orderPageFuture = _buildResetTrafficOrderPage(
    ref: ref,
    tradeNoFuture: tradeNoFuture,
    planFuture: planFuture,
  );

  if (!context.mounted) return;
  final confirmed = await _ResetTrafficConfirmDialog.show(context);
  if (confirmed != true) return;

  final orderPage = await orderPageFuture;
  if (orderPage == null) {
    final errorMessage = ref.read(userUIStateProvider).errorMessage;
    XBoardNotification.showError(
        errorMessage ?? l10n.xboardOrderCreationFailed);
    return;
  }

  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => orderPage,
    ),
  );
}

Future<String?> _createResetTrafficOrder({
  required WidgetRef ref,
  required int planId,
}) {
  return ref.read(xboardPaymentProvider.notifier).createOrder(
        planId: planId,
        period: 'reset_price',
      );
}

Future<DomainPlan?> _resolveResetTrafficPlan({
  required WidgetRef ref,
  required int planId,
  required DomainPlan? plan,
}) async {
  if (plan != null) return plan;
  var plans = ref.read(xboardSubscriptionProvider);
  if (plans.isEmpty) {
    await ref.read(xboardSubscriptionProvider.notifier).loadPlans();
    plans = ref.read(xboardSubscriptionProvider);
  }
  final matched = plans.where((item) => item.id == planId).firstOrNull;
  if (matched != null) return matched;

  // 兜底：可见套餐列表可能过滤掉当前套餐，按 planId 直拉详情拿 resetPrice。
  return await ref
      .read(xboardSubscriptionProvider.notifier)
      .loadPlanById(planId);
}

Future<OrderDetailPage?> _buildResetTrafficOrderPage({
  required WidgetRef ref,
  required Future<String?> tradeNoFuture,
  required Future<DomainPlan?> planFuture,
}) async {
  final tradeNo = await tradeNoFuture;
  if (tradeNo == null || tradeNo.isEmpty) return null;
  unawaited(ref.read(getOrderProvider(tradeNo).future).catchError((_) => null));
  final plan = await planFuture;
  return OrderDetailPage(
    tradeNo: tradeNo,
    plan: plan,
    period: 'reset_price',
    originalPrice: plan?.resetPrice,
    finalPrice: plan?.resetPrice,
    optimistic: true,
  );
}

int? _normalizePlanId(int? planId) =>
    planId != null && planId > 0 ? planId : null;

class _ResetTrafficConfirmDialog extends StatelessWidget {
  const _ResetTrafficConfirmDialog();

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ResetTrafficConfirmDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: XbUiStatusColor.pendingByTheme(theme).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.restart_alt,
          color: XbUiStatusColor.pendingByTheme(theme),
          size: 32,
        ),
      ),
      title: Text(
        l10n.xboardConfirmResetTraffic,
        style: XbUiText.sectionTitle(context).copyWith(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      content: Text(
        l10n.xboardResetTrafficConfirmContent,
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
                  backgroundColor:
                      WidgetStatePropertyAll(XbUiStatusColor.pendingByTheme(theme)),
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
