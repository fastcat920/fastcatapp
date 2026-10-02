import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'payment_webview_page.dart';
import 'package:fl_clash/xboard/features/payment/models/order_bill.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import '../services/payment_status_poller.dart';

part '../widgets/order_detail_content.dart';

const _logger = FileLogger('order_detail_page.dart');

bool isOrderPendingForDisplay(
  int? statusCode, {
  required bool paymentCompleted,
}) {
  if (paymentCompleted) return false;
  return OrderStatus.fromCode(statusCode ?? 0) == OrderStatus.pending;
}

class OrderDetailPage extends ConsumerStatefulWidget {
  final String tradeNo;
  final DomainPlan? plan;
  final String? period;
  final double? originalPrice;
  final double? finalPrice;
  final double? discountAmount;
  final double? balanceUsed;
  final bool optimistic;
  final VoidCallback? onOrderChanged;
  final VoidCallback? onPaymentSuccess;

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
    this.onOrderChanged,
    this.onPaymentSuccess,
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
  DomainPlan? _resolvedOrderPlan;
  int? _resolvedOrderPlanId;
  int? _resolvingPlanId;
  late final PaymentStatusPoller _poller = PaymentStatusPoller(
    tradeNo: widget.tradeNo,
    ref: ref,
    onSuccess: _handlePaymentSuccess,
  );
  bool _isPaymentCompleted = false;
  bool _isPaymentFlowActive = false;
  bool _didNotifyOrderChanged = false;
  bool _didNotifyPaymentSuccess = false;

  void _notifyOrderChanged() {
    if (_didNotifyOrderChanged) return;
    _didNotifyOrderChanged = true;
    widget.onOrderChanged?.call();
  }

  void _notifyPaymentSuccess() {
    if (_didNotifyPaymentSuccess) return;
    _didNotifyPaymentSuccess = true;
    widget.onPaymentSuccess?.call();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      ref.read(xboardPaymentProvider);
      // 先用缓存快速首屏，随后后台强刷订单级支付方式，避免后台开关变化滞后。
      unawaited(ref.read(xboardPaymentProvider.notifier).loadPaymentMethods());
      unawaited(_refreshPaymentMethodsInBackground());
      await ref.read(xboardSubscriptionProvider.notifier).refreshPlans();
    });
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
    if (state == AppLifecycleState.resumed &&
        _isPaymentFlowActive &&
        !_isPaymentCompleted) {
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
        error: (error, _) => XbErrorState(
          message: error,
          onRetry: _retryOrder,
        ),
        data: (order) {
          // Polling starts only after payment submission (see _submitPayment)
          if (order == null) {
            return XbErrorState(
              message: l10n.xboardOrderNotFound,
              onRetry: _retryOrder,
            );
          }
          final planId = order.planId ?? widget.plan?.id;
          final period = widget.period ?? order.period;
          _restoreLockedPaymentMethod(order.paymentId);
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
            methodsAsync: methodsAsync,
            globalPaymentMethods: globalPaymentMethods,
            plans: plans,
            currentSubscription: currentSubscription,
            userInfo: userInfo,
            selectedMethodId: _selectedMethodId ?? order.paymentId,
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
    // 支付方式、套餐列表和订单互不依赖，全部并行刷新。
    await Future.wait([
      ref
          .read(xboardPaymentProvider.notifier)
          .loadPaymentMethods(forceRefresh: true),
      ref.read(xboardSubscriptionProvider.notifier).refreshPlans(),
      ref.read(getOrderProvider(widget.tradeNo).future),
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

  void _restoreLockedPaymentMethod(String? paymentId) {
    final methodId = paymentId?.trim();
    if (methodId == null || methodId.isEmpty || _selectedMethodId != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedMethodId != null) return;
      setState(() => _selectedMethodId = methodId);
    });
  }

  // Polling handled by PaymentStatusPoller — see _poller field

  void _resolveOrderPlanIfNeeded({
    required int? planId,
    required String? period,
    required List<DomainPlan> plans,
  }) {
    if (planId == null || planId <= 0) return;
    if (widget.plan?.id == planId &&
        priceForOrderPeriod(widget.plan, period) != null) {
      return;
    }
    if (_resolvedOrderPlanId == planId || _resolvingPlanId == planId) return;
    final visiblePlan = _findPlan(plans, planId);
    if (priceForOrderPeriod(visiblePlan, period) != null) return;

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
    if (priceForOrderPeriod(plan, period) != null) return false;
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

      final currentOrder =
          ref.read(getOrderProvider(widget.tradeNo)).valueOrNull;
      final needsExternalPayment =
          currentOrder == null || (currentOrder.totalAmount ?? 0) > 0;

      if (needsExternalPayment && methods.isEmpty) {
        XBoardNotification.showError(l10n.xboardNoPaymentMethods);
        return;
      }

      final selectedMethodId = _selectedMethodId;
      String methodId;
      if (!needsExternalPayment) {
        methodId =
            selectedMethodId ?? (methods.isNotEmpty ? methods.first.id : '');
      } else if (selectedMethodId == null) {
        XBoardNotification.showError(l10n.xboardSelectPaymentMethod);
        return;
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
        _isPaymentFlowActive = true;
        await _handlePaymentSuccess();
        return;
      }

      if (data is String && data.isNotEmpty) {
        _isPaymentFlowActive = true;
        if (!mounted) return;
        final success = await PaymentWebViewPage.open(
          context,
          paymentUrl: data,
          tradeNo: widget.tradeNo,
        );
        if (success == true && mounted) {
          await _handlePaymentSuccess();
        } else if (!_isPaymentCompleted) {
          // WebView 关闭后由订单页接管轮询，避免两个页面同时查询同一订单。
          _poller.start();
        }
      } else if (!_isPaymentCompleted) {
        _isPaymentFlowActive = true;
        _poller.start();
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
      _notifyOrderChanged();
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
      final status = OrderStatus.fromCode(order?.status ?? 0);
      if (status == OrderStatus.completed || status == OrderStatus.discounted) {
        if (_isPaymentFlowActive) {
          await _handlePaymentSuccess();
        } else {
          XBoardNotification.showInfo(
              _statusLabelWithL10n(l10n, order?.status));
        }
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
    if (!_isPaymentFlowActive) {
      return;
    }
    if (_isHandlingPaymentSuccess) return;
    _isHandlingPaymentSuccess = true;
    try {
      if (mounted) setState(() => _isPaymentCompleted = true);
      _isPaymentFlowActive = false;
      final l10n = AppLocalizations.of(context);

      // 立即显示成功 toast 并返回，刷新操作放到后台异步执行
      clearGetOrderCache(widget.tradeNo);
      clearGetOrdersCache();
      ref.invalidate(getOrderProvider(widget.tradeNo));
      ref.invalidate(getOrdersProvider);
      ref
          .read(xboardPaymentProvider.notifier)
          .markOrderCompletedLocally(widget.tradeNo);
      _notifyOrderChanged();
      _notifyPaymentSuccess();
      XBoardNotification.showSuccess(l10n.xboardPaymentSuccess);

      // 余额支付成功和订单接口的最终状态可能有短暂延迟。
      // 页面先乐观更新，后台再确认订单并刷新订阅。
      unawaited(_synchronizeCompletedOrder());
    } finally {
      _isHandlingPaymentSuccess = false;
    }
  }

  Future<void> _synchronizeCompletedOrder() async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 400),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ];
    for (final delay in delays) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!mounted) return;
      try {
        clearGetOrderCache(widget.tradeNo);
        ref.invalidate(getOrderProvider(widget.tradeNo));
        final order = await ref.read(getOrderProvider(widget.tradeNo).future);
        final status = OrderStatus.fromCode(order?.status ?? 0);
        if (status == OrderStatus.completed ||
            status == OrderStatus.discounted) {
          clearGetOrdersCache();
          ref.invalidate(getOrdersProvider);
          break;
        }
      } catch (e) {
        _logger.warning('支付成功后同步订单状态失败: $e');
      }
    }
    if (mounted) await _refreshSubscriptionInBackground();
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
