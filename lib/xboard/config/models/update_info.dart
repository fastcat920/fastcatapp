/// 更新配置模型 — 与 release_config_plaintext.json 的 update 字段对应
///
/// OSS config.json 中 update 字段格式：
/// {
///   "min_version": "1.0.0",
///   "changelog": "更新说明",
///   "latest": {
///     "android": { "version": "1.0.0", "url": "https://...", "force": false },
///     "windows": { "version": "1.0.0", "url": "https://...", "force": false },
///     "macos":   { "version": "1.0.0", "url": "https://...", "force": false },
///     "linux":   { "version": "1.0.0", "url": "https://...", "force": false }
///   }
/// }

/// 单平台更新信息
class UpdatePlatformInfo {
  final String version;
  final String url;
  final bool force;

  const UpdatePlatformInfo({
    required this.version,
    required this.url,
    this.force = false,
  });

  factory UpdatePlatformInfo.fromJson(Map<String, dynamic> json) {
    return UpdatePlatformInfo(
      version: json['version'] as String? ?? '',
      url: json['url'] as String? ?? '',
      force: json['force'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'url': url,
    'force': force,
  };

  @override
  String toString() => 'UpdatePlatformInfo(version: $version, force: $force)';
}

/// 完整更新配置（对应 release_config_plaintext.json 的 update 对象）
class UpdateRichConfig {
  /// 最低支持版本，低于此版本强制更新
  final String? minVersion;

  /// 更新说明/changelog
  final String? changelog;

  /// 各平台最新版信息，key: android / windows / macos / linux / ios
  final Map<String, UpdatePlatformInfo> latest;

  const UpdateRichConfig({
    this.minVersion,
    this.changelog,
    required this.latest,
  });

  factory UpdateRichConfig.fromJson(Map<String, dynamic> json) {
    final latestJson = json['latest'] as Map<String, dynamic>? ?? {};
    return UpdateRichConfig(
      minVersion: json['min_version'] as String?,
      changelog: json['changelog'] as String?,
      latest: latestJson.map(
        (k, v) => MapEntry(k, UpdatePlatformInfo.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  /// 获取指定平台的更新信息
  UpdatePlatformInfo? platformInfo(String platform) => latest[platform];

  bool get isEmpty => latest.isEmpty;
  bool get isNotEmpty => latest.isNotEmpty;

  Map<String, dynamic> toJson() => {
    if (minVersion != null) 'min_version': minVersion,
    if (changelog != null) 'changelog': changelog,
    'latest': latest.map((k, v) => MapEntry(k, v.toJson())),
  };

  @override
  String toString() =>
      'UpdateRichConfig(platforms: ${latest.keys.join(', ')}, minVersion: $minVersion)';
}
