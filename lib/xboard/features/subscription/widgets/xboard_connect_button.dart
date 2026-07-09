import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/reset_traffic_order_flow.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_guard_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_checker.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_status_dialog.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';

class XBoardConnectButton extends ConsumerStatefulWidget {
  final bool isFloating; // 是否为浮动按钮模式
  final double? outerSize; // 外部指定按钮外圈大小（自适应布局）
  const XBoardConnectButton({
    super.key,
    this.isFloating = false,
    this.outerSize,
  });
  @override
  ConsumerState<XBoardConnectButton> createState() =>
      _XBoardConnectButtonState();
}

class _XBoardConnectButtonState extends ConsumerState<XBoardConnectButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool isStart = false;
  bool _isCheckingSubscription = false;
  bool _isSwitching = false;

  bool get _isBusy =>
      _isCheckingSubscription ||
      _isSwitching ||
      globalState.isCoreSwitchingNotifier.value;

  @override
  void initState() {
    super.initState();
    isStart = globalState.appState.runTime != null;
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    ref.listenManual(
      runTimeProvider.select((state) => state != null),
      (prev, next) {
        if (next != isStart) {
          isStart = next;
          // 外部断开时（如守护服务自动断开），同步停止守护
          if (!isStart) {
            subscriptionGuardService.stopGuard();
          }
          updateController();
          if (mounted) setState(() {});
        }
      },
      fireImmediately: true,
    );
    globalState.isCoreSwitchingNotifier.addListener(_handleCoreSwitching);
    globalState.coreSwitchStatusNotifier.addListener(_handleCoreSwitching);
  }

  @override
  void dispose() {
    globalState.isCoreSwitchingNotifier.removeListener(_handleCoreSwitching);
    globalState.coreSwitchStatusNotifier.removeListener(_handleCoreSwitching);
    _controller.dispose();
    super.dispose();
  }

  void _handleCoreSwitching() {
    if (mounted) setState(() {});
  }

  Future<void> handleSwitchStart() async {
    if (_isBusy || globalState.appController.isCoreSwitching) {
      return;
    }
    final currentlyRunning = ref.read(runTimeProvider) != null;
    // 断开连接：不拦截，停止守护
    if (currentlyRunning) {
      setState(() => _isSwitching = true);
      subscriptionGuardService.stopGuard();
      autoLatencyService.onConnectionStatusChanged(false);
      try {
        await globalState.appController.updateStatus(false);
      } finally {
        if (mounted) setState(() => _isSwitching = false);
      }
      return;
    }

    // 开始连接前：先刷新服务端订阅状态，避免首页缓存滞后时仍然放行连接。
    if (mounted) {
      setState(() => _isCheckingSubscription = true);
    } else {
      _isCheckingSubscription = true;
    }
    try {
      await ref
          .read(xboardUserProvider.notifier)
          .refreshSubscriptionInfo(importProfile: false);
    } finally {
      if (mounted) {
        setState(() => _isCheckingSubscription = false);
      } else {
        _isCheckingSubscription = false;
      }
    }
    if (!mounted) return;

    debugPrint('[handleSwitchStart] refreshSubscriptionInfo 完成，开始 checkBeforeConnect');
    final blockStatus = subscriptionGuardService.checkBeforeConnect();
    debugPrint('[handleSwitchStart] blockStatus=${blockStatus?.type}');
    if (blockStatus != null) {
      if (blockStatus.type == SubscriptionStatusType.noSubscription ||
          blockStatus.type == SubscriptionStatusType.expired ||
          blockStatus.type == SubscriptionStatusType.exhausted) {
        SubscriptionStatusDialog.show(
          context,
          blockStatus,
          onPurchase: _openPlans,
          onResetTraffic: blockStatus.type == SubscriptionStatusType.exhausted
              ? _openResetTrafficOrder
              : null,
          onRefresh: _refreshSubscriptionStatus,
        );
      } else {
        // 订阅无效，toast 提示，不连接
        XBoardNotification.showError(blockStatus.getMessage(context));
      }
      return;
    }

    setState(() => _isSwitching = true);
    try {
      final started = await globalState.appController.updateStatus(true);
      final isActuallyRunning = ref.read(runTimeProvider) != null;
      if (started && isActuallyRunning) {
        subscriptionGuardService.startGuard();
        autoLatencyService.onConnectionStatusChanged(true);
      } else {
        subscriptionGuardService.stopGuard();
        autoLatencyService.onConnectionStatusChanged(false);
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  String _busyLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isCheckingSubscription) {
      return l10n.xboardCheckingSubscription;
    }
    final status = globalState.coreSwitchStatusNotifier.value;
    final statusLabel = status.localizedLabel(l10n);
    if (status.stage != CoreSwitchStage.idle && statusLabel.isNotEmpty) {
      return statusLabel;
    }
    return isStart ? l10n.xboardDisconnecting : l10n.xboardConnecting;
  }

  Future<void> _openPlans() async {
    if (!mounted) return;
    await SubscriptionStatusChecker.handleRenewAction(context, ref);
  }

  Future<void> _openResetTrafficOrder() async {
    await showResetTrafficOrderDialog(
      context: context,
      ref: ref,
    );
  }

  Future<void> _refreshSubscriptionStatus() async {
    await ref
        .read(xboardUserProvider.notifier)
        .refreshSubscriptionInfo(importProfile: false);
    if (!mounted) return;

    debugPrint('[handleSwitchStart] refreshSubscriptionInfo 完成，开始 checkBeforeConnect');
    final blockStatus = subscriptionGuardService.checkBeforeConnect();
    debugPrint('[handleSwitchStart] blockStatus=${blockStatus?.type}');
    if (blockStatus == null) {
      XBoardNotification.showSuccess(
        AppLocalizations.of(context).subscriptionValid,
      );
      return;
    }

    if (blockStatus.type == SubscriptionStatusType.noSubscription ||
        blockStatus.type == SubscriptionStatusType.expired ||
        blockStatus.type == SubscriptionStatusType.exhausted) {
      SubscriptionStatusDialog.show(
        context,
        blockStatus,
        onPurchase: _openPlans,
        onResetTraffic: blockStatus.type == SubscriptionStatusType.exhausted
            ? _openResetTrafficOrder
            : null,
        onRefresh: _refreshSubscriptionStatus,
      );
      return;
    }

    XBoardNotification.showError(blockStatus.getMessage(context));
  }

  updateController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isStart) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(startButtonSelectorStateProvider);
    if (widget.isFloating) {
      return _buildFloatingButton(context);
    } else {
      return _buildInlineButton(context);
    }
  }

  Widget _buildFloatingButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonColor = colorScheme.primary;

    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          sizeConstraints: const BoxConstraints(
            minWidth: 56,
            maxWidth: 200,
          ),
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller.view,
        builder: (_, child) {
          final textWidth = globalState.measure
                  .computeTextSize(
                    Text(
                      _isBusy
                          ? _busyLabel(context)
                          : utils.getTimeDifference(
                              DateTime.now(),
                            ),
                      style: context.textTheme.titleMedium?.toSoftBold,
                    ),
                  )
                  .width +
              16;
          return FloatingActionButton.extended(
            clipBehavior: Clip.antiAlias,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            heroTag: 'xboard_connect_button',
            onPressed: _isBusy ? null : handleSwitchStart,
            icon: _isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _animation,
                  ),
            label: SizedBox(
              width: textWidth * _animation.value,
              child: child!,
            ),
          );
        },
        child: Consumer(
          builder: (_, ref, __) {
            final runTime = ref.watch(runTimeProvider);
            final text =
                _isBusy ? _busyLabel(context) : utils.getTimeText(runTime);
            return Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style:
                  Theme.of(context).textTheme.titleMedium?.toSoftBold.copyWith(
                        color: Colors.white,
                      ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInlineButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color offBg =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF0F4F8);
    final Color onBg = colorScheme.primary;

    final Color glowColor = isStart ? colorScheme.primary : Colors.transparent;

    const IconData btnIcon = Icons.power_settings_new;
    final Color iconColor = isStart
        ? colorScheme.onPrimary
        : (isDark ? colorScheme.primary : const Color(0xFF455A64));

    // 按钮只渲染圆圈部分，状态文字由首页单独放置
    return LayoutBuilder(
      builder: (context, constraints) {
        final double outerSize = widget.outerSize ??
            (constraints.maxHeight.isFinite
                ? constraints.maxHeight.clamp(80.0, 210.0)
                : 160);
        final double middleSize = outerSize * 0.89;
        final double btnSize = outerSize * 0.75;
        final double iconSize = outerSize * 0.34;

        return Center(
          child: SizedBox(
            width: outerSize,
            height: outerSize,
            child: Center(
              child: TVFocusable(
                autofocus: system.isTV,
                borderRadius: BorderRadius.circular(outerSize / 2),
                onPressed: _isBusy ? null : handleSwitchStart,
                child: GestureDetector(
                  onTap: _isBusy ? null : handleSwitchStart,
                  child: SizedBox(
                    width: outerSize,
                    height: outerSize,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: outerSize,
                        height: outerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isStart
                              ? glowColor.withValues(
                                  alpha: isDark ? 0.12 : 0.10)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: middleSize,
                            height: middleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isStart
                                  ? glowColor.withValues(
                                      alpha: isDark ? 0.12 : 0.10)
                                  : Colors.transparent,
                            ),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: btnSize,
                                height: btnSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isStart ? onBg : offBg,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isStart
                                          ? glowColor.withValues(
                                              alpha: isDark ? 0.36 : 0.30)
                                          : Colors.black.withValues(
                                              alpha: isDark ? 0.30 : 0.10),
                                      blurRadius: isStart ? 18 : 12,
                                      spreadRadius: isStart ? 1 : 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: _isBusy
                                      ? Column(
                                          key: const ValueKey('switching'),
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: iconSize * 0.58,
                                              height: iconSize * 0.58,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: iconColor,
                                              ),
                                            ),
                                            SizedBox(
                                                height:
                                                    (outerSize * 0.035).clamp(
                                              2.0,
                                              5.0,
                                            )),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              child: Text(
                                                _busyLabel(context),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: iconColor,
                                                      fontSize:
                                                          (outerSize * 0.07)
                                                              .clamp(9.0, 12.0),
                                                    ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          key: ValueKey(isStart),
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              btnIcon,
                                              size: iconSize * 0.75,
                                              color: iconColor,
                                            ),
                                            SizedBox(height: (outerSize * 0.03).clamp(2.0, 4.0)),
                                            Consumer(
                                              builder: (_, ref, __) {
                                                final runTime = ref.watch(runTimeProvider);
                                                final l10n = AppLocalizations.of(context);
                                                final label = isStart
                                                    ? utils.getTimeText(runTime)
                                                    : l10n.tapToConnect;
                                                return Text(
                                                  label,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: iconColor,
                                                        fontSize: (outerSize * 0.07).clamp(9.0, 12.0),
                                                      ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
