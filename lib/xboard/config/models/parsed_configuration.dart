import 'panel_configuration.dart';
import 'proxy_info.dart';
import 'websocket_info.dart';
import 'update_info.dart';
import 'subscription_info.dart';

/// 解析后的配置数据
///
/// 包含所有类型的配置信息
class ParsedConfiguration {
  final String panelType;  // 面板类型：xboard 或 v2board
  final PanelConfiguration panels;
  final List<ProxyInfo> proxies;
  final List<WebSocketInfo> webSockets;
  final UpdateRichConfig? updateConfig;
  final SubscriptionInfo? subscription;
  final DateTime parsedAt;
  final String sourceHash;
  final ConfigMetadata metadata;

  const ParsedConfiguration({
    required this.panelType,
    required this.panels,
    required this.proxies,
    required this.webSockets,
    this.updateConfig,
    this.subscription,
    required this.parsedAt,
    required this.sourceHash,
    required this.metadata,
  });

  /// 从JSON创建配置
  factory ParsedConfiguration.fromJson(
    Map<String, dynamic> json,
    String currentProvider,
  ) {
    // 读取面板类型：优先远程配置中的 panelType/panel_type，回退到 config.yaml 的 currentProvider。
    // 远程 OSS 配置是权威来源，无需用户手动在 config.yaml 中维护 panel_type。
    final panelType = (json['panelType'] as String?)?.isNotEmpty == true
        ? json['panelType'] as String
        : (json['panel_type'] as String?)?.isNotEmpty == true
            ? json['panel_type'] as String
            : currentProvider; // 远程配置未指定时回退到 config.yaml

    final panelsData = json['panels'] as Map<String, dynamic>? ?? {};
    final proxyList = json['proxy'] as List<dynamic>? ?? [];
    final wsList = json['ws'] as List<dynamic>? ?? [];
    final updateData = json['update'] as Map<String, dynamic>?;
    final subscriptionData = json['subscription'] as Map<String, dynamic>?;

    return ParsedConfiguration(
      panelType: panelType,
      // 用远程配置的 panelType 来选择面板，而非 config.yaml 的 currentProvider，
      // 确保 v2board / xboard 面板 URL 能被正确筛选出来。
      panels: PanelConfiguration.fromJson(panelsData, panelType),
      proxies: proxyList
          .map((item) => ProxyInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      webSockets: wsList
          .map((item) => WebSocketInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
      updateConfig: updateData != null ? UpdateRichConfig.fromJson(updateData) : null,
      subscription: subscriptionData != null ? SubscriptionInfo.fromJson(subscriptionData) : null,
      parsedAt: DateTime.now(),
      sourceHash: json.hashCode.toString(),
      metadata: ConfigMetadata.fromJson(json['metadata'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// 获取第一个可用的WebSocket URL
  String? get firstWsUrl {
    return webSockets.isNotEmpty ? webSockets.first.url : null;
  }

  /// 获取第一个可用的代理URL
  String? get firstProxyUrl {
    return proxies.isNotEmpty ? proxies.first.url : null;
  }

  /// 获取第一个可用的面板URL
  String? get firstPanelUrl {
    return panels.firstUrl;
  }

  /// 获取第一个可用的订阅URL
  String? get firstSubscriptionUrl {
    return subscription?.firstUrl;
  }

  /// 获取第一个支持加密的订阅URL
  String? get firstEncryptSubscriptionUrl {
    return subscription?.firstEncryptUrl?.url;
  }

  /// 构建订阅URL
  String? buildSubscriptionUrl(String token, {bool preferEncrypt = true}) {
    return subscription?.buildSubscriptionUrl(token, forceEncrypt: preferEncrypt);
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'panels': panels.toJson(),
      'proxy': proxies.map((e) => e.toJson()).toList(),
      'ws': webSockets.map((e) => e.toJson()).toList(),
      if (updateConfig != null) 'update': updateConfig!.toJson(),
      if (subscription != null) 'subscription': subscription!.toJson(),
      'parsedAt': parsedAt.toIso8601String(),
      'sourceHash': sourceHash,
      'metadata': metadata.toJson(),
    };
  }

  @override
  String toString() {
    return 'ParsedConfiguration(panels: $panels, proxies: ${proxies.length}, '
           'ws: ${webSockets.length}, update: ${updateConfig?.minVersion ?? 'none'}, '
           'subscription: ${subscription != null ? subscription!.urls.length : 0})';
  }
}

/// 配置元数据
class ConfigMetadata {
  final List<String> sources;
  final DateTime lastUpdated;
  final String version;
  final Map<String, dynamic> statistics;

  const ConfigMetadata({
    required this.sources,
    required this.lastUpdated,
    required this.version,
    required this.statistics,
  });

  factory ConfigMetadata.fromJson(Map<String, dynamic> json) {
    return ConfigMetadata(
      sources: (json['sources'] as List<dynamic>?)?.cast<String>() ?? [],
      lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ?? DateTime.now(),
      version: json['version'] as String? ?? '1.0.0',
      statistics: json['statistics'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sources': sources,
      'lastUpdated': lastUpdated.toIso8601String(),
      'version': version,
      'statistics': statistics,
    };
  }
}
