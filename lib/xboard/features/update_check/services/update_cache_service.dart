import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CachedUpdateInfo {
  const CachedUpdateInfo({
    required this.platform,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.checkedAt,
  });

  final String platform;
  final String currentVersion;
  final String latestVersion;
  final String updateUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final DateTime checkedAt;

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'updateUrl': updateUrl,
        'releaseNotes': releaseNotes,
        'forceUpdate': forceUpdate,
        'checkedAt': checkedAt.toIso8601String(),
      };

  factory CachedUpdateInfo.fromJson(Map<String, dynamic> json) {
    return CachedUpdateInfo(
      platform: json['platform']?.toString() ?? '',
      currentVersion: json['currentVersion']?.toString() ?? '',
      latestVersion: json['latestVersion']?.toString() ?? '',
      updateUrl: json['updateUrl']?.toString() ?? '',
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      forceUpdate: json['forceUpdate'] == true,
      checkedAt: DateTime.tryParse(json['checkedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class UpdateCacheService {
  static const _cachedUpdateKey = 'cached_update_info_v1';
  static const promptedOptionalUpdateVersionKey =
      'last_prompted_optional_update_version';

  Future<CachedUpdateInfo?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_cachedUpdateKey);
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return CachedUpdateInfo.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      await preferences.remove(_cachedUpdateKey);
      return null;
    }
  }

  Future<void> save(CachedUpdateInfo info) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cachedUpdateKey, jsonEncode(info.toJson()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cachedUpdateKey);
  }

  Future<String?> getPromptedOptionalVersion() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(promptedOptionalUpdateVersionKey)?.trim();
  }

  Future<void> markOptionalVersionPrompted(String version) async {
    final normalized = version.trim();
    if (normalized.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      promptedOptionalUpdateVersionKey,
      normalized,
    );
  }

  Future<void> clearPromptedOptionalVersion() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(promptedOptionalUpdateVersionKey);
  }
}
