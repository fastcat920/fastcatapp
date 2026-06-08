import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart' as fl_models;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_clash/l10n/l10n.dart';

import 'package:fl_clash/xboard/features/shared/shared.dart';
import 'package:fl_clash/xboard/features/notice/notice.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_checker.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_guard_service.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/config/utils/website_url_resolver.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import '../widgets/subscription_usage_card.dart';
import '../widgets/xboard_connect_button.dart';

class XBoardHomePage extends ConsumerStatefulWidget {
  const XBoardHomePage({super.key});
  @override
  ConsumerState<XBoardHomePage> createState() => _XBoardHomePageState();
}

class _XBoardHomePageState extends ConsumerState<XBoardHomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  void deactivate() {
    super.deactivate();
  }

  bool _hasInitialized = false;
  bool _hasCheckedSubscriptionStatus = false;
  bool _hasRequestedStartupLatencyTest = false;
  bool _isTokenExpiredDialogVisible = false;
  bool _isCheckingWebsite = false;

  @override
  bool get wantKeepAlive => true; // 保持页面状态，防止重建

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasInitialized) return;
      _hasInitialized = true;
      final userState = ref.read(xboardUserProvider);
      if (userState.isAuthenticated) {
        // 等待订阅导入完成后再检查订阅状态
        _waitForSubscriptionImportThenCheck();
      }
      autoLatencyService.initialize(ref);
      _scheduleStartupLatencyTest();
      // 主动拉取公告，保证铃铛和 Banner 都能显示数据
      ref.read(noticeProvider.notifier).fetchNotices();
    });
    ref.listenManual(xboardUserProvider, (previous, next) {
      if (next.isAuthenticated && next.errorMessage == 'TOKEN_EXPIRED') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTokenExpiredDialog();
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
            _scheduleStartupLatencyTest();
          }
        });
      }
    });

    ref.listenManual(groupsProvider, (previous, next) {
      if (next.isNotEmpty) {
        _scheduleStartupLatencyTest();
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
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，配合 AutomaticKeepAliveClientMixin

    // TV/投影仪虽然常是横屏，但首页按紧凑遥控器布局处理。
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final isTvHome = system.isTV;
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompactMobileHome =
        isTvHome || (!isDesktop && mediaSize.height < 640);

    return Scaffold(
      appBar: isDesktop || isCompactMobileHome
          ? null
          : AppBar(
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
            ),
      body: Consumer(
        builder: (_, ref, __) {
          const horizontalPadding = 16.0;
          final topInfoSlotHeight = isDesktop ? 136.0 : 148.0;

          return Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surface
                : const Color(0xFFFAFBFD),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 桌面端：响应式最大宽度
                  final contentMaxWidth = double.infinity;

                  final compactMode =
                      isTvHome || (!isDesktop && constraints.maxHeight < 560);
                  final isLandscapeHome =
                      constraints.maxWidth > constraints.maxHeight;
                  final isPortraitHome =
                      constraints.maxHeight >= constraints.maxWidth;
                  final showTopInfo = !compactMode;
                  final topInfoTopGap = isDesktop ? 0.0 : 12.0;
                  final shouldCompactConnectButton =
                      compactMode || isLandscapeHome;
                  final connectButtonScale =
                      shouldCompactConnectButton ? 0.9 : 1.0;
                  final connectButtonSize = 151.2 * connectButtonScale;
                  final buttonSlotHeight = 168.0 * connectButtonScale;
                  const connectionStatusGap = 5.0;
                  const statusRowHeight = 36.0;
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
                  final targetTopGap =
                      availableGap * (compactMode ? 0.28 : 0.36);
                  final adaptiveTopGap = targetTopGap < minTopGapForLowerHalf
                      ? minTopGapForLowerHalf
                      : targetTopGap;
                  final adaptiveBottomGap =
                      minBottomGap + (availableGap - adaptiveTopGap);

                  // 纯 Flex 布局：优先保留连接按钮、模式切换和线路选择。
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: contentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isDesktop && !compactMode)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  horizontalPadding, 6, horizontalPadding, 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const _HomeBrandHeader(),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        style:
                                            XbUiButton.textChipPrimary(context),
                                        icon: _isCheckingWebsite
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              )
                                            : Icon(
                                                Icons.language_outlined,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                        label: Text(
                                          _isCheckingWebsite
                                              ? AppLocalizations.of(context)
                                                  .checking
                                              : AppLocalizations.of(context)
                                                  .officialWebsite,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        onPressed: _isCheckingWebsite
                                            ? null
                                            : () =>
                                                _openOfficialWebsite(context),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.menu_open,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        tooltip: 'TUN',
                                        onPressed: () => _showVpnSheet(context),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          if (isDesktop && !compactMode)
                            const SizedBox(height: 2),
                          // ── 未连接显示公告，已连接显示套餐信息。空间不足时隐藏，优先保留主操作区。 ──
                          if (showTopInfo)
                            if (isDesktop)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: horizontalPadding,
                                    right: horizontalPadding,
                                    top: 0),
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
                          // ── 节点选择器保持在下方，作为最后的线路切换入口 ──
                          const SizedBox(height: sectionGap),
                          const SizedBox(
                            height: nodeSelectorHeight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding),
                              child: NodeSelectorBar(),
                            ),
                          ),
                          SizedBox(height: nodeBottomInset),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showVpnSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
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
                children: const [
                  TUNItem(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openOfficialWebsite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.cannotGetWebUrl),
        ),
      );
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
        );
      },
    );
  }

  Widget _buildConnectionStatusRow() {
    return SizedBox(
      height: 36,
      child: Center(
        child: _buildStatusText(),
      ),
    );
  }

  Widget _buildStatusText() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 34,
      child: Consumer(
        builder: (_, ref, __) {
          final runTime = ref.watch(runTimeProvider);
          final isRunning = runTime != null;

          if (!isRunning) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).notConnected,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).tapToConnect,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                ),
              ],
            );
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).connected,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.green.shade300
                          : Colors.green.shade700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                utils.getTimeText(runTime),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
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

  void _scheduleStartupLatencyTest() {
    if (_hasRequestedStartupLatencyTest) return;
    if (ref.read(groupsProvider).isEmpty) return;

    _hasRequestedStartupLatencyTest = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      autoLatencyService.initialize(ref);
      autoLatencyService.testCurrentGroupNodes(maxNodes: 999);
    });
  }

  void _showTokenExpiredDialog() {
    if (!mounted) return;
    if (_isTokenExpiredDialogVisible) return;
    if (!ref.read(xboardUserProvider).isAuthenticated) {
      ref.read(xboardUserProvider.notifier).clearTokenExpiredError();
      return;
    }
    _isTokenExpiredDialogVisible = true;
    final appLocalizations = AppLocalizations.of(context);
    // 保存外层页面 context 的 navigator 和 router，弹窗 pop 后弹窗 context 已失效
    final outerContext = context;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(appLocalizations.xboardTokenExpiredTitle),
        content: Text(appLocalizations.xboardTokenExpiredContent),
        actions: [
          TextButton(
            onPressed: () async {
              final userNotifier = ref.read(xboardUserProvider.notifier);
              // 先关闭对话框
              if (dialogContext.mounted) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              }
              // 清除错误状态
              userNotifier.clearTokenExpiredError();
              // 处理 Token 过期（清除数据）
              await userNotifier.handleTokenExpired();
              // 使用外层 context 导航到登录页（弹窗 context 已被 pop 销毁）
              if (outerContext.mounted) {
                GoRouter.of(outerContext).go('/login');
              }
            },
            child: Text(appLocalizations.xboardRelogin),
          ),
        ],
      ),
    ).whenComplete(() {
      _isTokenExpiredDialogVisible = false;
      if (mounted) {
        ref.read(xboardUserProvider.notifier).clearTokenExpiredError();
      }
    });
  }
}

class _HomeBrandHeader extends ConsumerWidget {
  const _HomeBrandHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(initializationProvider);
    final userState = ref.watch(xboardUserProvider);
    final showOfflineBadge = initState.isFailed && userState.isAuthenticated;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/icon.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          appName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showOfflineBadge) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.28)
                  : const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? theme.colorScheme.error.withValues(alpha: 0.45)
                    : const Color(0xFFFFD08A),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_outlined,
                  size: 12,
                  color: isDark
                      ? theme.colorScheme.onSurface
                      : const Color(0xFF8A5A00),
                ),
                const SizedBox(width: 4),
                Text(
                  '离线缓存模式',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurface
                        : const Color(0xFF8A5A00),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeNoticeCard extends ConsumerStatefulWidget {
  const _HomeNoticeCard();

  @override
  ConsumerState<_HomeNoticeCard> createState() => _HomeNoticeCardState();
}

class _HomeNoticeCardState extends ConsumerState<_HomeNoticeCard> {
  Timer? _timer;
  late final PageController _pageController;
  int _index = 0;
  int _noticeCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _syncTimer(int count) {
    if (_noticeCount == count) return;
    _noticeCount = count;
    if (_index >= count) _index = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_index);
    }
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final nextIndex = (_index + 1) % count;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        setState(() => _index = nextIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final noticeState = ref.watch(noticeProvider);
    final notices = noticeState.visibleNotices;
    _syncTimer(notices.length);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    final card = Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.18)
              : const Color(0xFFEEF0F4),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: notices.isEmpty
              ? null
              : () {
                  final notice = notices[_index];
                  showDialog(
                    context: context,
                    builder: (_) => NoticeDetailDialog(
                      notices: [notice],
                    ),
                  );
                },
          child: SizedBox(
            height: 136,
            child: Stack(
              children: [
                notices.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: _NoticeCardContent(
                          title: '暂无公告',
                          content: '当前没有最新公告',
                          isLoading: noticeState.isLoading,
                          colorScheme: colorScheme,
                          theme: theme,
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: notices.length,
                        onPageChanged: (index) =>
                            setState(() => _index = index),
                        itemBuilder: (context, index) {
                          final notice = notices[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: _NoticeCardContent(
                              title: notice.title.trim().isNotEmpty
                                  ? notice.title
                                  : '暂无公告',
                              content: _plainNoticeContent(notice.content),
                              dateText: _formatNoticeDate(notice.createdAt),
                              colorScheme: colorScheme,
                              theme: theme,
                            ),
                          );
                        },
                      ),
                if (notices.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: _buildNoticeIndicators(
                      count: notices.length,
                      activeIndex: _index,
                      colorScheme: colorScheme,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      height: isDesktop ? 136 : 148,
      child: card,
    );
  }

  String _plainNoticeContent(String content) {
    final normalized = content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? '点击查看公告详情' : normalized;
  }

  String _formatNoticeDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildNoticeIndicators({
    required int count,
    required int activeIndex,
    required ColorScheme colorScheme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: index == activeIndex ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: index == activeIndex
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _NoticeCardContent extends StatelessWidget {
  final String title;
  final String content;
  final String dateText;
  final bool isLoading;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _NoticeCardContent({
    required this.title,
    required this.content,
    required this.colorScheme,
    required this.theme,
    this.dateText = '',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.campaign_outlined,
                color: colorScheme.primary,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (dateText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                dateText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
