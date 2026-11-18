import 'package:fl_clash/xboard/features/update_check/models/update_artifact.dart';
// Per-platform update configuration. Legacy schemas are not consumed.

/// 单平台更新信息
class UpdatePlatformInfo {
  final String version;
  final int? build, minSupportedBuild;
  final Map<String, UpdateArtifact> artifacts;
  final String url;
  final bool force;
  final bool enabled;
  final String source;
  final String? minSupportedVersion;
  final String? appId;
  final Map<String, String> changelog;

  const UpdatePlatformInfo({
    required this.version,
    this.build,
    this.minSupportedBuild,
    this.artifacts = const {},
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
      version: _stringValue(json['latest_version']),
      build: int.tryParse('${json['build'] ?? ''}'),
      minSupportedBuild: int.tryParse('${json['min_supported_build'] ?? ''}'),
      artifacts: {
        if (json['artifacts'] is Map)
          for (final entry in (json['artifacts'] as Map).entries)
            if (entry.value is Map)
              entry.key.toString(): UpdateArtifact.fromJson(
                  Map<String, dynamic>.from(entry.value)),
      },
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

  Map<String, dynamic> toPlatformJson() => {
        if (build != null) 'build': build,
        if (minSupportedBuild != null) 'min_supported_build': minSupportedBuild,
        if (artifacts.isNotEmpty)
          'artifacts': artifacts.map((k, v) => MapEntry(k, v.toJson())),
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

  UpdateArtifact? artifactFor(List<String> architectureKeys) {
    for (final key in architectureKeys) {
      if (artifacts.containsKey(key)) {
        return artifacts[key];
      }
    }
    return null;
  }

  String get storeUrl {
    final id = appId?.trim().replaceFirst(RegExp(r'^id'), '') ?? '';
    if (RegExp(r'^\d+$').hasMatch(id)) {
      return 'https://apps.apple.com/app/id$id';
    }
    final uri = Uri.tryParse(url);
    return uri?.scheme == 'https' &&
            uri?.host == 'apps.apple.com' &&
            uri!.userInfo.isEmpty
        ? url
        : '';
  }

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

/// Each platform owns its version, minimum version, installer and release notes.
class UpdateRichConfig {
  final Map<String, UpdatePlatformInfo> platforms;
  final int schemaVersion;
  const UpdateRichConfig({this.platforms = const {}, this.schemaVersion = 2});
  factory UpdateRichConfig.fromJson(Map<String, dynamic> json) =>
      UpdateRichConfig(
        platforms: _platformMap(json['platforms']),
        schemaVersion: _intValue(json['schema_version'], fallback: 2),
      );
  UpdatePlatformInfo? platformInfo(String platform) {
    final key = platform == 'android_tv' ? 'android' : platform;
    final info = platforms[key];
    if (info == null) return null;
    if (key != 'android') return info;
    // Phone and TV share release information and architecture-specific APKs.
    return UpdatePlatformInfo(
      version: info.version,
      build: info.build,
      minSupportedBuild: info.minSupportedBuild,
      artifacts: {
        for (final key in ['arm64', 'arm'])
          if (info.artifacts[key] != null) key: info.artifacts[key]!,
      },
      url: '',
      force: info.force,
      enabled: info.enabled,
      source: info.source,
      minSupportedVersion: info.minSupportedVersion,
      appId: info.appId,
      changelog: info.changelog,
    );
  }

  String localizedChangelog(String platform, String languageCode) =>
      platformInfo(platform)?.localizedChangelog(languageCode) ?? '';
  bool get isEmpty => platforms.isEmpty;
  bool get isNotEmpty => !isEmpty;
  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'platforms': platforms
            .map((key, value) => MapEntry(key, value.toPlatformJson())),
      };
  @override
  String toString() =>
      'UpdateRichConfig(platforms: ${platforms.keys.join(", ")})';
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
