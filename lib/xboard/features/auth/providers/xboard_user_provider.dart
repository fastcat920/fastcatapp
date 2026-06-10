import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart'
    hide XBoardException;
import 'package:fl_clash/xboard/adapter/state/user_state.dart';
import 'package:fl_clash/xboard/adapter/state/subscription_state.dart';
import 'package:fl_clash/xboard/adapter/state/plan_state.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/domain_status/providers/domain_status_provider.dart';
import 'package:fl_clash/xboard/features/initialization/initialization.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_guard_service.dart';

// 初始化文件级日志器
const _logger = FileLogger('xboard_user_provider.dart');

// main() 中 runApp 前读取的初始 token 状态，通过 ProviderScope.overrides 注入
// 默认 false，override 后为实际值
final initialTokenProvider = Provider<bool>((_) => false);

class InitialUserSnapshot {
  final String? email;
  final DomainUser? userInfo;
  final DomainSubscription? subscriptionInfo;

  const InitialUserSnapshot({
    this.email,
    this.userInfo,
    this.subscriptionInfo,
  });

  String? get displayEmail {
    if (email?.isNotEmpty == true) return email;
    if (userInfo?.email.isNotEmpty == true) return userInfo?.email;
    if (subscriptionInfo?.email.isNotEmpty == true) {
      return subscriptionInfo?.email;
    }
    return null;
  }
}

final initialUserSnapshotProvider =
    Provider<InitialUserSnapshot>((_) => const InitialUserSnapshot());

// 使用领域模型
final userInfoProvider = StateProvider<DomainUser?>((ref) => null);
final subscriptionInfoProvider =
    StateProvider<DomainSubscription?>((ref) => null);
final userUIStateProvider = StateProvider<UIState>((ref) => const UIState());

class XBoardUserAuthNotifier extends Notifier<UserAuthState> {
  late final XBoardStorageService _storageService;
  bool _hasRetriedWithNewDomain = false;
  bool _isEnsuringUserSnapshot = false;
  int _authGeneration = 0;

  int _nextAuthGeneration() => ++_authGeneration;
  bool _isAuthGenerationActive(int generation) => generation == _authGeneration;

  @override
  UserAuthState build() {
    _storageService = ref.read(storageServiceProvider);
    // Flux 式：main() 已在 runApp 前同步读出 token，直接设置初始状态
    // isInitialized = true 从第一帧起就成立，spinner 永远不会出现
    final hasToken = ref.read(initialTokenProvider);
    final initialSnapshot = ref.read(initialUserSnapshotProvider);

    // 监听 SDK 401 事件：任意接口返回 401 时，若当前已登录则提示用户重新登录
    final sub = XBoardAuthEvents.onUnauthorized.listen((_) {
      if (state.isAuthenticated) {
        _logger.warning('SDK 检测到 401，token 已失效，提示用户重新登录');
        _showTokenExpiredDialog();
      }
    });
    ref.onDispose(sub.cancel);

    return UserAuthState(
      isAuthenticated: hasToken,
      isInitialized: true,
      email: hasToken ? initialSnapshot.displayEmail : null,
      userInfo: hasToken ? initialSnapshot.userInfo : null,
      subscriptionInfo: hasToken ? initialSnapshot.subscriptionInfo : null,
    );
  }

  Future<bool> quickAuth() async {
    // isInitialized 已在 build() 中设为 true，无需再次设置
    // 只根据当前认证状态启动后台任务
    if (state.isAuthenticated) {
      _logger.info('quickAuth：有 token，启动后台数据加载和 token 验证');
      final generation = _authGeneration;
      _loadCachedDataInBackground(generation);
      _backgroundTokenValidation(generation);
      return true;
    } else {
      _logger.info('quickAuth：无 token，留在登录页');
      return false;
    }
  }

  /// 后台并行加载缓存数据（不阻塞路由决策）
  ///
  /// email / userInfo / subscriptionInfo 只影响 UI 展示，不影响路由，
  /// 因此在 isInitialized=true 之后异步加载，不阻塞 loading 页面消失。
  void _loadCachedDataInBackground(int generation) {
    Future(() async {
      String? email;
      DomainUser? userInfo;
      DomainSubscription? subscriptionInfo;

      // 三个读取并行执行，各自独立容错
      await Future.wait([
        () async {
          try {
            final result = await _storageService
                .getUserEmail()
                .timeout(const Duration(seconds: 3));
            email = result.dataOrNull;
          } catch (_) {}
        }(),
        () async {
          try {
            final result = await _storageService
                .getDomainUser()
                .timeout(const Duration(seconds: 3));
            userInfo = result.dataOrNull;
          } catch (_) {}
        }(),
        () async {
          try {
            final result = await _storageService
                .getDomainSubscription()
                .timeout(const Duration(seconds: 3));
            subscriptionInfo = result.dataOrNull;
          } catch (_) {}
        }(),
      ]);

      if (!_isAuthGenerationActive(generation) || !state.isAuthenticated) {
        _logger.info('后台缓存加载取消：认证会话已变化');
        return;
      }

      _applyCachedUserSnapshot(
        email: email,
        userInfo: userInfo,
        subscriptionInfo: subscriptionInfo,
        allowInitialImport: true,
      );

      _logger.info('后台缓存数据加载完成: email=$email');
    });
  }

  Future<void> ensureUserSnapshotLoaded() async {
    if (!state.isAuthenticated || _isEnsuringUserSnapshot) {
      return;
    }

    final hasDisplaySnapshot = (state.email?.isNotEmpty == true ||
            ref.read(userInfoProvider)?.email.isNotEmpty == true ||
            ref.read(subscriptionInfoProvider)?.email.isNotEmpty == true) &&
        (ref.read(subscriptionInfoProvider)?.planName?.trim().isNotEmpty ==
                true ||
            state.subscriptionInfo?.planName?.trim().isNotEmpty == true);

    _isEnsuringUserSnapshot = true;
    try {
      final generation = _authGeneration;
      String? cachedEmail;
      DomainUser? cachedUser;
      DomainSubscription? cachedSubscription;

      await Future.wait([
        () async {
          try {
            final result = await _storageService
                .getUserEmail()
                .timeout(const Duration(seconds: 3));
            cachedEmail = result.dataOrNull;
          } catch (_) {}
        }(),
        () async {
          try {
            final result = await _storageService
                .getDomainUser()
                .timeout(const Duration(seconds: 3));
            cachedUser = result.dataOrNull;
          } catch (_) {}
        }(),
        () async {
          try {
            final result = await _storageService
                .getDomainSubscription()
                .timeout(const Duration(seconds: 3));
            cachedSubscription = result.dataOrNull;
          } catch (_) {}
        }(),
      ]);

      if (_isAuthGenerationActive(generation) && state.isAuthenticated) {
        _applyCachedUserSnapshot(
          email: cachedEmail,
          userInfo: cachedUser,
          subscriptionInfo: cachedSubscription,
          allowInitialImport: false,
        );
      }

      if (!hasDisplaySnapshot &&
          _isAuthGenerationActive(generation) &&
          state.isAuthenticated) {
        unawaited(_refreshUserSnapshotInBackground(generation));
      }
    } finally {
      _isEnsuringUserSnapshot = false;
    }
  }

  void _applyCachedUserSnapshot({
    required String? email,
    required DomainUser? userInfo,
    required DomainSubscription? subscriptionInfo,
    required bool allowInitialImport,
  }) {
    if (email != null || userInfo != null || subscriptionInfo != null) {
      final snapshotEmail = (email?.isNotEmpty == true)
          ? email
          : userInfo?.email.isNotEmpty == true
              ? userInfo?.email
              : subscriptionInfo?.email.isNotEmpty == true
                  ? subscriptionInfo?.email
                  : state.email;
      state = state.copyWith(
        email: snapshotEmail,
        userInfo: userInfo ?? state.userInfo,
        subscriptionInfo: subscriptionInfo ?? state.subscriptionInfo,
      );
    }
    if (userInfo != null) {
      ref.read(userInfoProvider.notifier).state = userInfo;
    }
    if (subscriptionInfo != null) {
      ref.read(subscriptionInfoProvider.notifier).state = subscriptionInfo;
      if (allowInitialImport && subscriptionInfo.subscribeUrl.isNotEmpty) {
        final currentProfileId = globalState.config.currentProfileId;
        if (currentProfileId != null && currentProfileId.isNotEmpty) {
          _logger.info('已有配置 ($currentProfileId)，跳过启动时下载，等待 init() 加载');
        } else {
          _logger.info('无当前配置，首次下载订阅: ${subscriptionInfo.subscribeUrl}');
          ref
              .read(profileImportProvider.notifier)
              .importSubscription(subscriptionInfo.subscribeUrl);
        }
      }
    }
  }

  Future<void> _refreshUserSnapshotInBackground(int generation) async {
    try {
      if (!_isAuthGenerationActive(generation) || !state.isAuthenticated) {
        return;
      }

      DomainUser? userInfo = ref.read(userInfoProvider) ?? state.userInfo;
      DomainSubscription? subscriptionInfo =
          ref.read(subscriptionInfoProvider) ?? state.subscriptionInfo;

      try {
        clearGetUserInfoCache();
        ref.invalidate(getUserInfoProvider);
        final userModel = await ref.read(getUserInfoProvider.future);
        if (!_isAuthGenerationActive(generation) || !state.isAuthenticated) {
          return;
        }
        userInfo = _mapUser(userModel);
        await _storageService.saveDomainUser(userInfo);
        ref.read(userInfoProvider.notifier).state = userInfo;
      } catch (e) {
        _logger.info('后台刷新用户缓存失败: $e');
      }

      try {
        clearGetSubscriptionCache();
        ref.invalidate(getSubscriptionProvider);
        final subscriptionModel =
            await ref.read(getSubscriptionProvider.future);
        if (!_isAuthGenerationActive(generation) || !state.isAuthenticated) {
          return;
        }
        subscriptionInfo =
            _mergeSubscriptionWithCache(_mapSubscription(subscriptionModel));
        await _storageService.saveDomainSubscription(subscriptionInfo);
        ref.read(subscriptionInfoProvider.notifier).state = subscriptionInfo;
      } catch (e) {
        _logger.info('后台刷新订阅缓存失败: $e');
      }

      state = state.copyWith(
        email: userInfo?.email.isNotEmpty == true
            ? userInfo?.email
            : subscriptionInfo?.email.isNotEmpty == true
                ? subscriptionInfo?.email
                : state.email,
        userInfo: userInfo,
        subscriptionInfo: subscriptionInfo,
      );
    } catch (e) {
      _logger.info('后台刷新用户快照异常: $e');
    }
  }

  void _backgroundTokenValidation(int generation) {
    // 等待 SDK 就绪后再验证（最多 20 秒），避免 SDK 未初始化时误判 token 失效
    Future(() async {
      try {
        _logger.info('后台验证：等待 SDK 初始化...');
        const maxWait = Duration(seconds: 20);
        final deadline = DateTime.now().add(maxWait);
        while (!XBoardSDK.instance.isInitialized &&
            DateTime.now().isBefore(deadline)) {
          await Future.delayed(const Duration(seconds: 1));
        }
        if (!XBoardSDK.instance.isInitialized) {
          _logger.info('后台验证：SDK 未就绪（超时），跳过 token 验证');
          return;
        }

        _logger.info('后台验证token有效性...');
        if (!_isAuthGenerationActive(generation) || !state.isAuthenticated) {
          _logger.info('后台验证取消：认证会话已变化');
          return;
        }
        // 使用 getUserInfo 验证 token
        try {
          await ref.read(getUserInfoProvider.future);
          _logger.info('Token验证成功，静默更新用户数据');
          await _silentUpdateUserData(generation);
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          // 只有明确的 401/auth 错误才判定 token 失效
          // 网络错误、超时、连接失败等不弹"登录过期"，避免误伤离线用户
          final isAuthError = errStr.contains('401') ||
              errStr.contains('unauthorized') ||
              errStr.contains('unauthenticated') ||
              errStr.contains('token') ||
              errStr.contains('auth');
          if (isAuthError) {
            _logger.info('Token验证失败（auth错误），显示登录过期提示: $e');
            _showTokenExpiredDialog();
          } else {
            _logger.info('Token验证失败（网络/其他错误），保持当前登录状态: $e');
          }
        }
      } catch (e) {
        _logger.info('后台token验证异常: $e');
      }
    });
  }

  Future<void> _silentUpdateUserData(int generation) async {
    if (!_isAuthGenerationActive(generation) || !state.isAuthenticated) {
      _logger.info('静默更新取消：认证会话已变化');
      return;
    }
    try {
      // 强制清除缓存，确保每次启动都获取最新数据
      clearGetSubscriptionCache();
      clearGetUserInfoCache();
      ref.invalidate(getSubscriptionProvider);
      ref.invalidate(getUserInfoProvider);

      // 获取订阅信息
      final subscriptionModel = await ref.read(getSubscriptionProvider.future);
      if (!_isAuthGenerationActive(generation) || !state.isAuthenticated) {
        _logger.info('静默更新中止：认证会话已变化');
        return;
      }
      final subscriptionData =
          _mergeSubscriptionWithCache(_mapSubscription(subscriptionModel));

      DomainUser? userInfoData;

      // 获取用户信息
      try {
        final userModel = await ref.read(getUserInfoProvider.future);
        if (!_isAuthGenerationActive(generation) || !state.isAuthenticated) {
          _logger.info('静默更新中止：认证会话已变化');
          return;
        }
        userInfoData = _mapUser(userModel);

        await _storageService.saveDomainUser(userInfoData);
        ref.read(userInfoProvider.notifier).state = userInfoData;
      } catch (e) {
        _logger.info('静默更新用户信息失败: $e');
      }

      await _storageService.saveDomainSubscription(subscriptionData);
      ref.read(subscriptionInfoProvider.notifier).state = subscriptionData;
      state = state.copyWith(
        email: userInfoData?.email.isNotEmpty == true
            ? userInfoData?.email
            : subscriptionData.email.isNotEmpty
                ? subscriptionData.email
                : state.email,
        userInfo: userInfoData ?? state.userInfo,
        subscriptionInfo: subscriptionData,
      );

      if (subscriptionData.subscribeUrl.isNotEmpty) {
        // 每次启动都重新下载订阅，确保节点配置保持最新
        _logger.info('[后台验证] 启动刷新：重新导入订阅: ${subscriptionData.subscribeUrl}');
        ref
            .read(profileImportProvider.notifier)
            .importSubscription(subscriptionData.subscribeUrl);
      } else {
        _logger.info('[后台验证] 订阅URL为空，跳过配置导入');
      }

      _logger.info('静默更新用户数据完成');
    } catch (e) {
      _logger.info('静默更新用户数据失败: $e');
    }
  }

  void _showTokenExpiredDialog() {
    state = state.copyWith(
      errorMessage: 'TOKEN_EXPIRED', // 特殊标记，UI层检测到后显示对话框
    );
  }

  void clearTokenExpiredError() {
    if (state.errorMessage == 'TOKEN_EXPIRED') {
      state = state.copyWith(errorMessage: null);
    }
  }

  Future<void> handleTokenExpired() async {
    _logger.info('处理token过期，清除认证状态');
    await XBoardSDK.instance.logout();
    state = const UserAuthState(isInitialized: true);
  }

  Future<bool> autoAuth() async {
    return await quickAuth();
  }

  /// 根据 Supabase 查询结果决定走哪个 OSS 源
  ///
  /// 返回目标 OSS 模式：0=打包OSS, 1=内置OSS
  ///
  /// 逻辑：
  /// - 先查用户 is_builtin 记录，有记录则始终按记录走（不受开关影响）
  /// - 无记录（新用户）：查全局开关，开关开=内置OSS，开关关=打包OSS
  /// - Supabase 不可达：降级走打包 OSS
  Future<int> _resolveOssMode(String email) async {
    try {
      // 1. 查用户 is_builtin（已注册用户始终按记录走）
      final isBuiltin = await SupabaseService.queryUserBuiltin(email);
      if (isBuiltin != null) {
        return isBuiltin;
      }

      // 2. 新用户：查全局开关决定走哪个 OSS
      final dualOssEnabled = await SupabaseService.isDualOssEnabled();
      return dualOssEnabled ? 1 : 0;
    } catch (e) {
      return 0;
    }
  }

  /// 切换到目标 OSS 配置源并重建 SDK
  ///
  /// 失败时自动回滚到原配置，保证 SDK 始终处于可用状态。
  Future<void> _switchOssSource(int targetOssMode) async {
    final currentOssMode = await _storageService.getOssMode();
    if (currentOssMode == targetOssMode) {
      return;
    }

    _logger.info('[_switchOssSource] $currentOssMode → $targetOssMode');

    // 1. 构建目标配置
    final baseSettings = await ConfigFileLoader.loadFromFile();
    final targetSettings = _buildConfigSettings(baseSettings, targetOssMode);

    // 2. 重置 XBoardConfig + SDK，切换到新配置源
    XBoardConfig.reset();
    try {
      await XBoardConfig.initialize(settings: targetSettings);
      await XBoardConfig.clearRacingCache();

      // 用新 OSS 的域名更新 domainStatusProvider
      final newPanelUrls = XBoardConfig.allPanelUrls;
      if (newPanelUrls.isNotEmpty) {
        _logger.info('[_switchOssSource] 更新域名: ${newPanelUrls.first}');
        ref.read(domainStatusProvider.notifier).setDomain(newPanelUrls.first);
      }

      // dispose 旧 SDK 单例，invalidate provider 触发重建
      XBoardSDK.instance.dispose();
      ref.invalidate(xboardSdkProvider);

      // 等待 SDK 重新初始化完成
      await ref.read(xboardSdkProvider.future);

      // 全部成功，持久化 OSS 模式
      await _storageService.setOssMode(targetOssMode);
      _logger.info('[_switchOssSource] 切换成功');
    } catch (e) {
      // 切换失败，回滚到原配置，保证 SDK 可用
      _logger.warning('[_switchOssSource] 切换失败，回滚到模式 $currentOssMode: $e');
      try {
        final rollbackSettings =
            _buildConfigSettings(baseSettings, currentOssMode);
        XBoardConfig.reset();
        await XBoardConfig.initialize(settings: rollbackSettings);
        XBoardSDK.instance.dispose();
        ref.invalidate(xboardSdkProvider);
        await ref.read(xboardSdkProvider.future);
        _logger.info('[_switchOssSource] 回滚成功');
      } catch (rollbackErr) {
        _logger.error('[_switchOssSource] 回滚也失败: $rollbackErr');
      }
      rethrow;
    }
  }

  /// 根据 ossMode 构建 ConfigSettings
  ConfigSettings _buildConfigSettings(ConfigSettings base, int ossMode) {
    if (ossMode != 1) return base;
    return ConfigSettings(
      currentProvider: base.currentProvider,
      apiPrefix: base.apiPrefix,
      remoteConfig: RemoteConfigSettings(
        sources: [RemoteSourceConfig(name: 'builtin', url: builtinOssUrl)],
        maxRetries: base.remoteConfig.maxRetries,
        timeout: base.remoteConfig.timeout,
        retryDelay: base.remoteConfig.retryDelay,
      ),
      subscription: base.subscription,
      log: base.log,
    );
  }

  Future<bool> login(String email, String password) async {
    final generation = _nextAuthGeneration();
    String? subscriptionUrlForImport;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 切号前先清内存态，避免旧账号套餐/用户信息短暂闪现
      _clearSessionScopedProvidersForLogin();
      _logger.info('开始登录: $email');

      // 使用统一网关配置（gateway_config.dart）
      final gatewayUrl = gatewayBaseUrl;
      if (gatewayUrl.isEmpty) {
        // 登录前决定走哪个配置源
        // _switchOssSource 内部有回滚机制，失败后 SDK 仍可用，可继续用当前配置登录
        try {
          final targetOssMode =
              await _resolveOssMode(email).timeout(const Duration(seconds: 5));
          await _switchOssSource(targetOssMode)
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          _logger.warning('OSS 源切换失败，使用当前配置继续登录: $e');
        }
        await _refreshSdkForLogin();
      } else {
        _logger.info('网关模式登录，跳过 OSS 源切换: $gatewayUrl');
        XBoardSDK.instance.dispose();
        ref.invalidate(xboardSdkProvider);
        await ref.read(xboardSdkProvider.future);
      }

      final deviceInfo = await XBoardDeviceIdentityService.buildLoginPayload();
      final success = await XBoardSDK.instance.loginWithCredentials(
        email,
        password,
        deviceInfo: deviceInfo,
      );
      if (!_isAuthGenerationActive(generation)) {
        _logger.info('登录结果丢弃：认证会话已变化');
        return false;
      }

      if (!success) {
        final connectivity = await Connectivity().checkConnectivity();
        final noNetwork = connectivity.contains(ConnectivityResult.none);
        final configFailed = ref.read(initializationProvider).isFailed;
        state = state.copyWith(
          isLoading: false,
          errorMessage: noNetwork
              ? '无法连接服务器，请检查网络后重试'
              : configFailed
                  ? '配置加载失败，请稍后再试'
                  : '账号或密码错误',
        );
        return false;
      }

      _logger.info('登录成功，立即获取用户信息');
      await _storageService.saveUserEmail(email);
      if (!_isAuthGenerationActive(generation)) {
        _logger.info('登录流程中止：认证会话已变化');
        return false;
      }
      state = state.copyWith(
        isAuthenticated: true,
        isInitialized: true,
        email: email,
        isLoading: false,
      );

      // 获取用户信息。用户信息失败不能影响订阅信息加载，否则连接前
      // 会因为 subscriptionInfoProvider 为空而误判为“无可用套餐”。
      try {
        _logger.info('开始获取用户信息...');
        final userModel = await ref.read(getUserInfoProvider.future);
        if (!_isAuthGenerationActive(generation)) {
          _logger.info('登录流程中止：认证会话已变化');
          return false;
        }
        final userInfo = _mapUser(userModel);

        _logger.info('用户信息API调用完成');
        ref.read(userInfoProvider.notifier).state = userInfo;
        state = state.copyWith(userInfo: userInfo);
        await _storageService.saveDomainUser(userInfo);
        _logger.info('用户信息已保存: ${userInfo.email}');
      } catch (e, stackTrace) {
        _logger.info('获取用户信息失败: $e');
        _logger.info('错误堆栈: $stackTrace');
      }

      // 单独获取订阅信息。只要登录 token 有效，/user/getSubscribe 成功即可
      // 让首页连接按钮正确识别当前套餐。
      try {
        _logger.info('开始获取订阅信息...');
        final subscriptionModel =
            await ref.read(getSubscriptionProvider.future);
        if (!_isAuthGenerationActive(generation)) {
          _logger.info('登录流程中止：认证会话已变化');
          return false;
        }
        final subscriptionInfo =
            _mergeSubscriptionWithCache(_mapSubscription(subscriptionModel));

        _logger.info('订阅信息API调用完成');
        ref.read(subscriptionInfoProvider.notifier).state = subscriptionInfo;
        state = state.copyWith(subscriptionInfo: subscriptionInfo);
        await _storageService.saveDomainSubscription(subscriptionInfo);
        _logger.info('订阅信息已保存，subscribeUrl: ${subscriptionInfo.subscribeUrl}');

        // 登录成功后在后台自动导入订阅配置，不阻塞登录页跳转。
        // 不做域名重写：subscribeUrl 是后端返回的权威地址，
        // _rewriteSubscriptionDomain 可能替换为面板域名导致订阅端点 404/403。
        // 手动刷新（node_selector_bar）也直接用原始 URL，保持一致。
        if (subscriptionInfo.subscribeUrl.isNotEmpty) {
          subscriptionUrlForImport = subscriptionInfo.subscribeUrl;
        } else {
          _logger.info('[登录成功] 订阅URL为空，跳过配置导入');
        }
      } catch (e, stackTrace) {
        _logger.info('获取订阅信息失败: $e');
        _logger.info('错误堆栈: $stackTrace');
        // 登录 API 已成功返回 token，token 是有效的。
        // getSubscription 失败可能是瞬态原因，不应该否定已成功的登录。
        // 继续登录流程，用户进入首页后可手动刷新。
      }

      _logger.info('准备更新状态...');
      if (!_isAuthGenerationActive(generation)) {
        _logger.info('状态更新取消：认证会话已变化');
        return false;
      }
      final newState = state.copyWith(
        isAuthenticated: true,
        isInitialized: true,
        email: email,
        isLoading: false,
      );
      state = newState;
      _logger.info('===== 认证状态已更新! =====');
      _logger.info('isAuthenticated: ${state.isAuthenticated}');
      _logger.info('isInitialized: ${state.isInitialized}');
      _logger.info('email: ${state.email}');
      _logger.info('===========================');

      _startPostLoginSubscriptionImport(subscriptionUrlForImport, generation);

      return true;
    } catch (e) {
      _logger.info('登录出错: $e (${e.runtimeType})');

      // 业务错误（密码错误/账号封禁等）直接展示后端消息，不重试
      if (e is ApiException) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: _normalizeLoginError(e.message),
        );
        return false;
      }
      if (e is AuthException) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: _normalizeLoginError(e.message),
        );
        return false;
      }

      // 网络异常（域名被墙/超时等）自动重新探测域名并重试一次
      if (e is NetworkException && !_hasRetriedWithNewDomain) {
        _hasRetriedWithNewDomain = true;
        _logger.info('网络异常，尝试重新探测域名...');
        state = state.copyWith(errorMessage: '正在切换线路重试...');
        try {
          await ref.read(initializationProvider.notifier).refresh();
          final initState = ref.read(initializationProvider);
          if (initState.isReady) {
            _logger.info('域名重新探测成功，重试登录');
            final result = await login(email, password);
            _hasRetriedWithNewDomain = false;
            return result;
          }
        } catch (retryError) {
          _logger.info('域名重新探测失败: $retryError');
        }
        _hasRetriedWithNewDomain = false;
      }

      String errorMessage = '登录失败';
      if (e is XBoardException) {
        errorMessage = _normalizeLoginError(e.message);
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      );
      return false;
    }
  }

  Future<void> _refreshSdkForLogin() async {
    try {
      _logger.info('登录前刷新 SDK，确保使用最新远程 API 地址');
      XBoardSDK.instance.dispose();
      ref.invalidate(xboardSdkProvider);
      await ref
          .read(initializationProvider.notifier)
          .refresh()
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      _logger.warning('登录前刷新 SDK 失败，继续使用当前 SDK: $e');
    }
  }

  void _clearSessionScopedProvidersForLogin() {
    ref.read(userInfoProvider.notifier).state = null;
    ref.read(subscriptionInfoProvider.notifier).state = null;
    clearGetUserInfoCache();
    clearGetSubscriptionCache();
    clearGetPlansCache();
    clearGetOrdersCache();
    ref.invalidate(getUserInfoProvider);
    ref.invalidate(getSubscriptionProvider);
    ref.invalidate(getPlansProvider);
    ref.invalidate(getOrdersProvider);
  }

  void _startPostLoginSubscriptionImport(String? url, int generation) {
    if (url == null || url.isEmpty) {
      return;
    }
    _logger.info('[登录成功] 后台导入订阅配置: $url');
    unawaited(Future<void>(() async {
      try {
        if (!_isAuthGenerationActive(generation)) {
          _logger.info('[后台导入] 跳过：认证会话已变化');
          return;
        }
        final success = await ref
            .read(profileImportProvider.notifier)
            .importSubscription(url);
        _logger.info('[后台导入] 订阅配置导入${success ? '成功' : '失败'}');
      } catch (e, stackTrace) {
        _logger.warning('[后台导入] 订阅配置导入异常: $e');
        _logger.debug('$stackTrace');
      }
    }));
  }

  String _normalizeLoginError(String message) {
    // 优先按网关 error code 精确分流（格式: [CODE] message）
    final codeMatch = RegExp(r'^\[([A-Z_]+)\]\s*').firstMatch(message);
    if (codeMatch != null) {
      final code = codeMatch.group(1)!;
      final rest = message.substring(codeMatch.end);
      if (code == 'BACKEND_UNREACHABLE' || code == 'BUSINESS_LOGIN_FAILED') {
        return '无法连接服务器，请稍后重试';
      }
      if (code == 'CREDENTIALS_REQUIRED' || code == 'DEVICE_ID_REQUIRED') {
        return '请求参数错误，请更新应用后重试';
      }
      // 未知 code，去掉前缀展示原始消息
      return rest.isNotEmpty ? rest : '登录失败，请稍后重试';
    }

    // 降级：旧格式走文本匹配
    final lower = message.toLowerCase();
    if (message == '登录失败' ||
        message.contains('登陆失败') ||
        message.contains('登录失败') ||
        lower.contains('invalid credentials') ||
        lower.contains('unauthorized') ||
        lower.contains('email or password')) {
      return '账号或密码错误';
    }
    if (message.contains('DEVICE_LIMIT_EXCEEDED') ||
        lower.contains('device limit exceeded')) {
      return '设备数量已达上限，请移除旧设备或升级套餐';
    }
    return message;
  }

  Future<bool> register(String email, String password, String? inviteCode,
      String emailCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      _logger.info('开始注册: $email');

      final success = await XBoardSDK.instance.auth.register(
        email,
        password,
        inviteCode: inviteCode,
        emailCode: emailCode,
      );

      if (success) {
        _logger.info('注册成功');
        await _storageService.saveUserEmail(email);

        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '注册失败',
        );
        return false;
      }
    } catch (e) {
      _logger.info('注册出错: $e');
      String errorMessage = '注册失败';
      if (e is XBoardException) {
        errorMessage = e.message;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      );
      return false;
    }
  }

  Future<bool> sendVerificationCode(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      _logger.info('发送验证码到: $email');
      final success = await XBoardSDK.instance.auth.sendEmailVerifyCode(email);
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      _logger.info('发送验证码出错: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> resetPassword(
      String email, String password, String emailCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      _logger.info('重置密码: $email');

      final success = await XBoardSDK.instance.auth.forgotPassword(
        email,
        emailCode,
        password,
      );

      if (success) {
        _logger.info('密码重置成功');
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '密码重置失败',
        );
        return false;
      }
    } catch (e) {
      _logger.info('重置密码出错: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> refreshSubscriptionInfoAfterPayment() async {
    if (!state.isAuthenticated) {
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      _logger.info('刷新订阅信息...');

      DomainUser? userInfo = ref.read(userInfoProvider) ?? state.userInfo;
      DomainSubscription? subscriptionData =
          ref.read(subscriptionInfoProvider) ?? state.subscriptionInfo;

      clearGetUserInfoCache();
      clearGetSubscriptionCache();
      ref.invalidate(getUserInfoProvider);
      ref.invalidate(getSubscriptionProvider);

      try {
        final userModel = await ref.read(getUserInfoProvider.future);
        userInfo = _mapUser(userModel);
        await _storageService.saveDomainUser(userInfo);
        ref.read(userInfoProvider.notifier).state = userInfo;
      } catch (e) {
        _logger.info('获取用户详细信息失败: $e');
      }

      try {
        final subscriptionModel =
            await ref.read(getSubscriptionProvider.future);
        subscriptionData =
            _mergeSubscriptionWithCache(_mapSubscription(subscriptionModel));
        await _storageService.saveDomainSubscription(subscriptionData);
        ref.read(subscriptionInfoProvider.notifier).state = subscriptionData;
      } catch (e) {
        _logger.info('获取订阅信息失败: $e');
      }

      state = state.copyWith(
        userInfo: userInfo,
        subscriptionInfo: subscriptionData,
        isLoading: false,
      );
      if (subscriptionData != null) {
        _logger.info('订阅信息已刷新');
      } else {
        _logger.info('订阅信息刷新完成，但未获取到有效订阅');
      }

      if (subscriptionData?.subscribeUrl.isNotEmpty == true) {
        _logger.info('[支付成功] 开始重新导入订阅配置: ${subscriptionData!.subscribeUrl}');
        _logger.info('[支付成功] 使用强制刷新模式，跳过重复检测');
        ref.read(profileImportProvider.notifier).importSubscription(
              subscriptionData.subscribeUrl,
              forceRefresh: true,
            );
      } else {
        _logger.info('[支付成功] 订阅链接为空，跳过重新导入');
      }
    } catch (e) {
      _logger.info('刷新订阅信息出错: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refreshSubscriptionInfo() async {
    if (!state.isAuthenticated) {
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      _logger.info('刷新订阅信息...');

      DomainUser? userInfo = ref.read(userInfoProvider) ?? state.userInfo;
      DomainSubscription? subscriptionData =
          ref.read(subscriptionInfoProvider) ?? state.subscriptionInfo;

      clearGetUserInfoCache();
      clearGetSubscriptionCache();
      ref.invalidate(getUserInfoProvider);
      ref.invalidate(getSubscriptionProvider);

      try {
        final userModel = await ref.read(getUserInfoProvider.future);
        userInfo = _mapUser(userModel);
        await _storageService.saveDomainUser(userInfo);
        ref.read(userInfoProvider.notifier).state = userInfo;
      } catch (e) {
        _logger.info('获取用户详细信息失败: $e');
      }

      try {
        final subscriptionModel =
            await ref.read(getSubscriptionProvider.future);
        subscriptionData =
            _mergeSubscriptionWithCache(_mapSubscription(subscriptionModel));
        await _storageService.saveDomainSubscription(subscriptionData);
        ref.read(subscriptionInfoProvider.notifier).state = subscriptionData;
      } catch (e) {
        _logger.info('获取订阅信息失败: $e');
      }

      state = state.copyWith(
        userInfo: userInfo,
        subscriptionInfo: subscriptionData,
        isLoading: false,
      );
      if (subscriptionData != null) {
        _logger.info('订阅信息已刷新');
      } else {
        _logger.info('订阅信息刷新完成，但未获取到有效订阅');
      }

      // 触发订阅导入流程
      if (subscriptionData?.subscribeUrl.isNotEmpty == true) {
        _logger.info('[手动刷新] 开始导入订阅配置: ${subscriptionData!.subscribeUrl}');
        _logger.info('[手动刷新] 使用强制刷新模式，跳过重复检测');
        ref.read(profileImportProvider.notifier).importSubscription(
              subscriptionData.subscribeUrl,
              forceRefresh: true,
            );
      } else {
        _logger.info('[手动刷新] 订阅链接为空，跳过导入');
      }
    } catch (e) {
      _logger.info('刷新订阅信息出错: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refreshUserInfo() async {
    if (!state.isAuthenticated) {
      return;
    }
    try {
      _logger.info('刷新用户详细信息...');

      clearGetUserInfoCache();
      ref.invalidate(getUserInfoProvider);
      final userModel = await ref.read(getUserInfoProvider.future);
      final userInfoData = _mapUser(userModel);

      await _storageService.saveDomainUser(userInfoData);
      ref.read(userInfoProvider.notifier).state = userInfoData;
      state = state.copyWith(userInfo: userInfoData);
      _logger.info('用户详细信息已刷新');
    } catch (e) {
      _logger.info('刷新用户详细信息出错: $e');
    }
  }

  Future<bool> updateReminderSettings({
    bool? remindExpire,
    bool? remindTraffic,
  }) async {
    if (!state.isAuthenticated) {
      return false;
    }
    final payload = <String, dynamic>{};
    if (remindExpire != null) {
      payload['remind_expire'] = remindExpire ? 1 : 0;
    }
    if (remindTraffic != null) {
      payload['remind_traffic'] = remindTraffic ? 1 : 0;
    }
    if (payload.isEmpty) {
      return false;
    }

    try {
      final success = await XBoardSDK.instance.user.updateUserInfo(payload);
      if (success) {
        await refreshUserInfo();
      }
      return success;
    } catch (e) {
      _logger.info('更新通知设置失败: $e');
      return false;
    }
  }

  DomainSubscription _mergeSubscriptionWithCache(DomainSubscription current) {
    final cached = ref.read(subscriptionInfoProvider);
    final planId = current.planId > 0 ? current.planId : (cached?.planId ?? 0);
    final planName = (current.planName?.trim().isNotEmpty == true)
        ? current.planName
        : ((cached?.planName?.trim().isNotEmpty == true)
            ? cached?.planName
            : null);
    final expiredAt = current.expiredAt ?? cached?.expiredAt;
    final nextResetAt = current.nextResetAt ?? cached?.nextResetAt;
    final resetDay = _resolveResetDay(
      current: current,
      cached: cached,
      nextResetAt: nextResetAt,
    );
    final mergedMetadata = <String, dynamic>{
      ...?cached?.metadata,
      ...current.metadata,
    };
    if (resetDay != null && resetDay >= 0) {
      mergedMetadata['resetDay'] = resetDay;
    }
    return current.copyWith(
      planId: planId,
      planName: planName,
      transferLimit: current.transferLimit > 0
          ? current.transferLimit
          : (cached?.transferLimit ?? 0),
      expiredAt: expiredAt,
      nextResetAt: nextResetAt,
      speedLimit: current.speedLimit ?? cached?.speedLimit,
      deviceLimit: current.deviceLimit ?? cached?.deviceLimit,
      metadata: mergedMetadata,
    );
  }

  int? _resolveResetDay({
    required DomainSubscription current,
    required DomainSubscription? cached,
    required DateTime? nextResetAt,
  }) {
    final currentValue = current.metadata['resetDay'];
    if (currentValue is num) return currentValue.toInt();
    if (currentValue is String) {
      final parsed = int.tryParse(currentValue);
      if (parsed != null) return parsed;
    }
    final cachedValue = cached?.metadata['resetDay'];
    if (cachedValue is num) return cachedValue.toInt();
    if (cachedValue is String) {
      final parsed = int.tryParse(cachedValue);
      if (parsed != null) return parsed;
    }
    if (nextResetAt != null) {
      final days = nextResetAt.difference(DateTime.now()).inDays;
      return days < 0 ? 0 : days;
    }
    return null;
  }

  Future<void> logout() async {
    _nextAuthGeneration();
    _logger.info('用户登出');
    final savedEmail = await _storageService.getSavedEmail();
    final savedPassword = await _storageService.getSavedPassword();
    final rememberPassword = await _storageService.getRememberPassword();
    state = const UserAuthState(isInitialized: true);

    // 1. 停止订阅守卫（停止自动刷新和过期检测）
    subscriptionGuardService.stopGuard();

    // 2. 如果正在连接，先断开
    try {
      if (globalState.appState.runTime != null) {
        _logger.info('登出前断开连接');
        await globalState.appController.updateStatus(false);
      }
    } catch (e) {
      _logger.error('登出断开连接失败: $e');
    }

    // 3. 清除 SDK Token 和存储层认证数据
    try {
      await XBoardSDK.instance.logout();
    } catch (e) {
      _logger.warning('SDK 登出失败，继续清理本地状态: $e');
    }
    try {
      await _storageService.clearAuthData();
      if (rememberPassword &&
          (savedEmail?.isNotEmpty == true ||
              savedPassword?.isNotEmpty == true)) {
        await _storageService.saveCredentials(
          savedEmail ?? '',
          savedPassword ?? '',
          true,
        );
      }
    } catch (e) {
      _logger.warning('清理认证存储失败，继续登出: $e');
    }
    // 清除 OSS 模式缓存，下次登录重新从 Supabase 查询
    try {
      await _storageService.clearOssMode();
    } catch (e) {
      _logger.warning('清除 OSS 模式缓存失败: $e');
    }
    // 清除域名竞速缓存，确保重新登录时从 OSS 拉取最新域名
    try {
      await XBoardConfig.clearRacingCache();
    } catch (e) {
      _logger.warning('清除域名竞速缓存失败: $e');
    }

    // 4. 清除 Clash 内存中的节点和延迟数据，防止跨账户污染
    try {
      _logger.info('清除 Clash 内存数据（节点/延迟）');
      globalState.appState = globalState.appState.copyWith(
        groups: [],
        delayMap: {},
      );
      ref.read(groupsProvider.notifier).value = [];
      ref.read(delayDataSourceProvider.notifier).value = {};
    } catch (e) {
      _logger.error('清除 Clash 内存数据失败: $e');
    }

    // 5. 清除用户信息和订阅信息 Provider
    try {
      ref.read(userInfoProvider.notifier).state = null;
      ref.read(subscriptionInfoProvider.notifier).state = null;
      clearGetUserInfoCache();
      clearGetSubscriptionCache();
      clearGetPlansCache();
      clearGetOrdersCache();
      ref.invalidate(getUserInfoProvider);
      ref.invalidate(getSubscriptionProvider);
      ref.invalidate(getPlansProvider);
      ref.invalidate(getOrdersProvider);
    } catch (e) {
      _logger.warning('清理 Provider 缓存失败: $e');
    }

    // 6. 清理 Profile（删除订阅 URL + 重置 currentProfileId）
    try {
      _logger.info('清理 Profile 数据');
      final profiles = ref.read(profilesProvider);
      for (final profile in profiles) {
        if (profile.url.isNotEmpty) {
          ref.read(profilesProvider.notifier).updateProfile(
                profile.id,
                (p) => p.copyWith(url: ''),
              );
        }
      }
    } catch (e) {
      _logger.error('清理 Profile 失败: $e');
    }

    // 7. 保存清理后的配置到磁盘
    try {
      await globalState.appController.savePreferences();
    } catch (e) {
      _logger.error('保存配置失败: $e');
    }

    state = const UserAuthState(
      isInitialized: true, // 登出后保持初始化状态，只重置认证信息
    );
    _logger.info('登出完成，所有账户数据已清除');
  }

  String? get currentAuthToken => null; // Token管理已委托给域名服务
  bool get isAuthenticated => state.isAuthenticated;
  String? get currentEmail => state.email;
}

final xboardUserAuthProvider =
    NotifierProvider<XBoardUserAuthNotifier, UserAuthState>(
  XBoardUserAuthNotifier.new,
);
final xboardUserProvider = xboardUserAuthProvider;

extension UserInfoHelpers on WidgetRef {
  DomainUser? get userInfo => read(userInfoProvider);
  DomainSubscription? get subscriptionInfo => read(subscriptionInfoProvider);
  UserAuthState get userAuthState => read(xboardUserAuthProvider);
  bool get isAuthenticated => read(xboardUserAuthProvider).isAuthenticated;
}

DomainUser _mapUser(UserModel user) {
  return DomainUser(
    email: user.email,
    uuid: user.uuid,
    avatarUrl: user.avatarUrl,
    planId: user.planId,
    transferLimit: user.transferEnable.toInt(),
    uploadedBytes: 0,
    downloadedBytes: 0,
    balanceInCents: user.balance.toInt(),
    commissionBalanceInCents: user.commissionBalance.toInt(),
    expiredAt: user.expiredAt != null && user.expiredAt!.year > 1970
        ? user.expiredAt
        : null,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
    banned: user.banned,
    remindExpire: user.remindExpire,
    remindTraffic: user.remindTraffic,
    discount: user.discount,
    commissionRate: user.commissionRate,
    telegramId: user.telegramId,
  );
}

DomainSubscription _mapSubscription(SubscriptionModel sub) {
  return DomainSubscription(
    subscribeUrl: sub.subscribeUrl ?? '',
    email: sub.email ?? '',
    uuid: sub.uuid ?? '',
    planId: sub.planId ?? 0,
    planName: sub.planName,
    token: sub.token,
    transferLimit: sub.transferEnable ?? 0,
    uploadedBytes: sub.u ?? 0,
    downloadedBytes: sub.d ?? 0,
    speedLimit: sub.speedLimit,
    deviceLimit: sub.deviceLimit,
    expiredAt: sub.expiredAt != null && sub.expiredAt!.year > 1970
        ? sub.expiredAt
        : null,
    nextResetAt: sub.nextResetAt,
    metadata: {
      if (sub.resetDay != null) 'resetDay': sub.resetDay,
    },
  );
}
