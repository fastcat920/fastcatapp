import 'package:fl_clash/common/constant.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import '../core/config_settings.dart';
import '../../core/core.dart';

// 初始化文件级日志器
final _logger = FileLogger('config_file_loader.dart');

/// 配置文件加载器
///
/// 从 assets/config/config.yaml 加载客户端配置
class ConfigFileLoader {
  /// 配置文件路径
  static const String configPath = 'assets/config/config.yaml';

  /// 加载配置文件
  ///
  /// 从 assets/config/config.yaml 加载配置，之后用 --dart-define 值覆盖
  static Future<ConfigSettings> loadFromFile() async {
    try {
      final yamlString = await rootBundle.loadString(configPath);
      final config = _parseYamlString(yamlString);
      _logger.info('从 assets 加载配置: $configPath');
      return _applyDartDefineOverrides(config);
    } catch (e) {
      _logger.error('加载配置文件失败', e);
      return const ConfigSettings();
    }
  }

  /// 将 --dart-define 编译时注入值覆盖 config.yaml 中对应字段
  ///
  /// 优先级：dart-define > config.yaml
  /// 支持覆盖：OSS_URL_1..4（远程配置源）、PANEL_TYPE（面板类型）
  static ConfigSettings _applyDartDefineOverrides(ConfigSettings base) {
    // dart-define 值在编译时注入，运行时为空字符串（未注入时）
    const ossUrl1 = String.fromEnvironment('OSS_URL_1');
    const ossUrl2 = String.fromEnvironment('OSS_URL_2');
    const ossUrl3 = String.fromEnvironment('OSS_URL_3');
    const ossUrl4 = String.fromEnvironment('OSS_URL_4');
    const panelType = String.fromEnvironment('PANEL_TYPE');
    const apiPrefix = String.fromEnvironment('API_PREFIX');

    final ddUrls = [ossUrl1, ossUrl2, ossUrl3, ossUrl4]
        .where((u) => u.isNotEmpty)
        .toList();

    _logger.info(
        '[ConfigLoader] dart-define 检查: OSS_URL数=${ddUrls.length}, PANEL_TYPE="$panelType", API_PREFIX="$apiPrefix"');
    if (ddUrls.isNotEmpty) {
      for (int i = 0; i < ddUrls.length; i++) {
        // 只打印前30字符，避免泄露完整URL
        final masked = ddUrls[i].length > 30
            ? '${ddUrls[i].substring(0, 30)}...'
            : ddUrls[i];
        _logger.info('[ConfigLoader] OSS_URL_${i + 1}: $masked');
      }
    }

    final provider = panelType.isNotEmpty ? panelType : base.currentProvider;
    final prefix = apiPrefix.isNotEmpty ? apiPrefix : base.apiPrefix;

    if (ddUrls.isEmpty) {
      final remoteConfig = _normalizeRemoteConfig(base.remoteConfig);
      if (panelType.isEmpty && apiPrefix.isEmpty) {
        _logger
            .warning('[ConfigLoader] ⚠️ 无 dart-define 覆盖，使用 config.yaml/内置配置');
      } else {
        _logger.info(
            '[ConfigLoader] dart-define PANEL_TYPE=$provider, API_PREFIX=$prefix');
      }
      return ConfigSettings(
        currentProvider: provider,
        apiPrefix: prefix,
        remoteConfig: remoteConfig,
        subscription: base.subscription,
        log: base.log,
      );
    }

    _logger.info(
        '[ConfigLoader] dart-define: ${ddUrls.length} OSS URL(s), panel_type=$provider');

    final sources = ddUrls
        .asMap()
        .entries
        .map((e) => RemoteSourceConfig(
              name: 'source_${e.key}',
              url: e.value,
            ))
        .toList();

    return ConfigSettings(
      currentProvider: provider,
      apiPrefix: prefix,
      remoteConfig: RemoteConfigSettings(
        sources: sources,
        maxRetries: base.remoteConfig.maxRetries,
        timeout: base.remoteConfig.timeout,
        retryDelay: base.remoteConfig.retryDelay,
      ),
      subscription: base.subscription,
      log: base.log,
    );
  }

  static RemoteConfigSettings _normalizeRemoteConfig(
    RemoteConfigSettings remoteConfig,
  ) {
    final sources = remoteConfig.sources
        .where((source) => !_isPlaceholderUrl(source.url))
        .toList();

    if (sources.length != remoteConfig.sources.length) {
      _logger.warning('[ConfigLoader] 忽略 config.yaml 中的示例 OSS 地址');
    }

    if (sources.isEmpty) {
      _logger.warning('[ConfigLoader] 未配置有效 OSS 地址，使用内置 OSS 配置源');
      return RemoteConfigSettings(
        sources: [
          RemoteSourceConfig(name: 'builtin', url: builtinOssUrl),
        ],
        maxRetries: remoteConfig.maxRetries,
        timeout: remoteConfig.timeout,
        retryDelay: remoteConfig.retryDelay,
      );
    }

    return RemoteConfigSettings(
      sources: sources,
      maxRetries: remoteConfig.maxRetries,
      timeout: remoteConfig.timeout,
      retryDelay: remoteConfig.retryDelay,
    );
  }

  static bool _isPlaceholderUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return true;
    final host = Uri.tryParse(trimmed)?.host.toLowerCase() ?? '';
    return host == 'your-oss.example.com' ||
        host == 'your-oss1.example.com' ||
        host == 'your-oss2.example.com' ||
        host == 'your-cdn.example.com' ||
        host.endsWith('.example.com');
  }

  /// 解析 YAML 配置字符串
  static ConfigSettings _parseYamlString(String yamlString) {
    try {
      // 解析 YAML
      final yamlDoc = loadYaml(yamlString);
      final configMap = _yamlToMap(yamlDoc);

      // 仅支持新格式：配置必须在顶层，禁止旧版 xboard: 嵌套
      if (configMap['xboard'] is Map<String, dynamic>) {
        throw Exception(
          'config.yaml 格式错误：检测到旧版 xboard: 嵌套。请将配置迁移到顶层字段。',
        );
      }
      final xboardConfig = configMap;

      // 提取配置参数
      // panel_type 用作内部 provider key，以区分 xboard/v2board 等面板类型
      final panelType = xboardConfig['panel_type'] as String? ??
          xboardConfig['provider'] as String? // 兼容旧字段名
          ??
          'xboard';
      final apiPrefix = xboardConfig['api_prefix'] as String? ?? '/api/v1';
      final remoteConfigJson =
          xboardConfig['remote_config'] as Map<String, dynamic>? ?? {};
      final subscriptionJson =
          xboardConfig['subscription'] as Map<String, dynamic>? ?? {};
      final logJson = xboardConfig['log'] as Map<String, dynamic>? ?? {};

      // 构建配置对象
      return ConfigSettings(
        currentProvider: panelType,
        apiPrefix: apiPrefix,
        remoteConfig: _parseRemoteConfig(remoteConfigJson),
        subscription: _parseSubscriptionSettings(subscriptionJson),
        log: _parseLogSettings(logJson),
      );
    } catch (e) {
      _logger.error('解析 YAML 配置失败', e);
      rethrow;
    }
  }

  /// 将 YAML 转换为 Map（或其他类型）
  static dynamic _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      yaml.forEach((key, value) {
        map[key.toString()] = _yamlToMap(value);
      });
      return map;
    } else if (yaml is YamlList) {
      return yaml.map((item) => _yamlToMap(item)).toList();
    } else {
      return yaml;
    }
  }

  /// 解析远程配置
  static RemoteConfigSettings _parseRemoteConfig(Map<String, dynamic> json) {
    final sourcesList = json['sources'] as List<dynamic>? ?? [];
    _logger.info('[ConfigLoader] 解析远程配置源: ${sourcesList.length} 个源');

    final sources = sourcesList
        .asMap()
        .entries
        .map((e) => _parseRemoteSource(e.value as Map<String, dynamic>, e.key))
        .toList();

    _logger.info('[ConfigLoader] 成功解析 ${sources.length} 个配置源');
    for (final source in sources) {
      _logger.info('[ConfigLoader] - ${source.name}: ${source.url}');
    }

    return RemoteConfigSettings(
      sources: sources,
      maxRetries: json['max_retries'] as int? ?? 3,
      timeout: Duration(seconds: json['timeout_seconds'] as int? ?? 10),
      retryDelay: Duration(seconds: json['retry_delay_seconds'] as int? ?? 2),
    );
  }

  /// 解析远程源配置（name 可选，缺省时自动生成 source_N）
  static RemoteSourceConfig _parseRemoteSource(
      Map<String, dynamic> json, int index) {
    return RemoteSourceConfig(
      name: (json['name'] as String?)?.isNotEmpty == true
          ? json['name'] as String
          : 'source_$index',
      url: json['url'] as String? ?? '',
      headers:
          (json['headers'] as Map<String, dynamic>?)?.cast<String, String>(),
      timeout: json['timeout_seconds'] != null
          ? Duration(seconds: json['timeout_seconds'] as int)
          : null,
    );
  }

  /// 解析订阅设置
  static SubscriptionSettings _parseSubscriptionSettings(
      Map<String, dynamic> json) {
    return SubscriptionSettings(
      preferEncrypt: json['prefer_encrypt'] as bool? ?? false,
    );
  }

  /// 解析日志设置
  static LogSettings _parseLogSettings(Map<String, dynamic> json) {
    return LogSettings(
      enabled: json['enabled'] as bool? ?? true,
      level: json['level'] as String? ?? 'info',
      prefix: json['prefix'] as String? ?? '[$appName]',
    );
  }

  /// 获取配置文件的其他配置项
  ///
  /// 从 assets/config/config.yaml 加载扩展配置
  static Future<Map<String, dynamic>> loadExtendedConfig() async {
    try {
      final yamlString = await rootBundle.loadString(configPath);
      final yamlDoc = loadYaml(yamlString);
      final configMap = _yamlToMap(yamlDoc);

      if (configMap['xboard'] is Map<String, dynamic>) {
        throw Exception(
          'config.yaml 格式错误：检测到旧版 xboard: 嵌套。请将配置迁移到顶层字段。',
        );
      }
      return configMap;
    } catch (e) {
      _logger.error('加载扩展配置失败', e);
      return {};
    }
  }

  /// 从 config.yaml 读取 features 配置作为本地兜底值
  static Future<Map<String, bool>> loadFeatures() async {
    try {
      final yamlString = await rootBundle.loadString(configPath);
      final yamlDoc = loadYaml(yamlString);
      final configMap = _yamlToMap(yamlDoc);
      final features = configMap['features'];
      if (features is Map) {
        return {
          for (final e in features.entries)
            e.key.toString(): e.value is bool ? e.value as bool : true,
        };
      }
    } catch (e) {
      _logger.warning('读取 features 配置失败: $e');
    }
    return {};
  }

}

/// 配置辅助函数
extension ConfigFileLoaderHelper on ConfigFileLoader {
  /// 获取订阅设置
  static Future<SubscriptionSettings> getSubscriptionSettings() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      final subscriptionJson =
          config['subscription'] as Map<String, dynamic>? ?? {};
      return SubscriptionSettings(
        preferEncrypt: subscriptionJson['prefer_encrypt'] as bool? ?? false,
      );
    } catch (e) {
      return const SubscriptionSettings();
    }
  }

  /// 获取是否优先使用加密订阅
  static Future<bool> getPreferEncrypt() async {
    try {
      final settings = await getSubscriptionSettings();
      return settings.preferEncrypt;
    } catch (e) {
      return true;
    }
  }

  /// 获取是否启用订阅URL竞速（自动跟随加密选项）
  static Future<bool> getEnableRace() async {
    try {
      final settings = await getSubscriptionSettings();
      return settings.enableRace; // enableRace 是计算属性，等于 preferEncrypt
    } catch (e) {
      return true;
    }
  }

  /// 获取延迟测试配置
  static Future<String> getLatencyTestUrl() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      final latencyTest = config['latency_test'] as Map<String, dynamic>? ?? {};
      return latencyTest['test_url'] as String? ??
          'http://www.gstatic.com/generate_204';
    } catch (e) {
      return 'http://www.gstatic.com/generate_204';
    }
  }

  /// 获取 SDK 配置
  static Future<Map<String, dynamic>> getSdkConfig() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      return config['sdk'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }

  /// 获取应用配置
  static Future<Map<String, dynamic>> getAppConfig() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      return config['app'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }

  /// 获取证书配置
  static Future<Map<String, dynamic>> getCertificateConfig() async {
    // 硬编码证书配置，不再从配置文件读取
    return {
      'path': 'assets/cer/client-cert.crt',
      'enabled': true,
    };
  }

  /// 获取应用标题
  /// 已移除从 config.yaml 读取；标题由 login_page 直接硬编码，
  /// 未来从远程配置的 contact.website 获取。
  static Future<String> getAppTitle() async => 'XBoard';

  /// 获取应用网站地址
  /// 已移除从 config.yaml 读取；网站地址未来从远程配置的 contact.website 获取。
  static Future<String> getAppWebsite() async => '';

  /// 获取本地 contact 兜底配置（assets/config/config.yaml -> contact_fallback）
  static Future<Map<String, dynamic>> getContactFallbackConfig() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      return config['contact_fallback'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }

  /// 获取本地兜底官网地址
  static Future<String> getFallbackWebsiteUrl() async {
    final contact = await getContactFallbackConfig();
    return contact['website'] as String? ?? '';
  }

  /// 获取本地兜底 Crisp Website ID
  static Future<String> getFallbackCrispWebsiteId() async {
    final contact = await getContactFallbackConfig();
    return contact['crisp_website_id'] as String? ?? '';
  }

  /// 启动缓存开关（startup_cache.enabled），默认 true
  static Future<bool> getStartupCacheEnabled() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      final startupCache = config['startup_cache'] as Map<String, dynamic>?;
      return startupCache?['enabled'] as bool? ?? true;
    } catch (e) {
      return true;
    }
  }

  /// 启动缓存有效期（startup_cache.ttl_hours），默认 72 小时
  static Future<int> getStartupCacheTtlHours() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      final startupCache = config['startup_cache'] as Map<String, dynamic>?;
      final ttl = startupCache?['ttl_hours'];
      if (ttl is int && ttl > 0) return ttl;
      if (ttl is String) {
        final parsed = int.tryParse(ttl);
        if (parsed != null && parsed > 0) return parsed;
      }
      return 72;
    } catch (e) {
      return 72;
    }
  }

  /// 启动缓存探测超时（startup_cache.probe_timeout_ms），默认 3000ms
  static Future<int> getStartupCacheProbeTimeoutMs() async {
    try {
      final config = await ConfigFileLoader.loadExtendedConfig();
      final startupCache = config['startup_cache'] as Map<String, dynamic>?;
      final timeout = startupCache?['probe_timeout_ms'];
      if (timeout is int && timeout > 0) return timeout;
      if (timeout is String) {
        final parsed = int.tryParse(timeout);
        if (parsed != null && parsed > 0) return parsed;
      }
      return 3000;
    } catch (e) {
      return 3000;
    }
  }
}
