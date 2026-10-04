import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import '../core/config_settings.dart';
import '../../core/core.dart';

final _logger = FileLogger('remote_config_manager.dart');

// ─────────────────────────────────────────────────────────────
// XOR+Base64 加密密钥（与 encrypt_config.py 中的 KEY 保持一致）
//
// 优先从 --dart-define=XOR_KEY=... 编译时注入（build.yaml CI 传入）
// 本地开发若未传入则使用 defaultValue 占位符
// ─────────────────────────────────────────────────────────────
const String _xorKey = String.fromEnvironment(
  'XOR_KEY',
  defaultValue: 'CHANGE_ME_TO_YOUR_SECRET_KEY_32C',
);

// 后台“客户端配置”生成的 Ed25519 公钥。启用签名加密 v2 时，CI 必须通过
// --dart-define=REMOTE_CONFIG_PUBLIC_KEY=... 注入；私钥只保留在服务端。
const String _remoteConfigPublicKey = String.fromEnvironment(
  'REMOTE_CONFIG_PUBLIC_KEY',
  defaultValue: '',
);

/// Only signed v2 envelopes are accepted, including when restoring disk caches.
Future<String> _smartDecrypt(
  String content, {
  String verificationPublicKey = _remoteConfigPublicKey,
}) async {
  Map<String, dynamic> decoded;
  try {
    decoded = json.decode(content.trim()) as Map<String, dynamic>;
  } catch (_) {
    throw const FormatException('远程配置仅支持 fastcat-config-v2 签名格式');
  }
  if (decoded['_format'] == 'fastcat-config-v2') {
    try {
      final payload = decoded['payload'];
      final signature = decoded['signature'];
      if (decoded['algorithm'] != 'Ed25519' ||
          decoded['encoding'] != 'xor+base64' ||
          payload is! String ||
          signature is! String) {
        throw const FormatException('签名配置格式不完整');
      }
      if (verificationPublicKey.trim().isEmpty) {
        throw const FormatException(
          '签名配置缺少 REMOTE_CONFIG_PUBLIC_KEY',
        );
      }
      final algorithm = Ed25519();
      final isValid = await algorithm.verify(
        utf8.encode(payload),
        signature: Signature(
          base64.decode(signature),
          publicKey: SimplePublicKey(
            base64.decode(verificationPublicKey),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!isValid) throw const FormatException('远程配置签名校验失败');
      _logger.info('[smartDecrypt] Ed25519 签名校验成功');
      return _xorDecrypt(payload);
    } catch (_) {
      throw const FormatException('签名配置校验或解密失败，请检查公钥和配置文件');
    }
  }
  throw const FormatException('远程配置仅支持 fastcat-config-v2 签名格式');
}

String _xorDecrypt(String encoded) {
  final keyBytes = utf8.encode(_xorKey);
  if (keyBytes.isEmpty) throw const FormatException('XOR 密钥不能为空');
  final encryptedBytes = base64.decode(encoded.trim());
  final decryptedBytes = Uint8List(encryptedBytes.length);
  for (var i = 0; i < encryptedBytes.length; i++) {
    decryptedBytes[i] = encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
  }
  final result = utf8.decode(decryptedBytes);
  json.decode(result);
  return result;
}

// ─────────────────────────────────────────────────────────────
// 数据模型
// ─────────────────────────────────────────────────────────────

enum RemoteConfigStatus { uninitialized, loading, success, error }

class ConfigResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final String source;
  final RemoteConfigStatus status;
  final DateTime fetchTime;
  final String? rawContent;
  final bool isStale;

  const ConfigResult({
    required this.isSuccess,
    this.data,
    this.error,
    required this.source,
    required this.status,
    required this.fetchTime,
    this.rawContent,
    this.isStale = false,
  });

  factory ConfigResult.success(T data, String source,
          {String? rawContent, DateTime? verifiedAt, bool isStale = false}) =>
      ConfigResult(
        isSuccess: true,
        data: data,
        source: source,
        status: RemoteConfigStatus.success,
        fetchTime: verifiedAt ?? DateTime.now(),
        rawContent: rawContent,
        isStale: isStale,
      );

  factory ConfigResult.failure(String error, String source) => ConfigResult(
        isSuccess: false,
        error: error,
        source: source,
        status: RemoteConfigStatus.error,
        fetchTime: DateTime.now(),
      );
}

class MultiConfigResult {
  final ConfigResult<Map<String, dynamic>> primaryResult;
  final ConfigResult<Map<String, dynamic>> backupResult;

  const MultiConfigResult(
      {required this.primaryResult, required this.backupResult});

  bool get hasSuccess => primaryResult.isSuccess || backupResult.isSuccess;

  Map<String, dynamic>? get firstSuccessfulData =>
      primaryResult.isSuccess ? primaryResult.data : backupResult.data;

  String? get firstSuccessfulSource =>
      primaryResult.isSuccess ? primaryResult.source : backupResult.source;

  ConfigResult<Map<String, dynamic>>? get firstSuccessful =>
      primaryResult.isSuccess
          ? primaryResult
          : (backupResult.isSuccess ? backupResult : null);

  @override
  String toString() =>
      'MultiConfigResult{primary: ${primaryResult.status}, backup: ${backupResult.status}}';
}

// ─────────────────────────────────────────────────────────────
// HTTP 客户端
// ─────────────────────────────────────────────────────────────

abstract class IHttpClient {
  Future<String?> getString(String url, {Duration? timeout});
}

class SimpleHttpClient implements IHttpClient {
  @override
  Future<String?> getString(String url, {Duration? timeout}) async {
    HttpClient? client;
    try {
      _logger.info('[SimpleHttpClient] 请求配置源: ${Uri.tryParse(url)?.host}');
      client = HttpClient();
      // findProxy=DIRECT 绕过 FastcatHttpOverrides，避免 Clash 未启动时
      // OSS 请求被路由到 localhost:PORT 导致连接被拒绝（"无法获取可用域名"）
      client.findProxy = (uri) => 'DIRECT';
      final configured = timeout ?? const Duration(seconds: 10);
      final limit = configured > const Duration(seconds: 10)
          ? const Duration(seconds: 10)
          : configured;
      final watch = Stopwatch()..start();
      Duration remaining() {
        final left = limit - watch.elapsed;
        return left.isNegative ? Duration.zero : left;
      }

      client.connectionTimeout = limit;
      final request = await client.getUrl(Uri.parse(url)).timeout(remaining());
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(remaining());
      _logger.info('[SimpleHttpClient] 响应: ${response.statusCode}');
      if (response.statusCode == 200) {
        final body =
            await response.transform(utf8.decoder).join().timeout(remaining());
        _logger.info('[SimpleHttpClient] 成功，数据长度: ${body.length}');
        return body;
      }
      _logger.warning('[SimpleHttpClient] 非200状态码: ${response.statusCode}');
      return null;
    } catch (_) {
      _logger.error('[SimpleHttpClient] 配置请求失败');
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 配置源
// ─────────────────────────────────────────────────────────────

abstract class ConfigSource {
  String get sourceName;
  int get priority;
  bool get isEmergency;
  Future<ConfigResult<Map<String, dynamic>>> fetchConfig();
}

/// OSS 配置源 — 仅接受 Ed25519 验签通过的 fastcat-config-v2。
class OssConfigSource implements ConfigSource {
  final IHttpClient _httpClient;
  final String url;
  final String name;
  final bool emergency;
  final Duration timeout;
  final String verificationPublicKey;

  OssConfigSource({
    IHttpClient? httpClient,
    required this.url,
    required this.name,
    this.emergency = false,
    Duration? timeout,
    this.verificationPublicKey = _remoteConfigPublicKey,
  })  : _httpClient = httpClient ?? SimpleHttpClient(),
        timeout = timeout ?? const Duration(seconds: 10);

  @override
  String get sourceName => name;

  @override
  int get priority => 1;

  @override
  bool get isEmergency => emergency;

  @override
  Future<ConfigResult<Map<String, dynamic>>> fetchConfig() async {
    try {
      // 只打印域名部分，避免日志泄露完整 OSS URL
      final maskedUrl =
          Uri.tryParse(url)?.host ?? url.substring(0, url.length.clamp(0, 20));
      _logger.info('获取 OSS 配置 ($name): $maskedUrl');
      final rawData = await _httpClient.getString(url, timeout: timeout);
      if (rawData == null || rawData.trim().isEmpty) {
        return ConfigResult.failure('OSS 配置数据为空', sourceName);
      }
      final decrypted = await _smartDecrypt(
        rawData,
        verificationPublicKey: verificationPublicKey,
      );
      final jsonData = json.decode(decrypted) as Map<String, dynamic>;
      _logger.info('OSS 配置获取成功 ($name), keys: ${jsonData.keys}');
      return ConfigResult.success(jsonData, sourceName, rawContent: rawData);
    } catch (e) {
      final errStr = e.toString();
      String detail;
      if (errStr.contains('FormatException')) {
        detail = 'OSS 配置解密/解析失败（仅支持 fastcat-config-v2，请检查签名公钥及XOR密钥）';
      } else if (errStr.contains('SocketException') ||
          errStr.contains('Connection')) {
        detail = 'OSS 地址不可达（请检查网络或URL是否正确）';
      } else {
        detail = 'OSS 配置源异常';
      }
      _logger.error('$detail ($name)');
      return ConfigResult.failure(detail, sourceName);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 远程配置管理器
// ─────────────────────────────────────────────────────────────

class RemoteConfigManager {
  static const _lastSuccessfulSourceKey =
      'xboard_remote_config_last_successful_source';
  static const rawCacheKey = 'xboard_remote_config_raw_v2';
  static const cacheFreshAge = Duration(days: 7);
  static const cacheMaxAge = Duration(days: 30);
  static const Duration _versionSettlementWindow = Duration(milliseconds: 350);
  final List<ConfigSource> _configSources;
  final int _maxRetries;
  final Duration _retryDelay;
  final String verificationPublicKey;
  final DateTime Function() _now;
  Future<ConfigResult<Map<String, dynamic>>>? _inFlight;

  RemoteConfigManager({
    List<ConfigSource>? sources,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    this.verificationPublicKey = _remoteConfigPublicKey,
    DateTime Function()? now,
  })  : _configSources = sources ?? [],
        _maxRetries = maxRetries,
        _retryDelay = retryDelay,
        _now = now ?? DateTime.now;

  /// 从 config.yaml 设置创建管理器（所有源必须使用 fastcat-config-v2）。
  factory RemoteConfigManager.fromSettings(RemoteConfigSettings settings) {
    final sources = <ConfigSource>[];
    for (final s in settings.sources) {
      sources.add(OssConfigSource(
        url: s.url,
        name: s.name,
        emergency: s.isEmergency,
        timeout: s.timeout ?? settings.timeout,
      ));
    }
    return RemoteConfigManager(
      sources: sources,
      maxRetries: settings.maxRetries,
      retryDelay: settings.retryDelay,
    );
  }

  /// Concurrently fetches all sources and returns the first response that can
  /// actually be parsed and accepted by the caller.
  ///
  /// The last successful source is started first on the next launch, while all
  /// other sources still run concurrently so a dead preferred source does not
  /// delay startup by its full timeout.
  Future<ConfigResult<Map<String, dynamic>>> fetchFirstUsableConfig(
    bool Function(Map<String, dynamic> data) isUsable,
  ) async {
    final existing = _inFlight;
    if (existing != null) return existing;
    final task = _fetchUsable(isUsable);
    _inFlight = task;
    try {
      return await task;
    } finally {
      if (identical(_inFlight, task)) _inFlight = null;
    }
  }

  Future<ConfigResult<Map<String, dynamic>>> _fetchUsable(
    bool Function(Map<String, dynamic>) isUsable,
  ) async {
    final cached = await _loadBestCachedConfig(isUsable);
    final orderedSources = await _sourcesWithLastSuccessFirst();
    final normalSources =
        orderedSources.where((source) => !source.isEmergency).toList();
    final emergencySources =
        orderedSources.where((source) => source.isEmergency).toList();
    final errors = <String>[];

    var liveResult = await _fetchFirstUsableGroup(
      normalSources,
      isUsable,
      errors,
      settleForHigherVersion: true,
    );

    // 普通源全部失败后，只快速重试上次成功的普通源一次，避免网络刚恢复时
    // 直接进入紧急源。无普通源时跳过。
    if (liveResult == null && normalSources.isNotEmpty) {
      final retryResult = await _fetchBounded(normalSources.first);
      if (retryResult.isSuccess &&
          retryResult.data != null &&
          isUsable(retryResult.data!)) {
        liveResult = retryResult;
      } else {
        errors.add(
          '${retryResult.source}: ${retryResult.error ?? '配置内容校验失败'}',
        );
      }
    }

    // 内置紧急 OSS 永远只在普通源没有有效结果后接管。
    liveResult ??= await _fetchFirstUsableGroup(
      emergencySources,
      isUsable,
      errors,
      settleForHigherVersion: true,
    );

    // Prefer a live response on equal versions: this revalidates cache age and
    // permits correcting a same-version deployment. Lower versions never
    // replace an unexpired newer cache; rollback is a new higher revision.
    final selected = _newerResult(cached, liveResult);
    if (selected != null) {
      if (selected.source != 'local_cache') {
        await _persistLastSuccessfulSource(selected.source);
        await _persistCompleteConfig(selected, isUsable);
      }
      _logger.info(
        '[RemoteConfigManager] ✅ 使用可解析配置源: ${selected.source} '
        '(config_version=${_configVersion(selected.data)})',
      );
      return selected;
    }

    return ConfigResult.failure(errors.join('; '), 'all');
  }

  Future<ConfigResult<Map<String, dynamic>>?> _fetchFirstUsableGroup(
    List<ConfigSource> sources,
    bool Function(Map<String, dynamic> data) isUsable,
    List<String> errors, {
    required bool settleForHigherVersion,
  }) async {
    if (sources.isEmpty) return null;
    final pending = <int, Future<(int, ConfigResult<Map<String, dynamic>>)>>{};
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      pending[i] = _fetchBounded(source).then((result) => (i, result));
    }

    ConfigResult<Map<String, dynamic>>? best;
    DateTime? settleDeadline;
    while (pending.isNotEmpty) {
      (int, ConfigResult<Map<String, dynamic>>) completed;
      if (settleDeadline == null) {
        completed = await Future.any(pending.values);
      } else {
        final remaining = settleDeadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        try {
          completed = await Future.any(pending.values).timeout(remaining);
        } on TimeoutException {
          break;
        }
      }
      pending.remove(completed.$1);
      final result = completed.$2;
      if (!result.isSuccess || result.data == null) {
        errors.add('${result.source}: ${result.error}');
        continue;
      }
      if (!isUsable(result.data!)) {
        errors.add('${result.source}: 配置内容校验失败');
        _logger.warning(
          '[RemoteConfigManager] ${result.source} 请求成功但配置不可用，继续接管源',
        );
        continue;
      }
      best = _newerResult(result, best);
      if (!settleForHigherVersion) return best;
      settleDeadline ??= DateTime.now().add(_versionSettlementWindow);
    }
    return best;
  }

  ConfigResult<Map<String, dynamic>>? _newerResult(
    ConfigResult<Map<String, dynamic>>? left,
    ConfigResult<Map<String, dynamic>>? right,
  ) {
    if (left == null) return right;
    if (right == null) return left;
    final comparison = _compareConfigVersions(
      _configVersion(left.data),
      _configVersion(right.data),
    );
    // Equal versions keep the right-hand result; callers pass live data on
    // the right when comparing disk cache against a verified network response.
    return comparison > 0 ? left : right;
  }

  String _configVersion(Map<String, dynamic>? data) {
    if (data == null) return '';
    final direct = data['config_version']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    for (final value in data.values) {
      if (value is Map) {
        final nested =
            value.map((key, value) => MapEntry(key.toString(), value));
        final version = _configVersion(nested);
        if (version.isNotEmpty) return version;
      }
    }
    return '';
  }

  int _compareConfigVersions(String left, String right) {
    if (left == right) return 0;
    if (left.isEmpty) return -1;
    if (right.isEmpty) return 1;
    final leftParts = left.split('.').map((p) => int.tryParse(p)).toList();
    final rightParts = right.split('.').map((p) => int.tryParse(p)).toList();
    if (leftParts.every((p) => p != null) &&
        rightParts.every((p) => p != null)) {
      final length = leftParts.length > rightParts.length
          ? leftParts.length
          : rightParts.length;
      for (var i = 0; i < length; i++) {
        final a = i < leftParts.length ? leftParts[i]! : 0;
        final b = i < rightParts.length ? rightParts[i]! : 0;
        if (a != b) return a.compareTo(b);
      }
      return 0;
    }
    return left.compareTo(right);
  }

  Future<ConfigResult<Map<String, dynamic>>> _fetchBounded(
      ConfigSource source) async {
    try {
      final configured = source is OssConfigSource
          ? source.timeout
          : const Duration(seconds: 10);
      final timeout = configured > const Duration(seconds: 10)
          ? const Duration(seconds: 10)
          : configured;
      return await source.fetchConfig().timeout(timeout);
    } catch (_) {
      return ConfigResult.failure('配置请求超时或失败', source.sourceName);
    }
  }

  // Only original signed envelopes can be cached; decoding verifies them again.
  bool _cacheable(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map && value['_format'] == 'fastcat-config-v2';
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistCompleteConfig(ConfigResult<Map<String, dynamic>> result,
      bool Function(Map<String, dynamic>) isUsable) async {
    final raw = result.rawContent;
    if (raw == null || !_cacheable(raw)) return;
    try {
      // Revalidate with the configured trust key before writing as well.
      final verified = jsonDecode(await _smartDecrypt(raw,
              verificationPublicKey: verificationPublicKey))
          as Map<String, dynamic>;
      if (!isUsable(verified)) return;
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> saved = {};
      try {
        saved = jsonDecode(prefs.getString(rawCacheKey) ?? '{}')
            as Map<String, dynamic>;
      } catch (_) {}
      final current = saved['current'];
      // Never rotate a corrupt current over a valid previous snapshot.
      final validCurrent = await _decodeCache(current, isUsable);
      final validPrevious = await _decodeCache(saved['previous'], isUsable);
      final previous = validCurrent != null &&
              current is Map &&
              current['raw_content'] != raw
          ? current
          : validPrevious != null
              ? saved['previous']
              : null;
      await prefs.setString(
          rawCacheKey,
          jsonEncode({
            'current': {
              'raw_content': raw,
              'verified_at': _now().toUtc().toIso8601String(),
              'source': result.source,
            },
            if (previous != null) 'previous': previous,
          }));
      // Old parsed caches cannot be re-authenticated. Retire them only after a
      // replacement has been saved; never manufacture a signature for old data.
      await prefs.remove('xboard_remote_config_complete_current_v1');
      await prefs.remove('xboard_remote_config_complete_previous_v1');
    } catch (_) {
      _logger.warning('[RemoteConfigManager] 保存原始配置缓存失败');
    }
  }

  Future<ConfigResult<Map<String, dynamic>>?> _decodeCache(
    dynamic record,
    bool Function(Map<String, dynamic>) isUsable,
  ) async {
    try {
      if (record is! Map || record['raw_content'] is! String) return null;
      final verifiedAt =
          DateTime.tryParse(record['verified_at']?.toString() ?? '');
      if (verifiedAt == null) return null;
      final age = _now().difference(verifiedAt);
      if (age.isNegative || age > cacheMaxAge) return null;
      final raw = record['raw_content'] as String;
      if (!_cacheable(raw)) return null;
      final data = jsonDecode(await _smartDecrypt(raw,
              verificationPublicKey: verificationPublicKey))
          as Map<String, dynamic>;
      if (!isUsable(data)) return null;
      return ConfigResult.success(data, 'local_cache',
          rawContent: raw,
          verifiedAt: verifiedAt,
          isStale: age > cacheFreshAge);
    } catch (_) {
      return null;
    }
  }

  Future<ConfigResult<Map<String, dynamic>>?> _loadBestCachedConfig(
    bool Function(Map<String, dynamic> data) isUsable,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(rawCacheKey) ?? '{}');
      if (saved is! Map) return null;
      final current = await _decodeCache(saved['current'], isUsable);
      final previous = await _decodeCache(saved['previous'], isUsable);
      return _newerResult(previous, current);
    } catch (_) {
      return null;
    }
  }

  Future<List<ConfigSource>> _sourcesWithLastSuccessFirst() async {
    String? preferred;
    try {
      final prefs = await SharedPreferences.getInstance();
      preferred = prefs.getString(_lastSuccessfulSourceKey);
    } catch (_) {}
    if (preferred == null || preferred.isEmpty) {
      return List<ConfigSource>.from(_configSources);
    }
    final ordered = List<ConfigSource>.from(_configSources);
    final index =
        ordered.indexWhere((source) => source.sourceName == preferred);
    if (index > 0) {
      final source = ordered.removeAt(index);
      ordered.insert(0, source);
    }
    return ordered;
  }

  Future<void> _persistLastSuccessfulSource(String sourceName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSuccessfulSourceKey, sourceName);
    } catch (_) {
      // Persistence is an optimization and must never block configuration.
    }
  }

  /// 按顺序尝试所有配置源，第一个成功即返回
  ///
  /// 遍历所有源（不限于前 2 个），每个源仅尝试 1 次（不重试），
  /// 找到第一个成功的作为 primary，继续找下一个成功的作为 backup。
  /// 这样 N 个源最多 N 次请求，避免重试导致的长时间阻塞。
  Future<MultiConfigResult> fetchAllConfigs() async {
    if (_configSources.isEmpty) {
      throw Exception('没有可用的配置源，请在 config.yaml 中配置 remote_config.sources');
    }

    final empty = ConfigResult<Map<String, dynamic>>.failure('未配置', 'none');
    ConfigResult<Map<String, dynamic>>? primary;
    ConfigResult<Map<String, dynamic>>? backup;
    final errors = <String>[];

    for (final source in _configSources) {
      final result = await source.fetchConfig();
      if (result.isSuccess) {
        if (primary == null) {
          primary = result;
          _logger.info('[RemoteConfigManager] ✅ 主源成功: ${source.sourceName}');
        } else if (backup == null) {
          backup = result;
          _logger.info('[RemoteConfigManager] ✅ 备源成功: ${source.sourceName}');
          break; // 已有主+备，无需继续
        }
      } else {
        errors.add('${source.sourceName}: ${result.error}');
        _logger.warning(
            '[RemoteConfigManager] ❌ ${source.sourceName} 失败: ${result.error}');
      }
    }

    // 所有源都失败时，对第一个源做重试（兼容单源场景）
    if (primary == null && _configSources.isNotEmpty) {
      _logger.info('[RemoteConfigManager] 所有源首轮失败，重试第一个源...');
      primary = await _fetchWithRetry(_configSources.first);
    }

    if (primary == null || !primary.isSuccess) {
      _logger.warning('[RemoteConfigManager] 所有配置源均失败: $errors');
    }

    return MultiConfigResult(
        primaryResult: primary ?? empty, backupResult: backup ?? empty);
  }

  /// 获取第一个成功的配置（遍历所有源，每个源带重试）
  Future<ConfigResult<Map<String, dynamic>>> fetchConfig() async {
    if (_configSources.isEmpty) throw Exception('没有可用的配置源');
    for (final source in _configSources) {
      final result = await _fetchWithRetry(source);
      if (result.isSuccess) return result;
    }
    return ConfigResult.failure('所有配置源均失败', 'all');
  }

  /// 兼容旧接口：获取主源
  Future<ConfigResult<Map<String, dynamic>>> getRedirectConfig() async {
    if (_configSources.isEmpty) throw Exception('没有可用的配置源');
    return _fetchWithRetry(_configSources.first);
  }

  /// 兼容旧接口：获取备用源
  Future<ConfigResult<Map<String, dynamic>>> getGiteeConfig() async {
    if (_configSources.length < 2) {
      return ConfigResult.failure('无备用配置源', 'backup');
    }
    return _fetchWithRetry(_configSources[1]);
  }

  /// 按名称获取指定源
  Future<ConfigResult<Map<String, dynamic>>> fetchFromSource(
      String sourceName) async {
    final source = _configSources.firstWhere(
      (s) => s.sourceName == sourceName,
      orElse: () => throw ArgumentError('未知配置源: $sourceName'),
    );
    return _fetchWithRetry(source);
  }

  Future<ConfigResult<Map<String, dynamic>>> _fetchWithRetry(
      ConfigSource source) async {
    ConfigResult<Map<String, dynamic>>? last;
    for (int i = 0; i <= _maxRetries; i++) {
      last = await _fetchBounded(source);
      if (last.isSuccess) return last;
      if (i < _maxRetries) await Future.delayed(_retryDelay);
    }
    return last!;
  }

  void addSource(ConfigSource source) => _configSources.add(source);
  void removeSource(String name) =>
      _configSources.removeWhere((s) => s.sourceName == name);
  List<String> get sourceNames =>
      _configSources.map((s) => s.sourceName).toList();
  int get sourceCount => _configSources.length;
}
