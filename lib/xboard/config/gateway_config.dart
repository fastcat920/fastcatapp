/// 设备网关统一配置
///
/// 所有需要访问设备网关的模块都应通过此文件获取配置，
/// 避免分散在多处声明 String.fromEnvironment 常量。
///
/// 优先级（叠加，非互斥）：
/// 1. XBOARD_GATEWAY_URL 编译期常量（调试用）
/// 2. 上次成功缓存的网关配置（冷启动优先）
/// 3. OSS 远程配置 gateway_urls / gateway_url + api_prefix
/// 4. productionGatewayUrl 硬编码兜底（始终追加在末尾）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_clash/xboard/core/core.dart';

import 'xboard_config.dart';

/// 编译期覆盖（用于本地调试，构建时通过 --dart-define 传入）
const _overrideUrl = String.fromEnvironment('XBOARD_GATEWAY_URL');

/// 生产网关域名（最后兜底，始终追加在 URL 列表末尾）
const productionGatewayUrl = 'https://d3.fastcat2.com';

/// 网关 API 前缀（需与网关环境变量 DG_API_PREFIX 保持一致，默认 /api/v1）
const gatewayApiPrefix = '/api/v1';

/// 上次成功通信的网关 URL（冷启动时优先尝试）
String? _cachedGatewayUrl;

/// 上次成功通信的网关 API 前缀
String? _cachedGatewayApiPrefix;

const _logger = FileLogger('gateway_config.dart');

String _normalizeBaseUrl(String value) =>
    value.trim().replaceAll(RegExp(r'/$'), '');

String _normalizeApiPrefix(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty || raw == '/') return gatewayApiPrefix;
  final prefixed = raw.startsWith('/') ? raw : '/$raw';
  return prefixed.replaceAll(RegExp(r'/$'), '');
}

String _currentRemoteApiPrefix() {
  try {
    if (XBoardConfig.isInitialized) {
      return _normalizeApiPrefix(XBoardConfig.provider.getApiPrefix());
    }
  } catch (_) {}
  return _cachedGatewayApiPrefix ?? gatewayApiPrefix;
}

String _currentRemoteVersionTag() {
  try {
    if (XBoardConfig.isInitialized) {
      final version = XBoardConfig.configVersion.trim();
      if (version.isNotEmpty) return version;
    }
  } catch (_) {}
  return '';
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int _compareVersionTags(String? left, String? right) {
  final a = (left ?? '').trim();
  final b = (right ?? '').trim();
  if (a == b) return 0;
  if (a.isEmpty) return -1;
  if (b.isEmpty) return 1;

  final numericPattern = RegExp(r'^\d+(\.\d+)*$');
  if (numericPattern.hasMatch(a) && numericPattern.hasMatch(b)) {
    final leftParts = a.split('.').map(int.parse).toList();
    final rightParts = b.split('.').map(int.parse).toList();
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var i = 0; i < length; i++) {
      final leftValue = i < leftParts.length ? leftParts[i] : 0;
      final rightValue = i < rightParts.length ? rightParts[i] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  return a.compareTo(b);
}

List<String> _collectConfiguredGatewayUrls() {
  final urls = <String>[];

  final override = _normalizeBaseUrl(_overrideUrl);
  if (override.isNotEmpty) {
    urls.add(override);
  }

  if (_cachedGatewayUrl != null && _cachedGatewayUrl!.isNotEmpty) {
    final cached = _normalizeBaseUrl(_cachedGatewayUrl!);
    if (cached.isNotEmpty && !urls.contains(cached)) {
      urls.add(cached);
    }
  }

  try {
    if (XBoardConfig.isInitialized) {
      for (final url in XBoardConfig.gatewayUrls) {
        final normalized = _normalizeBaseUrl(url);
        if (normalized.isNotEmpty && !urls.contains(normalized)) {
          urls.add(normalized);
        }
      }
    }
  } catch (_) {}

  final fallback = _normalizeBaseUrl(productionGatewayUrl);
  if (!urls.contains(fallback)) {
    urls.add(fallback);
  }

  return urls;
}

String maskGatewayAddress(String raw) {
  final normalized = _normalizeBaseUrl(raw);
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) {
    return _maskHost(normalized);
  }
  final maskedHost = _maskHost(uri.host);
  return uri.hasScheme ? '${uri.scheme}://$maskedHost' : maskedHost;
}

String gatewayAddressFingerprint(String raw) {
  final normalized = _normalizeBaseUrl(raw);
  if (normalized.isEmpty) return '----';
  final code = normalized.hashCode & 0xFFFF;
  return code.toRadixString(16).padLeft(4, '0');
}

String gatewayDisplayLabel(String raw) {
  return '${maskGatewayAddress(raw)} · ${gatewayAddressFingerprint(raw)}';
}

String _maskHost(String host) {
  final isIpv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  if (isIpv4) {
    final parts = host.split('.');
    if (parts.length == 4) {
      return '${parts.first}.***.***.${parts.last}';
    }
  }

  final parts = host.split('.');
  if (parts.length >= 2) {
    final root = parts.last;
    final secondLevel = parts[parts.length - 2];
    final maskedSecond = secondLevel.length <= 2
        ? '${secondLevel[0]}*'
        : '${secondLevel.substring(0, 1)}***${secondLevel.substring(secondLevel.length - 1)}';
    if (parts.length == 2) {
      return '$maskedSecond.$root';
    }
    final prefix = parts.sublist(0, parts.length - 2);
    final maskedPrefix = prefix
        .map(
          (item) => item.isEmpty
              ? '*'
              : item.length == 1
                  ? '*'
                  : '${item.substring(0, 1)}***',
        )
        .join('.');
    return '$maskedPrefix.$maskedSecond.$root';
  }

  if (host.length <= 2) return '${host[0]}*';
  return '${host.substring(0, 1)}***${host.substring(host.length - 1)}';
}

class GatewayEndpointConfig {
  final String baseUrl;
  final String apiPrefix;
  final String source;
  final String? versionTag;
  final DateTime updatedAt;
  final DateTime? lastVerifiedAt;
  final DateTime? lastFailureAt;
  final DateTime? disabledUntil;
  final int failureCount;
  final GatewayVerificationStatus verificationStatus;
  final int? lastVerificationStatusCode;

  const GatewayEndpointConfig({
    required this.baseUrl,
    required this.apiPrefix,
    required this.source,
    required this.updatedAt,
    this.versionTag,
    this.lastVerifiedAt,
    this.lastFailureAt,
    this.disabledUntil,
    this.failureCount = 0,
    this.verificationStatus = GatewayVerificationStatus.unverified,
    this.lastVerificationStatusCode,
  });

  GatewayEndpointConfig copyWith({
    String? baseUrl,
    String? apiPrefix,
    String? source,
    String? versionTag,
    DateTime? updatedAt,
    DateTime? lastVerifiedAt,
    DateTime? lastFailureAt,
    DateTime? disabledUntil,
    int? failureCount,
    GatewayVerificationStatus? verificationStatus,
    int? lastVerificationStatusCode,
  }) {
    return GatewayEndpointConfig(
      baseUrl: _normalizeBaseUrl(baseUrl ?? this.baseUrl),
      apiPrefix: _normalizeApiPrefix(apiPrefix ?? this.apiPrefix),
      source: source ?? this.source,
      versionTag: versionTag ?? this.versionTag,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
      disabledUntil: disabledUntil ?? this.disabledUntil,
      failureCount: failureCount ?? this.failureCount,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      lastVerificationStatusCode:
          lastVerificationStatusCode ?? this.lastVerificationStatusCode,
    );
  }

  bool get isCircuitOpen =>
      disabledUntil != null && disabledUntil!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'base_url': baseUrl,
      'api_prefix': apiPrefix,
      'source': source,
      'version_tag': versionTag,
      'updated_at': updatedAt.toIso8601String(),
      'last_verified_at': lastVerifiedAt?.toIso8601String(),
      'last_failure_at': lastFailureAt?.toIso8601String(),
      'disabled_until': disabledUntil?.toIso8601String(),
      'failure_count': failureCount,
      'verification_status': verificationStatus.name,
      'last_verification_status_code': lastVerificationStatusCode,
    };
  }

  static GatewayEndpointConfig? fromJson(Map<String, dynamic> json) {
    final baseUrl = _normalizeBaseUrl((json['base_url'] as String? ?? ''));
    if (baseUrl.isEmpty) return null;

    final updatedAtRaw = json['updated_at'] as String?;
    final verifiedAtRaw = json['last_verified_at'] as String?;
    return GatewayEndpointConfig(
      baseUrl: baseUrl,
      apiPrefix: _normalizeApiPrefix(json['api_prefix'] as String?),
      source: (json['source'] as String? ?? 'cache').trim(),
      versionTag: json['version_tag'] as String?,
      updatedAt: DateTime.tryParse(updatedAtRaw ?? '') ?? DateTime.now(),
      lastVerifiedAt:
          verifiedAtRaw == null ? null : DateTime.tryParse(verifiedAtRaw),
      lastFailureAt: _parseDateTime(json['last_failure_at']),
      disabledUntil: _parseDateTime(json['disabled_until']),
      failureCount: (json['failure_count'] as num?)?.toInt() ?? 0,
      verificationStatus: GatewayVerificationStatusX.fromName(
        json['verification_status'] as String?,
      ),
      lastVerificationStatusCode:
          (json['last_verification_status_code'] as num?)?.toInt(),
    );
  }

  @override
  String toString() => '$baseUrl$apiPrefix [$source]';
}

enum GatewayVerificationStatus {
  unverified,
  verified,
  failed,
  circuitOpen,
}

extension GatewayVerificationStatusX on GatewayVerificationStatus {
  static GatewayVerificationStatus fromName(String? raw) {
    return GatewayVerificationStatus.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => GatewayVerificationStatus.unverified,
    );
  }
}

class GatewayRuntimeSnapshot {
  final GatewayEndpointConfig? activeConfig;
  final GatewayEndpointConfig? lastKnownGoodConfig;
  final List<GatewayEndpointConfig> candidates;
  final String? activeVersionTag;

  const GatewayRuntimeSnapshot({
    required this.activeConfig,
    required this.lastKnownGoodConfig,
    required this.candidates,
    required this.activeVersionTag,
  });
}

enum GatewayRuntimeEventType {
  bootstrap,
  sync,
  configAccepted,
  configRejected,
  verifySuccess,
  verifyFailure,
  failoverCandidateSelected,
  failoverSuccess,
  endpointFailure,
  circuitOpened,
  rollback,
}

class GatewayRuntimeEvent {
  final GatewayRuntimeEventType type;
  final DateTime timestamp;
  final String message;
  final Map<String, Object?> payload;

  const GatewayRuntimeEvent({
    required this.type,
    required this.timestamp,
    required this.message,
    this.payload = const {},
  });
}

/// 网关运行时服务
///
/// 目标：
/// - 将 gateway_urls 和 api_prefix 作为原子配置管理
/// - 冷启动优先使用上次成功配置
/// - 运行时支持静默验证、热切换、故障回退
class GatewayRuntimeService {
  GatewayRuntimeService._();

  static final GatewayRuntimeService instance = GatewayRuntimeService._();

  static const _kGatewayRuntimeCacheKey = 'gateway_runtime_active_config';
  static const _failureThreshold = 2;
  static const Duration _circuitBreakDuration = Duration(seconds: 90);

  final StreamController<GatewayRuntimeSnapshot> _controller =
      StreamController<GatewayRuntimeSnapshot>.broadcast();
  final StreamController<GatewayRuntimeEvent> _eventController =
      StreamController<GatewayRuntimeEvent>.broadcast();
  final List<GatewayRuntimeEvent> _recentEvents = [];

  GatewayEndpointConfig? _activeConfig;
  GatewayEndpointConfig? _lastKnownGoodConfig;
  List<GatewayEndpointConfig> _candidates = const [];
  bool _bootstrapped = false;
  String? _activeVersionTag;

  Stream<GatewayRuntimeSnapshot> get stream => _controller.stream;
  Stream<GatewayRuntimeEvent> get events => _eventController.stream;

  GatewayEndpointConfig? get activeConfig => _activeConfig;

  GatewayEndpointConfig? get lastKnownGoodConfig => _lastKnownGoodConfig;

  List<GatewayEndpointConfig> get candidates =>
      List<GatewayEndpointConfig>.unmodifiable(_candidates);
  List<GatewayRuntimeEvent> get recentEvents =>
      List<GatewayRuntimeEvent>.unmodifiable(_recentEvents);

  Future<void> bootstrapFromCurrentConfig() async {
    if (_bootstrapped) {
      syncFromCurrentConfig();
      return;
    }

    final cached = await _loadPersistedActiveConfig();
    if (cached != null) {
      _activeConfig = cached;
      _activeVersionTag = cached.versionTag;
      _cachedGatewayUrl = cached.baseUrl;
      _cachedGatewayApiPrefix = cached.apiPrefix;
      _recordEvent(
        GatewayRuntimeEventType.bootstrap,
        '已从持久化缓存恢复网关候选',
        payload: {
          'base_url': cached.baseUrl,
          'api_prefix': cached.apiPrefix,
          'version_tag': cached.versionTag,
        },
      );
    }

    syncFromCurrentConfig();
    _bootstrapped = true;
  }

  void syncFromCurrentConfig() {
    final now = DateTime.now();
    final apiPrefix = _currentRemoteApiPrefix();
    final versionTag = _currentRemoteVersionTag();
    final next = <GatewayEndpointConfig>[];
    final seen = <String>{};

    GatewayVerificationStatus? existingStatusFor(String baseUrl) {
      final index = _candidates.indexWhere((item) => item.baseUrl == baseUrl);
      return index >= 0 ? _candidates[index].verificationStatus : null;
    }

    int? existingStatusCodeFor(String baseUrl) {
      final index = _candidates.indexWhere((item) => item.baseUrl == baseUrl);
      return index >= 0 ? _candidates[index].lastVerificationStatusCode : null;
    }

    void addCandidate(
      String baseUrl, {
      required String source,
      String? apiPrefixOverride,
      DateTime? updatedAt,
      DateTime? lastVerifiedAt,
      String? versionTagOverride,
      DateTime? lastFailureAt,
      DateTime? disabledUntil,
      int? failureCount,
      GatewayVerificationStatus? verificationStatus,
      int? lastVerificationStatusCode,
    }) {
      final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
      if (normalizedBaseUrl.isEmpty || !seen.add(normalizedBaseUrl)) return;
      next.add(GatewayEndpointConfig(
        baseUrl: normalizedBaseUrl,
        apiPrefix: _normalizeApiPrefix(apiPrefixOverride ?? apiPrefix),
        source: source,
        versionTag: versionTagOverride ?? versionTag,
        updatedAt: updatedAt ?? now,
        lastVerifiedAt: lastVerifiedAt,
        lastFailureAt: lastFailureAt,
        disabledUntil: disabledUntil,
        failureCount: failureCount ?? 0,
        verificationStatus:
            disabledUntil != null && disabledUntil.isAfter(DateTime.now())
                ? GatewayVerificationStatus.circuitOpen
                : (verificationStatus ??
                    existingStatusFor(normalizedBaseUrl) ??
                    GatewayVerificationStatus.unverified),
        lastVerificationStatusCode: lastVerificationStatusCode ??
            existingStatusCodeFor(normalizedBaseUrl),
      ));
    }

    final override = _normalizeBaseUrl(_overrideUrl);
    if (override.isNotEmpty) {
      addCandidate(
        override,
        source: 'dart_define',
        apiPrefixOverride: _cachedGatewayApiPrefix ?? apiPrefix,
        versionTagOverride: versionTag,
      );
    }

    if (_activeConfig != null) {
      addCandidate(
        _activeConfig!.baseUrl,
        source: _activeConfig!.source,
        apiPrefixOverride: _activeConfig!.apiPrefix,
        versionTagOverride: _activeConfig!.versionTag,
        updatedAt: _activeConfig!.updatedAt,
        lastVerifiedAt: _activeConfig!.lastVerifiedAt,
        lastFailureAt: _activeConfig!.lastFailureAt,
        disabledUntil: _activeConfig!.disabledUntil,
        failureCount: _activeConfig!.failureCount,
        verificationStatus: _activeConfig!.verificationStatus,
        lastVerificationStatusCode: _activeConfig!.lastVerificationStatusCode,
      );
    }

    if (_cachedGatewayUrl != null && _cachedGatewayUrl!.isNotEmpty) {
      addCandidate(
        _cachedGatewayUrl!,
        source: 'memory_cache',
        apiPrefixOverride: _cachedGatewayApiPrefix ?? apiPrefix,
        versionTagOverride: versionTag,
      );
    }

    for (final url in _collectConfiguredGatewayUrls()) {
      final existing =
          _candidates.where((item) => item.baseUrl == _normalizeBaseUrl(url));
      if (existing.isNotEmpty) {
        final candidate = existing.first;
        addCandidate(
          url,
          source: candidate.source == 'dart_define'
              ? candidate.source
              : 'remote_config',
          apiPrefixOverride: candidate.apiPrefix,
          versionTagOverride: candidate.versionTag ?? versionTag,
          updatedAt: candidate.updatedAt,
          lastVerifiedAt: candidate.lastVerifiedAt,
          lastFailureAt: candidate.lastFailureAt,
          disabledUntil: candidate.disabledUntil,
          failureCount: candidate.failureCount,
          verificationStatus: candidate.verificationStatus,
          lastVerificationStatusCode: candidate.lastVerificationStatusCode,
        );
      } else {
        addCandidate(url, source: 'remote_config');
      }
    }

    addCandidate(productionGatewayUrl, source: 'hardcoded_fallback');

    _candidates = next;
    if (_activeConfig == null && _candidates.isNotEmpty) {
      _activeConfig = _candidates.first;
    } else if (_activeConfig != null) {
      _activeConfig = _findMatchingCandidate(_activeConfig!) ?? _activeConfig;
    }
    _recordEvent(
      GatewayRuntimeEventType.sync,
      '已同步当前网关候选列表',
      payload: {
        'candidate_count': _candidates.length,
        'version_tag': versionTag,
      },
    );
    _emit();
  }

  Future<GatewayEndpointConfig?> verifyAndActivateBestCandidate({
    String? userAgent,
    bool preferCurrent = true,
  }) async {
    final queue = <GatewayEndpointConfig>[];
    final attemptedBaseUrls = <String>{};
    if (preferCurrent && _activeConfig != null) {
      queue.add(_activeConfig!);
    }
    for (final candidate in _candidates) {
      if (queue.any((item) => item.baseUrl == candidate.baseUrl)) continue;
      queue.add(candidate);
    }

    final currentVersion = _activeVersionTag ?? _currentRemoteVersionTag();
    for (final candidate in queue) {
      if (_shouldRejectByVersion(candidate, currentVersion)) {
        _recordEvent(
          GatewayRuntimeEventType.configRejected,
          '忽略旧版本网关配置',
          payload: {
            'base_url': candidate.baseUrl,
            'candidate_version': candidate.versionTag,
            'active_version': currentVersion,
          },
        );
        continue;
      }
      attemptedBaseUrls.add(candidate.baseUrl);
      final verified = await _verifyCandidate(candidate, userAgent: userAgent);
      if (verified != null) {
        await applyRuntimeConfig(verified, persist: true);
        _recordEvent(
          GatewayRuntimeEventType.configAccepted,
          '网关配置验证通过并已生效',
          payload: {
            'base_url': verified.baseUrl,
            'api_prefix': verified.apiPrefix,
            'version_tag': verified.versionTag,
          },
        );
        return verified;
      }
    }

    if (_lastKnownGoodConfig != null &&
        _lastKnownGoodConfig!.lastVerifiedAt != null &&
        !attemptedBaseUrls.contains(_lastKnownGoodConfig!.baseUrl)) {
      _recordEvent(
        GatewayRuntimeEventType.rollback,
        '所有候选验证失败，回退到最后成功配置',
        payload: {
          'base_url': _lastKnownGoodConfig!.baseUrl,
          'api_prefix': _lastKnownGoodConfig!.apiPrefix,
          'version_tag': _lastKnownGoodConfig!.versionTag,
        },
      );
      await applyRuntimeConfig(_lastKnownGoodConfig!, persist: true);
      return _lastKnownGoodConfig;
    }
    _recordEvent(
      GatewayRuntimeEventType.verifyFailure,
      '所有网关候选验证失败',
      payload: {
        'candidate_count': queue.length,
      },
    );
    return null;
  }

  Future<GatewayEndpointConfig?> forceReverifyCandidates({
    String? userAgent,
  }) async {
    _recordEvent(
      GatewayRuntimeEventType.sync,
      '手动触发候选重新验证',
      payload: {
        'candidate_count': _candidates.length,
      },
    );
    syncFromCurrentConfig();
    return verifyAndActivateBestCandidate(
      userAgent: userAgent,
      preferCurrent: false,
    );
  }

  Future<List<GatewayEndpointConfig>> reverifyAllCandidates({
    String? userAgent,
  }) async {
    _recordEvent(
      GatewayRuntimeEventType.sync,
      '手动触发全部候选探测',
      payload: {
        'candidate_count': _candidates.length,
      },
    );
    syncFromCurrentConfig();

    final currentVersion = _activeVersionTag ?? _currentRemoteVersionTag();
    final verifiedCandidates = <GatewayEndpointConfig>[];
    final queue = List<GatewayEndpointConfig>.from(_candidates);
    for (final candidate in queue) {
      if (_shouldRejectByVersion(candidate, currentVersion)) {
        _recordEvent(
          GatewayRuntimeEventType.configRejected,
          '忽略旧版本网关配置',
          payload: {
            'base_url': candidate.baseUrl,
            'candidate_version': candidate.versionTag,
            'active_version': currentVersion,
          },
        );
        continue;
      }
      final verified = await _verifyCandidate(candidate, userAgent: userAgent);
      if (verified == null) continue;
      verifiedCandidates.add(verified);
      _upsertCandidate(verified);
      _emit();
    }

    if (verifiedCandidates.isNotEmpty) {
      await applyRuntimeConfig(verifiedCandidates.first, persist: true);
      _recordEvent(
        GatewayRuntimeEventType.configAccepted,
        '全部候选探测完成，已应用首个可用网关',
        payload: {
          'base_url': verifiedCandidates.first.baseUrl,
          'api_prefix': verifiedCandidates.first.apiPrefix,
          'available_count': verifiedCandidates.length,
          'candidate_count': queue.length,
        },
      );
    } else {
      _recordEvent(
        GatewayRuntimeEventType.verifyFailure,
        '全部网关候选探测完成，未发现可用网关',
        payload: {
          'candidate_count': queue.length,
        },
      );
      _emit();
    }
    return verifiedCandidates;
  }

  Future<void> clearCircuitBreakers() async {
    if (_candidates.isEmpty) return;
    _candidates = _candidates
        .map(
          (candidate) => GatewayEndpointConfig(
            baseUrl: candidate.baseUrl,
            apiPrefix: candidate.apiPrefix,
            source: candidate.source,
            versionTag: candidate.versionTag,
            updatedAt: candidate.updatedAt,
            lastVerifiedAt: candidate.lastVerifiedAt,
            failureCount: 0,
            verificationStatus: GatewayVerificationStatus.unverified,
            lastVerificationStatusCode: candidate.lastVerificationStatusCode,
          ),
        )
        .toList();
    _recordEvent(
      GatewayRuntimeEventType.sync,
      '手动清空所有熔断状态',
      payload: {
        'candidate_count': _candidates.length,
      },
    );
    _emit();
  }

  GatewayEndpointConfig? nextFailoverCandidate(Set<String> attemptedBaseUrls) {
    for (final candidate in _candidates) {
      if (_activeConfig != null &&
          candidate.baseUrl == _activeConfig!.baseUrl) {
        continue;
      }
      if (attemptedBaseUrls.contains(candidate.baseUrl)) continue;
      if (candidate.isCircuitOpen) continue;
      _recordEvent(
        GatewayRuntimeEventType.failoverCandidateSelected,
        '选中备用网关候选',
        payload: {
          'base_url': candidate.baseUrl,
          'api_prefix': candidate.apiPrefix,
          'failure_count': candidate.failureCount,
          'disabled_until': candidate.disabledUntil?.toIso8601String(),
        },
      );
      return candidate;
    }
    if (_lastKnownGoodConfig != null &&
        _activeConfig != null &&
        _lastKnownGoodConfig!.baseUrl != _activeConfig!.baseUrl &&
        !attemptedBaseUrls.contains(_lastKnownGoodConfig!.baseUrl) &&
        !_lastKnownGoodConfig!.isCircuitOpen) {
      return _lastKnownGoodConfig;
    }
    return null;
  }

  void mergeGatewayUrls(
    List<String> urls, {
    String? apiPrefix,
    String source = 'login_response',
    String? versionTag,
  }) {
    final normalized =
        urls.map(_normalizeBaseUrl).where((url) => url.isNotEmpty).toList();
    if (normalized.isEmpty) return;

    final now = DateTime.now();
    final merged = <GatewayEndpointConfig>[];
    final seen = <String>{};

    void addConfig(GatewayEndpointConfig config) {
      if (seen.add(config.baseUrl)) {
        merged.add(config);
      }
    }

    for (final url in normalized) {
      addConfig(GatewayEndpointConfig(
        baseUrl: url,
        apiPrefix: _normalizeApiPrefix(apiPrefix ?? _currentRemoteApiPrefix()),
        source: source,
        versionTag: versionTag ?? _currentRemoteVersionTag(),
        updatedAt: now,
      ));
    }

    if (_activeConfig != null) {
      addConfig(_activeConfig!);
    }

    for (final candidate in _candidates) {
      addConfig(candidate);
    }

    _candidates = merged;
    _recordEvent(
      GatewayRuntimeEventType.sync,
      '已合并登录响应中的网关候选',
      payload: {
        'candidate_count': _candidates.length,
        'source': source,
        'version_tag': versionTag ?? _currentRemoteVersionTag(),
      },
    );
    _emit();
  }

  Future<void> markSuccess(
    String baseUrl, {
    String? apiPrefix,
    String source = 'runtime_success',
    String? versionTag,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (normalizedBaseUrl.isEmpty) return;

    final now = DateTime.now();
    final existing =
        _candidates.where((item) => item.baseUrl == normalizedBaseUrl);
    final config = existing.isNotEmpty
        ? existing.first.copyWith(
            apiPrefix: apiPrefix,
            source: source,
            versionTag: versionTag ?? existing.first.versionTag,
            updatedAt: now,
            lastVerifiedAt: now,
            lastFailureAt: null,
            disabledUntil: null,
            failureCount: 0,
            verificationStatus: GatewayVerificationStatus.verified,
          )
        : GatewayEndpointConfig(
            baseUrl: normalizedBaseUrl,
            apiPrefix:
                _normalizeApiPrefix(apiPrefix ?? _currentRemoteApiPrefix()),
            source: source,
            versionTag: versionTag ?? _currentRemoteVersionTag(),
            updatedAt: now,
            lastVerifiedAt: now,
            verificationStatus: GatewayVerificationStatus.verified,
          );

    _recordEvent(
      source == 'sdk_failover'
          ? GatewayRuntimeEventType.failoverSuccess
          : GatewayRuntimeEventType.verifySuccess,
      '网关请求成功',
      payload: {
        'base_url': config.baseUrl,
        'api_prefix': config.apiPrefix,
        'source': source,
        'version_tag': config.versionTag,
      },
    );
    await applyRuntimeConfig(config, persist: true);
  }

  Future<void> markFailure(
    String baseUrl, {
    String? apiPrefix,
    String source = 'runtime_failure',
    Object? error,
  }) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (normalizedBaseUrl.isEmpty) return;

    final existingIndex =
        _candidates.indexWhere((item) => item.baseUrl == normalizedBaseUrl);
    final now = DateTime.now();
    final existing = existingIndex >= 0 ? _candidates[existingIndex] : null;
    final statusCode = _extractStatusCode(error);
    final nextFailureCount = (existing?.failureCount ?? 0) + 1;
    final shouldOpenCircuit = nextFailureCount >= _failureThreshold;
    final updated = (existing ??
            GatewayEndpointConfig(
              baseUrl: normalizedBaseUrl,
              apiPrefix:
                  _normalizeApiPrefix(apiPrefix ?? _currentRemoteApiPrefix()),
              source: source,
              versionTag: _currentRemoteVersionTag(),
              updatedAt: now,
            ))
        .copyWith(
      apiPrefix: apiPrefix,
      source: source,
      updatedAt: now,
      lastFailureAt: now,
      failureCount: nextFailureCount,
      disabledUntil: shouldOpenCircuit
          ? now.add(_circuitBreakDuration)
          : existing?.disabledUntil,
      verificationStatus: shouldOpenCircuit
          ? GatewayVerificationStatus.circuitOpen
          : GatewayVerificationStatus.failed,
      lastVerificationStatusCode:
          statusCode ?? existing?.lastVerificationStatusCode,
    );

    if (existingIndex >= 0) {
      _candidates = [
        for (var i = 0; i < _candidates.length; i++)
          if (i == existingIndex) updated else _candidates[i],
      ];
    } else {
      _candidates = [..._candidates, updated];
    }

    _recordEvent(
      GatewayRuntimeEventType.endpointFailure,
      '网关请求失败',
      payload: {
        'base_url': updated.baseUrl,
        'api_prefix': updated.apiPrefix,
        'failure_count': updated.failureCount,
        'source': source,
        'error': error?.toString(),
        'status_code': statusCode ?? updated.lastVerificationStatusCode,
      },
    );

    if (shouldOpenCircuit) {
      _recordEvent(
        GatewayRuntimeEventType.circuitOpened,
        '网关节点已被熔断',
        payload: {
          'base_url': updated.baseUrl,
          'disabled_until': updated.disabledUntil?.toIso8601String(),
          'failure_count': updated.failureCount,
        },
      );
    }

    _emit();
  }

  int? _extractStatusCode(Object? error) {
    final text = error?.toString();
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'\b([45]\d{2})\b').firstMatch(text);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<void> applyRuntimeConfig(
    GatewayEndpointConfig config, {
    bool persist = true,
  }) async {
    final normalized = config.copyWith();
    _activeConfig = normalized;
    _lastKnownGoodConfig = normalized;
    _activeVersionTag = normalized.versionTag;
    _cachedGatewayUrl = normalized.baseUrl;
    _cachedGatewayApiPrefix = normalized.apiPrefix;

    final next = <GatewayEndpointConfig>[normalized];
    for (final candidate in _candidates) {
      if (candidate.baseUrl == normalized.baseUrl) continue;
      next.add(candidate);
    }
    _candidates = next;
    _emit();

    if (persist) {
      await _persistActiveConfig(normalized);
    }
  }

  Future<void> rollbackToLastKnownGood() async {
    if (_lastKnownGoodConfig == null) return;
    await applyRuntimeConfig(_lastKnownGoodConfig!, persist: true);
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(GatewayRuntimeSnapshot(
        activeConfig: _activeConfig,
        lastKnownGoodConfig: _lastKnownGoodConfig,
        candidates: candidates,
        activeVersionTag: _activeVersionTag,
      ));
    }
  }

  GatewayEndpointConfig? _findMatchingCandidate(GatewayEndpointConfig config) {
    for (final candidate in _candidates) {
      if (candidate.baseUrl == config.baseUrl) {
        return candidate.copyWith(
          apiPrefix: config.apiPrefix,
          source: config.source,
          versionTag: config.versionTag,
          updatedAt: config.updatedAt,
          lastVerifiedAt: config.lastVerifiedAt,
          lastFailureAt: config.lastFailureAt,
          disabledUntil: config.disabledUntil,
          failureCount: config.failureCount,
        );
      }
    }
    return null;
  }

  void _upsertCandidate(GatewayEndpointConfig config) {
    final index =
        _candidates.indexWhere((item) => item.baseUrl == config.baseUrl);
    if (index >= 0) {
      _candidates = [
        for (var i = 0; i < _candidates.length; i++)
          if (i == index) config else _candidates[i],
      ];
    } else {
      _candidates = [..._candidates, config];
    }
  }

  Future<void> _persistActiveConfig(GatewayEndpointConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kGatewayRuntimeCacheKey, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  Future<GatewayEndpointConfig?> _loadPersistedActiveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kGatewayRuntimeCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return GatewayEndpointConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return GatewayEndpointConfig.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<GatewayEndpointConfig?> _verifyCandidate(
    GatewayEndpointConfig candidate, {
    String? userAgent,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 4);
      client.badCertificateCallback = (_, __, ___) => true;

      final testUrl = Uri.parse(
        '${candidate.baseUrl}${candidate.apiPrefix}/guest/comm/config',
      );
      final request = await client.getUrl(testUrl);
      if (userAgent != null && userAgent.isNotEmpty) {
        request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      }
      final response =
          await request.close().timeout(const Duration(seconds: 4));
      await response.drain<void>();

      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        _recordEvent(
          GatewayRuntimeEventType.verifySuccess,
          '网关候选验证成功',
          payload: {
            'base_url': candidate.baseUrl,
            'api_prefix': candidate.apiPrefix,
            'version_tag': candidate.versionTag,
            'status_code': statusCode,
          },
        );
        return candidate.copyWith(
          lastVerifiedAt: DateTime.now(),
          lastFailureAt: null,
          disabledUntil: null,
          failureCount: 0,
          verificationStatus: GatewayVerificationStatus.verified,
          lastVerificationStatusCode: statusCode,
        );
      }
      _recordEvent(
        GatewayRuntimeEventType.verifyFailure,
        '网关候选验证失败',
        payload: {
          'base_url': candidate.baseUrl,
          'api_prefix': candidate.apiPrefix,
          'version_tag': candidate.versionTag,
          'status_code': statusCode,
        },
      );
      final failedCandidate = candidate.copyWith(
        lastFailureAt: DateTime.now(),
        verificationStatus: GatewayVerificationStatus.failed,
        lastVerificationStatusCode: statusCode,
      );
      _upsertCandidate(failedCandidate);
      _emit();
      return null;
    } catch (_) {
      _recordEvent(
        GatewayRuntimeEventType.verifyFailure,
        '网关候选验证失败',
        payload: {
          'base_url': candidate.baseUrl,
          'api_prefix': candidate.apiPrefix,
          'version_tag': candidate.versionTag,
        },
      );
      final failedCandidate = candidate.copyWith(
        lastFailureAt: DateTime.now(),
        verificationStatus: GatewayVerificationStatus.failed,
      );
      _upsertCandidate(failedCandidate);
      _emit();
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  bool _shouldRejectByVersion(
    GatewayEndpointConfig candidate,
    String currentVersion,
  ) {
    if (currentVersion.isEmpty || candidate.versionTag == null) return false;
    return _compareVersionTags(candidate.versionTag, currentVersion) < 0;
  }

  void _recordEvent(
    GatewayRuntimeEventType type,
    String message, {
    Map<String, Object?> payload = const {},
  }) {
    final event = GatewayRuntimeEvent(
      type: type,
      timestamp: DateTime.now(),
      message: message,
      payload: payload,
    );
    _recentEvents.insert(0, event);
    if (_recentEvents.length > 80) {
      _recentEvents.removeRange(80, _recentEvents.length);
    }
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
    final maskedPayload = payload.map((key, value) {
      if (key.toLowerCase().contains('base_url') || key == 'url') {
        return MapEntry(
            key, value == null ? null : gatewayDisplayLabel(value.toString()));
      }
      return MapEntry(key, value);
    });
    _logger.info('[GatewayRuntime][$type] $message | $maskedPayload');
  }
}

/// 上次成功通信的网关 URL（冷启动时优先尝试）
String? get cachedGatewayUrl =>
    GatewayRuntimeService.instance.activeConfig?.baseUrl ?? _cachedGatewayUrl;

/// 设置缓存的网关 URL（登录成功或故障转移成功后调用）
void setCachedGatewayUrl(String? url, {String? apiPrefix}) {
  final normalizedUrl = url == null ? null : _normalizeBaseUrl(url);
  _cachedGatewayUrl = normalizedUrl;
  _cachedGatewayApiPrefix =
      _normalizeApiPrefix(apiPrefix ?? _cachedGatewayApiPrefix);
  if (normalizedUrl == null || normalizedUrl.isEmpty) return;

  unawaited(
    GatewayRuntimeService.instance.markSuccess(
      normalizedUrl,
      apiPrefix: _cachedGatewayApiPrefix,
      source: 'legacy_cache',
    ),
  );
}

/// 获取所有可用的网关地址列表（含故障转移备用地址）
List<String> get allGatewayUrls {
  final runtimeUrls = GatewayRuntimeService.instance.candidates
      .map((item) => item.baseUrl)
      .toList();
  if (runtimeUrls.isNotEmpty) {
    return runtimeUrls;
  }
  return _collectConfiguredGatewayUrls();
}

/// 获取当前生效的网关配置
GatewayEndpointConfig? get activeGatewayConfig =>
    GatewayRuntimeService.instance.activeConfig;

/// 获取主网关 base URL（allGatewayUrls 的第一个）
String get gatewayBaseUrl {
  final active = GatewayRuntimeService.instance.activeConfig;
  if (active != null) return active.baseUrl;
  return allGatewayUrls.first;
}

/// 获取当前生效的 API 前缀
String get currentGatewayApiPrefix {
  final active = GatewayRuntimeService.instance.activeConfig;
  if (active != null) return active.apiPrefix;
  return _currentRemoteApiPrefix();
}
