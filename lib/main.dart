import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/tile.dart';
import 'package:fl_clash/plugins/vpn.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';

import 'application.dart';
import 'clash/core.dart';
import 'clash/lib.dart';
import 'common/common.dart';
import 'models/models.dart';
import 'package:fl_clash/xboard/features/remote_task/remote_task_manager.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/infrastructure/infrastructure.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

RemoteTaskManager? remoteTaskManager;

Future<void> main(List<String> args) async {
  if ((Platform.isWindows || Platform.isLinux) &&
      runWebViewTitleBarWidget(args)) {
    return;
  }

  globalState.isService = false;
  WidgetsFlutterBinding.ensureInitialized();
  const previewMode = bool.fromEnvironment('APP_PREVIEW_MODE');

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrintStack(
        stackTrace: details.stack,
        label: '[FlutterError Stack]',
      );
    }
  };
  if (previewMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('[PreviewMode ErrorWidget] ${details.exceptionAsString()}');
      if (details.stack != null) {
        debugPrintStack(
          stackTrace: details.stack,
          label: '[PreviewMode ErrorWidget Stack]',
        );
      }
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: const Color(0xFFF7F9FC),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE1E6EF)),
                ),
                child: Text(
                  'Preview mode skipped a widget error.\n\n${details.exceptionAsString()}',
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    };
  }

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error');
    debugPrintStack(stackTrace: stack, label: '[PlatformError Stack]');
    return false;
  };

  // Flux: read initial auth state once before runApp
  final prefs = await SharedPreferences.getInstance();
  final initialHasToken = (prefs.getString('xboard_token') ?? '').isNotEmpty;
  final initialStorage = SharedPrefsStorage(prefs);
  final initialSnapshot = await _loadInitialUserSnapshot(
    initialStorage,
    initialHasToken: initialHasToken,
  );

  // Phase 1: Run independent init tasks in parallel.
  // _initializeXBoardServicesWithPrefs, RemoteTaskManager.create,
  // system.version, and clashCore.preload are all independent.
  final parallelResults = await Future.wait([
    _initializeXBoardServicesWithPrefs(prefs),
    _initRemoteTaskManager(),
    system.version,
    clashCore.preload(),
  ]);

  remoteTaskManager = parallelResults[1] as RemoteTaskManager?;
  final version = parallelResults[2] as int;

  await system.detectTV();
  await globalState.initApp(version);
  await android?.init();
  await window?.init(version);
  HttpOverrides.global = FastcatHttpOverrides();

  WidgetsBinding.instance.addObserver(AppLifecycleObserver());

  runApp(ProviderScope(
    overrides: [
      initialTokenProvider.overrideWithValue(initialHasToken),
      initialUserSnapshotProvider.overrideWithValue(initialSnapshot),
      storageProvider.overrideWith((ref) => initialStorage),
      userInfoProvider.overrideWith((ref) => initialSnapshot.userInfo),
      subscriptionInfoProvider.overrideWith(
        (ref) => initialSnapshot.subscriptionInfo,
      ),
    ],
    child: const Application(),
  ));
}

Future<InitialUserSnapshot> _loadInitialUserSnapshot(
  StorageInterface storage, {
  required bool initialHasToken,
}) async {
  if (!initialHasToken) return const InitialUserSnapshot();

  final storageService = XBoardStorageService(storage);
  String? email;
  DomainUser? userInfo;
  DomainSubscription? subscriptionInfo;

  await Future.wait([
    () async {
      try {
        email = (await storageService.getUserEmail()).dataOrNull;
      } catch (_) {}
    }(),
    () async {
      try {
        userInfo = (await storageService.getDomainUser()).dataOrNull;
      } catch (_) {}
    }(),
    () async {
      try {
        subscriptionInfo =
            (await storageService.getDomainSubscription()).dataOrNull;
      } catch (_) {}
    }(),
  ]);

  return InitialUserSnapshot(
    email: email,
    userInfo: userInfo,
    subscriptionInfo: subscriptionInfo,
  );
}

/// Initialize XBoard services using a pre-fetched SharedPreferences instance
/// to avoid a duplicate native call.
Future<void> _initializeXBoardServicesWithPrefs(SharedPreferences prefs) async {
  try {
    print('[Main] 开始初始化XBoard配置模块...');

    var configSettings = await ConfigFileLoader.loadFromFile();
    print('[Main] 配置文件加载成功，Provider: ${configSettings.currentProvider}');

    final ossMode = prefs.getInt('xboard_oss_mode') ?? 0;
    if (ossMode == 1) {
      configSettings = ConfigSettings(
        currentProvider: configSettings.currentProvider,
        apiPrefix: configSettings.apiPrefix,
        remoteConfig: RemoteConfigSettings(
          sources: [RemoteSourceConfig(name: 'builtin', url: builtinOssUrl)],
          maxRetries: configSettings.remoteConfig.maxRetries,
          timeout: configSettings.remoteConfig.timeout,
          retryDelay: configSettings.remoteConfig.retryDelay,
        ),
        subscription: configSettings.subscription,
        log: configSettings.log,
      );
    }

    await _loadSecurityConfig();
    print('[Main] 安全配置加载成功');

    await XBoardConfig.initialize(settings: configSettings);
    print('[Main] XBoard配置模块初始化成功');
    print('[Main] SDK 将在应用启动后由 xboardSdkProvider 初始化');
  } catch (e) {
    print('[Main] XBoard服务初始化失败: $e');
    rethrow;
  }
}

/// Initialize RemoteTaskManager in background; failures are non-fatal.
Future<RemoteTaskManager?> _initRemoteTaskManager() async {
  try {
    final manager = await RemoteTaskManager.create();
    if (manager != null) {
      manager.initialize();
      manager.start();
      print('RemoteTaskManager 从配置初始化成功');
    } else {
      print('警告: RemoteTaskManager 初始化失败 - 配置中未找到 WebSocket URL');
    }
    return manager;
  } catch (e) {
    print('警告: RemoteTaskManager 初始化异常: $e');
    return null;
  }
}

Future<void> _loadSecurityConfig() async {
  try {
    final certConfig = await ConfigFileLoaderHelper.getCertificateConfig();
    final certPath = certConfig['path'] as String?;
    final certEnabled = certConfig['enabled'] as bool? ?? true;

    if (certEnabled && certPath != null && certPath.isNotEmpty) {
      DomainRacingService.setCertificatePath(certPath);
      print('[Main] 证书路径配置: $certPath');
    }
  } catch (e) {
    print('[Main] 加载安全配置失败（使用默认值）: $e');
  }
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      remoteTaskManager?.dispose();
      XBoardSDK.instance.dispose();
      print('应用生命周期状态改变: $state, 所有服务资源已释放。');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _service(List<String> flags) async {
  globalState.isService = true;
  WidgetsFlutterBinding.ensureInitialized();
  final quickStart = flags.contains("quick");
  final clashLibHandler = ClashLibHandler();
  await globalState.init();

  tile?.addListener(
    _TileListenerWithService(
      onStop: () async {
        await app?.tip(appLocalizations.stopVpn);
        clashLibHandler.stopListener();
        await vpn?.stop();
        exit(0);
      },
    ),
  );

  vpn?.handleGetStartForegroundParams = () {
    final traffic = clashLibHandler.getTraffic();
    return json.encode({"title": appName, "content": "$traffic"});
  };

  vpn?.addListener(
    _VpnListenerWithService(
      onDnsChanged: (String dns) {
        print("handle dns $dns");
        clashLibHandler.updateDns(dns);
      },
    ),
  );
  if (!quickStart) {
    _handleMainIpc(clashLibHandler);
  } else {
    commonPrint.log("quick start");
    await ClashCore.initGeo();
    app?.tip(appLocalizations.startVpn);
    final homeDirPath = await appPath.homeDirPath;
    final version = await system.version;
    final clashConfig = globalState.config.patchClashConfig.copyWith.tun(
      enable: true,
    );
    Future(() async {
      final profileId = globalState.config.currentProfileId;
      if (profileId == null) {
        return;
      }
      final params = await globalState.getSetupParams(
        pathConfig: clashConfig,
      );
      final res = await clashLibHandler.quickStart(
        InitParams(
          homeDir: homeDirPath,
          version: version,
        ),
        params,
        globalState.getCoreState(),
      );
      debugPrint(res);
      if (res.isNotEmpty) {
        await vpn?.stop();
        exit(0);
      }
      await vpn?.start(
        clashLibHandler.getAndroidVpnOptions(),
      );
      clashLibHandler.startListener();
    });
  }
}

_handleMainIpc(ClashLibHandler clashLibHandler) {
  final sendPort = IsolateNameServer.lookupPortByName(mainIsolate);
  if (sendPort == null) {
    return;
  }
  final serviceReceiverPort = ReceivePort();
  serviceReceiverPort.listen((message) async {
    final res = await clashLibHandler.invokeAction(message);
    sendPort.send(res);
  });
  sendPort.send(serviceReceiverPort.sendPort);
  final messageReceiverPort = ReceivePort();
  clashLibHandler.attachMessagePort(
    messageReceiverPort.sendPort.nativePort,
  );
  messageReceiverPort.listen((message) {
    sendPort.send(message);
  });
}

@immutable
class _TileListenerWithService with TileListener {
  final Function() _onStop;

  const _TileListenerWithService({
    required Function() onStop,
  }) : _onStop = onStop;

  @override
  void onStop() {
    _onStop();
  }
}

@immutable
class _VpnListenerWithService with VpnListener {
  final Function(String dns) _onDnsChanged;

  const _VpnListenerWithService({
    required Function(String dns) onDnsChanged,
  }) : _onDnsChanged = onDnsChanged;

  @override
  void onDnsChanged(String dns) {
    super.onDnsChanged(dns);
    _onDnsChanged(dns);
  }
}
