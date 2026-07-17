import 'dart:async';

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
  if (_isStartingNewPeriod || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final baseline = _NewPeriodSnapshot.capture(
    ref.read(subscriptionInfoProvider) ??
        ref.read(xboardUserProvider).subscriptionInfo,
  );
  _isStartingNewPeriod = true;
  try {
    final succeeded = await _NewPeriodConfirmDialog.show(
      context,
      onSubmit: () => _startNewPeriod(ref, l10n, baseline),
      onCheckResult: () => _checkNewPeriodResult(ref, baseline),
    );
    if (succeeded == true && context.mounted) {
      XBoardNotification.showSuccess(l10n.xboardNewPeriodSuccess);
    }
  } finally {
    _isStartingNewPeriod = false;
  }
}

Future<_NewPeriodAttemptResult> _startNewPeriod(
  WidgetRef ref,
  AppLocalizations l10n,
  _NewPeriodSnapshot before,
) async {
  try {
    await XBoardSDK.instance.httpService.postRequest(
        '/user/newPeriod', const {}).timeout(const Duration(seconds: 15));
    await ref
        .read(xboardUserProvider.notifier)
        .refreshSubscriptionInfo(importProfile: true);
    return const _NewPeriodAttemptResult.success();
  } catch (error) {
    if (!_isUncertainNewPeriodError(error)) {
      return _NewPeriodAttemptResult.failure(
        BackendMessageMapper.mapError(
          error,
          fallback: l10n.xboardNewPeriodFailed,
        ),
      );
    }

    // 超时或断线时后端可能已经执行成功，先核对订阅，禁止直接重复提交。
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final advanced = await _refreshAndDetectNewPeriod(ref, before);
    return advanced
        ? const _NewPeriodAttemptResult.success()
        : const _NewPeriodAttemptResult.uncertain();
  }
}

Future<_NewPeriodAttemptResult> _checkNewPeriodResult(
  WidgetRef ref,
  _NewPeriodSnapshot before,
) async {
  final advanced = await _refreshAndDetectNewPeriod(ref, before);
  return advanced
      ? const _NewPeriodAttemptResult.success()
      : const _NewPeriodAttemptResult.uncertain();
}

Future<bool> _refreshAndDetectNewPeriod(
  WidgetRef ref,
  _NewPeriodSnapshot before,
) async {
  await ref
      .read(xboardUserProvider.notifier)
      .refreshSubscriptionInfo(importProfile: true);
  final after = _NewPeriodSnapshot.capture(
    ref.read(subscriptionInfoProvider) ??
        ref.read(xboardUserProvider).subscriptionInfo,
  );
  return after.hasAdvancedFrom(before);
}

bool _isUncertainNewPeriodError(Object error) {
  if (error is TimeoutException || error is NetworkException) return true;
  final message = BackendMessageMapper.rawMessage(error).toLowerCase();
  return message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('connection reset') ||
      message.contains('connection closed') ||
      message.contains('broken pipe') ||
      message.contains('socket');
}

class _NewPeriodSnapshot {
  const _NewPeriodSnapshot({
    required this.totalUsedBytes,
    required this.expiredAt,
    required this.nextResetAt,
    required this.resetDay,
  });

  factory _NewPeriodSnapshot.capture(DomainSubscription? subscription) {
    return _NewPeriodSnapshot(
      totalUsedBytes: subscription?.totalUsedBytes,
      expiredAt: subscription?.expiredAt,
      nextResetAt: subscription?.nextResetAt,
      resetDay: subscription?.metadata['resetDay']?.toString(),
    );
  }

  final int? totalUsedBytes;
  final DateTime? expiredAt;
  final DateTime? nextResetAt;
  final String? resetDay;

  bool hasAdvancedFrom(_NewPeriodSnapshot before) {
    if (totalUsedBytes != null &&
        before.totalUsedBytes != null &&
        totalUsedBytes! < before.totalUsedBytes!) {
      return true;
    }
    return expiredAt != before.expiredAt ||
        nextResetAt != before.nextResetAt ||
        resetDay != before.resetDay;
  }
}

enum _NewPeriodAttemptStatus { success, uncertain, failure }

class _NewPeriodAttemptResult {
  const _NewPeriodAttemptResult._(this.status, [this.message]);

  const _NewPeriodAttemptResult.success()
      : this._(_NewPeriodAttemptStatus.success);
  const _NewPeriodAttemptResult.uncertain()
      : this._(_NewPeriodAttemptStatus.uncertain);
  const _NewPeriodAttemptResult.failure(String message)
      : this._(_NewPeriodAttemptStatus.failure, message);

  final _NewPeriodAttemptStatus status;
  final String? message;
}

class _NewPeriodConfirmDialog extends StatefulWidget {
  const _NewPeriodConfirmDialog({
    required this.onSubmit,
    required this.onCheckResult,
  });

  final Future<_NewPeriodAttemptResult> Function() onSubmit;
  final Future<_NewPeriodAttemptResult> Function() onCheckResult;

  static Future<bool?> show(
    BuildContext context, {
    required Future<_NewPeriodAttemptResult> Function() onSubmit,
    required Future<_NewPeriodAttemptResult> Function() onCheckResult,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NewPeriodConfirmDialog(
        onSubmit: onSubmit,
        onCheckResult: onCheckResult,
      ),
    );
  }

  @override
  State<_NewPeriodConfirmDialog> createState() =>
      _NewPeriodConfirmDialogState();
}

enum _NewPeriodDialogState { confirmation, submitting, uncertain, failure }

class _NewPeriodConfirmDialogState extends State<_NewPeriodConfirmDialog> {
  _NewPeriodDialogState _state = _NewPeriodDialogState.confirmation;
  String? _errorMessage;
  bool _checkingResult = false;

  bool get _isBusy => _state == _NewPeriodDialogState.submitting;

  Future<void> _run({required bool checkOnly}) async {
    if (_isBusy) return;
    setState(() {
      _state = _NewPeriodDialogState.submitting;
      _errorMessage = null;
      _checkingResult = checkOnly;
    });

    final result =
        await (checkOnly ? widget.onCheckResult() : widget.onSubmit());
    if (!mounted) return;
    switch (result.status) {
      case _NewPeriodAttemptStatus.success:
        Navigator.of(context).pop(true);
      case _NewPeriodAttemptStatus.uncertain:
        setState(() => _state = _NewPeriodDialogState.uncertain);
      case _NewPeriodAttemptStatus.failure:
        setState(() {
          _state = _NewPeriodDialogState.failure;
          _errorMessage = result.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final actionColor = XbUiStatusColor.pendingByTheme(theme);
    final isUncertain = _state == _NewPeriodDialogState.uncertain;
    final isFailure = _state == _NewPeriodDialogState.failure;
    return PopScope(
      canPop: !_isBusy,
      child: AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(context),
        icon: _isBusy
            ? Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: actionColor,
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isFailure ? theme.colorScheme.error : actionColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFailure
                      ? Icons.error_outline
                      : isUncertain
                          ? Icons.help_outline
                          : Icons.restart_alt,
                  color: isFailure ? theme.colorScheme.error : actionColor,
                  size: 32,
                ),
              ),
        title: Text(
          _isBusy
              ? (_checkingResult
                  ? l10n.xboardNewPeriodCheckingResult
                  : l10n.xboardNewPeriodStarting)
              : isUncertain
                  ? l10n.xboardNewPeriodResultUncertainTitle
                  : isFailure
                      ? l10n.xboardNewPeriodFailed
                      : l10n.xboardConfirmNewPeriod,
          style: XbUiText.sectionTitle(context).copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: Text(
          isUncertain
              ? l10n.xboardNewPeriodResultUncertainContent
              : isFailure
                  ? (_errorMessage ?? l10n.xboardNewPeriodFailed)
                  : l10n.xboardNewPeriodConfirmContent,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isFailure
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isBusy ? null : () => Navigator.of(context).pop(false),
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
                  onPressed:
                      _isBusy ? null : () => _run(checkOnly: isUncertain),
                  style: XbUiButton.filledPrimary(context).copyWith(
                    backgroundColor: WidgetStatePropertyAll(actionColor),
                  ),
                  child: Text(
                    _isBusy
                        ? (_checkingResult
                            ? l10n.xboardChecking
                            : l10n.xboardProcessing)
                        : isUncertain
                            ? l10n.xboardCheckStatus
                            : isFailure
                                ? l10n.xboardRetry
                                : l10n.confirm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
