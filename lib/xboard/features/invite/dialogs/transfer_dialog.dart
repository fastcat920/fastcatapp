import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';

class TransferDialog extends ConsumerStatefulWidget {
  const TransferDialog({super.key});

  @override
  ConsumerState<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<TransferDialog> {
  final TextEditingController _amountController = TextEditingController();
  bool _isTransferring = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.read(inviteProvider);
    final double maxAmount = inviteState.availableCommission; // 已经是元，不需要再除以100
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      title: Text(
        appLocalizations.transferToWallet,
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
                : _isTransferring
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
                    appLocalizations.transferSuccess,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    key: const ValueKey('success-text'),
                  )
                : _isTransferring
                    ? Text(
                        appLocalizations.transferring,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        key: const ValueKey('loading-text'),
                      )
                    : Text(
                        appLocalizations.maxTransferable(
                            inviteState.availableCommission.toStringAsFixed(2)),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        key: const ValueKey('balance-text'),
                      ),
          ),
          const SizedBox(height: 16),
          if (!_isTransferring && !_isSuccess) ...[
            TVDeferredInput(
              borderRadius: BorderRadius.circular(12),
              builder:
                  (context, focusNode, readOnly, showCursor, beginEditing) =>
                      TextField(
                focusNode: focusNode,
                readOnly: readOnly,
                showCursor: showCursor,
                onTap: beginEditing,
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: appLocalizations.transferAmount,
                  hintText: appLocalizations.enterTransferAmount,
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
                  suffixText: '¥',
                  helperText: appLocalizations
                      .maxTransferable(maxAmount.toStringAsFixed(2)),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              appLocalizations.transferNote,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (!_isTransferring && !_isSuccess) ...[
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: XbUiButton.outlinedNeutral(context),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () => _performTransfer(maxAmount),
            style: XbUiButton.filledPrimary(context),
            child: Text(appLocalizations.confirmTransfer),
          ),
        ],
      ],
    );
  }

  Future<void> _performTransfer(double maxAmount) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      if (mounted) {
        XBoardNotification.showError(appLocalizations.enterTransferAmountError);
      }
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (mounted) {
        XBoardNotification.showError(appLocalizations.invalidTransferAmount);
      }
      return;
    }

    if (amount > maxAmount) {
      if (mounted) {
        XBoardNotification.showError(appLocalizations
            .transferAmountExceeded(maxAmount.toStringAsFixed(2)));
      }
      return;
    }

    setState(() {
      _isTransferring = true;
    });

    try {
      final result =
          await ref.read(inviteProvider.notifier).transferCommission(amount);

      if (mounted) {
        setState(() {
          _isTransferring = false;
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
                XBoardNotification.showSuccess(appLocalizations
                    .transferSuccessMsg(amount.toStringAsFixed(2)));
              }
            });
          }
        } else {
          XBoardNotification.showError(appLocalizations.transferFailed("划转失败"));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _isSuccess = false;
        });
        XBoardNotification.showError(
            appLocalizations.transferFailed(e.toString()));
      }
    }
  }
}
