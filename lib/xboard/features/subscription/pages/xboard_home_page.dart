import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart' as fl_models;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/auth/models/session_termination.dart';
import 'package:fl_clash/xboard/features/settings/widgets/fastcat_tun_toggle.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/logout_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';

import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:fl_clash/xboard/features/notice/notice.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_checker.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_guard_service.dart';
import 'package:fl_clash/xboard/features/subscription/utils/home_layout.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/connectivity/connectivity.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/config/utils/website_url_resolver.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/widgets/widgets.dart';
import '../widgets/subscription_usage_card.dart';
import '../widgets/xboard_connect_button.dart';
import 'package:fl_clash/xboard/features/payment/widgets/coupon_entry_button.dart';

part '../widgets/home_panels.dart';

class XBoardHomePage extends ConsumerStatefulWidget {
  const XBoardHomePage({super.key});
  @override
  ConsumerState<XBoardHomePage> createState() => _XBoardHomePageState();
}

class _XBoardHomePageState extends ConsumerState<XBoardHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _hasInitialized = false;
  bool _hasCheckedSubscriptionStatus = false;
  bool _hasTriggeredLatencyTest = false;
  bool _deferredStartupTasksReady = false;
  bool _isTokenExpiredDialogVisible = false;
  bool _isCheckingWebsite = false;
  bool _isRefreshingTvSubscription = false;
  Timer? _noticeStartupTimer;
  Timer? _latencyStartupTimer;
  Timer? _latencyBatchTimer;
  Timer? _vpnHealthSyncTimer;

  @override
  bool get wantKeepAlive => true; // 保持页面状态，防止重建

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasInitialized) return;
      _hasInitialized = true;
      if (Platform.isAndroid) {
        unawaited(_synchronizeVpnStatus());
      }
      final userState = ref.read(xboardUserProvider);
      if (userState.isAuthenticated) {
        // 等待订阅导入完成后再检查订阅状态
        _waitForSubscriptionImportThenCheck();
      }
      _scheduleDeferredStartupTasks();
    });
    ref.listenManual(xboardUserProvider, (previous, next) {
      if (next.isAuthenticated && isSessionTerminationCode(next.errorMessage)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTokenExpiredDialog(next.errorMessage!);
        });
      }
      // 注意：登录后订阅下载的 HTTP 重试已在 SubscriptionDownloader 层处理，
      // 无需在此额外重试。
    });

    // 监听订阅导入完成事件
    ref.listenManual(profileImportProvider, (previous, next) {
      // 从导入中变为完成（成功或失败）
      if (previous?.isImporting == true &&
          !next.isImporting &&
          !_hasCheckedSubscriptionStatus) {
        _hasCheckedSubscriptionStatus = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            subscriptionStatusChecker.checkSubscriptionStatusOnStartup(
                context, ref);
          }
        });
      }
    });

    ref.listenManual(groupsProvider, (previous, next) {
      if (next.isNotEmpty) {
        _startSelectedNodeLatencyTestWhenReady();
      }
    });

    // 初始化订阅守护服务
    subscriptionGuardService.initialize(ref);
    // 如果启动时已经在连接状态，启动守护
    if (ref.read(runTimeProvider) != null) {
      subscriptionGuardService.startGuard();
    }

    // 监听订阅信息变化：通知守护服务重新评估
    ref.listenManual(subscriptionInfoProvider, (previous, next) {
      if (next == null) return;
      subscriptionGuardService.onSubscriptionInfoChanged();
    });

    // 监听用户信息变化：捕获账号封禁
    ref.listenManual(userInfoProvider, (previous, next) {
      if (next == null) return;
      subscriptionGuardService.onSubscriptionInfoChanged();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      unawaited(_synchronizeVpnStatus());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _vpnHealthSyncTimer?.cancel();
    }
  }

  Future<void> _synchronizeVpnStatus() async {
    final expectedRunning = ref.read(runTimeProvider) != null;
    if (!expectedRunning) return;
    final recoveringMessage =
        AppLocalizations.of(context).xboardServiceRecovering;
    final connectionState =
        await service?.getVpnConnectionState() ?? 'disconnected';
    if (!mounted) return;
    if (connectionState == 'recovering' || connectionState == 'degraded') {
      globalState.updateCoreSwitchStatus(
        CoreSwitchStage.coreConnecting,
        message: recoveringMessage,
      );
      _vpnHealthSyncTimer?.cancel();
      _vpnHealthSyncTimer = Timer(
        const Duration(seconds: 5),
        () => unawaited(_synchronizeVpnStatus()),
      );
      return;
    }
    _vpnHealthSyncTimer?.cancel();
    final running = await service?.isVpnActuallyRunning() ?? false;
    if (!mounted) return;
    if (running &&
        globalState.coreSwitchStatusNotifier.value.message ==
            recoveringMessage) {
      globalState.updateCoreSwitchStatus(CoreSwitchStage.connected);
    }
    if (!running && mounted && ref.read(runTimeProvider) != null) {
      // The native VPN service was reclaimed or disconnected while the TV
      // app was backgrounded. Clear stale UI state so the user can reconnect.
      globalState.updateCoreSwitchStatus(CoreSwitchStage.failed);
      globalState.startTime = null;
      globalState.stopUpdateTasks();
      ref.read(runTimeProvider.notifier).value = null;
    }
  }

  /// 更新检查和核心状态恢复属于首屏高优先级任务。公告及全节点延迟检测
  /// 分批启动，避免它们与连接按钮的初始化动画争抢 UI isolate 和网络资源。
  void _scheduleDeferredStartupTasks() {
    _noticeStartupTimer?.cancel();
    _latencyStartupTimer?.cancel();
    _noticeStartupTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      ref.read(noticeProvider.notifier).fetchNotices();
    });
    // Test the selected node first so the home page gets useful feedback
    // quickly. The more expensive all-node batch follows after the UI settles.
    _latencyStartupTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      _deferredStartupTasksReady = true;
      autoLatencyService.initialize(ref);
      _startSelectedNodeLatencyTestWhenReady();
      _latencyBatchTimer?.cancel();
      _latencyBatchTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        _startLatencyTestWhenReady();
      });
    });
  }

  void _startSelectedNodeLatencyTestWhenReady() {
    if (!_deferredStartupTasksReady || ref.read(groupsProvider).isEmpty) return;
    unawaited(autoLatencyService.testCurrentNode());
  }

  void _startLatencyTestWhenReady() {
    if (!_deferredStartupTasksReady || _hasTriggeredLatencyTest) return;
    if (ref.read(groupsProvider).isEmpty) return;
    _hasTriggeredLatencyTest = true;
    autoLatencyService.testCurrentGroupNodes(maxNodes: 999);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noticeStartupTimer?.cancel();
    _latencyStartupTimer?.cancel();
    _latencyBatchTimer?.cancel();
    _vpnHealthSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，配合 AutomaticKeepAliveClientMixin

    // TV/投影仪虽然常是横屏，但首页按紧凑遥控器布局处理。
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final isTvHome = system.isTV;
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompactMobileHome =
        isTvHome || (!isDesktop && mediaSize.height < 640);

    final bool showDesktopAppBar = isDesktop && !isCompactMobileHome;
    final bool showMobileAppBar = !(isDesktop || isCompactMobileHome);
    if (isTvHome) {
      return Scaffold(
        appBar: _buildTvAppBar(context),
        body: _buildTvHomeBody(),
      );
    }
    return Scaffold(
      appBar: showDesktopAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              titleSpacing: 16,
              title: const _HomeBrandHeader(),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
                statusBarBrightness:
                    Theme.of(context).brightness == Brightness.dark
                        ? Brightness.dark
                        : Brightness.light,
              ),
              actions: [
                const CouponEntryButton(
                  showOnlyWhenAvailable: true,
                  endSpacing: 8,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    style: XbUiButton.textChipPrimary(context),
                    icon: _isCheckingWebsite
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : Icon(Icons.language_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                    label: Text(
                      _isCheckingWebsite
                          ? AppLocalizations.of(context).checking
                          : AppLocalizations.of(context).officialWebsite,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onPressed: _isCheckingWebsite
                        ? null
                        : () => _openOfficialWebsite(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    icon: Icon(
                      Icons.menu_open,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'TUN',
                    onPressed: () => _showVpnSheet(context),
                  ),
                ),
              ],
            )
          : showMobileAppBar
              ? AppBar(
                  automaticallyImplyLeading: false,
                  titleSpacing: 16,
                  title: const _HomeBrandHeader(),
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surface
                          : Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness:
                        Theme.of(context).brightness == Brightness.dark
                            ? Brightness.light
                            : Brightness.dark,
                    statusBarBrightness:
                        Theme.of(context).brightness == Brightness.dark
                            ? Brightness.dark
                            : Brightness.light,
                  ),
                  actions: [
                    const CouponEntryButton(
                      showOnlyWhenAvailable: true,
                      endSpacing: 8,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: TextButton.icon(
                        style: XbUiButton.textChipPrimary(context),
                        icon: _isCheckingWebsite
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : Icon(Icons.language_outlined,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary),
                        label: Text(
                          _isCheckingWebsite
                              ? AppLocalizations.of(context).checking
                              : AppLocalizations.of(context).officialWebsite,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onPressed: _isCheckingWebsite
                            ? null
                            : () => _openOfficialWebsite(context),
                      ),
                    ),
                  ],
                )
              : null,
      body: Consumer(
        builder: (_, ref, __) {
          const horizontalPadding = 16.0;
          final topInfoSlotHeight = isDesktop ? 136.0 : 148.0;

          return Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface
                : const Color(0xFFFAFBFD),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 桌面端：响应式最大宽度
                const contentMaxWidth = double.infinity;

                final compactMode = shouldUseCompactHomeLayout(context) ||
                    (!isDesktop && constraints.maxHeight < 560);
                final isLandscapeHome =
                    constraints.maxWidth > constraints.maxHeight;
                final isPortraitHome =
                    constraints.maxHeight >= constraints.maxWidth;
                // TV keeps the compact control layout but still shows the
                // announcement/subscription slot. Only short mobile viewports
                // hide it to protect the primary controls from overflow.
                final showTopInfo = isTvHome || !compactMode;
                final topInfoTopGap = 12.0;
                final shouldCompactConnectButton =
                    compactMode || isLandscapeHome;
                final connectButtonScale =
                    shouldCompactConnectButton ? 0.9 : 1.0;
                final connectButtonSize = 151.2 * connectButtonScale;
                final buttonSlotHeight = 168.0 * connectButtonScale;
                const connectionStatusGap = 5.0;
                const statusRowHeight = 40.0;
                const outboundModeHeight = 48.0;
                const nodeSelectorHeight = 56.0;
                const sectionGap = 4.0;
                final nodeBottomInset = compactMode
                    ? (isLandscapeHome ? 24.0 : 22.0)
                    : (isPortraitHome ? 8.0 : 18.0);
                final headerHeight = isDesktop && !compactMode ? 42.0 : 0.0;
                final topInfoHeight = showTopInfo
                    ? topInfoSlotHeight +
                        topInfoTopGap +
                        (isDesktop ? 8.0 : 0.0)
                    : 0.0;
                final minBottomGap = compactMode ? 16.0 : 28.0;
                final fixedHeight = headerHeight +
                    topInfoHeight +
                    buttonSlotHeight +
                    connectionStatusGap +
                    statusRowHeight +
                    outboundModeHeight +
                    nodeSelectorHeight +
                    nodeBottomInset +
                    12.0 +
                    minBottomGap;
                final availableGap =
                    (constraints.maxHeight - fixedHeight).clamp(0.0, 240.0);
                final minTopGapForLowerHalf = (constraints.maxHeight * 0.5 -
                        headerHeight -
                        topInfoHeight -
                        buttonSlotHeight / 2)
                    .clamp(0.0, availableGap);
                final targetTopGap = availableGap * (compactMode ? 0.28 : 0.36);
                final adaptiveTopGap = (targetTopGap < minTopGapForLowerHalf
                        ? minTopGapForLowerHalf
                        : targetTopGap) +
                    (isDesktop ? 20.0 : 0.0);
                final adaptiveBottomGap =
                    minBottomGap + (availableGap - adaptiveTopGap);

                // 纯 Flex 布局：优先保留连接按钮、模式切换和线路选择。
                return Stack(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: contentMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
// Desktop header is now rendered in the AppBar (stays fixed on scroll).
                            // ── 未连接显示公告，已连接显示套餐信息。空间不足时隐藏，优先保留主操作区。 ──
                            if (showTopInfo)
                              if (isDesktop)
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: horizontalPadding,
                                      right: horizontalPadding,
                                      top: topInfoTopGap),
                                  child: SizedBox(
                                    height: topInfoSlotHeight,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: _buildTopInfoSection(),
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: horizontalPadding,
                                    right: horizontalPadding,
                                    top: topInfoTopGap,
                                  ),
                                  child: SizedBox(
                                    height: topInfoSlotHeight,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: _buildTopInfoSection(),
                                    ),
                                  ),
                                ),
                            // ── 主操作区按可用高度自适应，按钮中心不高于屏幕中线 ──
                            SizedBox(height: adaptiveTopGap),
                            // ── 连接按钮（仅圆圈，Flexible 自动缩放）──
                            SizedBox(
                              height: buttonSlotHeight,
                              child: Center(
                                child: SizedBox(
                                  width: connectButtonSize,
                                  height: connectButtonSize,
                                  child: XBoardConnectButton(
                                    isFloating: false,
                                    outerSize: connectButtonSize,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: connectionStatusGap),
                            // ── 状态文字（独立于按钮，固定高度不被 Flex 压缩）──
                            _buildConnectionStatusRow(),
                            // ── 模式选择：在状态文字和底部节点选择之间居中 ──
                            SizedBox(height: adaptiveBottomGap / 2),
                            const SizedBox(
                              height: outboundModeHeight,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding),
                                child: XBoardOutboundMode(),
                              ),
                            ),
                            SizedBox(height: adaptiveBottomGap / 2),
                            // ── 节点选择器保持在下方；TV 在右侧保留退出入口 ──
                            const SizedBox(height: sectionGap),
                            SizedBox(
                              height: nodeSelectorHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: horizontalPadding),
                                child: isTvHome
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Expanded(
                                            child: NodeSelectorBar(),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 144,
                                            child:
                                                _buildTvLogoutButton(context),
                                          ),
                                        ],
                                      )
                                    : const NodeSelectorBar(),
                              ),
                            ),
                            SizedBox(height: nodeBottomInset),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildTvAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(14);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 25,
      title: const _HomeBrandHeader(),
      backgroundColor: XbUiTokens.pageBackground(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 25),
          child: TVFocusable(
            borderRadius: radius,
            onPressed: _toggleTvTheme,
            child: ExcludeFocus(
              child: TextButton.icon(
                style: XbUiButton.textChipPrimary(context).copyWith(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
                onPressed: _toggleTvTheme,
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                label: Text(
                  l10n.switchTheme,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: XbFontWeight.semibold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleTvTheme() {
    final nextMode = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    ref.read(themeSettingProvider.notifier).updateState(
          (state) => state.copyWith(themeMode: nextMode),
        );
  }

  Widget _buildTvHomeBody() {
    return Container(
      color: XbUiTokens.pageBackground(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isShort = constraints.maxHeight < 620;
          final topInfoHeight = isShort ? 124.0 : 148.0;
          final horizontalPadding = constraints.maxWidth >= 1400 ? 33.0 : 25.0;
          final connectButtonSize = isShort ? 150.0 : 188.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              19,
              horizontalPadding,
              23,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: topInfoHeight,
                  child: _buildTvTopInfoSection(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildTvConnectionPanel(connectButtonSize),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 6,
                        child: _buildTvControlPanel(
                          isShort: isShort,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTvConnectionPanel(double connectButtonSize) {
    return Container(
      decoration: _tvCardDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Center(
              child: SizedBox.square(
                dimension: connectButtonSize,
                child: XBoardConnectButton(
                  isFloating: false,
                  outerSize: connectButtonSize,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildConnectionStatusRow(),
        ],
      ),
    );
  }

  Widget _buildTvControlPanel({
    required bool isShort,
  }) {
    final modeHeight = isShort ? 96.0 : 116.0;
    final nodeHeight = isShort ? 62.0 : 72.0;
    final accountHeight = isShort ? 70.0 : 82.0;
    const versionLineHeight = 20.0;
    final l10n = AppLocalizations.of(context);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: modeHeight,
          child: _buildTvModeCard(),
        ),
        const Spacer(),
        SizedBox(
          height: nodeHeight,
          child: const NodeSelectorBar(),
        ),
        const Spacer(),
        SizedBox(
          height: accountHeight,
          child: _buildTvAccountCard(),
        ),
        const Spacer(),
        SizedBox(
          height: versionLineHeight,
          child: Center(
            child: Text(
              '${l10n.xboardCurrentVersion}${chinese ? '：' : ': '}V${globalState.packageInfo.version}',
              key: const Key('tv-current-version'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.72),
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTvTopInfoSection() {
    final radius = BorderRadius.circular(XbUiTokens.radiusCard);
    final isRunning =
        ref.watch(runTimeProvider.select((state) => state != null));
    if (!isRunning) {
      return const _HomeNoticeCard();
    }
    return TVFocusable(
      borderRadius: radius,
      onPressed: _refreshTvSubscriptionInfo,
      child: ExcludeFocus(child: _buildUsageSection()),
    );
  }

  Future<void> _refreshTvSubscriptionInfo() async {
    if (_isRefreshingTvSubscription) return;
    setState(() => _isRefreshingTvSubscription = true);
    try {
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo(
            importProfile: false,
            source: 'TV 首页套餐卡片',
          );
    } finally {
      if (mounted) setState(() => _isRefreshingTvSubscription = false);
    }
  }

  Widget _buildTvModeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: _tvCardDecoration(context),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, size: 20, color: colorScheme.primary),
              const SizedBox(width: 9),
              Text(
                AppLocalizations.of(context).xboardProxyMode,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: XbFontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: XBoardOutboundMode(
              maxWidth: double.infinity,
              height: 44,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTvAccountCard() {
    return Consumer(
      builder: (context, ref, _) {
        final authState = ref.watch(xboardUserProvider);
        final userInfo = ref.watch(userInfoProvider);
        final subscriptionInfo = ref.watch(subscriptionInfoProvider);
        final email = authState.email?.trim().isNotEmpty == true
            ? authState.email!
            : userInfo?.email.trim().isNotEmpty == true
                ? userInfo!.email
                : subscriptionInfo?.email.trim().isNotEmpty == true
                    ? subscriptionInfo!.email
                    : AppLocalizations.of(context).account;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final l10n = AppLocalizations.of(context);
        final radius = BorderRadius.circular(XbUiTokens.radiusCard);
        void showLogoutDialog() => showDialog<void>(
              context: context,
              builder: (_) => const LogoutDialog(),
            );

        return Semantics(
          button: true,
          label: '${l10n.xboardAccountInfo}，$email，${l10n.xboardLogout}',
          child: TVFocusable(
            borderRadius: radius,
            onPressed: showLogoutDialog,
            child: ExcludeFocus(
              child: Container(
                decoration: _tvCardDecoration(context),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 24,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.xboardAccountInfo,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: XbFontWeight.semibold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: XbUiTokens.cardBorder(context),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.logout_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.xboardLogout,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _tvCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: XbUiCardStyle.background(context),
      borderRadius: BorderRadius.circular(XbUiTokens.radiusCard),
      border: Border.all(color: XbUiTokens.cardBorder(context)),
      boxShadow: XbUiCardStyle.shadowColor(context) == null
          ? null
          : [
              BoxShadow(
                color: XbUiCardStyle.shadowColor(context)!,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  Widget _buildTvLogoutButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);
    void showLogoutDialog() => showDialog<void>(
          context: context,
          builder: (_) => const LogoutDialog(),
        );

    return TVFocusable(
      borderRadius: radius,
      onPressed: showLogoutDialog,
      child: ExcludeFocus(
        child: OutlinedButton.icon(
          style: XbUiButton.outlinedNeutral(context).copyWith(
            foregroundColor:
                WidgetStatePropertyAll(colorScheme.onSurfaceVariant),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: radius),
            ),
          ),
          onPressed: showLogoutDialog,
          icon: const Icon(Icons.logout_outlined, size: 18),
          label: Text(l10n.xboardLogout),
        ),
      ),
    );
  }

  void _showVpnSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    Timer? closeTimer;
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight + 8, right: 8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: isDark
                ? Theme.of(context).colorScheme.surfaceContainer
                : Colors.white,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FastCatTunToggle(
                    onChanged: () {
                      closeTimer?.cancel();
                      closeTimer = Timer(const Duration(milliseconds: 500), () {
                        if (context.mounted &&
                            rootNavigator.mounted &&
                            ModalRoute.of(context)?.isCurrent == true) {
                          rootNavigator.pop();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() => closeTimer?.cancel());
  }

  Future<void> _openOfficialWebsite(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    setState(() => _isCheckingWebsite = true);

    final success = await WebsiteUrlResolver.openWithFallback(
      primaryUrls: XBoardConfig.websiteUrls,
      fallbackLocalUrl: () => ConfigFileLoaderHelper.getFallbackWebsiteUrl(),
      fallbackApiUrl: () async {
        try {
          final sdk = await ref.read(xboardSdkProvider.future);
          final resp = await sdk.httpService.getRequest('/guest/comm/config');
          final data = resp['data'] as Map<String, dynamic>?;
          return data?['app_url'] as String? ?? '';
        } catch (_) {
          return '';
        }
      },
    );

    setState(() => _isCheckingWebsite = false);

    if (!success && mounted) {
      XBoardNotification.showError(l10n.cannotGetWebUrl);
    }
  }

  Widget _buildTopInfoSection() {
    return Consumer(
      builder: (context, ref, _) {
        final isRunning = ref.watch(runTimeProvider.select((s) => s != null));
        return isRunning ? _buildUsageSection() : const _HomeNoticeCard();
      },
    );
  }

  Widget _buildUsageSection() {
    return Consumer(
      builder: (context, ref, child) {
        final isDesktop =
            Platform.isLinux || Platform.isWindows || Platform.isMacOS;
        final userInfo = ref.watch(userInfoProvider);
        final subscriptionInfo = ref.watch(subscriptionInfoProvider);
        final currentProfile = ref.watch(currentProfileProvider);

        // Use profile's Subscription-Userinfo headers when available.
        // Fall back to XBoard API data (subscriptionInfo) when the Mihomo profile
        // doesn't include Subscription-Userinfo response headers, or when the
        // profile hasn't been imported yet. Only synthesize if the user has an
        // active plan (planId > 0) to avoid showing valid status for no-plan users.
        fl_models.SubscriptionInfo? profileSubscriptionInfo =
            currentProfile?.subscriptionInfo;
        if (profileSubscriptionInfo == null &&
            subscriptionInfo != null &&
            subscriptionInfo.planId > 0) {
          profileSubscriptionInfo = fl_models.SubscriptionInfo(
            upload: subscriptionInfo.uploadedBytes,
            download: subscriptionInfo.downloadedBytes,
            total: subscriptionInfo.transferLimit,
            expire: subscriptionInfo.expiredAt != null
                ? subscriptionInfo.expiredAt!.millisecondsSinceEpoch ~/ 1000
                : 0,
          );
        }

        return SubscriptionUsageCard(
          subscriptionInfo: subscriptionInfo,
          userInfo: userInfo,
          profileSubscriptionInfo: profileSubscriptionInfo,
          showActions: false,
          usePlainBackground: true,
          prefixUsedTraffic: true,
          fixedHeight: isDesktop ? 136 : 148,
          isSyncing: system.isTV && _isRefreshingTvSubscription,
        );
      },
    );
  }

  Widget _buildConnectionStatusRow() {
    return SizedBox(
      height: 40,
      child: Center(
        child: _buildStatusText(),
      ),
    );
  }

  Widget _buildStatusText() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 38,
      child: ValueListenableBuilder<bool>(
        valueListenable: globalState.coreStatusReadyNotifier,
        builder: (context, isCoreStatusReady, _) {
          if (!isCoreStatusReady) {
            return ValueListenableBuilder<bool>(
              valueListenable: globalState.coreStatusRecoveringNotifier,
              builder: (context, isRecovering, _) => Center(
                child: Text(
                  isRecovering
                      ? AppLocalizations.of(context).xboardServiceRecovering
                      : AppLocalizations.of(context).xboardInitializing,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: XbFontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }
          return Consumer(
            builder: (_, ref, __) {
              final runTime = ref.watch(runTimeProvider);
              final isRunning = runTime != null;

              if (!isRunning) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context).notConnected,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          // fontSize inherited from titleSmall
                          fontWeight: XbFontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                );
              }

              return Center(
                child: Text(
                  AppLocalizations.of(context).connected,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        // fontSize inherited from titleSmall
                        fontWeight: XbFontWeight.bold,
                        color: isDark
                            ? Colors.green.shade300
                            : Colors.green.shade700,
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 等待订阅导入完成后再检查订阅状态（备用方案）
  /// 如果3秒后还没有触发导入完成监听器，则主动检查
  void _waitForSubscriptionImportThenCheck() async {
    await Future.delayed(const Duration(seconds: 3));

    // 如果已经通过监听器检查过了，就不再检查
    if (_hasCheckedSubscriptionStatus) {
      return;
    }

    _hasCheckedSubscriptionStatus = true;
    if (mounted) {
      subscriptionStatusChecker.checkSubscriptionStatusOnStartup(context, ref);
    }
  }

  void _showTokenExpiredDialog(String failureCode) {
    if (!mounted) return;
    if (_isTokenExpiredDialogVisible) return;
    if (!ref.read(xboardUserProvider).isAuthenticated) {
      ref.read(xboardUserProvider.notifier).clearTokenExpiredError();
      return;
    }
    _isTokenExpiredDialogVisible = true;
    // 保存外层页面 context 的 navigator 和 router，弹窗 pop 后弹窗 context 已失效
    final outerContext = context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          final latestCode = dialogRef.watch(
                xboardUserProvider.select((state) => state.errorMessage),
              ) ??
              failureCode;
          final appLocalizations = AppLocalizations.of(context);
          final (dialogTitle, dialogContent) = switch (latestCode) {
            SessionTerminationCode.deviceKickedByNewLogin => (
                appLocalizations.xboardDeviceKickedTitle,
                appLocalizations.xboardDeviceKickedContent,
              ),
            SessionTerminationCode.deviceRevoked => (
                appLocalizations.xboardDeviceSessionRevokedTitle,
                appLocalizations.xboardDeviceSessionRevokedContent,
              ),
            _ => (
                appLocalizations.xboardTokenExpiredTitle,
                appLocalizations.xboardTokenExpiredContent,
              ),
          };
          return PopScope(
            canPop: false,
            child: _TokenExpiredDialog(
              title: dialogTitle,
              content: dialogContent,
              actionLabel: appLocalizations.xboardRelogin,
              onRelogin: () async {
                final userNotifier =
                    dialogRef.read(xboardUserProvider.notifier);
                await userNotifier.handleTokenExpired();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
                if (outerContext.mounted) {
                  GoRouter.of(outerContext).go('/login');
                }
              },
            ),
          );
        },
      ),
    ).whenComplete(() {
      _isTokenExpiredDialogVisible = false;
      if (mounted) {
        ref.read(xboardUserProvider.notifier).clearTokenExpiredError();
      }
    });
  }
}
