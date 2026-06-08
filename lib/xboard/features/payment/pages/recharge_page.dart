import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/payment_method_selector_dialog.dart';
import '../widgets/payment_waiting_overlay.dart';
import '../models/payment_step.dart';

/// 余额充值页面（仅 v2board 面板支持）
class RechargePage extends ConsumerStatefulWidget {
  const RechargePage({super.key});

  @override
  ConsumerState<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends ConsumerState<RechargePage> {
  final _amountController = TextEditingController();
  final _presetAmounts = [10, 50, 100, 200, 500, 1000];
  int? _selectedPreset;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // 预加载支付方式
    ref.read(xboardPaymentProvider);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _currentBalance {
    final user = ref.read(userInfoProvider);
    return user?.balanceInYuan ?? 0.0;
  }

  int? get _amountInCents {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<void> _handleRecharge() async {
    final l10n = AppLocalizations.of(context);
    final amountCents = _amountInCents;
    if (amountCents == null || amountCents <= 0) {
      XBoardNotification.showError(l10n.xboardEnterAmount);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final paymentNotifier = ref.read(xboardPaymentProvider.notifier);

      // 显示支付等待浮层
      if (mounted) {
        PaymentWaitingManager.show(
          context,
          onClose: () {
            if (mounted) Navigator.of(context).pop();
          },
          onPaymentSuccess: () {
            _refreshUserInfo();
            if (mounted) {
              XBoardNotification.showSuccess(l10n.xboardPaymentSuccess);
              Navigator.of(context).pop(true);
            }
          },
        );
        PaymentWaitingManager.updateStep(PaymentStep.createOrder);
      }

      // 1. 创建充值订单
      final tradeNo = await paymentNotifier.createDepositOrder(
        amountInCents: amountCents,
      );
      if (tradeNo == null || tradeNo.isEmpty) {
        PaymentWaitingManager.hide();
        XBoardNotification.showError(l10n.xboardOrderCreationFailed);
        return;
      }

      PaymentWaitingManager.updateTradeNo(tradeNo);

      // 2. 获取支付方式
      final paymentMethods = ref.read(xboardAvailablePaymentMethodsProvider);
      if (paymentMethods.isEmpty) {
        // 尝试重新加载
        await paymentNotifier.loadPaymentMethods();
        final retryMethods = ref.read(xboardAvailablePaymentMethodsProvider);
        if (retryMethods.isEmpty) {
          PaymentWaitingManager.hide();
          XBoardNotification.showError(l10n.xboardNoPaymentMethods);
          return;
        }
      }

      final methods = ref.read(xboardAvailablePaymentMethodsProvider);

      // 3. 选择支付方式（和买套餐一样的弹窗）
      DomainPaymentMethod? selectedMethod;
      if (methods.length == 1) {
        selectedMethod = methods.first;
      } else {
        PaymentWaitingManager.hide();
        if (!mounted) return;
        selectedMethod = await PaymentMethodSelectorDialog.show(
          context,
          paymentMethods: methods,
        );
        if (selectedMethod == null) return;
        if (mounted) {
          PaymentWaitingManager.show(
            context,
            onClose: () {
              if (mounted) Navigator.of(context).pop();
            },
            onPaymentSuccess: () {
              _refreshUserInfo();
              if (mounted) {
                XBoardNotification.showSuccess(l10n.xboardPaymentSuccess);
                Navigator.of(context).pop(true);
              }
            },
            tradeNo: tradeNo,
          );
        }
      }

      // 4. 提交支付
      PaymentWaitingManager.updateStep(PaymentStep.loadingPayment);
      final result = await paymentNotifier.submitPayment(
        tradeNo: tradeNo,
        method: selectedMethod.id.toString(),
      );
      if (result == null) {
        PaymentWaitingManager.hide();
        XBoardNotification.showError(l10n.xboardPaymentFailed);
        return;
      }

      final type = result['type'] as int? ?? 0;
      final paymentData = result['data'];

      if (type == -1) {
        // 余额支付成功
        PaymentWaitingManager.hide();
        XBoardNotification.showSuccess(l10n.xboardPaymentSuccess);
        _refreshUserInfo();
        if (mounted) Navigator.of(context).pop(true);
      } else if (paymentData != null &&
          paymentData is String &&
          paymentData.isNotEmpty) {
        // 跳转外部支付
        PaymentWaitingManager.updateStep(PaymentStep.waitingPayment);
        await Clipboard.setData(ClipboardData(text: paymentData));
        final uri = Uri.tryParse(paymentData);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        PaymentWaitingManager.hide();
        XBoardNotification.showError(l10n.xboardOpenPaymentLinkFailed);
      }
    } catch (e) {
      PaymentWaitingManager.hide();
      XBoardNotification.showError('${l10n.xboardPaymentFailed}: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _refreshUserInfo() {
    try {
      ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
    } catch (_) {}
  }

  Future<void> _refreshPage() async {
    _refreshUserInfo();
    await ref.read(xboardPaymentProvider.notifier).loadPaymentMethods();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final balance = _currentBalance;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前余额卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(
              alpha: isDark ? 0.24 : 0.12,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary
                  .withValues(alpha: isDark ? 0.38 : 0.28),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.32 : 0.18,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 14,
                      color: isDark
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.xboardCurrentBalance,
                    style: TextStyle(
                      color: isDark
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.78)
                          : theme.colorScheme.primary.withValues(alpha: 0.88),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '¥${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isDark
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.primary.withValues(alpha: 0.96),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 快捷金额
        Text(l10n.xboardSelectRechargeAmount,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final spacing = 12.0;
            final itemWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _presetAmounts.map((amount) {
                final selected = _selectedPreset == amount;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPreset = amount;
                      _amountController.text = amount.toString();
                    });
                  },
                  child: Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : (isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : (isDark
                                ? theme.colorScheme.outline
                                    .withValues(alpha: 0.3)
                                : const Color(0xFFEEF0F4)),
                      ),
                      boxShadow: isDark || selected
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Text(
                        '¥$amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        // 自定义金额输入
        Text(l10n.xboardCustomRechargeAmount,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TVDeferredInput(
          borderRadius: BorderRadius.circular(14),
          builder: (context, focusNode, readOnly, showCursor, beginEditing) =>
              TextField(
            focusNode: focusNode,
            readOnly: readOnly,
            showCursor: showCursor,
            onTap: beginEditing,
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '¥ ',
              hintText: l10n.xboardEnterAmount,
              filled: true,
              fillColor: isDark ? null : const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: isDark
                        ? theme.colorScheme.outline.withValues(alpha: 0.3)
                        : const Color(0xFFEEF0F4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            onChanged: (_) {
              setState(() => _selectedPreset = null);
            },
          ),
        ),
        const SizedBox(height: 32),
        // 充值按钮
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isProcessing ? null : _handleRecharge,
            style: XbUiButton.filledPrimary(context).copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
              backgroundColor: isDark
                  ? null
                  : WidgetStatePropertyAll(theme.colorScheme.primary),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(l10n.xboardRechargeNow,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
        // 提示文字
        Center(
          child: Text(
            l10n.xboardRechargeBalanceTip,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFFAFBFD),
      appBar: AppBar(
        title: Text(l10n.xboardRechargeBalance),
        leading: const BackButton(),
        actions: [
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS || system.isTV)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshPage,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: XbUiTokens.pagePadding,
          child: content,
        ),
      ),
    );
  }
}
