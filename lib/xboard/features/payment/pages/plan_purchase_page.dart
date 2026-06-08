import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart'
    show XBoardSDK, CouponModel;
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'order_detail_page.dart';
import '../widgets/plan_header_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/coupon_input_section.dart';
import '../widgets/price_summary_card.dart';
import '../utils/price_calculator.dart';

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
  // 周期选择
  String? _selectedPeriod;

  // 优惠券相关
  final _couponController = TextEditingController();
  bool _isCouponValidating = false;
  bool? _isCouponValid;
  String? _couponErrorMessage;
  String? _couponCode;
  int? _couponType;
  int? _couponValue;
  double? _discountAmount;
  double? _finalPrice;

  // 用户余额
  double? _userBalance;

  @override
  void initState() {
    super.initState();
    // 确保 PaymentProvider 被初始化，以便开始加载支付方式
    ref.read(xboardPaymentProvider);

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
      }
      _loadUserBalance();
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  // ========== 数据加载 ==========

  Future<void> _loadUserBalance() async {
    try {
      // 使用 xboardUserProvider 获取用户信息
      final userInfo = ref.read(xboardUserProvider).userInfo;

      if (mounted) {
        setState(() => _userBalance = userInfo?.balanceInYuan);
      }
    } catch (e) {
      _logger.debug('[购买] 加载用户余额失败: $e');
    }
  }

  List<Map<String, dynamic>> _getAvailablePeriods(BuildContext context) {
    final List<Map<String, dynamic>> periods = [];
    final plan = widget.plan;
    final l10n = AppLocalizations.of(context);

    if (plan.monthlyPrice != null) {
      periods.add({
        'period': 'month_price',
        'label': l10n.xboardMonthlyPayment,
        'price': plan.monthlyPrice!,
        'description': l10n.xboardMonthlyRenewal,
      });
    }
    if (plan.quarterlyPrice != null) {
      periods.add({
        'period': 'quarter_price',
        'label': l10n.xboardQuarterlyPayment,
        'price': plan.quarterlyPrice!,
        'description': l10n.xboardThreeMonthCycle,
      });
    }
    if (plan.halfYearlyPrice != null) {
      periods.add({
        'period': 'half_year_price',
        'label': l10n.xboardHalfYearlyPayment,
        'price': plan.halfYearlyPrice!,
        'description': l10n.xboardSixMonthCycle,
      });
    }
    if (plan.yearlyPrice != null) {
      periods.add({
        'period': 'year_price',
        'label': l10n.xboardYearlyPayment,
        'price': plan.yearlyPrice!,
        'description': l10n.xboardTwelveMonthCycle,
      });
    }
    if (plan.twoYearPrice != null) {
      periods.add({
        'period': 'two_year_price',
        'label': l10n.xboardTwoYearPayment,
        'price': plan.twoYearPrice!,
        'description': l10n.xboardTwentyFourMonthCycle,
      });
    }
    if (plan.threeYearPrice != null) {
      periods.add({
        'period': 'three_year_price',
        'label': l10n.xboardThreeYearPayment,
        'price': plan.threeYearPrice!,
        'description': l10n.xboardThirtySixMonthCycle,
      });
    }
    if (plan.onetimePrice != null) {
      periods.add({
        'period': 'onetime_price',
        'label': l10n.xboardOneTimePayment,
        'price': plan.onetimePrice!,
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

  double _getCurrentPrice() {
    if (_selectedPeriod == null) return 0.0;
    final periods = _getAvailablePeriods(context);
    final selectedPeriod = periods.firstWhere(
      (period) => period['period'] == _selectedPeriod,
      orElse: () => {},
    );
    return selectedPeriod['price']?.toDouble() ?? 0.0;
  }

  // ========== 优惠券验证 ==========

  Future<void> _validateCoupon() async {
    if (_couponController.text.trim().isEmpty) {
      _clearCoupon();
      return;
    }

    setState(() {
      _isCouponValidating = true;
      _isCouponValid = null;
      _couponErrorMessage = null;
    });

    try {
      final couponCode = _couponController.text.trim();
      // TODO: 将来添加到 PaymentRepository，目前保留使用 SDK
      final couponData = await XBoardSDK.instance.order.checkCoupon(
        _couponController.text.trim(),
        widget.plan.id,
      );

      if (couponData != null && mounted) {
        _applyCoupon(couponCode, couponData);
      } else if (mounted) {
        _setCouponInvalid();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCouponValid = false;
          _couponErrorMessage =
              '${AppLocalizations.of(context).xboardValidationFailed}: ${e.toString()}';
          _clearCouponData();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCouponValidating = false);
      }
    }
  }

  void _applyCoupon(String code, CouponModel couponData) {
    final currentPrice = _getCurrentPrice();
    final discountAmount = PriceCalculator.calculateDiscountAmount(
      currentPrice,
      couponData.type,
      couponData.value,
    );
    final finalPrice = currentPrice - discountAmount;

    setState(() {
      _isCouponValid = true;
      _couponCode = code;
      _couponType = couponData.type;
      _couponValue = couponData.value;
      _discountAmount = discountAmount;
      _finalPrice = finalPrice > 0 ? finalPrice : 0;
      _couponErrorMessage = null;
    });
  }

  void _setCouponInvalid() {
    setState(() {
      _isCouponValid = false;
      _couponErrorMessage =
          AppLocalizations.of(context).xboardInvalidOrExpiredCoupon;
      _clearCouponData();
    });
  }

  void _clearCoupon() {
    if (mounted) {
      setState(() {
        _isCouponValid = null;
        _couponErrorMessage = null;
        _clearCouponData();
      });
    }
  }

  void _clearCouponData() {
    _discountAmount = null;
    _finalPrice = null;
    _couponCode = null;
    _couponType = null;
    _couponValue = null;
  }

  void _recalculateDiscount() {
    if (_couponType == null || _couponValue == null) return;

    final currentPrice = _getCurrentPrice();
    final discountAmount = PriceCalculator.calculateDiscountAmount(
      currentPrice,
      _couponType,
      _couponValue,
    );

    setState(() {
      _discountAmount = discountAmount;
      _finalPrice = PriceCalculator.calculateFinalPrice(
        currentPrice,
        _couponType,
        _couponValue,
      );
    });
  }

  // ========== 购买流程 ==========

  Future<void> _proceedToPurchase() async {
    if (_selectedPeriod == null) {
      XBoardNotification.showError(
          AppLocalizations.of(context).xboardPleaseSelectPaymentPeriod);
      return;
    }

    try {
      _logger
          .debug('[购买] 开始购买流程，套餐ID: ${widget.plan.id}, 周期: $_selectedPeriod');

      // 创建订单
      _logger.debug('[购买] 创建订单');

      final paymentNotifier = ref.read(xboardPaymentProvider.notifier);
      final tradeNo = await paymentNotifier.createOrder(
        planId: widget.plan.id,
        period: _selectedPeriod!,
        couponCode: _couponCode,
      );

      if (tradeNo == null) {
        final errorMessage = ref.read(userUIStateProvider).errorMessage;
        if (!mounted) return;
        throw Exception(
            '${AppLocalizations.of(context).xboardOrderCreationFailed}: $errorMessage');
      }

      _logger.debug('[购买] 订单创建成功: $tradeNo');

      // 计算实付金额
      final currentPrice = _getCurrentPrice();
      final displayFinalPrice = _finalPrice ?? _getCurrentPrice();
      final balanceToUse = _userBalance != null && _userBalance! > 0
          ? (_userBalance! > displayFinalPrice
              ? displayFinalPrice
              : _userBalance!)
          : 0.0;
      final actualPayAmount = displayFinalPrice - balanceToUse;

      _logger.debug(
          '[购买] 实付金额: $actualPayAmount (优惠后价格: $displayFinalPrice, 已抵扣余额: $balanceToUse)');

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(
            tradeNo: tradeNo,
            plan: widget.plan,
            period: _selectedPeriod,
            originalPrice: currentPrice,
            finalPrice: displayFinalPrice,
            discountAmount: _discountAmount,
            balanceUsed: balanceToUse,
          ),
        ),
      );
    } catch (e) {
      _logger.error('购买流程出错: $e');
      if (mounted) {
        XBoardNotification.showError(
            '${AppLocalizations.of(context).xboardOperationFailed}: ${e.toString()}');
      }
    }
  }

  // ========== UI 构建 ==========

  @override
  Future<void> _refreshPage() async {
    // 刷新用户余额
    try {
      ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
    } catch (_) {}
    // 重新加载优惠券和套餐信息
    await _loadUserBalance();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = _getAvailablePeriods(context);
    final currentPrice = _getCurrentPrice();
    // 用于判断平台类型
    final isPlatformDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: XbUiTokens.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 套餐信息卡片
              PlanHeaderCard(plan: widget.plan),
              const SizedBox(height: 16),

              // 周期选择器
              PeriodSelector(
                periods: periods,
                selectedPeriod: _selectedPeriod,
                onPeriodSelected: (period) {
                  setState(() {
                    _selectedPeriod = period;
                    if (_couponCode != null) {
                      _recalculateDiscount();
                    }
                  });
                },
                couponType: _couponType,
                couponValue: _couponValue,
              ),
              const SizedBox(height: 16),

              // 优惠券输入
              CouponInputSection(
                controller: _couponController,
                isValidating: _isCouponValidating,
                isValid: _isCouponValid,
                errorMessage: _couponErrorMessage,
                discountAmount: _discountAmount,
                onValidate: _validateCoupon,
                onChanged: _clearCoupon,
              ),
              const SizedBox(height: 16),

              // 价格汇总
              if (_selectedPeriod != null)
                PriceSummaryCard(
                  originalPrice: currentPrice,
                  finalPrice: _finalPrice,
                  discountAmount: _discountAmount,
                  userBalance: _userBalance,
                ),
              const SizedBox(height: 16),

              // 提交订单按钮
              SizedBox(
                width: double.infinity,
                height: 54,
                child: Consumer(
                  builder: (context, ref, child) {
                    final paymentState = ref.watch(userUIStateProvider);
                    return ElevatedButton(
                      onPressed:
                          paymentState.isLoading ? null : _proceedToPurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isDark ? 14 : 16),
                        ),
                      ),
                      child: paymentState.isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  AppLocalizations.of(context).xboardProcessing,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            )
                          : Text(
                              AppLocalizations.of(context).submit,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
        title:
            Text(AppLocalizations.of(context).xboardPurchaseSubscription),
        actions: [
          if (isPlatformDesktop)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshPage,
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
}
