import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'order_detail_page.dart';

String _preferPunctuationBreaks(String value) {
  return value.replaceAllMapped(
    RegExp(r'[，。！？；：、,.!?;:]'),
    (match) => '${match.group(0)}\u200B',
  );
}

/// 余额充值页面（仅 v2board 面板支持）
class RechargePage extends ConsumerStatefulWidget {
  const RechargePage({super.key});

  @override
  ConsumerState<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends ConsumerState<RechargePage> {
  final _amountController = TextEditingController();
  List<DepositBonusOption> _depositBonusOptions = const [];
  int? _selectedPresetAmountInCents;
  String _currencySymbol = '¥';
  bool _isLoadingDepositBonusOptions = true;
  bool _depositBonusOptionsLoadFailed = false;
  bool _isProcessing = false;
  bool _isAutoRenewalUpdating = false;
  bool _isRefreshingPage = false;

  @override
  void initState() {
    super.initState();
    // 先初始化支付 provider，再后台强刷可用支付方式，避免后台开关变化滞后。
    final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
    unawaited(
      paymentNotifier.loadPaymentMethods(forceRefresh: true),
    );
    unawaited(paymentNotifier.loadPendingOrders(updateUiState: false));
    unawaited(_loadDepositBonusOptions());
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

  Future<void> _loadDepositBonusOptions() async {
    if (mounted) {
      setState(() {
        _isLoadingDepositBonusOptions = true;
        _depositBonusOptionsLoadFailed = false;
      });
    }

    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final result = await sdk.httpService.getRequest('/user/comm/config');
      final rawData = result['data'];
      final data = rawData is Map
          ? rawData.map((key, value) => MapEntry(key.toString(), value))
          : const <String, dynamic>{};
      final options = <DepositBonusOption>[];
      final seenAmounts = <int>{};
      final rawOptions = data['deposit_bounus'];
      if (rawOptions is List) {
        for (final rawOption in rawOptions) {
          final option = DepositBonusOption.tryParse(rawOption);
          if (option == null || !seenAmounts.add(option.amountInCents)) {
            continue;
          }
          options.add(option);
        }
      }

      if (!mounted) return;
      final configuredCurrency = data['currency_symbol']?.toString().trim();
      setState(() {
        _depositBonusOptions = options;
        _currencySymbol =
            configuredCurrency?.isNotEmpty == true ? configuredCurrency! : '¥';
        _isLoadingDepositBonusOptions = false;
        _depositBonusOptionsLoadFailed = false;
        if (_selectedPresetAmountInCents != null &&
            !options.any((option) =>
                option.amountInCents == _selectedPresetAmountInCents)) {
          _selectedPresetAmountInCents = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _depositBonusOptions = const [];
        _selectedPresetAmountInCents = null;
        _isLoadingDepositBonusOptions = false;
        _depositBonusOptionsLoadFailed = true;
      });
    }
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
      final tradeNo = await paymentNotifier.createDepositOrder(
        amountInCents: amountCents,
      );
      if (tradeNo == null || tradeNo.isEmpty) {
        final errorMessage = ref.read(paymentUIStateProvider).errorMessage;
        if (!mounted) return;
        throw Exception(errorMessage ?? l10n.xboardOrderCreationFailed);
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(
            tradeNo: tradeNo,
            period: 'deposit',
            originalPrice: amountCents / 100,
            finalPrice: amountCents / 100,
            balanceUsed: 0,
          ),
        ),
      );
      if (mounted) {
        unawaited(_refreshUserInfo());
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError(
          '${l10n.xboardOperationFailed}: ${BackendMessageMapper.mapError(
            e,
            context: BackendMessageContext.order,
          )}',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _refreshUserInfo() async {
    try {
      await ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
    } catch (_) {}
  }

  Future<void> _refreshPage() async {
    if (_isRefreshingPage) return;
    setState(() => _isRefreshingPage = true);
    try {
      await Future.wait([
        _refreshUserInfo(),
        ref
            .read(xboardPaymentProvider.notifier)
            .loadPaymentMethods(forceRefresh: true),
        _loadDepositBonusOptions(),
      ]);
    } finally {
      if (mounted) setState(() => _isRefreshingPage = false);
    }
  }

  Future<void> _updateAutoRenewal(bool enabled) async {
    if (_isAutoRenewalUpdating) return;
    setState(() => _isAutoRenewalUpdating = true);
    final l10n = AppLocalizations.of(context);
    final success =
        await ref.read(xboardUserProvider.notifier).updateAutoRenewal(enabled);
    if (!mounted) return;
    setState(() => _isAutoRenewalUpdating = false);
    if (success) {
      XBoardNotification.showSuccess(
        enabled
            ? l10n.xboardAutoRenewalEnabled
            : l10n.xboardAutoRenewalDisabled,
      );
    } else {
      XBoardNotification.showError(l10n.xboardAutoRenewalUpdateFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final balanceContentColor = isDark
        ? theme.colorScheme.onSurface
        : theme.colorScheme.primary.withValues(alpha: 0.96);
    final mediaSize = MediaQuery.sizeOf(context);
    final useSideNavigation = mediaSize.width > mediaSize.height || system.isTV;
    final user = ref.watch(userInfoProvider);
    final balance = user?.balanceInYuan ?? _currentBalance;
    final hasPlan = user?.planId != null && user!.planId! > 0;
    final canChangeAutoRenewal = hasPlan || (user?.autoRenewal ?? false);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前余额卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rightWidth = constraints.maxWidth * 0.5;
              final description = _preferPunctuationBreaks(
                hasPlan
                    ? l10n.xboardAutoRenewalDescription
                    : l10n.xboardAutoRenewalNoPlan,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
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
                            Flexible(
                              child: Text(
                                l10n.xboardCurrentBalance,
                                style: TextStyle(
                                  color: isDark
                                      ? theme.colorScheme.onSurface
                                          .withValues(alpha: 0.78)
                                      : theme.colorScheme.primary
                                          .withValues(alpha: 0.88),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$_currencySymbol${balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isDark
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.primary
                                      .withValues(alpha: 0.96),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: rightWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                l10n.xboardAutoRenewal,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: balanceContentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                IgnorePointer(
                                  ignoring: _isAutoRenewalUpdating,
                                  child: Opacity(
                                    opacity: _isAutoRenewalUpdating ? 0.0 : 1.0,
                                    child: Switch(
                                      value: user?.autoRenewal ?? false,
                                      onChanged: canChangeAutoRenewal
                                          ? _updateAutoRenewal
                                          : null,
                                    ),
                                  ),
                                ),
                                if (_isAutoRenewalUpdating)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          textAlign: TextAlign.right,
                          softWrap: true,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: balanceContentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        // 快捷金额
        Text(l10n.xboardSelectRechargeAmount,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_isLoadingDepositBonusOptions)
          const SizedBox(
            height: 76,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_depositBonusOptionsLoadFailed)
          Center(
            child: TextButton.icon(
              onPressed: _loadDepositBonusOptions,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.xboardRetry),
            ),
          )
        else if (_depositBonusOptions.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final crossAxisCount = useSideNavigation ? 4 : 2;
              final itemWidth =
                  (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                      crossAxisCount;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _depositBonusOptions.map((option) {
                  final selected =
                      _selectedPresetAmountInCents == option.amountInCents;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPresetAmountInCents = option.amountInCents;
                        _amountController.text = option.amountInputText;
                      });
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
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
                                      : XbUiTokens.cardBorderLight),
                            ),
                            boxShadow: isDark || selected
                                ? null
                                : [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Text(
                              '$_currencySymbol${option.amountLabel}',
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
                        if (option.hasBonus)
                          Positioned(
                            top: -7,
                            right: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isDark
                                      ? theme.colorScheme.surface
                                      : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '+$_currencySymbol${option.bonusLabel}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
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
              prefixText: '$_currencySymbol ',
              hintText: l10n.xboardEnterAmount,
              filled: true,
              fillColor: isDark ? null : XbUiTokens.inputFillLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: isDark
                        ? theme.colorScheme.outline.withValues(alpha: 0.3)
                        : XbUiTokens.cardBorderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            onChanged: (_) {
              setState(() => _selectedPresetAmountInCents = null);
            },
          ),
        ),
        const SizedBox(height: 32),
        // 充值按钮
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isProcessing ? null : _handleRecharge,
            style: XbUiButton.filledPrimary(
              context,
              busy: _isProcessing,
            ).copyWith(
              backgroundColor: isDark
                  ? null
                  : WidgetStatePropertyAll(theme.colorScheme.primary),
            ),
            child: _isProcessing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 19),
                      const SizedBox(width: 8),
                      Text(
                        l10n.xboardRechargeNow,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
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
          if (Platform.isLinux ||
              Platform.isWindows ||
              Platform.isMacOS ||
              system.isTV)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: _isRefreshingPage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _isRefreshingPage ? null : _refreshPage,
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

class DepositBonusOption {
  final int amountInCents;
  final int bonusInCents;

  const DepositBonusOption({
    required this.amountInCents,
    required this.bonusInCents,
  });

  bool get hasBonus => bonusInCents > 0;
  String get amountLabel => _formatCents(amountInCents);
  String get bonusLabel => _formatCents(bonusInCents);
  String get amountInputText => _formatCents(amountInCents);

  static DepositBonusOption? tryParse(Object? raw) {
    final parts = raw?.toString().trim().split(':');
    if (parts == null || parts.length != 2) return null;
    final amount = double.tryParse(parts[0].trim());
    final bonus = double.tryParse(parts[1].trim());
    if (amount == null || bonus == null || amount <= 0 || bonus < 0) {
      return null;
    }
    return DepositBonusOption(
      amountInCents: (amount * 100).round(),
      bonusInCents: (bonus * 100).round(),
    );
  }

  static String _formatCents(int cents) {
    if (cents % 100 == 0) return (cents ~/ 100).toString();
    return (cents / 100).toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}
