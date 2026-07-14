import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'payment_webview_page.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import '../services/payment_status_poller.dart';

const _logger = FileLogger('order_detail_page.dart');

class OrderDetailPage extends ConsumerStatefulWidget {
  final String tradeNo;
  final DomainPlan? plan;
  final String? period;
  final double? originalPrice;
  final double? finalPrice;
  final double? discountAmount;
  final double? balanceUsed;
  final bool optimistic;

  const OrderDetailPage({
    super.key,
    required this.tradeNo,
    this.plan,
    this.period,
    this.originalPrice,
    this.finalPrice,
    this.discountAmount,
    this.balanceUsed,
    this.optimistic = false,
  });

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage>
    with WidgetsBindingObserver {
  String? _selectedMethodId;
  bool _isSubmitting = false;
  bool _isChecking = false;
  bool _isCanceling = false;
  bool _isHandlingPaymentSuccess = false;
  double? _couponPrice;
  double? _refundAmount;
  double? _surplusAmount;
  double? _depositAmount;
  double? _commissionBalance;
  double? _actualCommissionBalance;
  double? _depositBonusAmount;
  double? _depositCreditedAmount;
  DomainPlan? _resolvedOrderPlan;
  int? _resolvedOrderPlanId;
  int? _resolvingPlanId;
  late final PaymentStatusPoller _poller = PaymentStatusPoller(
    tradeNo: widget.tradeNo,
    ref: ref,
    onSuccess: _handlePaymentSuccess,
  );
  bool _isPaymentCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      ref.read(xboardPaymentProvider);
      // 先用缓存快速首屏，随后后台强刷订单级支付方式，避免后台开关变化滞后。
      unawaited(ref.read(xboardPaymentProvider.notifier).loadPaymentMethods());
      unawaited(_refreshPaymentMethodsInBackground());
      // 套餐列表与订单额外字段互不依赖，并行加载
      await Future.wait([
        ref.read(xboardSubscriptionProvider.notifier).refreshPlans(),
        _fetchOrderExtras(),
      ]);
    });
  }

  Future<void> _fetchOrderExtras() async {
    try {
      final httpService = XBoardSDK.instance.httpService;
      final result = await httpService.getRequest(
        '/user/order/detail?trade_no=${widget.tradeNo}',
      );
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          _couponPrice = (data['coupon_price'] as num?)?.toDouble();
          _refundAmount = (data['refund_amount'] as num?)?.toDouble();
          _surplusAmount = (data['surplus_amount'] as num?)?.toDouble();
          _depositAmount = (data['deposit_amount'] as num?)?.toDouble();
          _commissionBalance = (data['commission_balance'] as num?)?.toDouble();
          _actualCommissionBalance =
              (data['actual_commission_balance'] as num?)?.toDouble();
          _depositBonusAmount = (data['bounus'] as num?)?.toDouble();
          _depositCreditedAmount = (data['get_amount'] as num?)?.toDouble();
        });
      }
    } catch (_) {
      // 无额外数据，无需更新
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isPaymentCompleted) {
      _poller.checkNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orderAsync = ref.watch(getOrderProvider(widget.tradeNo));
    final methodsAsync =
        ref.watch(getOrderPaymentMethodsProvider(widget.tradeNo));
    final globalPaymentMethods =
        ref.watch(xboardAvailablePaymentMethodsProvider);
    final plans = ref.watch(xboardSubscriptionProvider);
    final currentSubscription = ref.watch(subscriptionInfoProvider);
    final userInfo = ref.watch(userInfoProvider);
    final fallbackPlan = widget.plan ?? _resolvedOrderPlan;

    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(title: Text(l10n.xboardOrderInfo)),
      body: orderAsync.when(
        loading: () => widget.optimistic && widget.plan != null
            ? _OrderDetailContent(
                isPaymentCompleted: _isPaymentCompleted,
                tradeNo: widget.tradeNo,
                order: null,
                widgetPlan: fallbackPlan,
                widgetPeriod: widget.period,
                originalPrice: widget.originalPrice,
                finalPrice: widget.finalPrice,
                discountAmount: widget.discountAmount,
                balanceUsed: widget.balanceUsed,
                couponPrice: _couponPrice,
                refundAmount: _refundAmount,
                surplusAmount: _surplusAmount,
                depositAmount: _depositAmount,
                commissionBalance: _commissionBalance,
                actualCommissionBalance: _actualCommissionBalance,
                depositBonusAmount: _depositBonusAmount,
                depositCreditedAmount: _depositCreditedAmount,
                methodsAsync: methodsAsync,
                globalPaymentMethods: globalPaymentMethods,
                plans: plans,
                currentSubscription: currentSubscription,
                userInfo: userInfo,
                selectedMethodId: _selectedMethodId,
                isSubmitting: _isSubmitting,
                isChecking: _isChecking,
                isCanceling: _isCanceling,
                onMethodSelected: (method) =>
                    setState(() => _selectedMethodId = method.id),
                onPay: _submitPayment,
                onCheck: _checkPaymentStatus,
                onCancel: _cancelOrder,
                onRefresh: _refreshPage,
              )
            : const Center(child: CircularProgressIndicator()),
        error: (error, _) => _OrderErrorView(
          message: BackendMessageMapper.mapError(error,
              context: BackendMessageContext.order),
          onRetry: _retryOrder,
        ),
        data: (order) {
          // Polling starts only after payment submission (see _submitPayment)
          if (order == null) {
            return _OrderErrorView(
              message: l10n.xboardOrderNotFound,
              onRetry: _retryOrder,
            );
          }
          final planId = order.planId ?? widget.plan?.id;
          final period = widget.period ?? order.period;
          _resolveOrderPlanIfNeeded(
            planId: planId,
            period: period,
            plans: plans,
          );
          final visiblePlan = _findPlan(plans, planId);
          final resolvedPlan = visiblePlan ?? fallbackPlan;
          if (_shouldWaitForPlanPrice(
            planId: planId,
            period: period,
            plan: resolvedPlan,
          )) {
            return const Center(child: CircularProgressIndicator());
          }
          return _OrderDetailContent(
            isPaymentCompleted: _isPaymentCompleted,
            tradeNo: widget.tradeNo,
            order: order,
            widgetPlan: fallbackPlan,
            widgetPeriod: widget.period,
            originalPrice: widget.originalPrice,
            finalPrice: widget.finalPrice,
            discountAmount: widget.discountAmount,
            balanceUsed: widget.balanceUsed,
            couponPrice: _couponPrice,
            refundAmount: _refundAmount,
            surplusAmount: _surplusAmount,
            depositAmount: _depositAmount,
            commissionBalance: _commissionBalance,
            actualCommissionBalance: _actualCommissionBalance,
            depositBonusAmount: _depositBonusAmount,
            depositCreditedAmount: _depositCreditedAmount,
            methodsAsync: methodsAsync,
            globalPaymentMethods: globalPaymentMethods,
            plans: plans,
            currentSubscription: currentSubscription,
            userInfo: userInfo,
            selectedMethodId: _selectedMethodId,
            isSubmitting: _isSubmitting,
            isChecking: _isChecking,
            isCanceling: _isCanceling,
            onMethodSelected: (method) =>
                setState(() => _selectedMethodId = method.id),
            onPay: _submitPayment,
            onCheck: _checkPaymentStatus,
            onCancel: _cancelOrder,
            onRefresh: _refreshPage,
          );
        },
      ),
    );
  }

  Future<void> _refreshPage() async {
    clearGetOrderCache(widget.tradeNo);
    clearGetOrderPaymentMethodsCache(widget.tradeNo);
    ref.invalidate(getOrderProvider(widget.tradeNo));
    ref.invalidate(getOrderPaymentMethodsProvider(widget.tradeNo));
    // 支付方式、套餐列表、订单、额外字段 互不依赖，全部并行
    await Future.wait([
      ref
          .read(xboardPaymentProvider.notifier)
          .loadPaymentMethods(forceRefresh: true),
      ref.read(xboardSubscriptionProvider.notifier).refreshPlans(),
      ref.read(getOrderProvider(widget.tradeNo).future),
      _fetchOrderExtras(),
    ]);
  }

  Future<void> _refreshPaymentMethodsInBackground() async {
    try {
      final freshMethods = await _loadFreshPaymentOptions();
      _clearUnavailableSelection(freshMethods);
    } catch (e) {
      _logger.warning('后台刷新支付方式失败: $e');
    }
  }

  void _retryOrder() {
    clearGetOrderCache(widget.tradeNo);
    ref.invalidate(getOrderProvider(widget.tradeNo));
  }

  // Polling handled by PaymentStatusPoller — see _poller field

  void _resolveOrderPlanIfNeeded({
    required int? planId,
    required String? period,
    required List<DomainPlan> plans,
  }) {
    if (planId == null || planId <= 0) return;
    if (widget.plan?.id == planId &&
        _priceForPeriod(widget.plan, period) != null) {
      return;
    }
    if (_resolvedOrderPlanId == planId || _resolvingPlanId == planId) return;
    final visiblePlan = _findPlan(plans, planId);
    if (_priceForPeriod(visiblePlan, period) != null) return;

    _resolvingPlanId = planId;
    Future<void>(() async {
      final plan = await ref
          .read(xboardSubscriptionProvider.notifier)
          .loadPlanById(planId);
      if (!mounted) return;
      setState(() {
        _resolvedOrderPlan = plan;
        _resolvedOrderPlanId = planId;
        _resolvingPlanId = null;
      });
    });
  }

  bool _shouldWaitForPlanPrice({
    required int? planId,
    required String? period,
    required DomainPlan? plan,
  }) {
    if (planId == null || planId <= 0) return false;
    if (period == null || period == 'deposit') return false;
    if (_priceForPeriod(plan, period) != null) return false;
    return _resolvedOrderPlanId != planId;
  }

  Future<void> _submitPayment() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      // 优先使用已缓存的支付方式，只在缓存为空时才拉取
      var methods = _globalPaymentOptions(
          ref.read(xboardAvailablePaymentMethodsProvider));
      if (methods.isEmpty) {
        methods = await _loadFreshPaymentOptions();
      }

      if (methods.isEmpty) {
        XBoardNotification.showError(l10n.xboardNoPaymentMethods);
        return;
      }

      final selectedMethodId = _selectedMethodId;
      String methodId;
      if (selectedMethodId == null) {
        methodId = methods.first.id;
        if (mounted) {
          setState(() => _selectedMethodId = methodId);
        }
      } else if (methods.any((method) => method.id == selectedMethodId)) {
        methodId = selectedMethodId;
      } else {
        _clearUnavailableSelection(methods);
        XBoardNotification.showError(l10n.xboardSelectPaymentMethod);
        return;
      }

      final paymentResult =
          await ref.read(xboardPaymentProvider.notifier).submitPayment(
                tradeNo: widget.tradeNo,
                method: methodId,
              );
      if (paymentResult == null) {
        throw Exception(l10n.xboardPaymentFailed);
      }

      final type = paymentResult['type'] as int? ?? 0;
      final data = paymentResult['data'];
      if (type == -2) {
        if (mounted) {
          XBoardNotification.showError(
              data?.toString() ?? l10n.xboardPaymentFailed);
        }
        return;
      }

      if (type == -1 && data == true) {
        await _handlePaymentSuccess();
        return;
      }

      // 支付已提交，启动轮询监控状态
      if (!_isPaymentCompleted) _poller.start();

      if (data is String && data.isNotEmpty) {
        if (!mounted) return;
        final success = await PaymentWebViewPage.open(
          context,
          paymentUrl: data,
          tradeNo: widget.tradeNo,
        );
        if (success == true && mounted) {
          await _handlePaymentSuccess();
        }
      }
    } catch (e, stackTrace) {
      _logger.error('提交支付失败: $e');
      _logger.error('提交支付失败堆栈: $stackTrace');
      if (mounted) {
        XBoardNotification.showError(BackendMessageMapper.mapError(e,
            context: BackendMessageContext.order));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<List<_PaymentOption>> _loadFreshPaymentOptions() async {
    try {
      final orderMethods = await _loadFreshOrderPaymentOptions();
      if (orderMethods.isNotEmpty) return orderMethods;
    } catch (e) {
      _logger.warning('刷新订单支付方式失败，改用全局支付方式兜底: $e');
    }

    await ref
        .read(xboardPaymentProvider.notifier)
        .loadPaymentMethods(forceRefresh: true);
    return _globalPaymentOptions(
        ref.read(xboardAvailablePaymentMethodsProvider));
  }

  Future<List<_PaymentOption>> _loadFreshOrderPaymentOptions() async {
    clearGetOrderPaymentMethodsCache(widget.tradeNo);
    ref.invalidate(getOrderPaymentMethodsProvider(widget.tradeNo));
    final orderMethods =
        await ref.read(getOrderPaymentMethodsProvider(widget.tradeNo).future);
    return orderMethods
        .where((m) => m.isAvailable)
        .map(_PaymentOption.fromSdk)
        .toList();
  }

  void _clearUnavailableSelection(List<_PaymentOption> freshMethods) {
    final selectedMethodId = _selectedMethodId;
    if (!mounted || selectedMethodId == null) return;
    final stillAvailable =
        freshMethods.any((method) => method.id == selectedMethodId);
    if (!stillAvailable) {
      setState(() => _selectedMethodId = null);
    }
  }

  Future<void> _cancelOrder() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await XBoardNotification.showConfirm(
      l10n.xboardCancelOrder,
      title: l10n.xboardCancelOrder,
    );
    if (!confirmed) return;

    setState(() => _isCanceling = true);
    try {
      await XBoardSDK.instance.order.cancelOrder(widget.tradeNo);
      clearGetOrderCache(widget.tradeNo);
      clearGetOrdersCache();
      ref.invalidate(getOrderProvider(widget.tradeNo));
      ref.invalidate(getOrdersProvider);
      XBoardNotification.showSuccess(l10n.xboardOrderStatusCancelled);
    } catch (e) {
      XBoardNotification.showError(
          '${l10n.xboardOperationFailed}: ${BackendMessageMapper.mapError(e, context: BackendMessageContext.order)}');
    } finally {
      if (mounted) {
        setState(() => _isCanceling = false);
      }
    }
  }

  Future<void> _checkPaymentStatus() async {
    setState(() => _isChecking = true);
    final l10n = AppLocalizations.of(context);
    try {
      clearGetOrderCache(widget.tradeNo);
      ref.invalidate(getOrderProvider(widget.tradeNo));
      final order = await ref.read(getOrderProvider(widget.tradeNo).future);
      if (order?.status == 3 || order?.status == 4) {
        await _handlePaymentSuccess();
      } else {
        XBoardNotification.showInfo(
          _statusLabelWithL10n(l10n, order?.status),
        );
      }
    } catch (e) {
      XBoardNotification.showError(
          '${l10n.xboardFailedToCheckPaymentStatus}: $e');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _handlePaymentSuccess() async {
    _poller.stop();
    if (_isHandlingPaymentSuccess) return;
    _isHandlingPaymentSuccess = true;
    try {
      if (mounted) setState(() => _isPaymentCompleted = true);
      final l10n = AppLocalizations.of(context);

      // 立即显示成功 toast 并返回，刷新操作放到后台异步执行
      clearGetOrderCache(widget.tradeNo);
      clearGetOrdersCache();
      ref.invalidate(getOrderProvider(widget.tradeNo));
      ref.invalidate(getOrdersProvider);
      XBoardNotification.showSuccess(l10n.xboardPaymentSuccess);

      // 后台异步刷新订阅信息，不阻塞 toast 和页面返回
      unawaited(_refreshSubscriptionInBackground());
    } finally {
      _isHandlingPaymentSuccess = false;
    }
  }

  Future<void> _refreshSubscriptionInBackground() async {
    try {
      await ref
          .read(xboardUserProvider.notifier)
          .refreshSubscriptionInfoAfterPayment();
    } catch (e) {
      _logger.warning('后台刷新订阅信息失败: $e');
    }
  }
}

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
  final double? couponPrice;
  final double? refundAmount;
  final double? surplusAmount;
  final double? depositAmount;
  final double? commissionBalance;
  final double? actualCommissionBalance;
  final double? depositBonusAmount;
  final double? depositCreditedAmount;
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
    required this.couponPrice,
    required this.refundAmount,
    required this.surplusAmount,
    required this.depositAmount,
    required this.commissionBalance,
    required this.actualCommissionBalance,
    required this.depositBonusAmount,
    required this.depositCreditedAmount,
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
    final isPending = order?.status != null ? order!.status == 0 : true;
    final latestPlan = _findPlan(plans, effectivePlanId);
    final resolvedPlan = latestPlan ?? widgetPlan;
    final trafficFallback = currentSubscription?.planId == effectivePlanId
        ? currentSubscription?.formattedTotalTraffic
        : null;
    final pricing = _OrderPricing.resolve(
      order: order,
      plan: resolvedPlan,
      period: period,
      originalPrice: originalPrice,
      finalPrice: finalPrice,
      discountAmount: discountAmount,
      balanceUsed: balanceUsed,
      orderBalanceAmount: order?.balanceAmount,
      accountBalance: userInfo?.balanceInYuan,
      couponPrice: couponPrice,
      refundAmount: refundAmount ?? order?.refundAmount,
      surplusAmount: surplusAmount ?? order?.surplusAmount,
      depositAmount: depositAmount ?? order?.depositAmount,
      commissionBalance: commissionBalance ?? order?.commissionBalance,
      actualCommissionBalance:
          actualCommissionBalance ?? order?.actualCommissionBalance,
      depositBonusAmount: depositBonusAmount,
      depositCreditedAmount: depositCreditedAmount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final contentPadding = EdgeInsets.symmetric(
          horizontal: isWide ? 32 : 16,
          vertical: 12,
        );
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
            ),
          ],
        );
        final rightColumn = Column(
          children: [
            _OrderStatusCard(order: order),
            if (isPending) ...[
              const SizedBox(height: 16),
              if (pricing.needExternalPayment) ...[
                _PaymentMethodsSection(
                  methodsAsync: methodsAsync,
                  globalPaymentMethods: globalPaymentMethods,
                  selectedMethodId: selectedMethodId,
                  onSelected: onMethodSelected,
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
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: leftColumn),
                          const SizedBox(width: 24),
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

  const _PaymentMethodsSection({
    required this.methodsAsync,
    required this.globalPaymentMethods,
    required this.selectedMethodId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return methodsAsync.when(
      loading: () {
        final fallbackMethods = _globalPaymentOptions(globalPaymentMethods);
        if (fallbackMethods.isNotEmpty) {
          return _PaymentMethodsCard(
            methods: fallbackMethods,
            selectedMethodId: selectedMethodId,
            onSelected: onSelected,
          );
        }
        return _InfoCard(
          title: AppLocalizations.of(context).xboardPaymentMethods,
          icon: Icons.payments_outlined,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
      error: (error, _) {
        final fallbackMethods = _globalPaymentOptions(globalPaymentMethods);
        if (fallbackMethods.isNotEmpty) {
          return _PaymentMethodsCard(
            methods: fallbackMethods,
            selectedMethodId: selectedMethodId,
            onSelected: onSelected,
          );
        }
        return _InfoCard(
          title: AppLocalizations.of(context).xboardPaymentMethods,
          icon: Icons.payments_outlined,
          child: _InlineError(
            message: BackendMessageMapper.mapError(error,
                context: BackendMessageContext.order),
            onRetry: () {},
          ),
        );
      },
      data: (methods) {
        final paymentOptions = methods
            .where((m) => m.isAvailable)
            .map(_PaymentOption.fromSdk)
            .toList();
        final fallbackMethods = _globalPaymentOptions(globalPaymentMethods);
        return _PaymentMethodsCard(
          methods: paymentOptions.isNotEmpty ? paymentOptions : fallbackMethods,
          selectedMethodId: selectedMethodId,
          onSelected: onSelected,
        );
      },
    );
  }
}

List<_PaymentOption> _globalPaymentOptions(
  List<DomainPaymentMethod> paymentMethods,
) {
  return paymentMethods.map(_PaymentOption.fromDomain).toList();
}

class _OrderPricing {
  final double packageAmount;
  final double discountAmount;
  final double refundAmount;
  final double surplusAmount;
  final double balanceUsed;
  final double payableAmount;
  final double depositBonusAmount;
  final double? depositCreditedAmount;
  final bool needExternalPayment;

  const _OrderPricing({
    required this.packageAmount,
    required this.discountAmount,
    required this.refundAmount,
    required this.surplusAmount,
    required this.balanceUsed,
    required this.payableAmount,
    required this.depositBonusAmount,
    required this.depositCreditedAmount,
    required this.needExternalPayment,
  });

  factory _OrderPricing.resolve({
    required OrderModel? order,
    required DomainPlan? plan,
    required String? period,
    required double? originalPrice,
    required double? finalPrice,
    required double? discountAmount,
    required double? balanceUsed,
    required double? orderBalanceAmount,
    required double? accountBalance,
    double? couponPrice,
    double? refundAmount,
    double? surplusAmount,
    double? depositAmount,
    double? commissionBalance,
    double? actualCommissionBalance,
    double? depositBonusAmount,
    double? depositCreditedAmount,
  }) {
    final isDeposit = period == 'deposit' || order?.period == 'deposit';
    final planPrice = _priceForPeriod(plan, period);
    final backendTotalAmount = _amountFromCents(order?.totalAmount);
    final backendBalanceAmount = _amountFromCents(orderBalanceAmount);
    final surplus = _amountFromCents(surplusAmount);
    final backendDepositAmount = _amountFromCents(depositAmount);
    final backendCommissionAmount =
        _amountFromCents(actualCommissionBalance ?? commissionBalance);

    // “套餐金额”优先取套餐价格口径（plan/resetPrice），
    // totalAmount 用于“订单实付/待支付”口径，不再重复扣减余额。
    final orderPackageFallback = backendTotalAmount + backendBalanceAmount;
    final depositPackageFallback = backendDepositAmount > 0
        ? backendDepositAmount
        : (orderPackageFallback + surplus > 0
            ? orderPackageFallback + surplus
            : backendCommissionAmount);
    final packageAmount = isDeposit
        ? (originalPrice ??
            (depositPackageFallback > 0 ? depositPackageFallback : 0.0))
        : (planPrice ??
            originalPrice ??
            (orderPackageFallback > 0 ? orderPackageFallback : 0.0));

    final computedBalance = order != null
        ? backendBalanceAmount
        : (balanceUsed != null && balanceUsed > 0
            ? balanceUsed
            : (accountBalance == null
                ? 0.0
                : (accountBalance > (finalPrice ?? packageAmount)
                    ? (finalPrice ?? packageAmount)
                    : accountBalance)));
    final payableAmount = order != null
        ? backendTotalAmount
        : ((finalPrice ?? packageAmount) - computedBalance)
            .clamp(0.0, double.infinity);

    final couponAmount = (couponPrice != null && couponPrice > 0)
        ? _amountFromCents(couponPrice)
        : null;
    final discount = couponAmount ?? discountAmount ?? 0;
    final refund = _amountFromCents(refundAmount);
    return _OrderPricing(
      packageAmount: packageAmount,
      discountAmount: discount,
      refundAmount: refund,
      surplusAmount: surplus,
      balanceUsed: computedBalance,
      payableAmount: payableAmount,
      depositBonusAmount: _amountFromCents(depositBonusAmount),
      depositCreditedAmount: depositCreditedAmount == null
          ? null
          : _amountFromCents(depositCreditedAmount),
      needExternalPayment: payableAmount > 0,
    );
  }
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
  final _OrderPricing pricing;

  const _OrderInfoCard({
    required this.tradeNo,
    required this.order,
    required this.period,
    required this.pricing,
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
          const SizedBox(height: 12),
          _InfoRow(
            label: isDeposit
                ? l10n.xboardRechargeAmount
                : l10n.xboardPackageAmount,
            value: '¥${pricing.packageAmount.toStringAsFixed(2)}',
            valueFontSize: 14,
            valueWeight: FontWeight.w700,
            valueColor: amountColor,
          ),
          if (isDeposit && pricing.depositBonusAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardRechargeBonus,
              value: '+¥${pricing.depositBonusAmount.toStringAsFixed(2)}',
              valueWeight: FontWeight.w700,
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (isDeposit && pricing.depositCreditedAmount != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardCreditedAmount,
              value: '¥${pricing.depositCreditedAmount!.toStringAsFixed(2)}',
              valueWeight: FontWeight.w700,
              valueColor: XbUiStatusColor.success(context),
            ),
          ],
          if (pricing.discountAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardDiscountAmount,
              value: '-¥${pricing.discountAmount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.success(context),
            ),
            if (order != null &&
                order!.couponCode != null &&
                order!.couponCode!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(
                label: '优惠码',
                value: order!.couponCode!,
                valueFontSize: 12,
              ),
            ],
          ],
          if (pricing.surplusAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: isDeposit
                  ? l10n.xboardCommissionOffsetAmount
                  : l10n.xboardSurplusAmount,
              value: '-¥${pricing.surplusAmount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.muted(context),
            ),
          ],
          if (shouldShowBalance) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardUseBalance,
              value: '-¥${pricing.balanceUsed.toStringAsFixed(2)}',
              valueFontSize: 14,
              valueWeight: FontWeight.w700,
              valueColor: amountColor,
            ),
          ],
          if (pricing.refundAmount > 0) ...[
            const SizedBox(height: 12),
            _InfoRow(
              label: l10n.xboardRefundAmount,
              value: '¥${pricing.refundAmount.toStringAsFixed(2)}',
              valueColor: XbUiStatusColor.info(context),
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
                AppLocalizations.of(context).xboardTotal,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Text(
                '¥${pricing.payableAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w800,
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

  const _OrderStatusCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order?.status, context);
    final icon = _statusIcon(order?.status);

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
                  _statusLabel(context, order?.status),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusDescription(context, order?.status),
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
                    selected: selectedMethodId == methods[i].id ||
                        (selectedMethodId == null && i == 0),
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

    return Material(
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (method.feePercentage > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '手续费 ${method.feePercentage.toStringAsFixed(1)}%',
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
    );
  }
}

class _PaymentOption {
  final String id;
  final String name;
  final String? iconUrl;
  final double feePercentage;

  const _PaymentOption({
    required this.id,
    required this.name,
    this.iconUrl,
    this.feePercentage = 0,
  });

  factory _PaymentOption.fromSdk(PaymentMethodModel method) {
    return _PaymentOption(
      id: method.id,
      name: method.name,
      iconUrl: method.icon,
      feePercentage: method.handlingFeePercent ?? 0,
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.credit_card, size: 20),
            label: Text(
                isSubmitting ? l10n.xboardSubmitting : effectivePayButtonText),
            style: XbUiButton.filledPrimary(context).copyWith(),
          ),
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
              ),
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
              ),
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
                  color: const Color(0xFF1565C0).withAlpha(12),
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
                  fontWeight: FontWeight.w800,
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
                    fontWeight: valueWeight ?? FontWeight.w600,
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

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).xboardRetry)),
      ],
    );
  }
}

class _OrderErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OrderErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).xboardOrderLoadingFailed,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).xboardRetry)),
          ],
        ),
      ),
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

double? _priceForPeriod(DomainPlan? plan, String? period) {
  if (plan == null) return null;
  switch (period) {
    case 'month_price':
      return plan.monthlyPrice;
    case 'quarter_price':
      return plan.quarterlyPrice;
    case 'half_year_price':
      return plan.halfYearlyPrice;
    case 'year_price':
      return plan.yearlyPrice;
    case 'two_year_price':
      return plan.twoYearPrice;
    case 'three_year_price':
      return plan.threeYearPrice;
    case 'onetime_price':
      return plan.onetimePrice;
    case 'reset_price':
      return plan.resetPrice;
  }
  return null;
}

double _amountFromCents(double? amount) => (amount ?? 0) / 100;

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
