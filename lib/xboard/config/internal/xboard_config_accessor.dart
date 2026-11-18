import '../models/legal_links.dart';
import 'dart:async';
import '../models/parsed_configuration.dart';
import '../models/config_entry.dart';
import '../models/proxy_info.dart';
import '../models/websocket_info.dart';
import '../models/update_info.dart';
import '../models/subscription_info.dart';
import '../fetchers/remote_config_manager.dart';
import '../../core/core.dart';
import '../parsers/configuration_parser.dart';
import '../services/panel_service.dart';
import '../services/proxy_service.dart';
import '../services/websocket_service.dart';

// 初始化文件级日志器
const _logger = FileLogger('xboard_config_accessor.dart');

/// 配置访问器状态
enum ConfigAccessorState {
  uninitialized,
  loading,
  ready,
  error,
}

/// XBoard配置访问器
///
/// 统一接口层，整合所有配置获取、解析和服务模块
/// 注意：这个类不应该被外部直接实例化，请使用XBoardConfig
class XBoardConfigAccessor {
  final RemoteConfigManager _remoteManager;
  final ConfigurationParser _parser;
  final String _currentProvider;

  // 状态管理
  ConfigAccessorState _state = ConfigAccessorState.uninitialized;
  ParsedConfiguration? _currentConfig;
  String? _lastError;
  DateTime? _lastUpdateTime;
  bool remoteConfirmed = false;
  bool usingStaleCache = false;

  // 服务实例
  PanelService? _panelService;
  ProxyService? _proxyService;
  WebSocketService? _webSocketService;

  // 远程配置 contact 字段
  bool _fastCatSupportEnabled = false;
  bool _fastCatSupportConfigured = false;
  String _fastCatSupportBaseUrl = '';
  String _fastCatSupportAppKey = '';
  List<String> _websiteUrls = [];
  String _telegramGroupUrl = '';
  LegalLinks legalLinks = const LegalLinks();
  String _inviteDomain = '';

  // API 路径前缀（远程配置可覆盖，默认 /api/v1）
  String _apiPrefix = '/api/v1';

  // 远程配置版本（用于判定 gateway/api_prefix 是否应覆盖当前运行时配置）
  String _configVersion = '';

  // 设备网关地址列表（远程配置 gateway_urls/gateway_url，OSS 可远程切换）
  List<String> _gatewayUrls = [];

  // 事件流
  final StreamController<ParsedConfiguration> _configStreamController =
      StreamController<ParsedConfiguration>.broadcast();
  final StreamController<ConfigAccessorState> _stateStreamController =
      StreamController<ConfigAccessorState>.broadcast();

  XBoardConfigAccessor({
    required RemoteConfigManager remoteManager,
    required ConfigurationParser parser,
    required String currentProvider,
    String apiPrefix = '/api/v1',
  })  : _remoteManager = remoteManager,
        _parser = parser,
        _currentProvider = currentProvider,
        _apiPrefix = apiPrefix;

  // ========== 状态属性 ==========

  /// 当前状态
  ConfigAccessorState get state => _state;

  /// 是否正在加载
  bool get isLoading => _state == ConfigAccessorState.loading;

  /// 是否已准备就绪
  bool get isReady => _state == ConfigAccessorState.ready;

  /// 最后的错误信息
  String? get lastError => _lastError;

  /// 最后更新时间
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// 当前配置
  ParsedConfiguration? get currentConfig => _currentConfig;

  /// 当前提供商
  String get currentProvider => _currentProvider;

  // ========== 事件流 ==========

  /// 配置变化流
  Stream<ParsedConfiguration> get configStream =>
      _configStreamController.stream;

  /// 状态变化流
  Stream<ConfigAccessorState> get stateStream => _stateStreamController.stream;

  // ========== 配置管理 ==========

  /// 获取完整配置
  Future<ParsedConfiguration?> getConfiguration() async {
    if (_currentConfig != null && _state == ConfigAccessorState.ready) {
      return _currentConfig;
    }

    await refreshConfiguration();
    return _currentConfig;
  }

  /// 刷新配置（纯远程实时获取）
  Future<void> refreshConfiguration() async {
    remoteConfirmed = false;
    await _updateState(ConfigAccessorState.loading);
    _lastError = null;

    try {
      // 并发获取所有远程源。只有能完成结构提取和完整解析的响应才
      // 算成功，避免 HTTP 200 但内容损坏的主源阻止备用源接管。
      final result = await _remoteManager.fetchFirstUsableConfig((data) {
        try {
          final extracted = _parser.extractConfigFromRemoteResult(data);
          if (extracted == null) return false;
          _parser.parseFromJson(extracted, _currentProvider);
          return _hasCompleteRuntimeRoute(extracted);
        } catch (_) {
          return false;
        }
      });
      if (result.isSuccess && result.data != null) {
        final configData = _parser.extractConfigFromRemoteResult(result.data!);
        if (configData != null) {
          remoteConfirmed = result.source != 'local_cache';
          usingStaleCache = result.isStale;
          await _processConfigData(configData, result.source);
          return;
        }
      }

      // 远程获取失败
      throw Exception('Remote config fetch failed');
    } catch (e) {
      remoteConfirmed = false;
      _lastError = 'Configuration refresh failed: $e';
      await _updateState(ConfigAccessorState.error);
      _logger.error('Configuration refresh failed', e);
      rethrow;
    }
  }

  bool _hasCompleteRuntimeRoute(Map<String, dynamic> config) {
    final panels = config['panels'];
    var hasBusinessRoute = false;
    if (panels is Map) {
      for (final value in panels.values) {
        if (value is! List) continue;
        for (final item in value) {
          final raw = item is Map ? item['url']?.toString() : item?.toString();
          if (_isHttpEndpoint(raw)) {
            hasBusinessRoute = true;
            break;
          }
        }
        if (hasBusinessRoute) break;
      }
    }

    final gatewayValues = <dynamic>[];
    final gatewayUrls = config['gateway_urls'];
    if (gatewayUrls is List) gatewayValues.addAll(gatewayUrls);
    gatewayValues.add(config['gateway_url']);
    final hasGatewayRoute = gatewayValues.any(
      (value) => _isHttpEndpoint(value?.toString()),
    );
    return hasBusinessRoute && hasGatewayRoute;
  }

  bool _isHttpEndpoint(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// 用外部已解析的配置数据直接注入（fallback 路径）
  Future<void> loadParsedConfig(
      Map<String, dynamic> configData, String source) async {
    remoteConfirmed = false;
    await _processConfigData(configData, source);
  }

  /// 从指定源刷新配置
  Future<void> refreshFromSource(String sourceName) async {
    // Legacy aliases are retained, but every refresh now observes the same
    // validation, anti-regression and cache rules instead of bypassing them.
    try {
      if (!['remote', 'redirect', 'gitee'].contains(sourceName.toLowerCase())) {
        throw ArgumentError('Unknown remote source: $sourceName');
      }
      await refreshConfiguration();
    } catch (e) {
      _lastError = 'Refresh from $sourceName failed: $e';
      await _updateState(ConfigAccessorState.error);
      _logger.error('Refresh from $sourceName failed', e);
    }
  }

  /// 清除缓存（已移除缓存功能）
  Future<void> clearCache() async {
    _logger.info('Cache functionality removed, using real-time data');
  }

  // ========== 服务数据分发方法 ==========

  /// 获取面板配置列表
  List<ConfigEntry> getPanelConfigList() {
    return _panelService?.getCurrentProviderPanels() ?? [];
  }

  /// 获取代理配置列表
  List<ProxyInfo> getProxyConfigList() {
    return _proxyService?.getAllProxies() ?? [];
  }

  /// 获取WebSocket配置列表
  List<WebSocketInfo> getWebSocketConfigList() {
    return _webSocketService?.getAllWebSockets() ?? [];
  }

  /// 获取更新富配置
  UpdateRichConfig? getUpdateRichConfig() {
    return _currentConfig?.updateConfig;
  }

  /// 获取订阅配置信息
  SubscriptionInfo? getSubscriptionInfo() {
    return _currentConfig?.subscription;
  }

  // ========== 便捷访问方法 ==========

  /// 获取面板类型
  ///
  /// 远程配置未加载时，回退到本地 config.yaml 中的 panel_type（即 _currentProvider）
  String getPanelType() {
    if (_currentConfig == null) {
      // 远程配置未加载时，用 config.yaml 的 panel_type 作为默认值
      if (_currentProvider.isNotEmpty) return _currentProvider;
      throw XBoardConfigException(
        message: '配置未初始化，无法获取面板类型',
        code: 'CONFIG_NOT_INITIALIZED',
      );
    }

    final panelType = _currentConfig!.panelType;
    if (panelType.isEmpty) {
      throw XBoardConfigException(
        message: '配置文件中未指定面板类型 (panelType)',
        code: 'PANEL_TYPE_NOT_CONFIGURED',
      );
    }

    return panelType;
  }

  /// 获取 API 路径前缀（默认 /api/v1，可通过远程配置 api_prefix 覆盖）
  String getApiPrefix() => _apiPrefix;

  /// 获取当前远程配置版本（优先 config_version，回退 metadata.version/sourceHash）
  String getConfigVersion() => _configVersion;

  /// 获取设备网关地址列表（OSS 远程配置，优先级高于硬编码兜底）
  List<String> getGatewayUrls() => List.unmodifiable(_gatewayUrls);

  /// 运行时更新网关地址列表（从登录/订阅响应中 gateway_urls 字段更新）
  void setGatewayUrls(List<String> urls) {
    if (urls.isEmpty) return;
    _gatewayUrls = urls;
  }

  /// 将指定 URL 排到网关地址列表第一位（故障转移成功后调用）
  void promoteGatewayUrl(String url, {void Function()? onPromoted}) {
    if (!_gatewayUrls.contains(url)) return;
    _gatewayUrls.remove(url);
    _gatewayUrls.insert(0, url);
    onPromoted?.call();
  }

  /// 获取第一个面板URL
  String? getFirstPanelUrl() {
    return _panelService?.getFirstPanelUrl();
  }

  /// 获取第一个代理URL
  String? getFirstProxyUrl() {
    return _proxyService?.getFirstProxyUrl();
  }

  /// 获取第一个WebSocket URL
  String? getFirstWebSocketUrl() {
    return _webSocketService?.getFirstWebSocketUrl();
  }

  /// 获取第一个订阅URL
  String? getFirstSubscriptionUrl() {
    return _currentConfig?.firstSubscriptionUrl;
  }

  /// 获取第一个支持加密的订阅URL
  String? getFirstEncryptSubscriptionUrl() {
    return _currentConfig?.firstEncryptSubscriptionUrl;
  }

  /// 构建订阅URL
  String? buildSubscriptionUrl(String token, {bool preferEncrypt = true}) {
    return _currentConfig?.buildSubscriptionUrl(token,
        preferEncrypt: preferEncrypt);
  }

  bool get fastCatSupportEnabled => _fastCatSupportEnabled;

  bool get fastCatSupportConfigured => _fastCatSupportConfigured;

  String get fastCatSupportBaseUrl => _fastCatSupportBaseUrl;

  String get fastCatSupportAppKey => _fastCatSupportAppKey;

  /// 获取官方网站 URL 列表（来自远程配置 contact.website，支持 string 或 array）
  List<String> get websiteUrls => _websiteUrls;

  /// 获取 Telegram 群组链接（来自远程配置 contact.telegram_group）
  String get telegramGroupUrl => _telegramGroupUrl;

  /// 获取邀请链接自定义域名（来自远程配置 contact.invite_domain）
  /// 为空字符串表示使用面板域名
  String get inviteDomain => _inviteDomain;

  // ========== 统计信息 ==========

  /// 获取配置统计信息
  Map<String, dynamic> getConfigStats() {
    if (_currentConfig == null) {
      return {
        'panels': 0,
        'proxies': 0,
        'webSockets': 0,
        'updates': 0,
        'subscriptionUrls': 0,
      };
    }

    return {
      'panels': _currentConfig!.panels.getAll().length,
      'proxies': _currentConfig!.proxies.length,
      'webSockets': _currentConfig!.webSockets.length,
      'updates': _currentConfig!.updateConfig?.isNotEmpty == true ? 1 : 0,
      'subscriptionUrls': _currentConfig!.subscription?.urls.length ?? 0,
      'subscriptionEncryptUrls':
          _currentConfig!.subscription?.encryptUrls.length ?? 0,
      'currentProvider': _currentProvider,
      'lastUpdateTime': _lastUpdateTime?.toIso8601String(),
      'sourceHash': _currentConfig!.sourceHash,
      'remoteConfirmed': remoteConfirmed,
      'usingStaleCache': usingStaleCache,
    };
  }

  /// 获取服务统计信息
  Map<String, dynamic> getServiceStats() {
    return {
      'panel': _panelService?.getPanelStats() ?? {},
      'proxy': _proxyService?.getProxyStats() ?? {},
      'webSocket': _webSocketService?.getWebSocketStats() ?? {},
    };
  }

  // ========== 内部方法 ==========

  /// 处理配置数据
  Future<void> _processConfigData(
      Map<String, dynamic> configData, String source) async {
    try {
      // 解析配置
      _currentConfig = _parser.parseFromJson(configData, _currentProvider);
      _lastUpdateTime = DateTime.now();

      // 创建服务实例
      _panelService = PanelService(_currentConfig!.panels);
      _proxyService = ProxyService(_currentConfig!.proxies);
      _webSocketService = WebSocketService(_currentConfig!.webSockets);

      legalLinks = LegalLinks.fromJson(configData['legal']);

      // 提取 contact 字段
      final contact = configData['contact'] as Map<String, dynamic>? ?? {};
      final rawFastCatSupport = contact['fastcat_support'];
      _fastCatSupportConfigured = rawFastCatSupport is Map;
      final fastCatSupport = rawFastCatSupport is Map
          ? rawFastCatSupport.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      _fastCatSupportBaseUrl =
          fastCatSupport['base_url']?.toString().trim() ?? '';
      _fastCatSupportAppKey =
          fastCatSupport['app_key']?.toString().trim() ?? '';
      _fastCatSupportEnabled = fastCatSupport['enabled'] != false &&
          _fastCatSupportBaseUrl.isNotEmpty &&
          _fastCatSupportAppKey.isNotEmpty;
      final rawWebsite = contact['website'];
      if (rawWebsite is String) {
        _websiteUrls = rawWebsite.isNotEmpty ? [rawWebsite] : [];
      } else if (rawWebsite is List) {
        _websiteUrls = rawWebsite
            .map((e) => e.toString().trim())
            .where((u) => u.isNotEmpty)
            .toList();
      } else {
        _websiteUrls = [];
      }
      _inviteDomain = contact['invite_domain'] as String? ?? '';
      // 兼容旧版 key 'telegram'（新版改为 'telegram_group'）
      _telegramGroupUrl =
          (contact['telegram_group'] as String?)?.isNotEmpty == true
              ? contact['telegram_group'] as String
              : contact['telegram'] as String? ?? '';

      // 提取 api_prefix（可选，默认 /api/v1）
      final rawApiPrefix = configData['api_prefix'] as String?;
      if (rawApiPrefix != null && rawApiPrefix.isNotEmpty) {
        _apiPrefix = rawApiPrefix;
      }

      // 提取配置版本（优先显式 config_version）
      final rawConfigVersion = configData['config_version']?.toString();
      if (rawConfigVersion != null && rawConfigVersion.trim().isNotEmpty) {
        _configVersion = rawConfigVersion.trim();
      } else {
        final metadataVersion = _currentConfig?.metadata.version.trim() ?? '';
        _configVersion = metadataVersion.isNotEmpty
            ? metadataVersion
            : _currentConfig!.sourceHash;
      }

      // 提取 gateway_urls / gateway_url（可选，OSS 远程控制网关地址）
      final rawGatewayUrls = configData['gateway_urls'];
      if (rawGatewayUrls is List && rawGatewayUrls.isNotEmpty) {
        _gatewayUrls = rawGatewayUrls
            .map((e) => e.toString().trim())
            .where((u) => u.isNotEmpty)
            .toList();
      } else {
        final rawGatewayUrl = configData['gateway_url'] as String?;
        if (rawGatewayUrl != null && rawGatewayUrl.trim().isNotEmpty) {
          _gatewayUrls = [rawGatewayUrl.trim()];
        }
      }

      await _updateState(ConfigAccessorState.ready);

      // 发送配置更新事件
      _configStreamController.add(_currentConfig!);

      _logger.info('Configuration loaded from $source');
    } catch (e) {
      throw Exception('Failed to process config data: $e');
    }
  }

  /// 更新状态
  Future<void> _updateState(ConfigAccessorState newState) async {
    if (_state != newState) {
      _state = newState;
      _stateStreamController.add(_state);
    }
  }

  /// 释放资源
  void dispose() {
    _configStreamController.close();
    _stateStreamController.close();
  }

  @override
  String toString() {
    return 'XBoardConfigAccessor(state: $_state, provider: $_currentProvider, '
        'hasConfig: ${_currentConfig != null})';
  }
}
