import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/subscription/services/reset_traffic_order_flow.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_guard_service.dart';
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
  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  late AnimationController _controller;
  late Animation<double> _animation;
  bool isStart = false;
  bool _isCheckingSubscription = false;
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> handleSwitchStart() async {
    if (_isCheckingSubscription) return;
    // 断开连接：不拦截，停止守护
    if (isStart) {
      isStart = false;
      setState(() {});
      updateController();
      subscriptionGuardService.stopGuard();
      debouncer.call(
        FunctionTag.updateStatus,
        () {
          globalState.appController.updateStatus(false);
        },
        duration: commonDuration,
      );
      return;
    }

    // 开始连接前：本地校验订阅状态
    var blockStatus = subscriptionGuardService.checkBeforeConnect();
    if (blockStatus?.type == SubscriptionStatusType.noSubscription) {
      _isCheckingSubscription = true;
      try {
        await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
        blockStatus = subscriptionGuardService.checkBeforeConnect();
      } finally {
        _isCheckingSubscription = false;
      }
      if (!mounted) return;
    }
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
        );
      } else {
        // 订阅无效，toast 提示，不连接
        XBoardNotification.showError(blockStatus.getMessage(context));
      }
      return;
    }

    // 订阅有效，正常连接 + 启动守护
    isStart = true;
    setState(() {});
    updateController();
    subscriptionGuardService.startGuard();
    debouncer.call(
      FunctionTag.updateStatus,
      () {
        globalState.appController.updateStatus(true);
      },
      duration: commonDuration,
    );
  }

  void _openPlans() {
    if (!mounted) return;
    GoRouter.of(context).go('/plans');
  }

  Future<void> _openResetTrafficOrder() async {
    await showResetTrafficOrderDialog(
      context: context,
      ref: ref,
    );
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
                      utils.getTimeDifference(
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
            heroTag: "xboard_connect_button",
            onPressed: () {
              handleSwitchStart();
            },
            icon: AnimatedIcon(
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
            final text = utils.getTimeText(runTime);
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
        ? Colors.white
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
                onPressed: handleSwitchStart,
                child: GestureDetector(
                  onTap: handleSwitchStart,
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
                                  child: Icon(
                                    btnIcon,
                                    key: ValueKey(isStart),
                                    size: iconSize,
                                    color: iconColor,
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
