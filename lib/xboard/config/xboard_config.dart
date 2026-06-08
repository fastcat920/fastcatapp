/// XBoard 配置模块 - 主入口
/// 
/// 这是重构后的XBoard配置模块，提供清晰的分层架构和统一的API接口
library;

// ========== 公共API导出 ==========
// 只导出外部需要使用的类和接口

// 配置接口（关键！允许SDK层依赖接口而非实现）
export 'interface/config_provider_interface.dart';

// 核心配置设置（外部可能需要自定义配置）
export 'core/config_settings.dart' show 
  ConfigSettings,
  RemoteConfigSettings,
  LogSettings,
  RemoteSourceConfig;

// 数据模型（外部需要访问配置数据）
export 'models/config_entry.dart';
export 'models/proxy_info.dart';
export 'models/websocket_info.dart';
export 'models/update_info.dart' show UpdateRichConfig, UpdatePlatformInfo;
// 注意：SubscriptionInfo与SDK中的同名，这里只导出SubscriptionUrlInfo
export 'models/subscription_info.dart' show SubscriptionUrlInfo;

// 状态枚举（外部需要监听状态）
export 'internal/xboard_config_accessor.dart' show ConfigAccessorState;

// 日志工具已移至core
// export 'utils/logger.dart' show ConfigLogger;

// 配置文件加载器（开源友好）
export 'utils/config_file_loader.dart';

// ========== 便捷API ==========

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/module_initializer.dart';
import 'core/config_settings.dart';
import 'internal/xboard_config_accessor.dart';
import 'models/config_entry.dart';
import 'models/proxy_info.dart';
import 'models/websocket_info.dart';
import 'models/update_info.dart' show UpdateRichConfig;
import 'models/subscription_info.dart';
import '../infrastructure/infrastructure.dart';

import 'interface/config_provider_interface.dart';

/// 内部配置提供者实现
/// 
/// 实现ConfigProviderInterface接口，供SDK层使用
class _XBoardConfigProvider implements ConfigProviderInterface {
  final XBoardConfigAccessor accessor;
  
  _XBoardConfigProvider(this.accessor);
  
  @override
  String getPanelType() => accessor.getPanelType();

  @override
  String getApiPrefix() => accessor.getApiPrefix();

  @override
  String? getPanelUrl() => accessor.getFirstPanelUrl();
  
  @override
  String? getProxyUrl() => accessor.getFirstProxyUrl();
  
  @override
  String? getWebSocketUrl() => accessor.getFirstWebSocketUrl();
  
  @override
  SubscriptionInfo? getSubscriptionInfo() => accessor.getSubscriptionInfo();
  
  @override
  String? getSubscriptionUrl() => getSubscriptionInfo()?.firstUrl;
  
  @override
  String? buildSubscriptionUrl(String token, {bool preferEncrypt = true}) {
    return getSubscriptionInfo()?.buildSubscriptionUrl(token, forceEncrypt: preferEncrypt);
  }
  
  @override
  Future<String?> getFastestPanelUrl() async {
    final panelUrls = getAllPanelUrls();
    if (panelUrls.isEmpty) return null;

    // 获取所有代理配置
    final proxyUrls = getAllProxyUrls();

    // 收集所有可达候选（而非仅返回最快一个），建立故障转移列表
    final candidates = await DomainRacingService.raceCollectAllDomains(
      panelUrls,
      forceHttpsResult: true,
      proxyUrls: proxyUrls,
    );

    if (candidates.isEmpty) return null;

    // 保存有序候选列表供故障转移使用
    XBoardConfig._orderedCandidates = candidates;
    XBoardConfig._currentCandidateIndex = 0;
    XBoardConfig._lastRacingResult = candidates.first;

    return candidates.first.domain;
  }
  
  @override
  List<String> getAllPanelUrls() => accessor.getPanelConfigList().map((e) => e.url).toList();

  @override
  List<String> getGatewayUrls() => accessor.getGatewayUrls();
  
  @override
  List<String> getAllProxyUrls() => accessor.getProxyConfigList().map((e) => e.url).toList();
  
  @override
  List<String> getAllWebSocketUrls() => accessor.getWebSocketConfigList().map((e) => e.url).toList();
  
  @override
  Future<void> refresh() async {
    await accessor.refreshConfiguration();
  }
  
  @override
  Future<void> refreshFromSource(String source) async {
    await accessor.refreshFromSource(source);
  }
  
  @override
  Stream<void> get configChangeStream => accessor.configStream.map((_) {});
}

/// XBoard配置模块主入口类
///
/// 这是唯一的公共API入口，外部应该只通过这个类访问配置功能
class XBoardConfig {
  static XBoardConfigAccessor? _instance;
  static _XBoardConfigProvider? _provider;

  // 内存缓存：最后一次竞速结果（指向 _orderedCandidates[_currentCandidateIndex]）
  static DomainRacingResult? _lastRacingResult;

  // 有序候选列表：所有竞速成功的域名，按响应时间升序排列（故障转移用）
  static List<DomainRacingResult> _orderedCandidates = [];
  // 当前正在使用的候选索引（故障转移时递增）
  static int _currentCandidateIndex = 0;

  // 兜底面板 URL（当远程配置和缓存均不可用时使用，可由 config.yaml 的 fallback_panel_url 配置）
  static String? _fallbackPanelUrl;

  // 磁盘缓存配置
  static const _kRacingCacheKey = 'xboard_racing_cache';
  // 缓存有效期：10 分钟。命中时立即返回，同时后台刷新以备下次使用
  static const _kRacingCacheTtlMs = 10 * 60 * 1000;

  // 私有构造函数，防止外部实例化
  XBoardConfig._();

  /// 初始化模块
  ///
  /// [provider] 当前使用的提供商 (Flclash/Flclash)
  /// [settings] 可选的详细配置设置
  ///
  /// 这是初始化模块的唯一方式
  static Future<void> initialize({
    String provider = 'Flclash',
    ConfigSettings? settings,
  }) async {
    final config = settings ?? ConfigSettings(currentProvider: provider);

    _instance = await ModuleInitializer.createConfigAccessor(
      settings: config,
      autoWarmUp: false,  // 不在 main() 里做网络请求，避免阻塞 runApp()
    );
    
    // 创建配置提供者实例
    _provider = _XBoardConfigProvider(_instance!);
  }
  
  /// 获取配置提供者接口（供SDK层使用）
  /// 
  /// 返回实现了ConfigProviderInterface的实例
  static ConfigProviderInterface get provider {
    if (_provider == null) {
      throw StateError('XBoardConfig not initialized. Call initialize() first.');
    }
    return _provider!;
  }
  
  /// 检查是否已初始化
  static bool get isInitialized => _instance != null;
  
  /// 获取最后一次竞速结果
  static DomainRacingResult? get lastRacingResult => _lastRacingResult;
  
  /// 重置模块
  static void reset() {
    _instance?.dispose();
    _instance = null;
    _provider = null;
    _lastRacingResult = null;
    _orderedCandidates = [];
    _currentCandidateIndex = 0;
    ModuleInitializer.reset();
  }

  /// 清除域名竞速的磁盘缓存和内存缓存
  ///
  /// 退出登录时调用，确保重新登录时从 OSS 拉取最新域名配置，
  /// 避免 OSS 配置已更新但客户端仍使用旧缓存域名的问题。
  static Future<void> clearRacingCache() async {
    _lastRacingResult = null;
    _orderedCandidates = [];
    _currentCandidateIndex = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRacingCacheKey);
    } catch (_) {}
  }
  
  // ========== 内部访问器（受保护） ==========
  
  /// 获取内部配置访问器（仅供内部使用）
  /// 
  /// 注意：这个方法主要用于高级用户，一般情况下使用便捷方法即可
  static XBoardConfigAccessor get _accessor {
    if (_instance == null) {
      throw StateError('XBoardConfig not initialized. Call initialize() first.');
    }
    return _instance!;
  }
  
  // ========== 公共API方法 ==========
  
  /// 获取第一个面板URL
  static String? get panelUrl => _accessor.getFirstPanelUrl();

  // 缓存正在进行的竞速任务（请求合并，防止并发重复竞速）
  static Future<String?>? _racingFuture;

  /// 将有序候选列表持久化到磁盘（SharedPreferences）
  static Future<void> _saveOrderedCandidatesToCache(List<DomainRacingResult> candidates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = candidates.map((r) => {
        'domain': r.domain,
        'useProxy': r.useProxy,
        'proxyUrl': r.proxyUrl,
        'responseTime': r.responseTime,
      }).toList();
      final data = jsonEncode({
        'candidates': list,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await prefs.setString(_kRacingCacheKey, data);
    } catch (_) {
      // 写缓存失败不影响主流程
    }
  }

  /// 从磁盘读取有序候选列表（兼容旧格式单结果；过期或不存在则返回 null）
  static Future<List<DomainRacingResult>?> _loadCachedOrderedCandidates({bool ignoreExpiry = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kRacingCacheKey);
      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      if (!ignoreExpiry) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > _kRacingCacheTtlMs) return null;
      }

      // 新格式：包含 candidates 数组
      if (data.containsKey('candidates')) {
        final list = (data['candidates'] as List).map((e) => DomainRacingResult(
          domain: e['domain'] as String,
          useProxy: e['useProxy'] as bool,
          proxyUrl: e['proxyUrl'] as String?,
          responseTime: e['responseTime'] as int,
        )).toList();
        return list.isEmpty ? null : list;
      }

      // 旧格式：单个结果，兼容转换为单元素列表
      if (data.containsKey('domain')) {
        return [DomainRacingResult(
          domain: data['domain'] as String,
          useProxy: data['useProxy'] as bool,
          proxyUrl: data['proxyUrl'] as String?,
          responseTime: data['responseTime'] as int,
        )];
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// 后台静默刷新竞速缓存（fire-and-forget，不阻塞调用方）
  static void _refreshRacingInBackground() {
    Future(() async {
      if (_racingFuture != null) return; // 已有竞速任务，跳过
      final panelUrls = allPanelUrls;
      if (panelUrls.isEmpty) return;
      final proxyUrls = allProxyUrls;
      final candidates = await DomainRacingService.raceCollectAllDomains(
        panelUrls,
        forceHttpsResult: true,
        proxyUrls: proxyUrls,
      );
      if (candidates.isNotEmpty) {
        _orderedCandidates = candidates;
        _currentCandidateIndex = 0;
        _lastRacingResult = candidates.first;
        await _saveOrderedCandidatesToCache(candidates);
      }
    });
  }

  /// 并发竞速获取最快的面板URL
  ///
  /// 专业客户端策略（Shadowrocket / Clash for Android 同款）：
  ///   1. 命中磁盘缓存（30 min 内）→ 立即返回，后台静默刷新
  ///   2. 缓存过期/不存在 → 阻塞竞速，结果写入缓存
  ///   3. 并发请求合并：多个调用方共享同一个竞速 Future
  ///
  /// 效果：冷启动后首次打开几乎无感知延迟（缓存命中时 <5ms），
  ///       后台刷新保证下次使用的缓存始终是最新最优的。
  static Future<String?> getFastestPanelUrl() async {
    // ── 1. 尝试磁盘缓存 ──────────────────────────────────────────
    final cachedCandidates = await _loadCachedOrderedCandidates();
    if (cachedCandidates != null && cachedCandidates.isNotEmpty) {
      _orderedCandidates = cachedCandidates;
      _currentCandidateIndex = 0;
      _lastRacingResult = cachedCandidates.first;
      // 后台静默刷新，不影响当前启动速度
      _refreshRacingInBackground();
      return cachedCandidates.first.domain;
    }

    // ── 2. 无有效缓存：阻塞竞速（请求合并） ─────────────────────
    if (_racingFuture != null) {
      return _racingFuture;
    }

    final panelUrls = allPanelUrls;
    if (panelUrls.isEmpty) {
      // 远程配置未加载，用过期缓存兜底（总比无域名好）
      final staleCandidates = await _loadCachedOrderedCandidates(ignoreExpiry: true);
      if (staleCandidates != null && staleCandidates.isNotEmpty) {
        _orderedCandidates = staleCandidates;
        _currentCandidateIndex = 0;
        _lastRacingResult = staleCandidates.first;
        // ignore: avoid_print
        print('[XBoardConfig] 远程配置为空，使用过期缓存域名: ${staleCandidates.first.domain}');
        return staleCandidates.first.domain;
      }
      // 最后兜底：config.yaml 的 fallback_panel_url
      if (_fallbackPanelUrl != null) {
        // ignore: avoid_print
        print('[XBoardConfig] 使用 config.yaml 兜底域名: $_fallbackPanelUrl');
        final fallback = DomainRacingResult(
          domain: _fallbackPanelUrl!,
          useProxy: false,
          proxyUrl: null,
          responseTime: 0,
        );
        _orderedCandidates = [fallback];
        _currentCandidateIndex = 0;
        _lastRacingResult = fallback;
        return _fallbackPanelUrl;
      }
      return null;
    }

    final proxyUrls = allProxyUrls;
    _racingFuture = DomainRacingService.raceCollectAllDomains(
      panelUrls,
      forceHttpsResult: true,
      proxyUrls: proxyUrls,
      onBackgroundComplete: (allResults) async {
        // 后台收集完成：用完整排序列表更新缓存和候选
        if (allResults.isNotEmpty) {
          _orderedCandidates = allResults;
          _currentCandidateIndex = 0;
          await _saveOrderedCandidatesToCache(allResults);
          // ignore: avoid_print
          print('[XBoardConfig] 后台竞速完成，更新缓存: ${allResults.length} 个候选');
        }
      },
    ).then((candidates) async {
      if (candidates.isNotEmpty) {
        _orderedCandidates = candidates;
        _currentCandidateIndex = 0;
        _lastRacingResult = candidates.first;
        await _saveOrderedCandidatesToCache(candidates); // 写入磁盘，供下次冷启动使用
        return candidates.first.domain;
      }
      return null;
    }).whenComplete(() {
      _racingFuture = null;
    });

    return _racingFuture;
  }

  /// 故障转移：返回下一个可用的面板URL
  ///
  /// 当当前面板URL不可达时调用，自动切换到响应次优的候选。
  /// 如果所有候选已耗尽，触发后台重新竞速并返回 null。
  static Future<String?> getNextPanelUrl() async {
    _currentCandidateIndex++;
    if (_currentCandidateIndex < _orderedCandidates.length) {
      final next = _orderedCandidates[_currentCandidateIndex];
      _lastRacingResult = next;
      // ignore: avoid_print
      print('[XBoardConfig] 🔄 故障转移 → 候选 #$_currentCandidateIndex: ${next.domain} (${next.responseTime}ms)');
      return next.domain;
    }
    // 候选列表已耗尽，触发后台重新竞速（供下次使用）
    // ignore: avoid_print
    print('[XBoardConfig] ⚠️ 所有 ${_orderedCandidates.length} 个候选均已失败，触发后台重新竞速');
    _refreshRacingInBackground();
    return null;
  }
  
  /// 获取第一个代理URL
  static String? get proxyUrl => _accessor.getFirstProxyUrl();
  
  /// 获取第一个WebSocket URL
  static String? get wsUrl => _accessor.getFirstWebSocketUrl();
  
  /// 获取更新富配置（含各平台版本/下载URL/是否强制更新）
  static UpdateRichConfig? get updateConfig => _instance?.getUpdateRichConfig();

  /// 获取面板配置列表
  static List<ConfigEntry> get panelList => _accessor.getPanelConfigList();
  
  /// 获取代理配置列表
  static List<ProxyInfo> get proxyList => _accessor.getProxyConfigList();
  
  /// 获取WebSocket配置列表
  static List<WebSocketInfo> get webSocketList => _accessor.getWebSocketConfigList();

  /// 获取订阅配置信息
  static SubscriptionInfo? get subscriptionInfo => _accessor.getSubscriptionInfo();

  /// 获取订阅URL列表
  static List<SubscriptionUrlInfo> get subscriptionUrlList => subscriptionInfo?.urls ?? [];

  /// 获取第一个订阅URL
  static String? get subscriptionUrl => subscriptionInfo?.firstUrl;

  /// 获取第一个支持加密的订阅URL
  static String? get encryptSubscriptionUrl => subscriptionInfo?.firstEncryptUrl?.url;

  /// 构建订阅URL（带token）
  static String? buildSubscriptionUrl(String token, {bool preferEncrypt = true}) {
    return subscriptionInfo?.buildSubscriptionUrl(token, forceEncrypt: preferEncrypt);
  }

  /// 并发竞速获取最快的订阅URL
  /// 
  /// 对所有订阅URL进行并发测试，返回第一个成功（200响应）的URL
  /// [token] 用户订阅token
  /// [preferEncrypt] 是否优先使用加密端点
  /// 
  /// 返回最快响应成功的订阅URL，如果都失败则返回第一个URL
  static Future<String?> getFastestSubscriptionUrl(
    String token, {
    bool preferEncrypt = true,
  }) async {
    final subInfo = subscriptionInfo;
    if (subInfo == null || subInfo.urls.isEmpty) return null;
    
    // 构建所有可能的订阅URL
    final List<String> subscriptionUrls = [];
    
    for (final urlInfo in subInfo.urls) {
      final url = urlInfo.buildSubscriptionUrl(token, preferEncrypt: preferEncrypt);
      if (url.isNotEmpty) {
        subscriptionUrls.add(url);
      }
    }
    
    if (subscriptionUrls.isEmpty) return null;
    
    // 获取所有代理
    final proxyUrls = allProxyUrls;
    
    // 使用竞速服务选择最快的订阅URL
    final racingResult = await DomainRacingService.raceSelectFastestDomain(
      subscriptionUrls,
      forceHttpsResult: false, // 订阅URL保持原始格式
      proxyUrls: proxyUrls,
    );
    
    return racingResult?.domain;
  }
  
  /// 获取所有面板URL列表
  static List<String> get allPanelUrls => panelList.map((e) => e.url).toList();

  /// 设备网关地址列表（OSS 远程配置 gateway_urls）
  /// 用于故障转移：主地址不可用时自动切换到备用地址
  static List<String> get gatewayUrls => _accessor.getGatewayUrls();

  /// 当前远程配置版本（优先 config_version，回退 metadata.version/sourceHash）
  static String get configVersion => _accessor.getConfigVersion();

  static const _kGatewayCacheKey = 'gateway_cached_url';

  /// 运行时更新网关地址列表，并持久化到 SharedPreferences
  static void setGatewayUrls(List<String> urls) {
    _accessor.setGatewayUrls(urls);
    if (urls.isNotEmpty) _persistGatewayUrl(urls.first);
  }

  /// 故障转移成功后，将成功的 URL 排到第一位，并持久化
  static void promoteGatewayUrl(String url) {
    _accessor.promoteGatewayUrl(url, onPromoted: () => _persistGatewayUrl(url));
  }

  /// 读取缓存的上次成功网关 URL
  static Future<String?> getCachedGatewayUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kGatewayCacheKey);
    } catch (_) {
      return null;
    }
  }

  static void _persistGatewayUrl(String url) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kGatewayCacheKey, url);
    });
  }

  /// 获取所有代理URL列表
  static List<String> get allProxyUrls => proxyList.map((e) => e.url).toList();
  
  /// 获取所有WebSocket URL列表
  static List<String> get allWsUrls => webSocketList.map((e) => e.url).toList();

  /// 获取所有订阅URL列表
  static List<String> get allSubscriptionUrls => subscriptionUrlList.map((e) => e.url).toList();

  /// 获取所有支持加密的订阅URL列表
  static List<String> get allEncryptSubscriptionUrls =>
      subscriptionUrlList.where((e) => e.supportEncrypt).map((e) => e.url).toList();

  /// 获取 Crisp 客服 Website ID（来自远程配置 contact.crisp_website_id）
  /// 为空字符串表示未配置，UI 层应据此决定是否显示客服入口
  static String get crispWebsiteId => _instance?.crispWebsiteId ?? '';

  /// 获取 Salesmartly 客服配置（来自远程配置 contact.salesmartly_token）
  /// 支持两种格式：
  /// - 新版：完整 JS URL，如 https://assets.salesmartly.com/js/project_XXXXX_XXXXX_XXXXXXXXXX.js
  /// - 旧版：Widget Token 字符串
  /// 为空字符串表示未配置
  static String get salesmartlyToken => _instance?.salesmartlyToken ?? '';

  /// 是否有任何客服渠道已配置（Salesmartly 或 Crisp）
  static bool get hasCustomerService =>
      salesmartlyToken.isNotEmpty || crispWebsiteId.isNotEmpty;

  /// 获取邀请链接自定义域名（来自远程配置 contact.invite_domain）
  /// 为空字符串表示使用面板域名拼接邀请链接
  static String get inviteDomain => _instance?.inviteDomain ?? '';

  /// 获取官方网站 URL 列表（来自远程配置 contact.website，支持 string 或 array）
  /// 为空列表表示未配置，回退到 API /api/v1/guest/comm/config 的 app_url
  static List<String> get websiteUrls => _instance?.websiteUrls ?? [];

  /// 获取 Telegram 群组链接（来自远程配置 contact.telegram_group）
  /// 为空字符串表示未配置，回退到 API /api/v1/user/comm/config 的 telegram_discuss_link
  static String get telegramGroupUrl => _instance?.telegramGroupUrl ?? '';

  /// 获取 ImgBB API Key（来自远程配置 ticket.imgbb_api_key）
  /// 为空字符串表示未配置，工单图片上传功能将被禁用
  /// 前往 https://imgbb.com 注册并获取 API Key
  static String get imgbbApiKey => _instance?.imgbbApiKey ?? '';

  /// 是否显示流量明细（来自远程配置 features.traffic_details_enabled，默认 true）
  static bool get isTrafficDetailsEnabled => _instance?.trafficDetailsEnabled ?? true;

  /// 是否显示文档中心（来自远程配置 features.knowledge_base_enabled，默认 true）
  static bool get isKnowledgeBaseEnabled => _instance?.knowledgeBaseEnabled ?? true;

  /// 是否显示礼品卡兑换（来自远程配置 features.gift_card_enabled，默认 true）
  static bool get isGiftCardEnabled => _instance?.giftCardEnabled ?? true;

  /// 是否显示加入群组（来自远程配置 features.join_group_enabled，默认 true）
  static bool get isJoinGroupEnabled => _instance?.joinGroupEnabled ?? true;

  /// 是否显示订单记录（来自远程配置 features.orders_enabled，默认 true）
  static bool get isOrdersEnabled => _instance?.ordersEnabled ?? true;

  /// 是否显示设备管理（来自远程配置 features.devices_enabled，默认 true）
  static bool get isDevicesEnabled => _instance?.devicesEnabled ?? true;

  /// 是否显示我的工单（来自远程配置 features.tickets_enabled，默认 true）
  static bool get isTicketsEnabled => _instance?.ticketsEnabled ?? true;

  /// 是否显示余额充值（来自远程配置 features.balance_enabled，默认 true）
  static bool get isBalanceEnabled => _instance?.balanceEnabled ?? true;

  /// 刷新配置
  static Future<void> refresh() async {
    await _accessor.refreshConfiguration();
  }
  
  /// 从指定源刷新配置
  static Future<void> refreshFromSource(String source) async {
    await _accessor.refreshFromSource(source);
  }

  /// 直接注入已解析的配置（fallback：配置模块刷新失败时，用外部直连结果填充）
  static Future<void> loadParsedConfig(Map<String, dynamic> configData, {String source = 'direct_fallback'}) async {
    await _accessor.loadParsedConfig(configData, source);
  }
  
  /// 获取配置统计信息
  static Map<String, dynamic> get stats => _accessor.getConfigStats();
  
  /// 获取当前配置状态
  static ConfigAccessorState get state => _accessor.state;
  
  /// 获取最后的错误信息
  static String? get lastError => _accessor.lastError;
  
  /// 监听配置变化
  static Stream<Map<String, dynamic>> get configChangeStream => 
      _accessor.configStream.map((config) => _accessor.getConfigStats());
  
  /// 监听状态变化
  static Stream<ConfigAccessorState> get stateChangeStream => _accessor.stateStream;
}

/// 使用示例：
/// 
/// ```dart
/// // 1. 初始化模块（唯一的初始化方式）
/// await XBoardConfig.initialize(provider: 'Flclash');
/// 
/// // 2. 使用公共API获取配置
/// final panelUrl = XBoardConfig.panelUrl;
/// final proxyUrl = XBoardConfig.proxyUrl;
/// final panelList = XBoardConfig.panelList;
/// final proxyList = XBoardConfig.proxyList;
/// 
/// // 3. 监听配置变化
/// XBoardConfig.configChangeStream.listen((stats) {
///   print('配置已更新: ${stats['panels']} 个面板');
/// });
/// 
/// // 4. 刷新配置
/// await XBoardConfig.refresh();
/// await XBoardConfig.refreshFromSource('redirect');
/// ```
/// 
/// 注意：外部代码不应该直接访问内部类，所有功能都通过XBoardConfig提供
