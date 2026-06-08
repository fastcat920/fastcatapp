import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
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

import 'controller.dart';
import 'xboard/xboard.dart';
import 'package:fl_clash/xboard/core/logger/capture_logger.dart'
    show CaptureLogger, mapFastcatLogLevel;
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/router/app_router.dart' as xboard_router;
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/xboard/features/notice/notice.dart';
import 'package:fl_clash/xboard/features/shared/widgets/notice_banner.dart';

class Application extends ConsumerStatefulWidget {
  const Application({
    super.key,
  });

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateProfilesTaskTimer;
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

  @override
  void initState() {
    super.initState();
    _autoUpdateProfilesTask();
    globalState.appController = AppController(context, ref);

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

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
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

      // 启动后检查更新
      _checkForUpdates();
    });
  }

  void _setupRootListeners() {
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
        if (previous?.isAuthenticated != next.isAuthenticated ||
            previous?.isInitialized != next.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _router.refresh();
            }
          });
        }
      },
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
          showDialog(
            context: ctx,
            builder: (_) => NoticeDetailDialog(
              notices: [notice],
              onDismiss: () {
                ref.read(noticeProvider.notifier).markPopupShown(noticeId);
              },
            ),
          );
        });
      },
    );
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

  /// 检查应用更新
  void _checkForUpdates() {
    // 延迟5秒后检查更新，确保应用完全启动
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        debugPrint('[Application] 开始自动检查更新...');
        final updateNotifier = ref.read(updateCheckProvider.notifier);
        await updateNotifier.checkForUpdates();

        // 检查是否有更新
        final updateState = ref.read(updateCheckProvider);
        if (updateState.hasUpdate && mounted) {
          final currentContext = globalState.navigatorKey.currentContext;
          if (currentContext != null) {
            debugPrint('[Application] 发现新版本，显示更新弹窗');
            // 显示更新弹窗
            showDialog(
              context: currentContext,
              barrierDismissible: !updateState.forceUpdate, // 强制更新时不能取消
              builder: (context) => UpdateDialog(state: updateState),
            );
          }
        } else if (updateState.error != null) {
          debugPrint('[Application] 自动更新检查失败，忽略错误: ${updateState.error}');
          // 自动检查失败时静默处理，不打扰用户
        } else {
          debugPrint('[Application] 已是最新版本');
        }
      } catch (e) {
        debugPrint('[Application] 自动更新检查异常: $e');
        // 自动检查异常时静默处理，不影响应用正常使用
      }
    });
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
            if (!results.contains(ConnectivityResult.vpn)) {
              await clashCore.closeConnections();
            }
            globalState.appController.updateLocalIp();
            globalState.appController.addCheckIpNumDebounce();
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
    return MessageManager(
      child: ThemeManager(
        child: child,
      ),
    );
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

            // 使用 go_router 的路由系统
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate
              ],
              builder: (_, child) {
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
                  final mq = MediaQuery.of(_);
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
              title: appName,
              locale: utils.getLocaleForString(locale),
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              themeMode: themeProps.themeMode,
              theme: ThemeData(
                useMaterial3: true,
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.light,
                  primaryColor: themeProps.primaryColor,
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
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
                pageTransitionsTheme: _pageTransitionsTheme,
                colorScheme: _getAppColorScheme(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                ).toPureBlack(themeProps.pureBlack),
                appBarTheme: const AppBarTheme(
                  centerTitle: false,
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
      linkManager.destroy();
      _autoUpdateProfilesTaskTimer?.cancel();

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
