import 'dart:async';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/boot_diag.dart';
import 'package:fl_clash/common/macos_startup_diagnostics.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/hotkey_manager.dart';
import 'package:fl_clash/manager/manager.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import 'controller.dart';
import 'xboard/xboard.dart';
import 'package:fl_clash/xboard/core/logger/capture_logger.dart'
    show CaptureLogger, mapFastcatLogLevel;
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/router/app_router.dart' as xboard_router;
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/xboard/features/auth/utils/customer_service_helper.dart';
import 'package:fl_clash/xboard/features/auth/services/device_heartbeat_service.dart';
import 'package:fl_clash/xboard/features/connectivity/connectivity.dart';

class Application extends ConsumerStatefulWidget {
  const Application({
    super.key,
  });

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application>
    with WidgetsBindingObserver {
  static const _fontFamilyFallback = [
    'Noto Sans CJK SC',
    'Noto Sans CJK',
    'Noto Sans SC',
    'Source Han Sans SC',
    'WenQuanYi Micro Hei',
    'Microsoft YaHei',
    'PingFang SC',
    'Arial Unicode MS',
    'sans-serif',
  ];

  Timer? _autoUpdateProfilesTaskTimer;
  Timer? _customerServicePrewarmTimer;
  Timer? _mobileLogRecoveryTimer;
  Timer? _automaticUpdateRetryTimer;
  StreamSubscription<Map<String, dynamic>>? _updateConfigSubscription;
  bool _automaticUpdateCheckInFlight = false;
  bool _automaticUpdateCheckPending = false;
  int _automaticUpdateRetryIndex = 0;
  String? _lastAutomaticUpdateSignature;
  // Router 只创建一次，通过 refresh() 触发 redirect 重新求值
  // 避免每次 auth 状态变化都重建 GoRouter 导致 StatefulShellRoute 重置（Windows 空白屏）
  late final GoRouter _router;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CommonPageTransitionsBuilder(),
      TargetPlatform.iOS: CommonPageTransitionsBuilder(),
      TargetPlatform.windows: CommonPageTransitionsBuilder(),
      TargetPlatform.linux: CommonPageTransitionsBuilder(),
      TargetPlatform.macOS: CommonPageTransitionsBuilder(),
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) {
    return ref.read(genColorSchemeProvider(brightness));
  }

  Brightness _effectiveBrightness(
    ThemeMode themeMode,
    Brightness? platformBrightness,
  ) {
    return switch (themeMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => platformBrightness ??
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }

  WidgetStateProperty<MouseCursor?> get _clickableMouseCursor =>
      WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click;
      });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CustomerServiceHelper.ensureAndroidBackHandlerRegistered();
    _autoUpdateProfilesTask();
    globalState.appController = AppController(context, ref);
    unawaited(
      XBoardDeviceHeartbeatService.markActive(reason: 'app_start'),
    );

    // Router 只创建一次，redirect 每次都从 Riverpod 读取最新 auth 状态
    _router = GoRouter(
      navigatorKey: globalState.navigatorKey,
      initialLocation: '/',
      routes: xboard_router.routes,
      redirect: (context, state) {
        final userState = ref.read(xboardUserProvider);
        final isAuthenticated = userState.isAuthenticated;
        final isInitialized = userState.isInitialized;
        final path = state.uri.path;
        final isLoginPage = path == '/login';

        // 未初始化时留在登录页（Widget 层的加载遮罩盖在上方，用户不会看到登录页）
        if (!isInitialized) return '/login';
        if (!isAuthenticated && !isLoginPage) return '/login';
        if (isAuthenticated && isLoginPage) return '/';
        return null;
      },
    );
    _setupRootListeners();
    unawaited(_restoreUpdateStateAndInitializeCheck());

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      unawaited(bootDiagLog('flutter first frame callback reached'));
      unawaited(MacOSStartupDiagnostics.markFirstFrame());
      final currentContext = globalState.navigatorKey.currentContext;
      if (currentContext != null) {
        globalState.appController = AppController(currentContext, ref);
      }

      // ✅ 后台预热：统一初始化服务（不阻塞 UI）
      // 放到首帧之后，避免在 initState/build 生命周期内修改 provider。
      unawaited(() async {
        try {
          await ref.read(initializationProvider.notifier).initialize();
        } catch (e) {
          // 初始化失败，登录页会处理
          debugPrint('[Application] 预热初始化失败: $e');
        }
      }());

      // ✅ 立即发起快速认证（不等待 clash core 初始化）
      // quickAuth() 只读 SharedPreferences，与 appController.init() 并发执行
      // 这样 loading 页面能在 <200ms 内消失，不受 clash core 启动耗时影响
      _performQuickAuthWithDomainService();

      await globalState.appController.init();
      await bootDiagLog(
        'app controller initialization complete',
      );
      globalState.appController.initLink();
      app?.initShortcuts();

      // 恢复日志捕获设置，并同步当前日志等级
      if (ref.read(appSettingProvider).logCapture) {
        final currentLogLevel = ref.read(patchClashConfigProvider).logLevel;
        XBoardLogger.setLogger(
          CaptureLogger(minLevel: mapFastcatLogLevel(currentLogLevel)),
        );
        // 联动：确保核心日志推送也开启
        if (!ref.read(appSettingProvider).openLogs) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(openLogs: true),
              );
        }
      }

      _scheduleCustomerServicePrewarm();
    });
  }

  void _setupRootListeners() {
    void syncDeviceHeartbeat() {
      final isAuthenticated = ref.read(xboardUserProvider).isAuthenticated;
      final isConnected = ref.read(runTimeProvider) != null;
      if (isAuthenticated && isConnected) {
        XBoardDeviceHeartbeatService.startPeriodic();
      } else {
        XBoardDeviceHeartbeatService.stopPeriodic();
      }
    }

    ref.listenManual(
      serviceConnectivityProvider,
      (previous, next) {
        final recoveredFromOffline = previous?.isOffline == true ||
            (previous?.isRecovering == true &&
                (previous?.consecutiveFailures ?? 0) >= 2);
        if (next.isOnline && recoveredFromOffline) {
          unawaited(_refreshRemoteDataAfterRecovery());
        }
      },
      fireImmediately: true,
    );

    ref.listenManual(
      appSettingProvider.select((s) => s.logCapture),
      (_, next) {
        if (next) {
          final currentLogLevel = ref.read(patchClashConfigProvider).logLevel;
          XBoardLogger.setLogger(
            CaptureLogger(minLevel: mapFastcatLogLevel(currentLogLevel)),
          );
        } else {
          XBoardLogger.reset();
        }
      },
      fireImmediately: true,
    );

    ref.listenManual(
      patchClashConfigProvider.select((s) => s.logLevel),
      (_, next) {
        final logger = XBoardLogger.instance;
        if (logger is CaptureLogger) {
          logger.minLevel = mapFastcatLogLevel(next);
        }
      },
      fireImmediately: true,
    );

    ref.listenManual(
      xboardUserProvider,
      (previous, next) {
        if (previous?.isAuthenticated != true && next.isAuthenticated) {
          _scheduleCustomerServicePrewarm();
          unawaited(
            XBoardDeviceHeartbeatService.markActive(
              reason: 'auth_ready',
              force: true,
            ),
          );
        }
        if (previous?.isAuthenticated != next.isAuthenticated ||
            previous?.isInitialized != next.isInitialized) {
          syncDeviceHeartbeat();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _router.refresh();
            }
          });
        }
      },
    );

    ref.listenManual(
      runTimeProvider,
      (_, __) => syncDeviceHeartbeat(),
      fireImmediately: true,
    );

    // 监听公告弹窗：popupNoticeId 非 null 时自动弹出
    ref.listenManual(
      noticeProvider.select((s) => s.popupNoticeId),
      (_, next) {
        if (next == null) return;
        final noticeId = next;
        final state = ref.read(noticeProvider);
        final notice = state.notices.firstWhere(
          (n) => n.id == noticeId,
          orElse: () => state.notices.first,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = globalState.navigatorKey.currentContext;
          if (ctx == null) return;
          final previousFocus = TvFocusRestoration.capture();
          showDialog(
            context: ctx,
            builder: (_) => NoticeDetailDialog(
              notices: [notice],
              onDismiss: () {
                ref.read(noticeProvider.notifier).markPopupShown(noticeId);
              },
            ),
          ).whenComplete(() {
            final restoreContext = globalState.navigatorKey.currentContext;
            if (restoreContext != null && restoreContext.mounted) {
              TvFocusRestoration.restore(restoreContext, previousFocus);
            }
          });
        });
      },
    );
  }

  void _scheduleCustomerServicePrewarm() {
    _customerServicePrewarmTimer?.cancel();
    if (!ref.read(xboardUserProvider).isAuthenticated) return;
    _customerServicePrewarmTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !ref.read(xboardUserProvider).isAuthenticated) return;
      CustomerServiceHelper.prewarm();
    });
  }

  Future<void> _refreshRemoteDataAfterRecovery() async {
    final userState = ref.read(xboardUserProvider);
    if (!userState.isAuthenticated) return;
    try {
      await ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo(
            importProfile: false,
          );
    } catch (error) {
      debugPrint('[Application] 网络恢复后刷新订阅信息失败: $error');
    }
    try {
      await ref.read(xboardSubscriptionProvider.notifier).refreshPlans();
    } catch (error) {
      debugPrint('[Application] 网络恢复后刷新套餐失败: $error');
    }
    try {
      await ref.read(noticeProvider.notifier).fetchNotices(forceRefresh: true);
    } catch (error) {
      debugPrint('[Application] 网络恢复后刷新公告失败: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      globalState.appBackgroundedAt ??= DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = globalState.appBackgroundedAt;
      globalState.appBackgroundedAt = null;
      if (backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >=
              const Duration(seconds: 5)) {
        // 移动系统可能已挂起网络、DNS 或 VPN IPC。给恢复后的首次测速
        // 一个短暂的内核就绪保护窗口，避免整批误判超时。
        globalState.latencyWarmupUntil =
            DateTime.now().add(const Duration(seconds: 15));
      }
      unawaited(
        ref.read(serviceConnectivityProvider.notifier).verifyNow(),
      );
      unawaited(
        XBoardDeviceHeartbeatService.markActive(
          reason: 'app_resumed',
          force: true,
        ),
      );
      if (_updateConfigSubscription == null) {
        unawaited(_initializeAutomaticUpdateCheck());
      } else {
        unawaited(_runAutomaticUpdateCheck(reason: 'app_resumed'));
      }
      _restoreMobileCoreLogging();
    }
  }

  /// Android may suspend the isolate/core message callback while the app is in
  /// the background. Re-arming the listener is idempotent and keeps non-app
  /// log levels available when the user has selected them in the log page.
  void _restoreMobileCoreLogging() {
    if (!Platform.isAndroid || !ref.read(appSettingProvider).openLogs) return;
    clashCore.startLog();
    _mobileLogRecoveryTimer?.cancel();
    _mobileLogRecoveryTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted || !ref.read(appSettingProvider).openLogs) return;
      clashCore.startLog();
    });
  }

  /// 使用新域名服务架构进行快速认证检查
  void _performQuickAuthWithDomainService() {
    // quickAuth() 直接读取 SharedPreferences，不依赖 SDK 是否初始化
    // 完成后 xboardUserProvider 状态变化，Consumer 自动重建，无需 setState
    unawaited(() async {
      try {
        debugPrint('[Application] 开始快速认证检查...');
        await ref.read(xboardUserProvider.notifier).quickAuth();
        debugPrint('[Application] 快速认证检查完成');
      } catch (e) {
        debugPrint('[Application] 快速认证检查失败: $e');
      }
    }());
  }

  Future<void> _restoreUpdateStateAndInitializeCheck() async {
    try {
      await ref.read(updateCheckProvider.notifier).restoreCachedUpdate();
    } catch (error) {
      debugPrint('[Application] 恢复本地更新提示失败: $error');
    }
    // 上次已由 OSS 确认的普通更新可在首帧后立即提示，
    // 不必再等待本次远程配置下载。后台检查仍会继续校正缓存。
    final cachedUpdate = ref.read(updateCheckProvider);
    if (mounted &&
        ref.read(appSettingProvider).autoCheckUpdate &&
        cachedUpdate.hasUpdate) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        await _showAutomaticUpdateDialog(ref.read(updateCheckProvider));
      }
    }
    if (mounted) await _initializeAutomaticUpdateCheck();
  }

  /// 配置就绪后再检查更新，避免固定延时早于 OSS 配置加载完成。
  Future<void> _initializeAutomaticUpdateCheck() async {
    for (var attempt = 0;
        mounted && !XBoardConfig.isInitialized && attempt < 100;
        attempt++) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    if (!XBoardConfig.isInitialized) {
      debugPrint('[Application] 更新配置模块尚未初始化，安排兜底重试');
      _scheduleAutomaticUpdateRetry('config_module_not_ready');
      return;
    }

    _updateConfigSubscription ??= XBoardConfig.configChangeStream.listen(
      (_) {
        _automaticUpdateRetryIndex = 0;
        _automaticUpdateRetryTimer?.cancel();
        unawaited(_runAutomaticUpdateCheck(reason: 'config_changed'));
      },
      onError: (Object error) {
        debugPrint('[Application] 更新配置监听异常: $error');
        _scheduleAutomaticUpdateRetry('config_stream_error');
      },
      onDone: () {
        _updateConfigSubscription = null;
        if (mounted) unawaited(_initializeAutomaticUpdateCheck());
      },
    );

    // 初始化模块可能在监听建立前已载入缓存或远程配置，立即检查一次。
    await _runAutomaticUpdateCheck(reason: 'config_available');
  }

  String? _currentUpdateConfigSignature() {
    final config = XBoardConfig.updateConfig;
    if (config == null || config.isEmpty) return null;
    final platform = switch (Platform.operatingSystem) {
      'android' => 'android',
      'ios' => 'ios',
      'windows' => 'windows',
      'macos' => 'macos',
      'linux' => 'linux',
      _ => 'unknown',
    };
    final info = config.platformInfo(platform);
    if (info == null || info.version.trim().isEmpty) return null;
    return [
      platform,
      info.version.trim(),
      info.url.trim(),
      info.force,
      config.minVersion?.trim() ?? '',
    ].join('|');
  }

  void _scheduleAutomaticUpdateRetry(String reason) {
    if (!mounted || !ref.read(appSettingProvider).autoCheckUpdate) return;
    const delays = [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ];
    if (_automaticUpdateRetryIndex >= delays.length) {
      debugPrint('[Application] 自动更新检查已达到重试上限: $reason');
      return;
    }
    final delay = delays[_automaticUpdateRetryIndex++];
    _automaticUpdateRetryTimer?.cancel();
    debugPrint(
      '[Application] ${delay.inSeconds} 秒后重试自动更新检查: $reason',
    );
    _automaticUpdateRetryTimer = Timer(delay, () {
      if (!mounted) return;
      if (_updateConfigSubscription == null) {
        unawaited(_initializeAutomaticUpdateCheck());
      } else {
        unawaited(_runAutomaticUpdateCheck(reason: 'retry'));
      }
    });
  }

  Future<void> _runAutomaticUpdateCheck({required String reason}) async {
    if (!mounted) return;
    if (!ref.read(appSettingProvider).autoCheckUpdate) {
      debugPrint('[Application] 自动检查更新已关闭');
      return;
    }
    final updateNotifier = ref.read(updateCheckProvider.notifier);
    if (updateNotifier.isInteractiveCheckInFlight) {
      debugPrint('[Application] 手动更新检查正在进行，跳过本次自动检查');
      return;
    }
    if (!XBoardConfig.isInitialized) {
      _scheduleAutomaticUpdateRetry('config_module_not_ready');
      return;
    }

    final signature = _currentUpdateConfigSignature();
    if (signature == null) {
      _scheduleAutomaticUpdateRetry('platform_update_config_not_ready');
      return;
    }
    if (signature == _lastAutomaticUpdateSignature) return;
    if (_automaticUpdateCheckInFlight) {
      _automaticUpdateCheckPending = true;
      return;
    }

    _automaticUpdateCheckInFlight = true;
    try {
      debugPrint('[Application] 开始自动检查更新: $reason');
      await updateNotifier.checkForUpdates();
      if (!mounted) return;
      if (updateNotifier.isInteractiveCheckInFlight) {
        debugPrint('[Application] 手动检查已接管更新结果展示');
        return;
      }

      final updateState = ref.read(updateCheckProvider);
      if (updateState.error != null) {
        debugPrint('[Application] 自动更新检查失败: ${updateState.error}');
        _scheduleAutomaticUpdateRetry('check_failed');
        return;
      }

      if (!updateState.hasUpdate) {
        _lastAutomaticUpdateSignature = signature;
        _automaticUpdateRetryIndex = 0;
        _automaticUpdateRetryTimer?.cancel();
        debugPrint('[Application] 已是最新版本');
        return;
      }

      final shown = await _showAutomaticUpdateDialog(updateState);
      if (shown) {
        _lastAutomaticUpdateSignature = signature;
      }
      if (!shown) {
        _scheduleAutomaticUpdateRetry('dialog_context_not_ready');
      } else {
        _automaticUpdateRetryIndex = 0;
        _automaticUpdateRetryTimer?.cancel();
      }
    } catch (error) {
      debugPrint('[Application] 自动更新检查异常: $error');
      _scheduleAutomaticUpdateRetry('unexpected_error');
    } finally {
      _automaticUpdateCheckInFlight = false;
      if (_automaticUpdateCheckPending && mounted) {
        _automaticUpdateCheckPending = false;
        unawaited(_runAutomaticUpdateCheck(reason: 'pending_config_change'));
      }
    }
  }

  Future<bool> _showAutomaticUpdateDialog(UpdateCheckState updateState) async {
    final cacheService = ref.read(updateCacheServiceProvider);
    final latestVersion = updateState.latestVersion?.trim() ?? '';
    if (!updateState.forceUpdate) {
      final lastPromptedVersion =
          await cacheService.getPromptedOptionalVersion();
      if (latestVersion.isNotEmpty && lastPromptedVersion == latestVersion) {
        debugPrint(
          '[Application] 普通更新 V$latestVersion 已提示过，仅保留红点',
        );
        return true;
      }
    }

    if (!mounted) return false;
    final currentContext = globalState.navigatorKey.currentContext;
    if (currentContext == null || !currentContext.mounted) return false;

    debugPrint(updateState.forceUpdate
        ? '[Application] 发现强制更新，显示不可关闭弹窗'
        : '[Application] 首次发现普通更新，显示一次更新弹窗');
    final previousFocus = TvFocusRestoration.capture();
    final dialogFuture = showDialog<void>(
      context: currentContext,
      barrierDismissible: !updateState.forceUpdate,
      builder: (context) => UpdateDialog(state: updateState),
    );

    // 路由成功入栈后才记录，避免上下文不可用时误标记为已提示。
    if (!updateState.forceUpdate && latestVersion.isNotEmpty) {
      await cacheService.markOptionalVersionPrompted(latestVersion);
    }
    unawaited(dialogFuture.whenComplete(() {
      final restoreContext = globalState.navigatorKey.currentContext;
      if (restoreContext != null && restoreContext.mounted) {
        TvFocusRestoration.restore(restoreContext, previousFocus);
      }
    }));
    return true;
  }

  _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await globalState.appController.autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  _buildPlatformState(Widget child) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(
            child: ProxyManager(
              child: child,
            ),
          ),
        ),
      );
    }
    return AndroidManager(
      child: TileManager(
        child: child,
      ),
    );
  }

  _buildState(Widget child) {
    return AppStateManager(
      child: ClashManager(
        child: ConnectivityManager(
          onConnectivityChanged: (results) async {
            globalState.appController.handleConnectivityChanged(results);
          },
          child: child,
        ),
      ),
    );
  }

  _buildPlatformApp(Widget child) {
    if (system.isDesktop) {
      return WindowHeaderContainer(
        child: child,
      );
    }
    return VpnManager(
      child: child,
    );
  }

  _buildApp(Widget child) {
    return Consumer(
      builder: (context, ref, _) {
        final isAuthenticated = ref.watch(
          xboardUserProvider.select((state) => state.isAuthenticated),
        );
        return ValueListenableBuilder<RouteInformation>(
          valueListenable: _router.routeInformationProvider,
          builder: (context, routeInformation, _) => MessageManager(
            rootNavigationVisible: isAuthenticated &&
                _isRootNavigationRoute(routeInformation.uri.path),
            child: ThemeManager(
              child: child,
            ),
          ),
        );
      },
    );
  }

  bool _isRootNavigationRoute(String path) {
    if (path == '/') return true;
    final firstSegment = Uri.tryParse(path)?.pathSegments.firstOrNull;
    return const {'plans', 'invite', 'mine', 'logs'}.contains(firstSegment);
  }

  @override
  Widget build(context) {
    return _buildPlatformState(
      _buildState(
        Consumer(
          builder: (_, ref, child) {
            final locale =
                ref.watch(appSettingProvider.select((state) => state.locale));
            final themeProps = ref.watch(themeSettingProvider);
            final appBrightness = ref.watch(appBrightnessProvider);
            final effectiveBrightness = _effectiveBrightness(
              themeProps.themeMode,
              appBrightness,
            );
            final effectiveColorScheme = _getAppColorScheme(
              brightness: effectiveBrightness,
              primaryColor: themeProps.primaryColor,
            );
            final lightColorScheme = _getAppColorScheme(
              brightness: Brightness.light,
              primaryColor: themeProps.primaryColor,
            );
            final darkColorScheme = _getAppColorScheme(
              brightness: Brightness.dark,
              primaryColor: themeProps.primaryColor,
            ).toPureBlack(themeProps.pureBlack);
            final currentContext = globalState.navigatorKey.currentContext;
            final currentL10n = currentContext == null
                ? null
                : AppLocalizations.maybeOf(currentContext);
            CustomerServiceHelper.syncDesktopWindowState(
              effectiveBrightness,
              localeTag: locale,
              accentColor: effectiveColorScheme.primary,
              loadingText: currentL10n?.onlineSupportConnecting,
            );
            PaymentWebViewPage.syncDesktopTheme(effectiveBrightness);

            // 使用 go_router 的路由系统
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate
              ],
              builder: (context, child) {
                // Flux 式加载遮罩：loading 状态用 Widget 表达，不再作为路由
                // GoRouter Navigator 始终挂载（child 始终在树中），navigatorKey 始终有效
                // 遮罩仅在 isInitialized=false 时覆盖在 GoRouter 内容上方
                Widget content = AppEnvManager(
                  child: _buildPlatformApp(
                    _buildApp(
                      Consumer(
                        builder: (_, ref, __) {
                          final isInitialized = ref.watch(
                            xboardUserProvider.select((s) => s.isInitialized),
                          );
                          return Stack(
                            children: [
                              child!,
                              if (!isInitialized)
                                const Scaffold(
                                  body: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );

                // TV 10ft UI: text scale 1.3x + overscan-safe padding (5%)
                if (system.isTV) {
                  final mq = MediaQuery.of(context);
                  content = MediaQuery(
                    data: mq.copyWith(
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: SafeArea(
                      minimum: EdgeInsets.symmetric(
                        horizontal: mq.size.width * 0.05,
                        vertical: mq.size.height * 0.05,
                      ),
                      child: content,
                    ),
                  );
                }

                return content;
              },
              routerConfig: _router,
              scrollBehavior: BaseScrollBehavior(),
              title: localizedAppName,
              locale: locale != null && locale.isNotEmpty
                  ? utils.getLocaleForString(locale)
                  : null,
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              localeResolutionCallback: (locale, supportedLocales) {
                if (locale != null) {
                  if (locale.languageCode == 'zh') {
                    return const Locale.fromSubtags(
                        languageCode: 'zh', countryCode: 'CN');
                  }
                  if (locale.languageCode == 'en') {
                    return const Locale.fromSubtags(languageCode: 'en');
                  }
                }
                return const Locale.fromSubtags(languageCode: 'en');
              },
              themeMode: themeProps.themeMode,
              theme: ThemeData(
                useMaterial3: true,
                fontFamilyFallback: _fontFamilyFallback,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: lightColorScheme,
                typography: buildAppTypography(
                  platform: defaultTargetPlatform,
                  colorScheme: lightColorScheme,
                ),
                scaffoldBackgroundColor: const Color(0xFFFAFBFD),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF1A2138),
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  centerTitle: false,
                ),
                cardTheme: CardThemeData(
                  elevation: 0,
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: const Color(0xFF2196F3),
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                  ).copyWith(mouseCursor: _clickableMouseCursor),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ).copyWith(mouseCursor: _clickableMouseCursor),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ).copyWith(mouseCursor: _clickableMouseCursor),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: ButtonStyle(mouseCursor: _clickableMouseCursor),
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: ButtonStyle(mouseCursor: _clickableMouseCursor),
                ),
                switchTheme: SwitchThemeData(
                  mouseCursor: _clickableMouseCursor,
                ),
                checkboxTheme: CheckboxThemeData(
                  mouseCursor: _clickableMouseCursor,
                ),
                radioTheme: RadioThemeData(
                  mouseCursor: _clickableMouseCursor,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEEF0F4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEEF0F4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF2196F3), width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
                dividerTheme: const DividerThemeData(
                  color: Color(0xFFEEF0F4),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                fontFamilyFallback: _fontFamilyFallback,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: darkColorScheme,
                typography: buildAppTypography(
                  platform: defaultTargetPlatform,
                  colorScheme: darkColorScheme,
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: false,
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: ButtonStyle(mouseCursor: _clickableMouseCursor),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ButtonStyle(mouseCursor: _clickableMouseCursor),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: ButtonStyle(mouseCursor: _clickableMouseCursor),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: ButtonStyle(mouseCursor: _clickableMouseCursor),
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: ButtonStyle(mouseCursor: _clickableMouseCursor),
                ),
                switchTheme: SwitchThemeData(
                  mouseCursor: _clickableMouseCursor,
                ),
                checkboxTheme: CheckboxThemeData(
                  mouseCursor: _clickableMouseCursor,
                ),
                radioTheme: RadioThemeData(
                  mouseCursor: _clickableMouseCursor,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    try {
      WidgetsBinding.instance.removeObserver(this);
      linkManager.destroy();
      _autoUpdateProfilesTaskTimer?.cancel();
      _customerServicePrewarmTimer?.cancel();
      _mobileLogRecoveryTimer?.cancel();
      _automaticUpdateRetryTimer?.cancel();
      await _updateConfigSubscription?.cancel();

      // 释放XBoard SDK资源
      try {
        XBoardSDK.instance.dispose();
        // ignore: empty_catches
      } catch (e) {}

      await clashCore.destroy();
      await globalState.appController.savePreferences();
      await globalState.appController.handleExit();

      // ignore: empty_catches
    } catch (e) {}

    super.dispose();
  }
}
