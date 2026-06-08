import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import '../models/payment_step.dart';

// 初始化文件级日志器
final _logger = FileLogger('payment_waiting_overlay.dart');

class PaymentWaitingOverlay extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onPaymentSuccess;
  final String? tradeNo;
  final String? paymentUrl;
  const PaymentWaitingOverlay({
    super.key,
    this.onClose,
    this.onPaymentSuccess,
    this.tradeNo,
    this.paymentUrl,
  });
  @override
  ConsumerState<PaymentWaitingOverlay> createState() =>
      _PaymentWaitingOverlayState();
}

class _PaymentWaitingOverlayState extends ConsumerState<PaymentWaitingOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  PaymentStep _currentStep = PaymentStep.cancelingOrders;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _paymentCheckTimer;
  String? _currentTradeNo;
  @override
  void initState() {
    super.initState();
    _currentTradeNo = widget.tradeNo;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _pulseController.repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentCheckTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void updateStep(PaymentStep step) {
    if (mounted) {
      setState(() {
        _currentStep = step;
      });
      if (step == PaymentStep.waitingPayment && _currentTradeNo != null) {
        _startPaymentStatusCheck();
      }
    }
  }

  void updateTradeNo(String tradeNo) {
    if (mounted) {
      setState(() {
        _currentTradeNo = tradeNo;
      });
    }
  }

  void updatePaymentUrl(String paymentUrl) {
    if (mounted) {
      setState(() {});
    }
  }

  void _startPaymentStatusCheck() {
    _logger.info('[PaymentWaiting] 开始定时检测支付状态，订单号: $_currentTradeNo');
    _paymentCheckTimer?.cancel();

    // 立即执行一次检查
    _checkPaymentStatus();

    _paymentCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkPaymentStatus();
    });
  }

  bool _isCheckingPayment = false;
  bool _isManualCheck = false; // 仅手动点击时禁用按钮

  Future<void> _checkPaymentStatus({bool manual = false}) async {
    if (!mounted || _currentTradeNo == null) {
      _paymentCheckTimer?.cancel();
      return;
    }
    if (_isCheckingPayment) return;
    _isCheckingPayment = true;
    if (manual) {
      _isManualCheck = true;
      if (mounted) setState(() {});
    }

    try {
      _logger.info('[PaymentWaiting] ===== 开始检测支付状态 =====');
      _logger.info('[PaymentWaiting] 订单号: $_currentTradeNo');

      // 使用 SDK 检查订单状态
      final orderModels = await XBoardSDK.instance.order.getOrders();
      final orderData = orderModels.firstWhere(
        (o) => o.tradeNo == _currentTradeNo,
        orElse: () => const OrderModel(status: -1),
      );

      _logger.info('[PaymentWaiting] API 调用完成，订单状态: ${orderData.status}');

      if (orderData.status != -1) {
        // 检查订单状态
        // 状态值: 0=待付款, 1=开通中, 2=已取消, 3=已完成, 4=已折抵
        if (orderData.status == 3) {
          // 支付成功，立即执行成功回调
          _logger.info(
              '[PaymentWaiting] ===== 检测到支付成功！状态: ${orderData.status} =====');
          _paymentCheckTimer?.cancel();
          if (mounted) {
            setState(() {
              _currentStep = PaymentStep.paymentSuccess;
            });
            _pulseController.stop();

            // 立即执行成功回调
            if (widget.onPaymentSuccess != null) {
              widget.onPaymentSuccess?.call();
            }
          }
        } else if (orderData.status == 0 || orderData.status == 1) {
          // 仍在等待支付 (0: 待付款, 1: 开通中)
          _logger.info('[PaymentWaiting] 支付仍在等待中 (状态: ${orderData.status})...');
        } else {
          // 其他状态视为失败 (2: 已取消, 4: 已折抵)
          _logger.info('[PaymentWaiting] 支付视为失败/结束，状态: ${orderData.status}');
          _paymentCheckTimer?.cancel();
          if (mounted) {
            widget.onClose?.call();
          }
        }
      } else {
        _logger.info('[PaymentWaiting] 获取订单状态失败：订单不存在');
      }
    } catch (e) {
      _logger.info('[PaymentWaiting] 检测支付状态异常: $e');
    } finally {
      _isCheckingPayment = false;
      if (_isManualCheck) {
        _isManualCheck = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _confirmCancelOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(ctx),
        titlePadding: EdgeInsets.zero,
        title: Container(
          decoration: BoxDecoration(
            color: XbUiStatusColor.pending(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text('确认取消订单？',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: XbUiStatusColor.pending(ctx).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: XbUiStatusColor.pending(ctx),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '系统未检测到支付成功，继续取消将关闭本次订单。确定要继续吗？',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: XbUiButton.outlinedNeutral(ctx),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: XbUiButton.filledPrimary(ctx).copyWith(
              backgroundColor:
                  WidgetStatePropertyAll(XbUiStatusColor.pending(ctx)),
            ),
            child: const Text('继续取消'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentTradeNo != null && mounted) {
      try {
        await XBoardSDK.instance.order.cancelOrder(_currentTradeNo!);
        _logger.info('[PaymentWaiting] 订单已取消: $_currentTradeNo');
      } catch (e) {
        _logger.info('[PaymentWaiting] 取消订单失败: $e');
      } finally {
        widget.onClose?.call();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logger.info('[PaymentWaiting] 应用回到前台，立即检测支付状态');
      if (_currentStep == PaymentStep.waitingPayment &&
          _currentTradeNo != null) {
        _checkPaymentStatus();
      }
    }
  }

  String _getStepTitle(PaymentStep step) {
    switch (step) {
      case PaymentStep.cancelingOrders:
        return '清理旧订单';
      case PaymentStep.createOrder:
        return AppLocalizations.of(context).xboardCreatingOrder;
      case PaymentStep.loadingPayment:
        return AppLocalizations.of(context).xboardLoadingPaymentPage;
      case PaymentStep.verifyPayment:
        return AppLocalizations.of(context).xboardPaymentMethodVerified;
      case PaymentStep.waitingPayment:
        return AppLocalizations.of(context).xboardWaitingPaymentCompletion;
      case PaymentStep.paymentSuccess:
        return AppLocalizations.of(context).xboardPaymentSuccess;
    }
  }

  String _getStepDescription(PaymentStep step) {
    switch (step) {
      case PaymentStep.cancelingOrders:
        return '正在清理之前的待支付订单...';
      case PaymentStep.createOrder:
        return AppLocalizations.of(context).xboardCreatingOrderPleaseWait;
      case PaymentStep.loadingPayment:
        return AppLocalizations.of(context).xboardPreparingPaymentPage;
      case PaymentStep.verifyPayment:
        return AppLocalizations.of(context)
            .xboardPaymentMethodVerifiedPreparing;
      case PaymentStep.waitingPayment:
        return '支付页面已打开，支付链接已复制到剪贴板。如果没有自动跳转，请手动粘贴到浏览器打开。';
      case PaymentStep.paymentSuccess:
        return AppLocalizations.of(context)
            .xboardCongratulationsSubscriptionActivated;
    }
  }

  Color _getStepColor(PaymentStep step) {
    switch (step) {
      case PaymentStep.cancelingOrders:
        return XbUiStatusColor.muted(context);
      case PaymentStep.createOrder:
        return XbUiStatusColor.pending(context);
      case PaymentStep.loadingPayment:
        return XbUiStatusColor.processing(context);
      case PaymentStep.verifyPayment:
        return XbUiStatusColor.success(context);
      case PaymentStep.waitingPayment:
        return XbUiStatusColor.offset(context);
      case PaymentStep.paymentSuccess:
        return XbUiStatusColor.success(context);
    }
  }

  IconData _getStepIcon(PaymentStep step) {
    switch (step) {
      case PaymentStep.cancelingOrders:
        return Icons.clear_all;
      case PaymentStep.createOrder:
        return Icons.receipt_long;
      case PaymentStep.loadingPayment:
        return Icons.payment;
      case PaymentStep.verifyPayment:
        return Icons.verified_user;
      case PaymentStep.waitingPayment:
        return Icons.access_time;
      case PaymentStep.paymentSuccess:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _getStepColor(_currentStep)
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getStepColor(_currentStep),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getStepIcon(_currentStep),
                          size: 40,
                          color: _getStepColor(_currentStep),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  _getStepTitle(_currentStep),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _getStepDescription(_currentStep),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_currentStep == PaymentStep.paymentSuccess)
                  Icon(
                    Icons.check_circle,
                    size: 48,
                    color: XbUiStatusColor.success(context),
                  )
                else
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStepColor(_currentStep),
                      ),
                    ),
                  ),
              ],
            ),
            actions: () {
              if (_currentStep == PaymentStep.paymentSuccess &&
                  widget.onPaymentSuccess != null) {
                return [
                  ElevatedButton(
                    onPressed: widget.onPaymentSuccess,
                    style: XbUiButton.filledPrimary(context).copyWith(
                      backgroundColor: WidgetStatePropertyAll(
                          XbUiStatusColor.success(context)),
                    ),
                    child: Text(AppLocalizations.of(context).xboardConfirm),
                  ),
                ];
              } else if (_currentStep == PaymentStep.waitingPayment) {
                return [
                  OutlinedButton(
                    onPressed: () => _confirmCancelOrder(context),
                    style: XbUiButton.outlinedNeutral(context),
                    child: const Text('取消支付'),
                  ),
                  FilledButton(
                    onPressed: _isManualCheck
                        ? null
                        : () => _checkPaymentStatus(manual: true),
                    style: XbUiButton.filledPrimary(context),
                    child: const Text('我已支付'),
                  ),
                ];
              }
              return null;
            }(),
          ),
        ),
      ),
    );
  }
}

class PaymentWaitingManager {
  static OverlayEntry? _overlayEntry;
  static GlobalKey<_PaymentWaitingOverlayState>? _overlayKey;
  static VoidCallback? _onClose;
  static VoidCallback? _onPaymentSuccess;
  static void show(
    BuildContext context, {
    VoidCallback? onClose,
    VoidCallback? onPaymentSuccess,
    String? tradeNo,
  }) {
    _logger.debug('[PaymentWaitingManager.show] 准备显示支付等待弹窗');
    _logger.debug(
        '[PaymentWaitingManager.show] onClose 是否为 null: ${onClose == null}');
    _logger.debug(
        '[PaymentWaitingManager.show] onPaymentSuccess 是否为 null: ${onPaymentSuccess == null}');
    hide(); // 确保之前的overlay被清除
    _onClose = onClose;
    _onPaymentSuccess = onPaymentSuccess;
    _logger.debug(
        '[PaymentWaitingManager.show] 静态变量已设置，_onPaymentSuccess 是否为 null: ${_onPaymentSuccess == null}');
    _overlayKey = GlobalKey<_PaymentWaitingOverlayState>();
    _overlayEntry = OverlayEntry(
      builder: (context) => PaymentWaitingOverlay(
        key: _overlayKey,
        onClose: () {
          hide();
          _onClose?.call();
        },
        onPaymentSuccess: () {
          _logger.debug('[PaymentWaitingManager] 收到支付成功通知，准备处理');
          // 先保存回调，再隐藏弹窗（因为hide()会清空回调）
          final callback = _onPaymentSuccess;
          _logger.debug(
              '[PaymentWaitingManager] 保存的回调是否为 null: ${callback == null}');
          hide();
          _logger.debug('[PaymentWaitingManager] 弹窗已隐藏，准备调用外部回调');
          if (callback != null) {
            _logger.debug('[PaymentWaitingManager] 外部回调存在，开始调用');
            callback.call();
            _logger.debug('[PaymentWaitingManager] 外部回调调用完成');
          } else {
            _logger.debug('[PaymentWaitingManager] 警告：外部回调为 null');
          }
        },
        tradeNo: tradeNo,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  static void updateStep(PaymentStep step) {
    _overlayKey?.currentState?.updateStep(step);
  }

  static void updateTradeNo(String tradeNo) {
    _overlayKey?.currentState?.updateTradeNo(tradeNo);
  }

  static void updatePaymentUrl(String paymentUrl) {
    _overlayKey?.currentState?.updatePaymentUrl(paymentUrl);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayKey = null;
    _onClose = null;
    _onPaymentSuccess = null;
  }
}
