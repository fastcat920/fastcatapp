import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

class PaymentGatewayPage extends ConsumerStatefulWidget {
  final String paymentUrl;
  final String tradeNo;
  const PaymentGatewayPage({
    super.key,
    required this.paymentUrl,
    required this.tradeNo,
  });
  @override
  ConsumerState<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends ConsumerState<PaymentGatewayPage> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCheckingPayment = false;
  bool _autoPollingEnabled = false;
  @override
  void initState() {
    super.initState();
    _openPaymentUrl();
    _startPaymentStatusCheck();
  }

  @override
  void dispose() {
    _stopAutoPolling();
    super.dispose();
  }

  Future<void> _openPaymentUrl() async {
    try {
      setState(() {
        _isLoading = false;
      });
      await _launchPaymentUrl(isAutomatic: true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _launchPaymentUrl({bool isAutomatic = false}) async {
    final l10n = AppLocalizations.of(context);
    try {
      final uri = Uri.parse(widget.paymentUrl);
      if (!await canLaunchUrl(uri)) {
        throw Exception(
            '${l10n.xboardOpenPaymentLinkFailed}: ${widget.paymentUrl}');
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // 强制在外部浏览器打开
      );
      if (!launched) {
        throw Exception(l10n.xboardOpenPaymentLinkFailed);
      }
      if (mounted) {
        XBoardNotification.showInfo(isAutomatic
            ? l10n.xboardAutoOpeningPaymentPage
            : l10n.xboardPaymentPageOpenedInBrowser);
        _startAutoPolling();
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError('${l10n.xboardOpenPaymentLinkFailed}: $e');
      }
    }
  }

  Future<void> _copyPaymentUrl() async {
    final l10n = AppLocalizations.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: widget.paymentUrl));
      if (mounted) {
        XBoardNotification.showSuccess(l10n.xboardPaymentLinkCopied);
      }
    } catch (e) {
      if (mounted) {
        XBoardNotification.showError('${l10n.xboardCopyFailed}: $e');
      }
    }
  }

  Future<void> _startPaymentStatusCheck() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _checkPaymentStatus();
    }
  }

  void _startAutoPolling() {
    if (_autoPollingEnabled) return;
    setState(() {
      _autoPollingEnabled = true;
    });
    _pollPaymentStatus();
  }

  void _stopAutoPolling() {
    setState(() {
      _autoPollingEnabled = false;
    });
  }

  Future<void> _pollPaymentStatus() async {
    if (!_autoPollingEnabled || !mounted) return;
    await Future.delayed(const Duration(seconds: 5));
    if (!_autoPollingEnabled || !mounted) return;
    await _checkPaymentStatus(silent: true);
    if (_autoPollingEnabled && mounted) {
      _pollPaymentStatus();
    }
  }

  Future<void> _checkPaymentStatus({bool silent = false}) async {
    if (_isCheckingPayment) return;
    setState(() {
      _isCheckingPayment = true;
    });
    try {
      // 使用 SDK 查询订单状态
      final orderModels = await XBoardSDK.instance.order.getOrders();
      // SDK getOrder(tradeNo) might not exist, getOrders() returns list.
      // Need to find by tradeNo.
      // Wait, OrderApi has getOrder()?
      // Step 288: OrderApi has getOrder(), getPaymentMethods(), checkCoupon().
      // Step 156: `getOrder` (singular) was missing in providers.
      // Step 178: `OrderApi` interface: `Future<List<OrderModel>> getOrders();`
      // It does NOT have `getOrderByTradeNo`.
      // So I must fetch all orders and filter? Or `getOrders` supports query?
      // SDK `getOrders` implementation?
      // I'll assume I have to fetch all and find.
      // Or maybe `XBoardSDK.instance.order.getOrder(tradeNo)` exists?
      // I'll check `OrderApi` again.
      // Step 178 view_file lines 1-14:
      // `Future<List<OrderModel>> getOrders();`
      // `Future<String> createOrder(...)`
      // `Future<PaymentResultModel> checkoutOrder(...)`
      // `Future<bool> cancelOrder(...)`
      // `Future<List<PaymentMethodModel>> getPaymentMethods();`
      // `Future<CouponModel> checkCoupon(...)`
      // No `getOrder(tradeNo)`.
      // So I must use `getOrders()` and filter.

      final order = orderModels.firstWhere(
        (o) => o.tradeNo == widget.tradeNo,
        orElse: () => const OrderModel(status: -1), // Dummy
      );

      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
        });
        if (order.status != -1) {
          // status: 0=pending, 1=processing, 2=canceled, 3=completed
          if (order.status == 3) {
            _stopAutoPolling();
            XBoardNotification.showSuccess(
                AppLocalizations.of(context).xboardPaymentSuccessful);
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });
          } else if (order.status == 2) {
            _stopAutoPolling();
            if (!silent) {
              XBoardNotification.showInfo(
                  AppLocalizations.of(context).xboardPaymentCancelled);
            }
          } else if (order.status == 0 || order.status == 1) {
            if (!silent) {
              XBoardNotification.showInfo(_autoPollingEnabled
                  ? AppLocalizations.of(context).xboardWaitingForPayment
                  : AppLocalizations.of(context).xboardOrderStatusPending);
            }
          }
        } else {
          if (!silent) {
            XBoardNotification.showError(
                AppLocalizations.of(context).xboardOrderNotFound);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
        });
        if (!silent) {
          XBoardNotification.showError(
              '${AppLocalizations.of(context).xboardFailedToCheckPaymentStatus}: $e');
        }
      }
    }
  }

  void _completePayment() {
    XBoardNotification.showSuccess(
        AppLocalizations.of(context).xboardPaymentCompleted);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _cancelPayment() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return CommonScaffold(
      title: l10n.xboardPaymentGateway,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error,
                          size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: XbUiButton.filledPrimary(context),
                        child: Text(l10n.xboardReturn),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: XbUiTokens.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: isDark ? null : Colors.white,
                        shape: XbUiCardStyle.shape(context),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.xboardPaymentInfo,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                      '${AppLocalizations.of(context).xboardOrderNumber}: '),
                                  Expanded(
                                    child: Text(
                                      widget.tradeNo,
                                      style: const TextStyle(
                                          fontFamily: 'monospace'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _copyPaymentUrl,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  l10n.xboardPaymentLink,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Icon(
                                                  Icons.copy,
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  l10n.xboardClickToCopy,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              widget.paymentUrl,
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_autoPollingEnabled)
                        Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          color: XbUiStatusColor.success(context)
                              .withValues(alpha: isDark ? 0.22 : 0.10),
                          shape: XbUiCardStyle.shape(context),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        XbUiStatusColor.success(context)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.xboardAutoDetectPaymentStatus,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              XbUiStatusColor.success(context),
                                        ),
                                      ),
                                      Text(
                                        l10n.xboardAutoCheckEvery5Seconds,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              XbUiStatusColor.success(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _stopAutoPolling,
                                  child: Text(
                                    l10n.xboardStop,
                                    style: TextStyle(
                                        color:
                                            XbUiStatusColor.success(context)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_autoPollingEnabled) const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: isDark ? null : Colors.white,
                        shape: XbUiCardStyle.shape(context),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.xboardOperationTips,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(l10n.xboardPaymentPageAutoOpened),
                              Text(l10n.xboardCompletePaymentInBrowser),
                              Text(l10n.xboardReturnAfterPaymentAutoDetect),
                              Text(l10n.xboardReopenPaymentPageTip),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: XbUiStatusColor.pending(context)
                                      .withValues(alpha: isDark ? 0.24 : 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: XbUiStatusColor.pending(context)
                                          .withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 16,
                                        color:
                                            XbUiStatusColor.pending(context)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.xboardBrowserNotOpenedTip,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              XbUiStatusColor.pending(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _launchPaymentUrl(isAutomatic: false),
                              icon: const Icon(Icons.open_in_browser),
                              label: Text(l10n.xboardReopen),
                              style: XbUiButton.filledPrimary(context).copyWith(
                                padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyPaymentUrl,
                              icon: const Icon(Icons.copy),
                              label: Text(l10n.xboardCopyLink),
                              style:
                                  XbUiButton.outlinedNeutral(context).copyWith(
                                padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isCheckingPayment
                                  ? null
                                  : _checkPaymentStatus,
                              icon: _isCheckingPayment
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                              label: Text(_isCheckingPayment
                                  ? l10n.xboardChecking
                                  : l10n.xboardCheckStatus),
                              style: XbUiButton.filledPrimary(context).copyWith(
                                backgroundColor: WidgetStatePropertyAll(
                                  XbUiStatusColor.pending(context),
                                ),
                                padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _completePayment,
                              icon: const Icon(Icons.check_circle),
                              label: Text(l10n.xboardPaymentComplete),
                              style: XbUiButton.filledPrimary(context).copyWith(
                                backgroundColor: WidgetStatePropertyAll(
                                  XbUiStatusColor.success(context),
                                ),
                                padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _cancelPayment,
                              icon: const Icon(Icons.cancel),
                              label: Text(l10n.xboardCancelPayment),
                              style: XbUiButton.filledDanger(context).copyWith(
                                padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
