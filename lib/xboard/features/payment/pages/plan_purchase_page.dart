import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart'
    show
        XBoardSDK,
        CatboardOrderPreview,
        CatboardCoupon,
        CatboardFlashSale,
        CatboardPromotionOption;
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'order_detail_page.dart';
import '../widgets/plan_header_card.dart';
import '../widgets/period_selector.dart';

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
  Object? _previewError;
  int? _selectedUserCouponId;
  bool _disableAutoCoupon = false;
  String _promotionMode = 'auto';
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final periods = _getAvailablePeriods(context);
      if (periods.isNotEmpty && _selectedPeriod == null) {
        // 优先使用 initialPeriod
        final initial = widget.initialPeriod;
        final hasInitial =
            initial != null && periods.any((p) => p['period'] == initial);
        setState(() {
          _selectedPeriod = hasInitial ? initial : periods.first['period'];
          _isPreviewLoading = true;
          _previewError = null;
        });
        // 最新后端固定支持订单预览。套餐快照与价格并行刷新，且价格只请求一次。
        await Future.wait([
          _refreshPlan(showLoading: false),
          _refreshOrderPreview(),
        ]);
      }
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

  Future<void> _refreshOrderPreview() async {
    final period = _selectedPeriod;
    if (period == null) return;
    final requestId = ++_previewRequestId;
    if (mounted) {
      setState(() {
        _isPreviewLoading = true;
        _previewError = null;
      });
    }
    try {
      final preview = await XBoardSDK.instance.catboard.previewOrder(
        planId: _plan.id,
        period: period,
        userCouponId: _selectedUserCouponId,
        disableAutoCoupon: _disableAutoCoupon,
        promotionMode: _promotionMode,
      );
      if (!mounted || requestId != _previewRequestId) return;
      setState(() {
        _orderPreview = preview;
        _previewError = null;
        _selectedUserCouponId = preview.selectedCoupon?.id;
        // 互斥模式下 allow_coupon=false 表示不能与限时活动叠加，
        // 并不代表用户明确禁用优惠券；否则提交 auto 时会排除券方案。
        if (preview.promotionExclusive) {
          _disableAutoCoupon = false;
        } else if (!preview.allowCoupon) {
          _disableAutoCoupon = true;
        }
      });
    } catch (error) {
      if (!mounted || requestId != _previewRequestId) return;
      _logger.warning('订单预览失败: $error');
      setState(() {
        _orderPreview = null;
        _previewError = error;
      });
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
    final preview = _orderPreview;
    if (preview == null) {
      XBoardNotification.showError(
        _copy(context, '订单金额尚未加载，请重试',
            'Order pricing is not ready. Please retry.'),
      );
      return;
    }

    try {
      _logger.debug('[购买] 开始购买流程，套餐ID: ${_plan.id}, 周期: $_selectedPeriod');

      // 创建订单
      _logger.debug('[购买] 创建订单');

      final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
      final tradeNo = await paymentNotifier.createCatboardOrder(
        planId: _plan.id,
        period: _selectedPeriod!,
        userCouponId: _selectedUserCouponId,
        disableAutoCoupon: _disableAutoCoupon,
        promotionMode: _promotionMode,
      );

      if (tradeNo == null) {
        final errorMessage = ref.read(paymentUIStateProvider).errorMessage;
        if (!mounted) return;
        throw Exception(errorMessage ??
            AppLocalizations.of(context).xboardOrderCreationFailed);
      }

      _logger.debug('[购买] 订单创建成功');

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(
            tradeNo: tradeNo,
            plan: _plan,
            period: _selectedPeriod,
            originalPrice: preview.originalAmount / 100,
            finalPrice: preview.finalAmount / 100,
            discountAmount:
                (preview.originalAmount - preview.finalAmount) / 100,
            balanceUsed: preview.balanceAmount / 100,
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
        _refreshOrderPreview(),
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
                _orderPreview = null;
                _previewError = null;
                _isPreviewLoading = true;
                _selectedUserCouponId = null;
                _disableAutoCoupon = false;
                _promotionMode = 'auto';
              });
              _refreshOrderPreview();
            },
          ),
          const SizedBox(height: 16),

          if (_orderPreview != null) ...[
            _buildCouponSelector(context),
            const SizedBox(height: 16),
            _buildServerPriceSummary(context, _orderPreview!),
          ] else if (_previewError != null)
            _buildPreviewError(context)
          else if (_selectedPeriod != null)
            _buildPricingSkeleton(context),
          const SizedBox(height: 16),

          // 提交订单按钮
          SizedBox(
            width: double.infinity,
            child: Consumer(
              builder: (context, ref, child) {
                final paymentState = ref.watch(paymentUIStateProvider);
                return FilledButton(
                  onPressed: paymentState.isLoading ||
                          _isPreviewLoading ||
                          _orderPreview == null
                      ? null
                      : _proceedToPurchase,
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

  Widget _buildPricingSkeleton(BuildContext context) {
    final color = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.7);
    Widget line(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Semantics(
      liveRegion: true,
      label: _copy(context, '正在加载订单金额', 'Loading order pricing'),
      child: Column(
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line(92, 14),
                        const SizedBox(height: 8),
                        line(180, 11),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: index == 4 ? 0 : 14),
                    child: Row(
                      children: [
                        line(index == 4 ? 88 : 72, 12),
                        const Spacer(),
                        line(index == 4 ? 96 : 70, index == 4 ? 18 : 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewError(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: SizedBox(
          height: 240,
          child: XbErrorState(
            message: _previewError,
            compact: true,
            onRetry: _refreshOrderPreview,
          ),
        ),
      );

  Widget _buildCouponSelector(BuildContext context) {
    final preview = _orderPreview;
    if (preview?.promotionExclusive == true &&
        preview!.promotionOptions.isNotEmpty) {
      return _buildPromotionSelector(context, preview);
    }
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
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                _copy(context, '选择优惠券', 'Choose a coupon'),
                style: XbUiText.pageTitle(sheetContext),
              ),
              const SizedBox(height: 6),
              Text(
                _copy(
                  context,
                  '系统会优先推荐本单优惠金额最高的优惠券。',
                  'The coupon with the highest saving for this order is recommended first.',
                ),
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _couponPickerControl(
                sheetContext,
                icon: Icons.auto_awesome_outlined,
                title: _copy(
                  context,
                  '自动选择最优优惠券',
                  'Best available coupon',
                ),
                subtitle: _copy(
                  context,
                  '套餐或优惠变化时自动重新匹配',
                  'Re-evaluates when the package or offer changes',
                ),
                selected: !_disableAutoCoupon && _selectedUserCouponId == null,
                onTap: () => Navigator.pop(sheetContext, -2),
              ),
              const SizedBox(height: 8),
              _couponPickerControl(
                sheetContext,
                icon: Icons.block_outlined,
                title: _copy(context, '不使用优惠券', 'Do not use a coupon'),
                selected: _disableAutoCoupon,
                onTap: () => Navigator.pop(sheetContext, -1),
              ),
              if (preview.availableCoupons.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  _copy(context, '当前可用', 'Available now'),
                  style: XbUiText.sectionTitle(sheetContext),
                ),
                const SizedBox(height: 10),
                ...preview.availableCoupons.asMap().entries.map(
                      (entry) => _couponTile(
                        sheetContext,
                        entry.value,
                        enabled: true,
                        recommended: entry.key == 0,
                        selected: !_disableAutoCoupon &&
                            entry.value.id == _selectedUserCouponId,
                      ),
                    ),
              ],
              if (preview.unavailableCoupons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _copy(context, '当前订单不可用', 'Unavailable for this order'),
                  style: XbUiText.sectionTitle(sheetContext),
                ),
                const SizedBox(height: 10),
                ...preview.unavailableCoupons.map(
                  (coupon) => _couponTile(
                    sheetContext,
                    coupon,
                    enabled: false,
                    recommended: false,
                    selected: false,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() {
      _disableAutoCoupon = selection == -1;
      _selectedUserCouponId = selection < 0 ? null : selection;
      _promotionMode = selection >= 0 ? 'coupon' : 'auto';
    });
    await _refreshOrderPreview();
  }

  Widget _buildPromotionSelector(
    BuildContext context,
    CatboardOrderPreview preview,
  ) {
    final selected = preview.selectedPromotion;
    final subtitle = selected == null
        ? _copy(context, '系统正在比较最优优惠方案', 'Comparing the best promotion options')
        : '${_promotionName(context, selected)} · ${_copy(context, '实付', 'Final')} ¥${(selected.finalAmount / 100).toStringAsFixed(2)}';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.auto_awesome_outlined),
        title: Row(
          children: [
            Text(_copy(context, '优惠方案', 'Promotion option')),
            if (selected?.recommended == true) ...[
              const SizedBox(width: 8),
              _promotionRecommendedBadge(context),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: _isPreviewLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        enabled: !_isPreviewLoading,
        onTap: () => _showPromotionPicker(context, preview),
      ),
    );
  }

  Future<void> _showPromotionPicker(
    BuildContext context,
    CatboardOrderPreview preview,
  ) async {
    final selectedKey = preview.selectedPromotion?.key;
    final selection = await showModalBottomSheet<CatboardPromotionOption>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _copy(context, '选择优惠方案', 'Choose a promotion'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                _copy(
                  context,
                  '限时优惠、优惠券和会员折扣不可同时使用时，系统会推荐实付最低的方案。',
                  'When offers cannot be combined, the option with the lowest final price is recommended.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              ...preview.promotionOptions.map(
                (option) => _promotionOptionTile(
                  sheetContext,
                  option,
                  selected: option.key == selectedKey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() {
      _promotionMode = selection.type;
      _selectedUserCouponId =
          selection.type == 'coupon' ? selection.couponId : null;
      _disableAutoCoupon = false;
    });
    await _refreshOrderPreview();
  }

  Widget _promotionOptionTile(
    BuildContext context,
    CatboardPromotionOption option, {
    required bool selected,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, option),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.discountAmount > 0
                          ? '-¥${(option.discountAmount / 100).toStringAsFixed(2)}'
                          : _copy(context, '无优惠', 'No discount'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _copy(context, '已优惠', 'Saved'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _promotionName(context, option),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (option.recommended)
                          _promotionRecommendedBadge(context),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _promotionDescription(context, option),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_copy(context, '实付', 'Final')} ¥${(option.finalAmount / 100).toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _promotionRecommendedBadge(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _copy(context, '最优推荐', 'Best choice'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  String _promotionName(
    BuildContext context,
    CatboardPromotionOption option,
  ) {
    if (option.type == 'standard') {
      return option.memberDiscount > 0
          ? _copy(context, '会员等级优惠', 'Membership discount')
          : _copy(context, '标准价格', 'Standard price');
    }
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final preferred = zh ? option.name : option.nameEn;
    final fallback = zh ? option.nameEn : option.name;
    return preferred?.trim().isNotEmpty == true
        ? preferred!
        : fallback?.trim().isNotEmpty == true
            ? fallback!
            : option.type == 'coupon'
                ? _copy(context, '优惠券方案', 'Coupon option')
                : _copy(context, '限时优惠', 'Flash sale');
  }

  String _promotionDescription(
    BuildContext context,
    CatboardPromotionOption option,
  ) {
    if (option.type == 'standard') {
      return option.memberDiscount > 0
          ? _copy(context, '仅使用当前会员等级折扣',
              'Uses your current membership discount only')
          : _copy(context, '不使用限时优惠或优惠券', 'No flash sale or coupon applied');
    }
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final preferred = zh ? option.description : option.descriptionEn;
    final fallback = zh ? option.descriptionEn : option.description;
    return preferred?.trim().isNotEmpty == true
        ? preferred!
        : fallback?.trim().isNotEmpty == true
            ? fallback!
            : option.type == 'coupon'
                ? _copy(context, '使用此优惠券结算', 'Checkout with this coupon')
                : _copy(context, '使用当前限时优惠', 'Use the current flash sale');
  }

  Widget _couponTile(
    BuildContext context,
    CatboardCoupon coupon, {
    required bool enabled,
    required bool recommended,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final template = coupon.template;
    final value = template.discountType == 'percent'
        ? '${template.discountValue}%'
        : '¥${(template.discountValue / 100).toStringAsFixed(2)}';
    final description = _localizedCouponField(
      context,
      template.description,
      template.descriptionEn,
    );
    final title = _localizedCouponField(
      context,
      template.name,
      template.nameEn,
    );
    final primary = theme.colorScheme.primary;
    final foreground = theme.colorScheme.onPrimary;
    final borderColor = selected ? primary : XbUiTokens.cardBorder(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: enabled ? 1 : 0.58,
        child: Semantics(
          button: true,
          enabled: enabled,
          selected: selected,
          label: title,
          child: Material(
            color: selected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                : XbUiCardStyle.background(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XbUiTokens.radiusMd),
              side: BorderSide(
                color: borderColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? () => Navigator.pop(context, coupon.id) : null,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 88,
                      constraints: const BoxConstraints(minHeight: 104),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: enabled
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primary,
                                  primary.withValues(alpha: 0.72),
                                ],
                              )
                            : null,
                        color: enabled
                            ? null
                            : theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value,
                              maxLines: 1,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: enabled
                                    ? foreground
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: XbFontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            template.discountType == 'percent'
                                ? _copy(context, '折扣券', 'Discount')
                                : _copy(context, '金额券', 'Amount'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: enabled
                                  ? foreground.withValues(alpha: 0.86)
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: XbFontWeight.semibold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: XbFontWeight.semibold,
                                    ),
                                  ),
                                ),
                                if (recommended && enabled) ...[
                                  const SizedBox(width: 6),
                                  _promotionRecommendedBadge(context),
                                ],
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 7),
                            Text(
                              enabled
                                  ? _copy(
                                      context,
                                      '本单优惠 ¥${(coupon.calculatedDiscount / 100).toStringAsFixed(2)}',
                                      'Save ¥${(coupon.calculatedDiscount / 100).toStringAsFixed(2)}',
                                    )
                                  : _couponUnavailableText(
                                      context,
                                      coupon.unavailableReason,
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: enabled
                                    ? primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: XbFontWeight.semibold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: selected
                            ? Icon(
                                Icons.check_circle,
                                key: const ValueKey('selected'),
                                color: primary,
                                size: 22,
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('unselected'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _couponPickerControl(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.24)
            : XbUiCardStyle.background(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XbUiTokens.radiusMd),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : XbUiTokens.cardBorder(context),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: XbFontWeight.semibold,
                          ),
                        ),
                        if (subtitle?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedCouponField(
    BuildContext context,
    String? zh,
    String? en,
  ) {
    final useChinese =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
    final preferred = useChinese ? zh : en;
    final fallback = useChinese ? en : zh;
    if (preferred?.trim().isNotEmpty == true) return preferred!.trim();
    return fallback?.trim() ?? '';
  }

  String _couponUnavailableText(BuildContext context, String? reason) {
    return switch (reason) {
      'template_disabled' => _copy(context, '优惠券已停用', 'Coupon is disabled'),
      'plan_not_supported' =>
        _copy(context, '不适用于当前套餐', 'Not valid for this plan'),
      'period_not_supported' =>
        _copy(context, '不适用于当前周期', 'Not valid for this period'),
      'first_order_only' => _copy(context, '仅限首单', 'First order only'),
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
