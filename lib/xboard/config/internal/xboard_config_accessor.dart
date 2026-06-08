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

  // 服务实例
  PanelService? _panelService;
  ProxyService? _proxyService;
  WebSocketService? _webSocketService;

  // 远程配置 contact 字段
  String _crispWebsiteId = '';
  String _salesmartlyToken = '';
  List<String> _websiteUrls = [];
  String _telegramGroupUrl = '';
  String _inviteDomain = '';

  // 远程配置 ticket 字段
  String _imgbbApiKey = '';

  // API 路径前缀（远程配置可覆盖，默认 /api/v1）
  String _apiPrefix = '/api/v1';

  // 远程配置版本（用于判定 gateway/api_prefix 是否应覆盖当前运行时配置）
  String _configVersion = '';

  // 设备网关地址列表（远程配置 gateway_urls/gateway_url，OSS 可远程切换）
  List<String> _gatewayUrls = [];

  // 远程配置 features 字段
  bool _trafficDetailsEnabled = true;
  bool _knowledgeBaseEnabled = true;
  bool _giftCardEnabled = true;
  bool _joinGroupEnabled = true;
  bool _ordersEnabled = true;
  bool _devicesEnabled = true;
  bool _ticketsEnabled = true;
  bool _balanceEnabled = true;

  /// 应用本地 features 配置作为默认值
  void _applyLocalFeatures(Map<String, bool> f) {
    _trafficDetailsEnabled = f['traffic_details_enabled'] ?? true;
    _knowledgeBaseEnabled = f['knowledge_base_enabled'] ?? true;
    _giftCardEnabled = f['gift_card_enabled'] ?? true;
    _joinGroupEnabled = f['join_group_enabled'] ?? true;
    _ordersEnabled = f['orders_enabled'] ?? true;
    _devicesEnabled = f['devices_enabled'] ?? true;
    _ticketsEnabled = f['tickets_enabled'] ?? true;
    _balanceEnabled = f['balance_enabled'] ?? true;
  }

  // 事件流
  final StreamController<ParsedConfiguration> _configStreamController =
      StreamController<ParsedConfiguration>.broadcast();
  final StreamController<ConfigAccessorState> _stateStreamController =
      StreamController<ConfigAccessorState>.broadcast();

  XBoardConfigAccessor({
    Map<String, bool> localFeatures = const {},
    required RemoteConfigManager remoteManager,
    required ConfigurationParser parser,
    required String currentProvider,
    String apiPrefix = '/api/v1',
  }) : _remoteManager = remoteManager,
       _parser = parser,
       _currentProvider = currentProvider,
       _apiPrefix = apiPrefix {
    _applyLocalFeatures(localFeatures);
  }

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
  Stream<ParsedConfiguration> get configStream => _configStreamController.stream;

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
    await _updateState(ConfigAccessorState.loading);
    _lastError = null;

    try {
      // 直接从远程获取最新配置
      final multiResult = await _remoteManager.fetchAllConfigs();
      if (multiResult.hasSuccess && multiResult.firstSuccessfulData != null) {
        final configData = _parser.extractConfigFromRemoteResult(multiResult.firstSuccessfulData!);
        if (configData != null) {
          await _processConfigData(configData, multiResult.firstSuccessfulSource ?? 'remote');
          return;
        }
      }

      // 远程获取失败
      throw Exception('Remote config fetch failed');

    } catch (e) {
      _lastError = 'Configuration refresh failed: $e';
      await _updateState(ConfigAccessorState.error);
      _logger.error('Configuration refresh failed', e);
      rethrow;
    }
  }

  /// 用外部已解析的配置数据直接注入（fallback 路径）
  Future<void> loadParsedConfig(Map<String, dynamic> configData, String source) async {
    await _processConfigData(configData, source);
  }

  /// 从指定源刷新配置
  Future<void> refreshFromSource(String sourceName) async {
    await _updateState(ConfigAccessorState.loading);
    _lastError = null;

    try {
      ConfigResult<Map<String, dynamic>> result;

      switch (sourceName.toLowerCase()) {
        case 'remote':
          final multiResult = await _remoteManager.fetchAllConfigs();
          result = multiResult.firstSuccessful ?? ConfigResult.failure('No successful remote source', 'remote');
          break;
        case 'redirect':
          result = await _remoteManager.getRedirectConfig();
          break;
        case 'gitee':
          result = await _remoteManager.getGiteeConfig();
          break;
        default:
          result = ConfigResult.failure('Unknown source: $sourceName. Only remote sources (redirect, gitee) are supported.', sourceName);
      }

      if (result.isSuccess && result.data != null) {
        // 提取配置数据（所有源都是远程源）
        final configData = _parser.extractConfigFromRemoteResult(result.data!);

        if (configData != null) {
          await _processConfigData(configData, result.source);
        } else {
          throw Exception('Invalid config data from $sourceName');
        }
      } else {
        throw Exception('Failed to get config from $sourceName: ${result.error}');
      }

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
    return _currentConfig?.buildSubscriptionUrl(token, preferEncrypt: preferEncrypt);
  }

  /// 获取 Crisp 客服 Website ID（来自远程配置 contact.crisp_website_id）
  String get crispWebsiteId => _crispWebsiteId;

  /// 获取 Salesmartly 客服配置（来自远程配置 contact.salesmartly_token）
  /// 支持两种格式：
  /// - 新版：完整 JS URL，如 https://assets.salesmartly.com/js/project_XXXXX_XXXXX_XXXXXXXXXX.js
  /// - 旧版：Widget Token 字符串
  String get salesmartlyToken => _salesmartlyToken;

  /// 获取官方网站 URL 列表（来自远程配置 contact.website，支持 string 或 array）
  List<String> get websiteUrls => _websiteUrls;

  /// 获取 Telegram 群组链接（来自远程配置 contact.telegram_group）
  String get telegramGroupUrl => _telegramGroupUrl;

  /// 获取邀请链接自定义域名（来自远程配置 contact.invite_domain）
  /// 为空字符串表示使用面板域名
  String get inviteDomain => _inviteDomain;

  /// 获取 ImgBB API Key（来自远程配置 ticket.imgbb_api_key）
  String get imgbbApiKey => _imgbbApiKey;

  /// 是否显示流量明细（来自远程配置 features.traffic_details_enabled，默认 true）
  bool get trafficDetailsEnabled => _trafficDetailsEnabled;

  /// 是否显示文档中心（来自远程配置 features.knowledge_base_enabled，默认 true）
  bool get knowledgeBaseEnabled => _knowledgeBaseEnabled;

  /// 是否显示礼品卡兑换（来自远程配置 features.gift_card_enabled，默认 true）
  bool get giftCardEnabled => _giftCardEnabled;

  /// 是否显示加入群组（来自远程配置 features.join_group_enabled，默认 true）
  bool get joinGroupEnabled => _joinGroupEnabled;

  /// 订单记录菜单开关
  bool get ordersEnabled => _ordersEnabled;

  /// 设备管理菜单开关
  bool get devicesEnabled => _devicesEnabled;

  /// 我的工单菜单开关
  bool get ticketsEnabled => _ticketsEnabled;

  /// 余额充值菜单开关
  bool get balanceEnabled => _balanceEnabled;

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
      'subscriptionEncryptUrls': _currentConfig!.subscription?.encryptUrls.length ?? 0,
      'currentProvider': _currentProvider,
      'lastUpdateTime': _lastUpdateTime?.toIso8601String(),
      'sourceHash': _currentConfig!.sourceHash,
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
  Future<void> _processConfigData(Map<String, dynamic> configData, String source) async {
    try {
      // 解析配置
      _currentConfig = _parser.parseFromJson(configData, _currentProvider);
      _lastUpdateTime = DateTime.now();

      // 创建服务实例
      _panelService = PanelService(_currentConfig!.panels);
      _proxyService = ProxyService(_currentConfig!.proxies);
      _webSocketService = WebSocketService(_currentConfig!.webSockets);

      // 提取 contact 字段
      final contact = configData['contact'] as Map<String, dynamic>? ?? {};
      _crispWebsiteId = contact['crisp_website_id'] as String? ?? '';
      _salesmartlyToken = contact['salesmartly_token'] as String? ?? '';
      final rawWebsite = contact['website'];
      if (rawWebsite is String) {
        _websiteUrls = rawWebsite.isNotEmpty ? [rawWebsite] : [];
      } else if (rawWebsite is List) {
        _websiteUrls = rawWebsite.map((e) => e.toString().trim()).where((u) => u.isNotEmpty).toList();
      } else {
        _websiteUrls = [];
      }
      _inviteDomain = contact['invite_domain'] as String? ?? '';
      // 兼容旧版 key 'telegram'（新版改为 'telegram_group'）
      _telegramGroupUrl = (contact['telegram_group'] as String?)?.isNotEmpty == true
          ? contact['telegram_group'] as String
          : contact['telegram'] as String? ?? '';

      // 提取 ticket 字段
      final ticket = configData['ticket'] as Map<String, dynamic>? ?? {};
      _imgbbApiKey = ticket['imgbb_api_key'] as String? ?? '';

      // 提取 api_prefix（可选，默认 /api/v1）
      final rawApiPrefix = configData['api_prefix'] as String?;
      if (rawApiPrefix != null && rawApiPrefix.isNotEmpty) {
        _apiPrefix = rawApiPrefix;
      }

      // 提取配置版本（优先显式 config_version）
      final rawConfigVersion = configData['config_version'] as String?;
      if (rawConfigVersion != null && rawConfigVersion.trim().isNotEmpty) {
        _configVersion = rawConfigVersion.trim();
      } else {
        final metadataVersion = _currentConfig?.metadata.version.trim() ?? '';
        _configVersion =
            metadataVersion.isNotEmpty ? metadataVersion : _currentConfig!.sourceHash;
      }

      // 提取 gateway_urls / gateway_url（可选，OSS 远程控制网关地址）
      final rawGatewayUrls = configData['gateway_urls'];
      if (rawGatewayUrls is List && rawGatewayUrls.isNotEmpty) {
        _gatewayUrls = rawGatewayUrls.map((e) => e.toString().trim()).where((u) => u.isNotEmpty).toList();
      } else {
        final rawGatewayUrl = configData['gateway_url'] as String?;
        if (rawGatewayUrl != null && rawGatewayUrl.trim().isNotEmpty) {
          _gatewayUrls = [rawGatewayUrl.trim()];
        }
      }

      // 提取 features 字段（远程有的覆盖，没有的保留本地配置值）
      final remoteFeatures = configData['features'] as Map<String, dynamic>?;
      if (remoteFeatures != null) {
        _trafficDetailsEnabled = remoteFeatures['traffic_details_enabled'] as bool? ?? _trafficDetailsEnabled;
        _knowledgeBaseEnabled = remoteFeatures['knowledge_base_enabled'] as bool? ?? _knowledgeBaseEnabled;
        _giftCardEnabled = remoteFeatures['gift_card_enabled'] as bool? ?? _giftCardEnabled;
        _joinGroupEnabled = remoteFeatures['join_group_enabled'] as bool? ?? _joinGroupEnabled;
        _ordersEnabled = remoteFeatures['orders_enabled'] as bool? ?? _ordersEnabled;
        _devicesEnabled = remoteFeatures['devices_enabled'] as bool? ?? _devicesEnabled;
        _ticketsEnabled = remoteFeatures['tickets_enabled'] as bool? ?? _ticketsEnabled;
        _balanceEnabled = remoteFeatures['balance_enabled'] as bool? ?? _balanceEnabled;
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
