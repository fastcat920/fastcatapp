// 更新配置模型，同时兼容旧版 latest 和新版 platforms 结构。

/// 单平台更新信息
class UpdatePlatformInfo {
  final String version;
  final String url;
  final bool force;
  final bool enabled;
  final String source;
  final String? minSupportedVersion;
  final String? appId;
  final Map<String, String> changelog;

  const UpdatePlatformInfo({
    required this.version,
    required this.url,
    this.force = false,
    this.enabled = true,
    this.source = 'direct',
    this.minSupportedVersion,
    this.appId,
    this.changelog = const {},
  });

  factory UpdatePlatformInfo.fromJson(Map<String, dynamic> json) {
    return UpdatePlatformInfo(
      version: _stringValue(json['latest_version']).isNotEmpty
          ? _stringValue(json['latest_version'])
          : _stringValue(json['version']),
      url: _stringValue(json['url']),
      force: json['force'] == true,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      source: _stringValue(json['source']).isEmpty
          ? 'direct'
          : _stringValue(json['source']),
      minSupportedVersion: _nullableString(json['min_supported_version']),
      appId: _nullableString(json['app_id']),
      changelog: _localizedText(json['changelog']),
    );
  }

  Map<String, dynamic> toLegacyJson() => {
        'version': version,
        'url': url,
        'force': force,
      };

  Map<String, dynamic> toPlatformJson() => {
        'enabled': enabled,
        'source': source,
        'latest_version': version,
        if (minSupportedVersion != null)
          'min_supported_version': minSupportedVersion,
        'url': url,
        'force': force,
        if (changelog.isNotEmpty) 'changelog': changelog,
        if (appId != null) 'app_id': appId,
      };

  String localizedChangelog(String languageCode) {
    if (changelog.isEmpty) return '';
    final isChinese = languageCode.toLowerCase().startsWith('zh');
    final preferredKeys = isChinese
        ? const ['zh_CN', 'zh-CN', 'zh']
        : const ['en_US', 'en-US', 'en'];
    for (final key in preferredKeys) {
      final value = changelog[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return changelog.values.firstWhere(
      (value) => value.trim().isNotEmpty,
      orElse: () => '',
    );
  }

  String get resolvedUrl {
    final directUrl = url.trim();
    if (directUrl.isNotEmpty) return directUrl;
    final id = appId?.trim() ?? '';
    if (id.isEmpty) return '';
    return 'https://apps.apple.com/app/${id.startsWith('id') ? id : 'id$id'}';
  }

  @override
  String toString() =>
      'UpdatePlatformInfo(version: $version, enabled: $enabled, force: $force)';
}

/// 完整更新配置（对应 release_config_plaintext.json 的 update 对象）
class UpdateRichConfig {
  /// 最低支持版本，低于此版本强制更新
  final String? minVersion;

  /// 旧客户端使用的全局更新说明。
  final String? changelog;

  /// 旧版各平台配置。
  final Map<String, UpdatePlatformInfo> latest;

  /// 新版按平台独立配置。
  final Map<String, UpdatePlatformInfo> platforms;

  final int schemaVersion;

  const UpdateRichConfig({
    this.minVersion,
    this.changelog,
    this.latest = const {},
    this.platforms = const {},
    this.schemaVersion = 1,
  });

  factory UpdateRichConfig.fromJson(Map<String, dynamic> json) {
    return UpdateRichConfig(
      minVersion: _nullableString(json['min_version']),
      changelog: _nullableString(json['changelog']),
      latest: _platformMap(json['latest']),
      platforms: _platformMap(json['platforms']),
      schemaVersion: _intValue(json['schema_version'], fallback: 1),
    );
  }

  /// 新版显式配置优先；只有该平台未出现在 platforms 时才回退旧版。
  /// 因此 enabled=false 不会被旧版 latest 意外重新启用。
  UpdatePlatformInfo? platformInfo(String platform) {
    if (platforms.containsKey(platform)) return platforms[platform];
    return latest[platform];
  }

  String localizedChangelog(String platform, String languageCode) {
    final platformText =
        platformInfo(platform)?.localizedChangelog(languageCode);
    if (platformText != null && platformText.isNotEmpty) return platformText;
    return changelog?.trim() ?? '';
  }

  bool get isEmpty => latest.isEmpty && platforms.isEmpty;
  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toJson() => {
        if (schemaVersion > 1) 'schema_version': schemaVersion,
        if (minVersion != null) 'min_version': minVersion,
        if (changelog != null) 'changelog': changelog,
        if (latest.isNotEmpty)
          'latest': latest.map((k, v) => MapEntry(k, v.toLegacyJson())),
        if (platforms.isNotEmpty)
          'platforms': platforms.map((k, v) => MapEntry(k, v.toPlatformJson())),
      };

  @override
  String toString() =>
      'UpdateRichConfig(platforms: ${(platforms.keys.followedBy(latest.keys)).toSet().join(', ')}, minVersion: $minVersion)';
}

Map<String, UpdatePlatformInfo> _platformMap(Object? value) {
  if (value is! Map) return const {};
  final result = <String, UpdatePlatformInfo>{};
  for (final entry in value.entries) {
    if (entry.value is Map) {
      result[entry.key.toString()] = UpdatePlatformInfo.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
  }
  return result;
}

Map<String, String> _localizedText(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return {'default': value.trim()};
  }
  if (value is! Map) return const {};
  final result = <String, String>{};
  for (final entry in value.entries) {
    final text = _stringValue(entry.value).trim();
    if (text.isNotEmpty) result[entry.key.toString()] = text;
  }
  return result;
}

String _stringValue(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final result = _stringValue(value).trim();
  return result.isEmpty ? null : result;
}

int _intValue(Object? value, {required int fallback}) {
  if (value is int) return value;
  return int.tryParse(_stringValue(value)) ?? fallback;
}
