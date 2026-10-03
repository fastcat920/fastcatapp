part of '../pages/order_detail_page.dart';

class _OrderDetailContent extends StatelessWidget {
  final bool isPaymentCompleted;
  final String tradeNo;
  final OrderModel? order;
  final DomainPlan? widgetPlan;
  final String? widgetPeriod;
  final double? originalPrice;
  final double? finalPrice;
  final double? discountAmount;
  final double? balanceUsed;
  final AsyncValue<List<PaymentMethodModel>> methodsAsync;
  final List<DomainPaymentMethod> globalPaymentMethods;
  final List<DomainPlan> plans;
  final DomainSubscription? currentSubscription;
  final DomainUser? userInfo;
  final String? selectedMethodId;
  final bool isSubmitting;
  final bool isChecking;
  final bool isCanceling;
  final ValueChanged<_PaymentOption> onMethodSelected;
  final VoidCallback onPay;
  final VoidCallback onCheck;
  final VoidCallback onCancel;
  final Future<void> Function() onRefresh;

  const _OrderDetailContent({
    this.isPaymentCompleted = false,
    required this.tradeNo,
    required this.order,
    required this.widgetPlan,
    required this.widgetPeriod,
    required this.originalPrice,
    required this.finalPrice,
    required this.discountAmount,
    required this.balanceUsed,
    required this.methodsAsync,
    required this.globalPaymentMethods,
    required this.plans,
    required this.currentSubscription,
    required this.userInfo,
    required this.selectedMethodId,
    required this.isSubmitting,
    required this.isChecking,
    required this.isCanceling,
    required this.onMethodSelected,
    required this.onPay,
    required this.onCheck,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePlanId = order?.planId ?? widgetPlan?.id;
    final period = widgetPeriod ?? order?.period;
    final isPending = isOrderPendingForDisplay(
      order?.status,
      paymentCompleted: isPaymentCompleted,
    );
    final latestPlan = _findPlan(plans, effectivePlanId);
    final resolvedPlan = latestPlan ?? widgetPlan;
    final trafficFallback = currentSubscription?.planId == effectivePlanId
        ? currentSubscription?.formattedTotalTraffic
        : null;
    final pricing = OrderBill.resolve(
      order: order,
      plan: resolvedPlan,
      period: period,
      originalPrice: originalPrice,
      finalPrice: finalPrice,
      previewDiscountAmount: discountAmount,
      balanceUsed: balanceUsed,
      accountBalance: userInfo?.balanceInYuan,
    );
    final priceChanged = order != null &&
        finalPrice != null &&
        (pricing.orderAmount - finalPrice!).abs() >= 0.005;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final useSideNavigation =
            mediaSize.width > mediaSize.height || system.isTV;
        // 与订单列表、充值和套餐页面统一使用页面级边距；桌面端不再额外
        // 扩大左右留白，保证内容卡片与其他界面的边界对齐。
        const contentPadding = XbUiTokens.pagePadding;
        const columnGap = 12.0;
        final paymentOptions =
            _paymentOptions(methodsAsync.valueOrNull, globalPaymentMethods);
        final selectedPaymentOption = _findPaymentOption(
          paymentOptions,
          selectedMethodId,
        );
        final lockedPaymentId = order?.paymentId?.trim();
        final useLockedFee = pricing.lockedHandlingFee != null &&
            (lockedPaymentId == null ||
                selectedPaymentOption?.id == lockedPaymentId);
        final paymentFee = useLockedFee
            ? pricing.lockedHandlingFee!
            : (isPending && selectedPaymentOption != null
                ? selectedPaymentOption.feeFor(pricing.payableAmount)
                : 0.0);
        final leftColumn = Column(
          children: [
            _ProductInfoCard(
              tradeNo: tradeNo,
              order: order,
              plan: resolvedPlan,
              period: period,
              trafficFallback: trafficFallback,
            ),
            const SizedBox(height: 16),
            _OrderInfoCard(
              tradeNo: tradeNo,
              order: order,
              period: period,
              pricing: pricing,
              paymentFee: paymentFee,
              priceChanged: priceChanged,
              paymentCompleted: isPaymentCompleted,
            ),
          ],
        );
        final rightColumn = Column(
          children: [
            _OrderStatusCard(
              order: order,
              completedOverride: isPaymentCompleted,
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              if (pricing.needExternalPayment) ...[
                _PaymentMethodsSection(
                  methodsAsync: methodsAsync,
                  globalPaymentMethods: globalPaymentMethods,
                  selectedMethodId: selectedPaymentOption?.id,
                  onSelected: onMethodSelected,
                  onRetry: onRefresh,
                ),
                const SizedBox(height: 16),
              ],
              _ActionButtons(
                payButtonText: pricing.needExternalPayment
                    ? AppLocalizations.of(context).xboardPayNow
                    : AppLocalizations.of(context).xboardBalancePay,
                isSubmitting: isSubmitting,
                isChecking: isChecking,
                isCanceling: isCanceling,
                onPay: onPay,
                onCheck: onCheck,
                onCancel: onCancel,
              ),
            ],
          ],
        );

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: contentPadding,
            child: useSideNavigation
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leftColumn),
                      SizedBox(width: columnGap),
                      Expanded(child: rightColumn),
                    ],
                  )
                : Column(
                    children: [
                      leftColumn,
                      const SizedBox(height: 16),
                      rightColumn,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _PaymentMethodsSection extends StatelessWidget {
  final AsyncValue<List<PaymentMethodModel>> methodsAsync;
  final List<DomainPaymentMethod> globalPaymentMethods;
  final String? selectedMethodId;
  final ValueChanged<_PaymentOption> onSelected;
  final VoidCallback onRetry;

  const _PaymentMethodsSection({
    required this.methodsAsync,
    required this.globalPaymentMethods,
    required this.selectedMethodId,
    required this.onSelected,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final options =
        _paymentOptions(methodsAsync.valueOrNull, globalPaymentMethods);
    if (options.isNotEmpty ||
        (!methodsAsync.isLoading && !methodsAsync.hasError)) {
      return _PaymentMethodsCard(
        methods: options,
        selectedMethodId: selectedMethodId,
        onSelected: onSelected,
      );
    }
    return _InfoCard(
      title: AppLocalizations.of(context).xboardPaymentMethods,
      icon: Icons.payments_outlined,
      child: methodsAsync.isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : XbErrorState(
              message: methodsAsync.error, onRetry: onRetry, compact: true),
    );
  }
}

List<_PaymentOption> _globalPaymentOptions(
  List<DomainPaymentMethod> paymentMethods,
) {
  return paymentMethods.map(_PaymentOption.fromDomain).toList();
}

List<_PaymentOption> _paymentOptions(
  List<PaymentMethodModel>? orderMethods,
  List<DomainPaymentMethod> globalMethods,
) {
  final available = orderMethods
          ?.where((method) => method.isAvailable && method.id.trim().isNotEmpty)
          .map(_PaymentOption.fromSdk)
          .toList() ??
      const <_PaymentOption>[];
  return available.isNotEmpty
      ? available
      : _globalPaymentOptions(globalMethods);
}

_PaymentOption? _findPaymentOption(
  List<_PaymentOption> options,
  String? selectedMethodId,
) {
  final resolvedId = resolvePaymentMethodId(
      options.map((option) => option.id), selectedMethodId);
  for (final option in options) {
    if (option.id == resolvedId) return option;
  }
  return null;
}

class _ProductInfoCard extends StatelessWidget {
  final String tradeNo;
  final OrderModel? order;
  final DomainPlan? plan;
  final String? period;
  final String? trafficFallback;

  const _ProductInfoCard({
    required this.tradeNo,
    required this.order,
    required this.plan,
    required this.period,
    this.trafficFallback,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePeriod = period ?? order?.period;
    final planName = effectivePeriod == 'deposit'
        ? AppLocalizations.of(context).xboardRechargeBalance
        : (plan?.name ??
            order?.orderPlan?.name ??
            AppLocalizations.of(context).xboardProductInfo);
    final traffic = effectivePeriod == 'reset_price'
        ? (plan?.formattedTraffic ??
            trafficFallback ??
            (order?.orderPlan?.content != null
                ? AppLocalizations.of(context).xboardResetCurrentPlanTraffic
                : AppLocalizations.of(context).xboardCurrentPlanBased))
        : (plan?.formattedTraffic ??
            trafficFallback ??
            AppLocalizations.of(context).xboardPlanBased);

    final isDeposit = effectivePeriod == 'deposit';
    final children = <Widget>[
      _InfoRow(
          label: AppLocalizations.of(context).xboardPlanName, value: planName),
      const SizedBox(height: 12),
      _InfoRow(
          label: AppLocalizations.of(context).xboardPeriod,
          value: _formatPeriod(context, effectivePeriod)),
    ];
    if (!isDeposit) {
      children.addAll([
        const SizedBox(height: 12),
        _InfoRow(
            label: AppLocalizations.of(context).xboardTraffic, value: traffic),
      ]);
    }

    return _InfoCard(
      title: AppLocalizations.of(context).xboardProductInfo,
      icon: Icons.inventory_2_outlined,
      child: Column(children: children),
    );
  }
}

class _OrderInfoCard extends StatelessWidget {
  final String tradeNo;
  final OrderModel? order;
  final String? period;
  final OrderBill pricing;
  final double paymentFee;
  final bool priceChanged;
  final bool paymentCompleted;

  const _OrderInfoCard({
    required this.tradeNo,
    required this.order,
    required this.period,
    required this.pricing,
    required this.paymentFee,
    required this.priceChanged,
    required this.paymentCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final amountColor =
        isDark ? Colors.white : Theme.of(context).colorScheme.primary;
    final shouldShowBalance = pricing.balanceUsed > 0;
    final isDeposit = period == 'deposit' || order?.period == 'deposit';
    final l10n = AppLocalizations.of(context);

    return _InfoCard(
      title: l10n.xboardOrderInfo,
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _InfoRow(
            label: l10n.xboardOrderNumber,
            value: order?.tradeNo ?? tradeNo,
            valueFontSize: 11,
            valueWeight: FontWeight.w500,
            trailing: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: order?.tradeNo ?? tradeNo),
                  );
                  if (context.mounted) {
                    XBoardNotification.showSuccess(
                      l10n.copiedToClipboard,
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.copy,
                    size: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: l10n.xboardCreatedAt,
            value: order?.createdAt != null
                ? _formatDateTime(order!.createdAt!)
                : '-',
          ),
          if (priceChanged) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                Localizations.localeOf(context).languageCode == 'zh'
                    ? '订单价格已发生变化，请确认下方最终账单后再支付。'
                    : 'The order price changed. Review the final bill before paying.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            label: isDeposit
                ? l10n.xboardRechargeAmount
                : (Localizations.localeOf(context).languageCode == 'zh'
                    ? '套餐原价'
                    : 'Original package price'),
            value: '¥${pricing.packageAmount.toStringAsFixed(2)}',
            valueFontSize: 14,
            valueWeight: XbFontWeight.bold,
            valueColor: amountColor,
          ),
          if (!isDeposit && pricing.activityDiscount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: Localizations.localeOf(context).languageCode == 'zh'
                  ? '限时优惠'
                  : 'Limited-time offer',
              value: '-¥${pricing.activityDiscount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (!isDeposit && pricing.surplusAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: Localizations.localeOf(context).languageCode == 'zh'
                  ? '旧套餐抵扣'
                  : 'Previous package credit',
              value: '-¥${pricing.surplusAmount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (!isDeposit && pricing.couponDiscount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: Localizations.localeOf(context).languageCode == 'zh'
                  ? '优惠券优惠'
                  : 'Coupon discount',
              value: '-¥${pricing.couponDiscount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (!isDeposit && pricing.memberDiscount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: Localizations.localeOf(context).languageCode == 'zh'
                  ? '会员等级优惠'
                  : 'Member discount',
              value: '-¥${pricing.memberDiscount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (isDeposit && pricing.depositBonusAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardRechargeBonus,
              value: '+¥${pricing.depositBonusAmount.toStringAsFixed(2)}',
              valueWeight: XbFontWeight.bold,
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (isDeposit) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardCreditedAmount,
              value: pricing.depositCreditedAmount == null
                  ? '--'
                  : '¥${pricing.depositCreditedAmount!.toStringAsFixed(2)}',
              valueWeight: XbFontWeight.bold,
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (isDeposit && pricing.discountAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardDiscountAmount,
              value: '-¥${pricing.discountAmount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (isDeposit && pricing.surplusAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: isDeposit
                  ? l10n.xboardCommissionOffsetAmount
                  : l10n.xboardSurplusAmount,
              value: '-¥${pricing.surplusAmount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.muted(context),
            ),
          ],
          if (pricing.refundAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardRefundAmount,
              value: '+¥${pricing.refundAmount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.info(context),
            ),
          ],
          if (shouldShowBalance) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: isDeposit
                  ? l10n.xboardUseBalance
                  : (Localizations.localeOf(context).languageCode == 'zh'
                      ? '余额抵扣'
                      : 'Balance deduction'),
              value: '-¥${pricing.balanceUsed.toStringAsFixed(2)}',
              valueFontSize: 14,
              valueWeight: XbFontWeight.bold,
              valueColor: amountColor,
            ),
          ],
          if (paymentFee > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: Localizations.localeOf(context).languageCode == 'zh'
                  ? '支付手续费'
                  : 'Payment fee',
              value: '¥${paymentFee.toStringAsFixed(2)}',
            ),
          ],
          const SizedBox(height: 14),
          Divider(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                orderPaymentAmountLabel(
                  order?.status,
                  paymentCompleted: paymentCompleted,
                  chinese: Localizations.localeOf(context).languageCode == 'zh',
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Text(
                '¥${(pricing.payableAmount + paymentFee).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: amountColor,
                      fontWeight: XbFontWeight.heavy,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderStatusCard extends StatelessWidget {
  final OrderModel? order;
  final bool completedOverride;

  const _OrderStatusCard({
    required this.order,
    this.completedOverride = false,
  });

  @override
  Widget build(BuildContext context) {
    final backendStatus = order?.status;
    final isPendingBackendStatus = backendStatus == null ||
        backendStatus == OrderStatus.pending.code ||
        backendStatus == OrderStatus.processing.code;
    final effectiveStatus = completedOverride && isPendingBackendStatus
        ? OrderStatus.completed.code
        : backendStatus;
    final color = _statusColor(effectiveStatus, context);
    final icon = _statusIcon(effectiveStatus);

    return _InfoCard(
      title: AppLocalizations.of(context).xboardOrderStatus,
      icon: Icons.verified_outlined,
      child: Row(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(context, effectiveStatus),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: XbFontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusDescription(context, effectiveStatus),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  final List<_PaymentOption> methods;
  final String? selectedMethodId;
  final ValueChanged<_PaymentOption> onSelected;

  const _PaymentMethodsCard({
    required this.methods,
    required this.selectedMethodId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: AppLocalizations.of(context).xboardPaymentMethods,
      icon: Icons.payments_outlined,
      child: methods.isEmpty
          ? Text(
              AppLocalizations.of(context).xboardNoPaymentMethods,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          : Column(
              children: [
                for (var i = 0; i < methods.length; i++) ...[
                  _PaymentMethodTile(
                    method: methods[i],
                    selected: selectedMethodId == methods[i].id,
                    onTap: () => onSelected(methods[i]),
                  ),
                  if (i != methods.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final _PaymentOption method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withValues(alpha: 0.16);

    return TVFocusable(
      borderRadius: BorderRadius.circular(14),
      onPressed: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                _PaymentIcon(iconUrl: method.iconUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: XbFontWeight.bold,
                        ),
                      ),
                      if (method.feePercentage > 0 || method.fixedFee > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          _paymentFeeDescription(method),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentOption {
  final String id;
  final String name;
  final String? iconUrl;
  final double feePercentage;
  final double fixedFee;

  const _PaymentOption({
    required this.id,
    required this.name,
    this.iconUrl,
    this.feePercentage = 0,
    this.fixedFee = 0,
  });

  double feeFor(double amount) {
    final amountInCents = (amount * 100).round();
    final fixedFeeInCents = (fixedFee * 100).round();
    return ((amountInCents * feePercentage / 100) + fixedFeeInCents).round() /
        100;
  }

  factory _PaymentOption.fromSdk(PaymentMethodModel method) {
    return _PaymentOption(
      id: method.id,
      name: method.name,
      iconUrl: method.icon,
      feePercentage: method.handlingFeePercent ?? 0,
      fixedFee: amountFromCents(method.handlingFeeFixed),
    );
  }

  factory _PaymentOption.fromDomain(DomainPaymentMethod method) {
    return _PaymentOption(
      id: method.id.toString(),
      name: method.name,
      iconUrl: method.iconUrl,
      feePercentage: method.feePercentage,
    );
  }
}

String _paymentFeeDescription(_PaymentOption method) {
  final parts = <String>[];
  if (method.feePercentage > 0) {
    parts.add('${method.feePercentage.toStringAsFixed(1)}%');
  }
  if (method.fixedFee > 0) {
    parts.add('¥${method.fixedFee.toStringAsFixed(2)}');
  }
  return '手续费 ${parts.join(' + ')}';
}

class _PaymentIcon extends StatelessWidget {
  final String? iconUrl;

  const _PaymentIcon({this.iconUrl});

  @override
  Widget build(BuildContext context) {
    final icon = iconUrl;
    if (icon == null || icon.isEmpty) {
      return const Icon(Icons.payment, size: 30);
    }
    return CachedNetworkImage(
      imageUrl: icon,
      width: 34,
      height: 34,
      errorWidget: (context, url, error) => const Icon(Icons.payment, size: 30),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final String payButtonText;
  final bool isSubmitting;
  final bool isChecking;
  final bool isCanceling;
  final VoidCallback onPay;
  final VoidCallback onCheck;
  final VoidCallback onCancel;

  const _ActionButtons({
    this.payButtonText = '',
    required this.isSubmitting,
    required this.isChecking,
    required this.isCanceling,
    required this.onPay,
    required this.onCheck,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final effectivePayButtonText =
        payButtonText.isEmpty ? l10n.xboardPayNow : payButtonText;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isSubmitting ? null : onPay,
            icon: isSubmitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.credit_card, size: 20),
            label: Text(
                isSubmitting ? l10n.xboardSubmitting : effectivePayButtonText),
            style: XbUiButton.filledPrimary(
              context,
              busy: isSubmitting,
            ),
          ).withTvFocus(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isCanceling ? null : onCancel,
                icon: isCanceling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close, size: 19),
                label: Text(isCanceling
                    ? l10n.xboardCanceling
                    : l10n.xboardCancelOrder),
                style: XbUiButton.outlinedNeutral(context).copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                  foregroundColor:
                      WidgetStatePropertyAll(theme.colorScheme.onSurface),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ).withTvFocus(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isChecking ? null : onCheck,
                icon: isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 19),
                label: Text(isChecking
                    ? l10n.xboardChecking
                    : l10n.xboardCheckPaymentStatus),
                style: XbUiButton.outlinedNeutral(context).copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                  foregroundColor:
                      WidgetStatePropertyAll(theme.colorScheme.onSurface),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ).withTvFocus(),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.18)
              : XbUiTokens.cardBorderLight,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withAlpha(12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: XbFontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final double? valueFontSize;
  final FontWeight? valueWeight;
  final Color? valueColor;
  final Widget? trailing;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueFontSize,
    this.valueWeight,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: valueColor ??
                        theme.colorScheme.onSurface.withValues(alpha: 0.48),
                    fontSize: valueFontSize,
                    fontWeight: valueWeight ?? XbFontWeight.semibold,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}

DomainPlan? _findPlan(List<DomainPlan> plans, int? planId) {
  if (planId == null || planId <= 0) return null;
  try {
    return plans.firstWhere((plan) => plan.id == planId);
  } catch (_) {
    return null;
  }
}

String _formatPeriod(BuildContext context, String? period) {
  final l10n = AppLocalizations.of(context);
  final map = {
    'month_price': l10n.xboardMonthlyPayment,
    'quarter_price': l10n.xboardQuarterlyPayment,
    'half_year_price': l10n.xboardHalfYearlyPayment,
    'year_price': l10n.xboardYearlyPayment,
    'two_year_price': l10n.xboardTwoYearPayment,
    'three_year_price': l10n.xboardThreeYearPayment,
    'onetime_price': l10n.xboardOneTimePayment,
    'reset_price': l10n.xboardResetTraffic,
    'deposit': l10n.xboardRecharge,
  };
  return map[period] ?? period ?? l10n.xboardUnknownPeriod;
}

String _formatDateTime(DateTime date) =>
    '${date.year}/${date.month}/${date.day} '
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}:'
    '${date.second.toString().padLeft(2, '0')}';

Color _statusColor(int? status, BuildContext context) {
  switch (status) {
    case 0:
      return XbUiStatusColor.pending(context);
    case 1:
      return XbUiStatusColor.processing(context);
    case 2:
      return XbUiStatusColor.error(context);
    case 3:
      return XbUiStatusColor.success(context);
    case 4:
      return XbUiStatusColor.offset(context);
    default:
      return XbUiStatusColor.muted(context);
  }
}

IconData _statusIcon(int? status) {
  switch (status) {
    case 0:
      return Icons.schedule;
    case 1:
      return Icons.hourglass_bottom;
    case 2:
      return Icons.cancel_outlined;
    case 3:
      return Icons.check_circle_outline;
    case 4:
      return Icons.redeem;
    default:
      return Icons.help_outline;
  }
}

String _statusLabel(BuildContext context, int? status) {
  return _statusLabelWithL10n(AppLocalizations.of(context), status);
}

String _statusLabelWithL10n(AppLocalizations l10n, int? status) {
  switch (status) {
    case 0:
      return l10n.xboardOrderStatusPending;
    case 1:
      return l10n.xboardOrderStatusOpening;
    case 2:
      return l10n.xboardOrderStatusCancelled;
    case 3:
      return l10n.xboardOrderStatusCompleted;
    case 4:
      return l10n.xboardOrderStatusOffset;
    default:
      return l10n.xboardUnknownErrorRetry;
  }
}

String _statusDescription(BuildContext context, int? status) {
  final l10n = AppLocalizations.of(context);
  switch (status) {
    case 0:
      return l10n.xboardSelectPaymentMethod;
    case 1:
      return l10n.xboardPleaseWait;
    case 2:
      return l10n.xboardPaymentCancelled;
    case 3:
      return l10n.xboardPaymentCompleted;
    case 4:
      return l10n.xboardOrderStatusOffset;
    default:
      return l10n.xboardUnknownErrorRetry;
  }
}
