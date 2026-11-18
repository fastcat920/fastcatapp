import 'dart:async';
import 'dart:io';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/services/connection_button_activity.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/traffic_recovery_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_guard_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_checker.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_status_dialog.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/features/connectivity/connectivity.dart';
import 'package:fl_clash/xboard/features/shared/utils/tv_focus_restoration.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _autoConnectTimer;
  bool _autoConnectConsumed = false;
  bool _wasBackgrounded = false;
  int _autoConnectGeneration = 0;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool isStart = false;
  bool _isCheckingSubscription = false;
  bool _isSwitching = false;
  String? _subscriptionCheckLabel;
  late final FocusNode _tvFocusNode;

  bool get _showProgress => showConnectionProgress(
        ready: globalState.coreStatusReadyNotifier.value,
        checkingSubscription: _isCheckingSubscription,
        userSwitching: _isSwitching,
        coreSwitching: globalState.isCoreSwitchingNotifier.value,
        configurationSwitching:
            globalState.appController.isConfigurationSwitching,
        status: globalState.coreSwitchStatusNotifier.value,
      );

  // A silent configuration update still prevents conflicting user operations.
  bool get _isBusy =>
      _showProgress ||
      globalState.isCoreSwitchingNotifier.value ||
      globalState.appController.isCoreSwitching;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoConnect());
    _tvFocusNode = FocusNode(debugLabel: 'home-connect');
    TvFocusRestoration.registerDefault(_tvFocusNode);
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
    globalState.coreStatusReadyNotifier.addListener(_handleCoreSwitching);
    globalState.coreStatusRecoveringNotifier.addListener(_handleCoreSwitching);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoConnectGeneration++;
    _autoConnectTimer?.cancel();
    TvFocusRestoration.unregisterDefault(_tvFocusNode);
    _tvFocusNode.dispose();
    globalState.isCoreSwitchingNotifier.removeListener(_handleCoreSwitching);
    globalState.coreSwitchStatusNotifier.removeListener(_handleCoreSwitching);
    globalState.coreStatusReadyNotifier.removeListener(_handleCoreSwitching);
    globalState.coreStatusRecoveringNotifier
        .removeListener(_handleCoreSwitching);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isIOS) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      _autoConnectGeneration++;
      _autoConnectTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_wasBackgrounded) {
        _autoConnectConsumed = false;
        _wasBackgrounded = false;
      }
      _scheduleAutoConnect();
    }
  }

  void _scheduleAutoConnect() {
    _autoConnectTimer?.cancel();
    if (!mounted ||
        !Platform.isIOS ||
        _autoConnectConsumed ||
        !ref.read(appSettingProvider).autoRun) {
      return;
    }
    _autoConnectTimer = Timer(
        const Duration(milliseconds: 500), () => unawaited(_tryAutoConnect()));
  }

  Future<void> _tryAutoConnect() async {
    if (!mounted ||
        _autoConnectConsumed ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (!ref.read(appSettingProvider).autoRun) return;
    if (!ref.read(xboardUserProvider).isAuthenticated ||
        ref.read(currentProfileIdProvider) == null ||
        !globalState.coreStatusReadyNotifier.value ||
        _isBusy) {
      _scheduleAutoConnect();
      return;
    }
    final generation = _autoConnectGeneration;
    try {
      final snapshot = await service!.restoreIosVpnState();
      if (!mounted ||
          generation != _autoConnectGeneration ||
          _autoConnectConsumed ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          !ref.read(appSettingProvider).autoRun) {
        return;
      }
      final status = snapshot['status'];
      if (status == 'connected') {
        _autoConnectConsumed = true;
        await globalState.appController.restoreIosConnection();
        return;
      }
      if (status != 'disconnected') {
        _scheduleAutoConnect();
        return;
      }
      if (_isBusy) {
        _scheduleAutoConnect();
        return;
      }
      _autoConnectConsumed = true;
      debugPrint('[IOSAutoConnect] starting once after readiness');
      await handleSwitchStart();
    } catch (_) {
      // Status-read failures are not permission to start or stop a tunnel.
      if (!_autoConnectConsumed && generation == _autoConnectGeneration) {
        _scheduleAutoConnect();
      }
    }
  }

  void _handleCoreSwitching() {
    if (mounted) setState(() {});
  }

  Future<void> handleSwitchStart() async {
    _autoConnectConsumed = true;
    _autoConnectTimer?.cancel();
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

    // 开始连接前：在线时限时刷新；离线或超时时立即使用本地缓存校验。
    if (mounted) {
      setState(() => _isCheckingSubscription = true);
    } else {
      _isCheckingSubscription = true;
    }
    try {
      await _prepareSubscriptionForConnect();
    } finally {
      if (mounted) {
        setState(() => _isCheckingSubscription = false);
      } else {
        _isCheckingSubscription = false;
      }
    }
    if (!mounted) return;

    debugPrint(
        '[handleSwitchStart] refreshSubscriptionInfo 完成，开始 checkBeforeConnect');
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
          onTrafficRecovery:
              blockStatus.type == SubscriptionStatusType.exhausted
                  ? _openTrafficRecovery
                  : null,
          useNewPeriod: isNewPeriodEnabled(ref),
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
    if (!globalState.coreStatusReadyNotifier.value) {
      return globalState.coreStatusRecoveringNotifier.value
          ? l10n.xboardServiceRecovering
          : l10n.xboardInitializing;
    }
    if (_isCheckingSubscription) {
      return _subscriptionCheckLabel ?? l10n.xboardCheckingSubscription;
    }
    final status = globalState.coreSwitchStatusNotifier.value;
    final statusLabel = status.localizedLabel(l10n);
    if (status.stage != CoreSwitchStage.idle && statusLabel.isNotEmpty) {
      return statusLabel;
    }
    return isStart ? l10n.xboardDisconnecting : l10n.xboardConnecting;
  }

  Future<void> _prepareSubscriptionForConnect() async {
    final l10n = AppLocalizations.of(context);
    var connectivity = ref.read(serviceConnectivityProvider);

    if (connectivity.isOffline) {
      _setSubscriptionCheckLabel(l10n.xboardCheckingCachedSubscription);
      return;
    }

    Duration refreshTimeout;
    if (connectivity.isRecovering) {
      _setSubscriptionCheckLabel(l10n.xboardServiceRecovering);
      final recovered = await ref
          .read(serviceConnectivityProvider.notifier)
          .verifyNow()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => false,
          );
      connectivity = ref.read(serviceConnectivityProvider);
      if (!recovered || !connectivity.isOnline) {
        _setSubscriptionCheckLabel(l10n.xboardCheckingCachedSubscription);
        return;
      }
      // 恢复探测最多 3 秒，剩余刷新最多 5 秒，总等待不超过约 8 秒。
      refreshTimeout = const Duration(seconds: 5);
    } else if (connectivity.isDegraded) {
      refreshTimeout = const Duration(seconds: 5);
    } else {
      refreshTimeout = const Duration(seconds: 8);
    }

    _setSubscriptionCheckLabel(l10n.xboardCheckingSubscription);
    final refreshed = await ref
        .read(xboardUserProvider.notifier)
        .refreshSubscriptionForConnect(refreshTimeout);
    if (!refreshed) {
      _setSubscriptionCheckLabel(l10n.xboardSubscriptionSlowUsingCache);
    }
  }

  void _setSubscriptionCheckLabel(String label) {
    if (!mounted) {
      _subscriptionCheckLabel = label;
      return;
    }
    setState(() => _subscriptionCheckLabel = label);
  }

  Future<void> _openPlans() async {
    if (!mounted) return;
    await SubscriptionStatusChecker.handleRenewAction(context, ref);
  }

  Future<void> _openTrafficRecovery() async {
    await showTrafficRecoveryDialog(
      context: context,
      ref: ref,
    );
  }

  Future<void> _refreshSubscriptionStatus() async {
    await ref
        .read(xboardUserProvider.notifier)
        .refreshSubscriptionInfo(importProfile: false);
    if (!mounted) return;

    debugPrint(
        '[handleSwitchStart] refreshSubscriptionInfo 完成，开始 checkBeforeConnect');
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
        onTrafficRecovery: blockStatus.type == SubscriptionStatusType.exhausted
            ? _openTrafficRecovery
            : null,
        useNewPeriod: isNewPeriodEnabled(ref),
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
          final measuredTextWidth = globalState.measure
                  .computeTextSize(
                    Text(
                      _showProgress
                          ? _busyLabel(context)
                          : utils.getTimeDifference(
                              DateTime.now(),
                            ),
                      style: context.textTheme.titleMedium?.toSoftBold,
                    ),
                  )
                  .width +
              16;
          final labelWidth = measuredTextWidth.clamp(0.0, 116.0);
          return FloatingActionButton.extended(
            clipBehavior: Clip.antiAlias,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            heroTag: 'xboard_connect_button',
            onPressed: _isBusy ? null : handleSwitchStart,
            icon: _showProgress
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
              width: labelWidth * (_showProgress ? 1 : _animation.value),
              child: child!,
            ),
          );
        },
        child: Consumer(
          builder: (_, ref, __) {
            final runTime = ref.watch(runTimeProvider);
            final text = _showProgress
                ? _busyLabel(context)
                : utils.getTimeText(runTime);
            return _ConnectionTimerLabel(
              runTime: _showProgress ? null : runTime,
              text: text,
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
          child: RepaintBoundary(
            child: SizedBox(
              width: outerSize,
              height: outerSize,
              child: Center(
                child: TVFocusable(
                  autofocus: system.isTV,
                  focusNode: _tvFocusNode,
                  // Busy disables activation, not the remote's current focus.
                  focusableWhenDisabled: true,
                  borderRadius: BorderRadius.circular(outerSize / 2),
                  onPressed: _isBusy ? null : handleSwitchStart,
                  child: XbPointerCursor(
                    enabled: !_isBusy,
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
                                      duration:
                                          const Duration(milliseconds: 250),
                                      child: _showProgress
                                          ? Column(
                                              key: const ValueKey('switching'),
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: iconSize * 0.58,
                                                  height: iconSize * 0.58,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: iconColor,
                                                  ),
                                                ),
                                                SizedBox(
                                                    height: (outerSize * 0.035)
                                                        .clamp(
                                                  2.0,
                                                  5.0,
                                                )),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  child: _LeftScrollingText(
                                                    text: _busyLabel(context),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: iconColor,
                                                          fontSize: (outerSize *
                                                                  0.07)
                                                              .clamp(9.0, 12.0),
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              key: ValueKey(isStart),
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  btnIcon,
                                                  size: iconSize * 0.75,
                                                  color: iconColor,
                                                ),
                                                SizedBox(
                                                    height: (outerSize * 0.03)
                                                        .clamp(2.0, 4.0)),
                                                Consumer(
                                                  builder: (_, ref, __) {
                                                    final runTime = ref
                                                        .watch(runTimeProvider);
                                                    final l10n =
                                                        AppLocalizations.of(
                                                            context);
                                                    final label = isStart
                                                        ? utils.getTimeText(
                                                            runTime)
                                                        : l10n.tapToConnect;
                                                    return _ConnectionTimerLabel(
                                                      runTime: isStart
                                                          ? runTime
                                                          : null,
                                                      text: label,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: iconColor,
                                                            fontSize:
                                                                (outerSize *
                                                                        0.07)
                                                                    .clamp(9.0,
                                                                        12.0),
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
            ),
          ),
        );
      },
    );
  }
}

class _LeftScrollingText extends StatefulWidget {
  const _LeftScrollingText({
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  State<_LeftScrollingText> createState() => _LeftScrollingTextState();
}

class _LeftScrollingTextState extends State<_LeftScrollingText> {
  final ScrollController _scrollController = ScrollController();
  int _animationGeneration = 0;
  double? _lastWidth;

  @override
  void initState() {
    super.initState();
    _scheduleAnimation();
  }

  @override
  void didUpdateWidget(covariant _LeftScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _scheduleAnimation();
    }
  }

  void _scheduleAnimation() {
    final generation = ++_animationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _animationGeneration) return;
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;

      await Future.delayed(const Duration(milliseconds: 600));
      while (mounted && generation == _animationGeneration) {
        if (!_scrollController.hasClients) return;
        final extent = _scrollController.position.maxScrollExtent;
        if (extent <= 0) return;
        final durationMs = (extent / 28 * 1000).round().clamp(1200, 12000);
        await _scrollController.animateTo(
          extent,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );
        if (!mounted || generation != _animationGeneration) return;
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted || generation != _animationGeneration) return;
        _scrollController.jumpTo(0);
        await Future.delayed(const Duration(milliseconds: 450));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width.isFinite && width != _lastWidth) {
          _lastWidth = width;
          _scheduleAnimation();
        }
        if (!width.isFinite) {
          return Text(
            widget.text,
            maxLines: 1,
            softWrap: false,
            style: widget.style,
          );
        }
        return ClipRect(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(minWidth: width),
                alignment: Alignment.center,
                child: Text(
                  widget.text,
                  maxLines: 1,
                  softWrap: false,
                  style: widget.style,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationGeneration++;
    _scrollController.dispose();
    super.dispose();
  }
}

class _ConnectionTimerLabel extends StatelessWidget {
  const _ConnectionTimerLabel(
      {required this.runTime, required this.text, this.style});
  final int? runTime;
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final days = ((runTime ?? 0) ~/ Duration.millisecondsPerDay).clamp(0, 99);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _LeftScrollingText(text: text, style: style),
      if (days > 0) ...[
        const SizedBox(height: 8),
        Text(chinese ? '$days 天' : '$days ${days == 1 ? "day" : "days"}',
            style: style),
      ],
    ]);
  }
}
