import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart'
    show XBoardSDK, CatboardOrderPreview, CatboardCoupon, CatboardFlashSale;
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'order_detail_page.dart';
import '../widgets/plan_header_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/price_summary_card.dart';

// 初始化文件级日志器
final _logger = FileLogger('plan_purchase_page.dart');

/// 套餐购买页面
class PlanPurchasePage extends ConsumerStatefulWidget {
  final DomainPlan plan;
  final bool embedded; // 是否为嵌入模式（桌面端页面内切换时使用）
  final VoidCallback? onBack; // 返回回调
  final String? initialPeriod; // 初始选中的付款周期

  const PlanPurchasePage({
    super.key,
    required this.plan,
    this.embedded = false,
    this.onBack,
    this.initialPeriod,
  });

  @override
  ConsumerState<PlanPurchasePage> createState() => _PlanPurchasePageState();
}

class _PlanPurchasePageState extends ConsumerState<PlanPurchasePage> {
  bool _isRefreshing = false;
  late DomainPlan _plan;
  // 周期选择
  String? _selectedPeriod;

  CatboardOrderPreview? _orderPreview;
  bool _isPreviewLoading = false;
  int? _selectedUserCouponId;
  bool _disableAutoCoupon = false;
  bool _supportsOrderPreview = false;
  int _previewRequestId = 0;

  // 用户余额
  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    // 确保 PaymentProvider 被初始化，并后台预加载支付方式和待支付订单
    // 这样用户点击"提交订单"时 cancelPendingOrders 命中缓存，省去一次网络请求
    final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
    paymentNotifier.loadPaymentMethods();
    paymentNotifier.loadPendingOrders(updateUiState: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final periods = _getAvailablePeriods(context);
      if (periods.isNotEmpty && _selectedPeriod == null) {
        // 优先使用 initialPeriod
        final initial = widget.initialPeriod;
        final hasInitial =
            initial != null && periods.any((p) => p['period'] == initial);
        setState(() {
          _selectedPeriod = hasInitial ? initial : periods.first['period'];
        });
        _loadCommerceCapabilities();
      }
      _refreshPlan(showLoading: false);
    });
  }

  // ========== 数据加载 ==========

  List<Map<String, dynamic>> _getAvailablePeriods(BuildContext context) {
    final List<Map<String, dynamic>> periods = [];
    final plan = _plan;
    final l10n = AppLocalizations.of(context);

    if (plan.monthlyPrice != null) {
      periods.add({
        'period': 'month_price',
        'label': l10n.xboardMonthlyPayment,
        'price': _periodPrice('month_price', plan.monthlyPrice!),
        'description': l10n.xboardMonthlyRenewal,
      });
    }
    if (plan.quarterlyPrice != null) {
      periods.add({
        'period': 'quarter_price',
        'label': l10n.xboardQuarterlyPayment,
        'price': _periodPrice('quarter_price', plan.quarterlyPrice!),
        'description': l10n.xboardThreeMonthCycle,
      });
    }
    if (plan.halfYearlyPrice != null) {
      periods.add({
        'period': 'half_year_price',
        'label': l10n.xboardHalfYearlyPayment,
        'price': _periodPrice('half_year_price', plan.halfYearlyPrice!),
        'description': l10n.xboardSixMonthCycle,
      });
    }
    if (plan.yearlyPrice != null) {
      periods.add({
        'period': 'year_price',
        'label': l10n.xboardYearlyPayment,
        'price': _periodPrice('year_price', plan.yearlyPrice!),
        'description': l10n.xboardTwelveMonthCycle,
      });
    }
    if (plan.twoYearPrice != null) {
      periods.add({
        'period': 'two_year_price',
        'label': l10n.xboardTwoYearPayment,
        'price': _periodPrice('two_year_price', plan.twoYearPrice!),
        'description': l10n.xboardTwentyFourMonthCycle,
      });
    }
    if (plan.threeYearPrice != null) {
      periods.add({
        'period': 'three_year_price',
        'label': l10n.xboardThreeYearPayment,
        'price': _periodPrice('three_year_price', plan.threeYearPrice!),
        'description': l10n.xboardThirtySixMonthCycle,
      });
    }
    if (plan.onetimePrice != null) {
      periods.add({
        'period': 'onetime_price',
        'label': l10n.xboardOneTimePayment,
        'price': _periodPrice('onetime_price', plan.onetimePrice!),
        'description': l10n.xboardBuyoutPlan,
      });
    }
    if (widget.initialPeriod == 'reset_price' && plan.resetPrice != null) {
      periods.add({
        'period': 'reset_price',
        'label': '重置流量',
        'price': plan.resetPrice!,
        'description': '重置当前套餐流量',
      });
    }
    return periods;
  }

  double _periodPrice(String period, double fallback) {
    final sales = _plan.metadata['activeFlashSales'];
    if (sales is! Map || sales[period] is! Map) return fallback;
    final sale = CatboardFlashSale.fromJson(
      (sales[period] as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    return sale.finalAmount > 0 ? sale.finalAmount / 100 : fallback;
  }

  double _getCurrentPrice() {
    if (_selectedPeriod == null) return 0.0;
    final periods = _getAvailablePeriods(context);
    final selectedPeriod = periods.firstWhere(
      (period) => period['period'] == _selectedPeriod,
      orElse: () => {},
    );
    return selectedPeriod['price']?.toDouble() ?? 0.0;
  }

  double? _getBasePeriodPrice(String? period) => switch (period) {
        'month_price' => _plan.monthlyPrice,
        'quarter_price' => _plan.quarterlyPrice,
        'half_year_price' => _plan.halfYearlyPrice,
        'year_price' => _plan.yearlyPrice,
        'two_year_price' => _plan.twoYearPrice,
        'three_year_price' => _plan.threeYearPrice,
        'onetime_price' => _plan.onetimePrice,
        'reset_price' => _plan.resetPrice,
        _ => null,
      };

  Future<void> _loadCommerceCapabilities() async {
    try {
      final features = await XBoardSDK.instance.catboard.getFeatures();
      if (!mounted) return;
      setState(() => _supportsOrderPreview = features.orderPreview);
      if (features.orderPreview) {
        await _refreshOrderPreview();
      } else {
        _clearModernCommerceState();
      }
    } catch (error) {
      // 旧后端没有能力标记，按旧版下单协议处理，且不探测 preview 路由。
      _logger.info('未检测到新版订单预览能力，回退旧版下单流程: $error');
      if (mounted) {
        setState(() => _supportsOrderPreview = false);
        _clearModernCommerceState();
      }
    }
  }

  void _clearModernCommerceState() {
    if (!mounted) return;
    setState(() {
      _orderPreview = null;
      _selectedUserCouponId = null;
      _disableAutoCoupon = false;
      _isPreviewLoading = false;
    });
  }

  Future<void> _refreshOrderPreview() async {
    final period = _selectedPeriod;
    if (period == null || !_supportsOrderPreview) return;
    final requestId = ++_previewRequestId;
    if (mounted) setState(() => _isPreviewLoading = true);
    try {
      final preview = await XBoardSDK.instance.catboard.previewOrder(
        planId: _plan.id,
        period: period,
        userCouponId: _selectedUserCouponId,
        disableAutoCoupon: _disableAutoCoupon,
      );
      if (!mounted || requestId != _previewRequestId) return;
      setState(() {
        _orderPreview = preview;
        _selectedUserCouponId = preview.selectedCoupon?.id;
        if (!preview.allowCoupon) _disableAutoCoupon = true;
      });
    } catch (error) {
      if (!mounted || requestId != _previewRequestId) return;
      // 预览是增强能力，失败时保留基础价格与下单功能，不弹出订单错误。
      _logger.warning('订单预览失败，使用基础价格继续: $error');
      setState(() => _orderPreview = null);
    } finally {
      if (mounted && requestId == _previewRequestId) {
        setState(() => _isPreviewLoading = false);
      }
    }
  }

  // ========== 购买流程 ==========

  Future<void> _proceedToPurchase() async {
    if (_selectedPeriod == null) {
      XBoardNotification.showError(
          AppLocalizations.of(context).xboardPleaseSelectPaymentPeriod);
      return;
    }

    try {
      _logger.debug('[购买] 开始购买流程，套餐ID: ${_plan.id}, 周期: $_selectedPeriod');

      // 创建订单
      _logger.debug('[购买] 创建订单');

      final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
      final tradeNo = _supportsOrderPreview
          ? await paymentNotifier.createCatboardOrder(
              planId: _plan.id,
              period: _selectedPeriod!,
              userCouponId: _selectedUserCouponId,
              disableAutoCoupon: _disableAutoCoupon,
            )
          : await paymentNotifier.createOrder(
              planId: _plan.id,
              period: _selectedPeriod!,
              couponCode: '',
            );

      if (tradeNo == null) {
        final errorMessage = ref.read(paymentUIStateProvider).errorMessage;
        if (!mounted) return;
        throw Exception(errorMessage ??
            AppLocalizations.of(context).xboardOrderCreationFailed);
      }

      _logger.debug('[购买] 订单创建成功');

      // 计算订单金额
      final currentPrice = _orderPreview == null
          ? _getCurrentPrice()
          : _orderPreview!.originalAmount / 100;
      final displayFinalPrice = _orderPreview == null
          ? _getCurrentPrice()
          : _orderPreview!.finalAmount / 100;

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(
            tradeNo: tradeNo,
            plan: _plan,
            period: _selectedPeriod,
            originalPrice: currentPrice,
            finalPrice: displayFinalPrice,
            discountAmount: _orderPreview == null
                ? null
                : (_orderPreview!.originalAmount - _orderPreview!.finalAmount) /
                    100,
            balanceUsed: (_orderPreview?.balanceAmount ?? 0) / 100,
          ),
        ),
      );
    } catch (e) {
      _logger.error('购买流程出错: $e');
      if (mounted) {
        XBoardNotification.showError(
          '${AppLocalizations.of(context).xboardOperationFailed}: ${BackendMessageMapper.mapError(
            e,
            context: BackendMessageContext.order,
          )}',
        );
      }
    }
  }

  // ========== UI 构建 ==========

  Future<void> _refreshPage() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.read(xboardUserAuthProvider.notifier).refreshUserInfo(),
        _refreshPlan(showLoading: false),
      ]);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _refreshPlan({required bool showLoading}) async {
    if (showLoading && mounted) setState(() => _isRefreshing = true);
    try {
      final latest = await ref
          .read(xboardSubscriptionProvider.notifier)
          .refreshPlanById(_plan.id);
      if (latest != null && mounted) {
        setState(() => _plan = latest);
        await _refreshOrderPreview();
      }
    } catch (error) {
      _logger.warning('刷新套餐详情失败，继续使用当前快照: $error');
    } finally {
      if (showLoading && mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = _getAvailablePeriods(context);
    final currentPrice = _getCurrentPrice();
    // 用于判断平台类型
    final isPlatformDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: XbUiTokens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 套餐信息卡片
          PlanHeaderCard(plan: _plan),
          const SizedBox(height: 16),

          // 周期选择器
          PeriodSelector(
            periods: periods,
            selectedPeriod: _selectedPeriod,
            forceFourColumns:
                Platform.isLinux || Platform.isWindows || Platform.isMacOS,
            onPeriodSelected: (period) {
              setState(() {
                _selectedPeriod = period;
                _selectedUserCouponId = null;
                _disableAutoCoupon = false;
              });
              _refreshOrderPreview();
            },
          ),
          const SizedBox(height: 16),

          if (_supportsOrderPreview) ...[
            _buildCouponSelector(context),
            const SizedBox(height: 16),
          ],

          // 价格汇总
          if (_orderPreview != null)
            _buildServerPriceSummary(context, _orderPreview!)
          else if (_selectedPeriod != null)
            PriceSummaryCard(
              originalPrice: currentPrice,
              userBalance: ref.watch(userInfoProvider)?.balanceInYuan,
            ),
          const SizedBox(height: 16),

          // 提交订单按钮
          SizedBox(
            width: double.infinity,
            child: Consumer(
              builder: (context, ref, child) {
                final paymentState = ref.watch(paymentUIStateProvider);
                return FilledButton(
                  onPressed: paymentState.isLoading ? null : _proceedToPurchase,
                  style: XbUiButton.filledPrimary(
                    context,
                    busy: paymentState.isLoading,
                  ).copyWith(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  child: paymentState.isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context).xboardProcessing,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 20),
                            const SizedBox(width: 8),
                            Text(
                                AppLocalizations.of(context).xboardSubmitOrder),
                          ],
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    // 桌面端嵌入模式：只返回内容（外层已有 Scaffold）
    if (widget.embedded) {
      return content;
    }

    // 移动端全屏或独立页面：带 AppBar 的 Scaffold
    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFFAFBFD),
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(AppLocalizations.of(context).xboardPurchaseSubscription),
        actions: [
          if (isPlatformDesktop)
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isRefreshing ? null : _refreshPage,
              tooltip: AppLocalizations.of(context).refresh,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: content,
      ),
    );
  }

  String _copy(BuildContext context, String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  Widget _buildCouponSelector(BuildContext context) {
    final preview = _orderPreview;
    final selected = preview?.selectedCoupon;
    final couponDiscount = preview?.couponDiscount ?? 0;
    final String couponSubtitle;
    if (!(preview?.allowCoupon ?? true)) {
      couponSubtitle = _copy(context, '当前限时特价不可叠加优惠券',
          'Coupons are unavailable for this flash sale');
    } else if (selected != null) {
      couponSubtitle = _copy(
        context,
        '当前使用：${selected.template.name}，已优惠 ¥${(couponDiscount / 100).toStringAsFixed(2)}',
        'Using: ${selected.template.name}, saved ¥${(couponDiscount / 100).toStringAsFixed(2)}',
      );
    } else if (_disableAutoCoupon) {
      couponSubtitle = _copy(context, '不使用优惠券', 'No coupon selected');
    } else if (preview != null && preview.availableCoupons.isEmpty) {
      couponSubtitle = _copy(
          context, '当前订单暂无可用优惠券', 'No coupons are available for this order');
    } else {
      couponSubtitle =
          _copy(context, '系统自动选择最优优惠券', 'Best coupon selected automatically');
    }
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.confirmation_number_outlined),
        title: Text(_copy(context, '优惠券', 'Coupon')),
        subtitle: Text(couponSubtitle),
        trailing: _isPreviewLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        enabled: !_isPreviewLoading && (_orderPreview?.allowCoupon ?? true),
        onTap: () => _showCouponPicker(context),
      ),
    );
  }

  Future<void> _showCouponPicker(BuildContext context) async {
    final preview = _orderPreview;
    if (preview == null) return;
    final selection = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(_copy(context, '自动选择最优优惠券', 'Best available coupon')),
              trailing: !_disableAutoCoupon && _selectedUserCouponId == null
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(sheetContext, -2),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(_copy(context, '不使用优惠券', 'Do not use a coupon')),
              trailing: _disableAutoCoupon ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetContext, -1),
            ),
            ...preview.availableCoupons.map(
              (coupon) => _couponTile(sheetContext, coupon, enabled: true),
            ),
            if (preview.unavailableCoupons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  _copy(context, '当前订单不可用', 'Unavailable for this order'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ...preview.unavailableCoupons.map(
              (coupon) => _couponTile(sheetContext, coupon, enabled: false),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() {
      _disableAutoCoupon = selection == -1;
      _selectedUserCouponId = selection < 0 ? null : selection;
    });
    await _refreshOrderPreview();
  }

  Widget _couponTile(
    BuildContext context,
    CatboardCoupon coupon, {
    required bool enabled,
  }) {
    final template = coupon.template;
    final value = template.discountType == 'percent'
        ? '${template.discountValue}%'
        : '¥${(template.discountValue / 100).toStringAsFixed(2)}';
    return ListTile(
      enabled: enabled,
      leading: CircleAvatar(child: Text(value)),
      title: Text(template.name),
      subtitle: Text(enabled
          ? _copy(
              context,
              '本单优惠 ¥${(coupon.calculatedDiscount / 100).toStringAsFixed(2)}',
              'Save ¥${(coupon.calculatedDiscount / 100).toStringAsFixed(2)}',
            )
          : _couponUnavailableText(context, coupon.unavailableReason)),
      trailing:
          coupon.id == _selectedUserCouponId ? const Icon(Icons.check) : null,
      onTap: enabled ? () => Navigator.pop(context, coupon.id) : null,
    );
  }

  String _couponUnavailableText(BuildContext context, String? reason) {
    return switch (reason) {
      'template_disabled' => _copy(context, '优惠券已停用', 'Coupon is disabled'),
      'plan_not_supported' =>
        _copy(context, '不适用于当前套餐', 'Not valid for this plan'),
      'period_not_supported' =>
        _copy(context, '不适用于当前周期', 'Not valid for this period'),
      'first_order_only' => _copy(context, '仅限首单', 'First order only'),
      'renewal_not_supported' =>
        _copy(context, '不支持续费订单', 'Not valid for renewals'),
      _ => _copy(context, '当前订单不可用', 'Unavailable for this order'),
    };
  }

  Widget _buildServerPriceSummary(
    BuildContext context,
    CatboardOrderPreview preview,
  ) {
    final baseAmount =
        ((_getBasePeriodPrice(_selectedPeriod) ?? 0) * 100).round();
    final inferredSurplus = baseAmount > preview.originalAmount
        ? baseAmount - preview.originalAmount
        : 0;
    final surplusAmount =
        preview.surplusAmount > 0 ? preview.surplusAmount : inferredSurplus;
    final originalAmount = surplusAmount > 0 && baseAmount > 0
        ? baseAmount
        : preview.originalAmount;
    Widget row(
      String label,
      int amount, {
      bool discount = false,
      bool credit = false,
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(label),
              const Spacer(),
              Text(
                '${discount ? '-' : credit ? '+' : ''}¥${(amount / 100).toStringAsFixed(2)}',
                style: discount
                    ? TextStyle(color: Colors.green.shade700)
                    : credit
                        ? TextStyle(color: Colors.blue.shade700)
                        : null,
              ),
            ],
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row(_copy(context, '套餐原价', 'Original price'), originalAmount),
            if (preview.activityDiscount > 0)
              row(_copy(context, '限时优惠', 'Flash sale'),
                  preview.activityDiscount,
                  discount: true),
            if (surplusAmount > 0)
              row(_copy(context, '旧套餐抵扣', 'Previous plan credit'),
                  surplusAmount,
                  discount: true),
            if (preview.couponDiscount > 0)
              row(_copy(context, '优惠券', 'Coupon'), preview.couponDiscount,
                  discount: true),
            if (preview.vipDiscount > 0)
              row(_copy(context, '会员折扣', 'Member discount'),
                  preview.vipDiscount,
                  discount: true),
            if (preview.refundAmount > 0)
              row(_copy(context, '退回余额', 'Balance refund'),
                  preview.refundAmount,
                  credit: true),
            const Divider(),
            row(_copy(context, '订单金额', 'Order amount'), preview.finalAmount),
            if (preview.balanceAmount > 0)
              row(_copy(context, '余额抵扣', 'Balance deduction'),
                  preview.balanceAmount,
                  discount: true),
            const Divider(),
            row(_copy(context, '还需支付', 'Amount due'), preview.payableAmount),
          ],
        ),
      ),
    );
  }
}
