import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';

class WithdrawDialog extends ConsumerStatefulWidget {
  const WithdrawDialog({super.key});

  @override
  ConsumerState<WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends ConsumerState<WithdrawDialog> {
  final TextEditingController _accountController = TextEditingController();
  bool _isWithdrawing = false;
  bool _isSuccess = false;

  String? _selectedMethod;

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.watch(inviteProvider);
    final double availableAmount =
        inviteState.availableCommission; // 已经是元，不需要再除以100
    final withdrawMethods = inviteState.withdrawMethods;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      title: Text(
        appLocalizations.withdrawCommission,
        style: XbUiText.sectionTitle(context),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSuccess
                ? const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Colors.green,
                    key: ValueKey('success'),
                  )
                : _isWithdrawing
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          key: ValueKey('loading'),
                        ),
                      )
                    : Icon(
                        Icons.account_balance_wallet,
                        size: 48,
                        color: theme.colorScheme.primary,
                        key: ValueKey('wallet'),
                      ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSuccess
                ? Text(
                    appLocalizations.withdrawRequestSubmitted,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    key: const ValueKey('success-text'),
                  )
                : _isWithdrawing
                    ? Text(
                        appLocalizations.xboardSubmitting,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        key: const ValueKey('loading-text'),
                      )
                    : Text(
                        appLocalizations.withdrawableAmount(
                            '¥${availableAmount.toStringAsFixed(2)}'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        key: const ValueKey('balance-text'),
                      ),
          ),
          const SizedBox(height: 16),
          if (!_isWithdrawing && !_isSuccess) ...[
            DropdownButtonFormField<String>(
              value: _selectedMethod,
              decoration: InputDecoration(
                labelText: appLocalizations.withdrawMethod,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? theme.colorScheme.outline
                        : const Color(0xFFEEF0F4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? theme.colorScheme.outline
                        : const Color(0xFFEEF0F4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                  ),
                ),
                filled: true,
                fillColor: isDark ? null : const Color(0xFFF5F7FA),
                prefixIcon: const Icon(Icons.payment),
              ),
              items: withdrawMethods.map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMethod = newValue;
                });
              },
              hint: Text(appLocalizations.pleaseSelectWithdrawMethod),
            ),
            const SizedBox(height: 12),
            TVDeferredInput(
              borderRadius: BorderRadius.circular(12),
              builder:
                  (context, focusNode, readOnly, showCursor, beginEditing) =>
                      TextField(
                focusNode: focusNode,
                readOnly: readOnly,
                showCursor: showCursor,
                onTap: beginEditing,
                controller: _accountController,
                decoration: InputDecoration(
                  labelText: appLocalizations.withdrawAccount,
                  hintText: appLocalizations.pleaseEnterWithdrawAccount,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? theme.colorScheme.outline
                          : const Color(0xFFEEF0F4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? theme.colorScheme.outline
                          : const Color(0xFFEEF0F4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? null : const Color(0xFFF5F7FA),
                  prefixIcon: const Icon(Icons.account_box),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              appLocalizations.withdrawSubmissionNote,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (!_isWithdrawing && !_isSuccess) ...[
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: XbUiButton.outlinedNeutral(context),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: _performWithdraw,
            style: XbUiButton.filledPrimary(context),
            child: Text(appLocalizations.submit),
          ),
        ],
      ],
    );
  }

  Future<void> _performWithdraw() async {
    if (_selectedMethod == null || _selectedMethod!.isEmpty) {
      if (mounted) {
        XBoardNotification.showError(
            appLocalizations.pleaseSelectWithdrawMethod);
      }
      return;
    }

    final account = _accountController.text.trim();
    if (account.isEmpty) {
      if (mounted) {
        XBoardNotification.showError(
            appLocalizations.pleaseEnterWithdrawAccount);
      }
      return;
    }

    setState(() {
      _isWithdrawing = true;
    });

    try {
      final result = await ref.read(inviteProvider.notifier).withdrawCommission(
            withdrawMethod: _selectedMethod!,
            withdrawAccount: account,
          );

      if (mounted) {
        setState(() {
          _isWithdrawing = false;
          _isSuccess = result;
        });

        if (result) {
          // 成功后显示动画，然后自动关闭
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            // 关闭后显示提示
            Future.microtask(() {
              if (mounted) {
                XBoardNotification.showSuccess(
                    appLocalizations.withdrawRequestSubmittedWaitReview);
              }
            });
          }
        } else {
          XBoardNotification.showError(
              appLocalizations.withdrawSubmissionFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWithdrawing = false;
          _isSuccess = false;
        });
        XBoardNotification.showError(
            appLocalizations.withdrawSubmissionFailedWithError(e.toString()));
      }
    }
  }
}
