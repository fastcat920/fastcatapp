import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/domain_status/providers/domain_status_provider.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/services/storage/xboard_storage_provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/initialization_state.dart';

// 初始化文件级日志器
const _logger = FileLogger('initialization_provider.dart');

/// XBoard 统一初始化 Provider
///
/// 封装整个初始化流程：
/// 1. 域名检查（逐个尝试）
/// 2. SDK 初始化
///
/// 提供统一的初始化入口和状态管理
class XBoardInitializationNotifier extends StateNotifier<InitializationState> {
  final Ref ref;

  /// 上次已知的域名列表，用于检测变化
  Set<String>? _lastKnownDomains;

  XBoardInitializationNotifier(this.ref) : super(const InitializationState()) {
    _logger.info('[Initialization] Provider 已创建');
    _listenForConfigChanges();
  }

  /// 监听配置变化流，域名列表变化时主动清除竞速缓存
  void _listenForConfigChanges() {
    XBoardConfig.configChangeStream.listen((_) {
      final current = XBoardConfig.allPanelUrls.toSet();
      if (_lastKnownDomains != null &&
          current.isNotEmpty &&
          _lastKnownDomains != current) {
        _logger.info('[Initialization] 配置流检测到域名变化，清除竞速缓存');
        XBoardConfig.clearRacingCache();
      }
      _lastKnownDomains = current;
    });
  }

  /// 统一初始化入口
  ///
  /// 执行完整的初始化流程，包括：
  /// - 域名检查（逐个尝试）
  /// - SDK 初始化
  ///
  /// 如果已经初始化完成，会直接返回（幂等性）
  Future<void> initialize() async {
    // 如果已经就绪，跳过初始化
    if (state.isReady) {
      _logger.info('[Initialization] ✅ 已初始化，跳过重复执行');
      return;
    }

    // 如果正在初始化，避免重复触发
    if (state.isInitializing) {
      _logger.info('[Initialization] ⏳ 正在初始化中，跳过重复触发');
      return;
    }

    try {
      _logger.info('[Initialization] 🚀 开始初始化流程');

      // ========== 步骤 0: 加载远程配置（限时 20 秒） ==========
      // 重试时也重新拉取，确保能获取到最新配置
      _logger.info(
          '[Initialization] 当前面板URL数: ${XBoardConfig.allPanelUrls.length}');
      state = state.copyWith(currentStepDescription: '正在获取配置...');

      // 快照当前域名列表，用于变化检测
      final previousDomains = XBoardConfig.allPanelUrls.toSet();

      try {
        await XBoardConfig.refresh().timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            _logger.warning('[Initialization] 配置加载超时（20s）');
          },
        );
        _logger.info(
            '[Initialization] 远程配置加载完成，面板数: ${XBoardConfig.allPanelUrls.length}');
      } catch (e) {
        _logger.warning('[Initialization] 配置模块刷新失败: $e');
      }

      // 域名变化检测：OSS 返回的域名列表和之前不同 → 清竞速缓存
      final currentDomains = XBoardConfig.allPanelUrls.toSet();
      if (previousDomains.isNotEmpty &&
          currentDomains.isNotEmpty &&
          previousDomains != currentDomains) {
        _logger.info(
            '[Initialization] 域名列表已变化 (${previousDomains.length}→${currentDomains.length})，清除竞速缓存');
        await XBoardConfig.clearRacingCache();
      }
      _lastKnownDomains = currentDomains;

      // Fallback: 配置模块失败且面板列表仍为空时，直连 OSS（限时 15 秒）
      if (XBoardConfig.allPanelUrls.isEmpty) {
        _logger.info('[Initialization] 🔄 启动直连 OSS fallback...');
        try {
          await _directFetchOssConfig().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              _logger.warning('[Initialization] 直连 OSS 超时（15s）');
            },
          );
        } catch (e) {
          _logger.warning('[Initialization] 直连 OSS 失败: $e');
        }
      }

      // Fallback 第三层：远程+直连都失败时，尝试使用上次成功缓存启动
      if (XBoardConfig.allPanelUrls.isEmpty) {
        _logger.info('[Initialization] 🧰 尝试使用启动缓存...');
        final cachedOk = await _tryBootstrapFromCachedEndpoint();
        if (cachedOk) {
          _logger.info('[Initialization] ✅ 启动缓存注入成功');
        } else {
          _logger.warning('[Initialization] 启动缓存不可用');
        }
      }

      // ========== 步骤 1: 加载缓存的成功网关 URL（冷启动优先） ==========
      try {
        final cached = await XBoardConfig.getCachedGatewayUrl();
        if (cached != null && cached.isNotEmpty) {
          setCachedGatewayUrl(cached);
          _logger.info('[Initialization] 加载缓存网关 URL: $cached');
        }
      } catch (e) {
        _logger.warning('[Initialization] 读取网关缓存失败: $e');
      }

      // ========== 步骤 1.5: 启动网关运行时配置 ==========
      final gatewayRuntime = GatewayRuntimeService.instance;
      await gatewayRuntime.bootstrapFromCurrentConfig();
      await gatewayRuntime.verifyAndActivateBestCandidate(
        userAgent: globalState.ua,
        preferCurrent: true,
      );

      // ========== 步骤 2: 选择可用域名（逐个尝试，不竞速） ==========
      final gatewayUrls = allGatewayUrls;
      final panelUrls = gatewayUrls.isNotEmpty
          ? gatewayUrls
          : XBoardConfig.allPanelUrls;
      if (panelUrls.isEmpty) {
        const msg = '无法连接服务器，请检查网络后重试';
        await _writeDiagnosticFile(msg);
        state = state.copyWith(
          status: InitializationStatus.failed,
          errorMessage: msg,
          currentStepDescription: '初始化失败',
        );
        return;
      }

      _logger.info('[Initialization] 📡 步骤 1/2: 尝试域名 (共${panelUrls.length}个)');
      state = state.copyWith(
        status: InitializationStatus.checkingDomain,
        errorMessage: null,
        currentStepDescription: '正在连接服务器...',
      );

      // 并发探测所有域名，第一个成功的立即返回
      final apiPrefix = XBoardConfig.provider.getApiPrefix();
      String? usableDomain;
      usableDomain = await _probeDomains(panelUrls, apiPrefix);

      // 所有域名都不可达 → 直接用第一个（让后续 API 调用自然报错）
      usableDomain ??= panelUrls.first;
      _logger.info('[Initialization] 使用域名: $usableDomain');

      // 通知域名状态 provider
      ref.read(domainStatusProvider.notifier).setDomain(usableDomain);

      // ========== 步骤 2: 初始化 SDK ==========
      _logger.info('[Initialization] 🔧 步骤 2/2: 初始化 SDK');
      state = state.copyWith(
        status: InitializationStatus.initializingSDK,
        currentDomain: usableDomain,
        currentStepDescription: '正在初始化...',
      );

      // 等待 SDK 初始化完成
      await ref.read(xboardSdkProvider.future);

      _logger.info('[Initialization] ✅ SDK 初始化完成');

      // 记录最后一次成功可用的 API 地址，用于下次离线兜底启动
      await _saveUsableEndpointCache(usableDomain);

      // ========== 完成 ==========
      _logger.info('[Initialization] 🎉 初始化流程完成');
      state = state.copyWith(
        status: InitializationStatus.ready,
        lastChecked: DateTime.now(),
        currentStepDescription: '初始化完成',
        errorMessage: null,
      );
    } catch (e, stackTrace) {
      _logger.error('[Initialization] ❌ 初始化失败', e, stackTrace);

      final errMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      await _writeDiagnosticFile('$errMsg\n堆栈: $stackTrace');
      state = state.copyWith(
        status: InitializationStatus.failed,
        errorMessage: errMsg,
        currentStepDescription: '初始化失败',
      );

      rethrow;
    }
  }

  /// 刷新（重新初始化）
  ///
  /// 重置状态并重新执行完整的初始化流程
  Future<void> refresh() async {
    _logger.info('[Initialization] 🔄 刷新初始化状态');

    // 重置状态
    state = const InitializationState();

    // xboardSdkProvider 是 keepAlive:true，失败状态会被 Riverpod 永久缓存。
    // 重试前必须先使其失效，否则 initialize() 步骤2仍会读到缓存的失败结果。
    ref.invalidate(xboardSdkProvider);
    _logger.info('[Initialization] 🗑️ 已清除 xboardSdkProvider 缓存');

    // 重新初始化
    await initialize();
  }

  /// 重置为初始状态
  void reset() {
    _logger.info('[Initialization] 🔄 重置初始化状态');
    state = const InitializationState();
  }

  /// 并发探测域名，返回第一个可达的域名（超时 5 秒）
  Future<String?> _probeDomains(
      List<String> panelUrls, String apiPrefix) async {
    final prefix =
        apiPrefix.startsWith('/') ? apiPrefix.substring(1) : apiPrefix;
    final completer = Completer<String?>();
    var failCount = 0;

    for (final domain in panelUrls) {
      _probeSingleDomain(domain, prefix).then((ok) {
        if (ok && !completer.isCompleted) {
          completer.complete(domain);
        } else {
          failCount++;
          if (failCount == panelUrls.length && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      });
    }

    // 总超时兜底
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  }

  Future<bool> _probeSingleDomain(String domain, String prefix) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 4);
      client.badCertificateCallback = (cert, host, port) => true;
      final testUrl = domain.endsWith('/')
          ? '$domain$prefix/guest/comm/config'
          : '$domain/$prefix/guest/comm/config';
      final request = await client.getUrl(Uri.parse(testUrl));
      request.headers.set(HttpHeaders.userAgentHeader, globalState.ua);
      final response =
          await request.close().timeout(const Duration(seconds: 4));
      await response.drain<void>();
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        _logger.info(
            '[Initialization] ✅ 域名可用: $domain (HTTP $statusCode)');
        return true;
      }
      _logger.warning(
          '[Initialization] ❌ 域名不可用: $domain (HTTP $statusCode)');
      return false;
    } catch (e) {
      _logger.warning('[Initialization] ❌ 域名不可用: $domain ($e)');
      return false;
    } finally {
      client?.close();
    }
  }

  Future<void> _saveUsableEndpointCache(String usableDomain) async {
    final apiPrefix = XBoardConfig.provider.getApiPrefix();
    final panelType = XBoardConfig.provider.getPanelType();
    final storage = ref.read(storageServiceProvider);
    final saveResult = await storage.saveCachedApiEndpoint(
      baseUrl: usableDomain,
      apiPrefix: apiPrefix,
      panelType: panelType,
      sourceTag: 'startup_success',
    );
    if (saveResult.dataOrNull == true) {
      _logger.info(
          '[Initialization] 已写入 API 启动缓存: $usableDomain ($panelType$apiPrefix)');
    } else {
      _logger.warning('[Initialization] 写入 API 启动缓存失败');
    }
  }

  Future<bool> _tryBootstrapFromCachedEndpoint() async {
    final enabled = await ConfigFileLoaderHelper.getStartupCacheEnabled();
    if (!enabled) {
      _logger.info('[Initialization] startup_cache.enabled=false，跳过缓存启动');
      return false;
    }

    final storage = ref.read(storageServiceProvider);
    final cachedResult = await storage.getCachedApiEndpoint();
    final cached = cachedResult.dataOrNull;
    if (cached == null) {
      _logger.info('[Initialization] 未找到 API 启动缓存');
      return false;
    }

    final baseUrl = (cached['base_url'] as String? ?? '').trim();
    final apiPrefix = (cached['api_prefix'] as String? ?? '/api/v1').trim();
    final panelType = (cached['panel_type'] as String? ?? 'xboard').trim();
    final updatedAtRaw = (cached['updated_at'] as String? ?? '').trim();
    final updatedAt = DateTime.tryParse(updatedAtRaw);
    final ttlHours = await ConfigFileLoaderHelper.getStartupCacheTtlHours();
    if (updatedAt == null ||
        DateTime.now().difference(updatedAt) > Duration(hours: ttlHours)) {
      _logger.warning('[Initialization] API 启动缓存已过期，清理缓存');
      await storage.clearCachedApiEndpoint();
      return false;
    }

    if (baseUrl.isEmpty) {
      _logger.warning('[Initialization] API 启动缓存缺少 base_url');
      return false;
    }

    final probeTimeoutMs =
        await ConfigFileLoaderHelper.getStartupCacheProbeTimeoutMs();
    final prefix =
        apiPrefix.startsWith('/') ? apiPrefix.substring(1) : apiPrefix;
    final reachable = await _probeSingleDomainWithTimeout(
      baseUrl,
      prefix,
      Duration(milliseconds: probeTimeoutMs),
    );
    if (!reachable) {
      _logger.warning('[Initialization] API 启动缓存探测失败，跳过缓存启动');
      return false;
    }

    final normalized = <String, dynamic>{
      'panelType': panelType,
      'api_prefix': apiPrefix,
      'panels': {
        panelType: [
          {'url': baseUrl, 'description': baseUrl}
        ],
      },
    };
    await XBoardConfig.loadParsedConfig(normalized, source: 'cached_startup');
    return XBoardConfig.allPanelUrls.isNotEmpty;
  }

  Future<bool> _probeSingleDomainWithTimeout(
    String domain,
    String prefix,
    Duration timeout,
  ) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = timeout;
      client.badCertificateCallback = (_, __, ___) => true;
      final testUrl = domain.endsWith('/')
          ? '$domain$prefix/guest/comm/config'
          : '$domain/$prefix/guest/comm/config';
      final request = await client.getUrl(Uri.parse(testUrl));
      request.headers.set(HttpHeaders.userAgentHeader, globalState.ua);
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      final statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        _logger.info('[Initialization] 缓存域名探测成功: $domain (HTTP $statusCode)');
        return true;
      }
      _logger.warning('[Initialization] 缓存域名探测失败: $domain (HTTP $statusCode)');
      return false;
    } catch (e) {
      _logger.warning('[Initialization] 缓存域名探测失败: $domain ($e)');
      return false;
    } finally {
      client?.close();
    }
  }

  /// 直连 OSS 获取配置（绕过配置模块，作为 fallback）
  Future<void> _directFetchOssConfig() async {
    const ossUrl1 = String.fromEnvironment('OSS_URL_1');
    const ossUrl2 = String.fromEnvironment('OSS_URL_2');
    const xorKey = String.fromEnvironment('XOR_KEY',
        defaultValue: 'CHANGE_ME_TO_YOUR_SECRET_KEY_32C');

    const isDefaultKey = xorKey == 'CHANGE_ME_TO_YOUR_SECRET_KEY_32C';
    _logger.info(
        '[Fallback] XOR_KEY: ${isDefaultKey ? "⚠️ 默认占位符（CI未注入）" : "✅ 已注入(${xorKey.length}字符)"}');

    final urls = [ossUrl1, ossUrl2].where((u) => u.isNotEmpty).toList();
    if (urls.isEmpty) {
      _logger.warning('[Fallback] 无 OSS URL（dart-define 未注入 OSS_URL_1/2）');
      return;
    }
    _logger.info('[Fallback] OSS URLs: ${urls.length} 个');

    for (final url in urls) {
      HttpClient? client;
      try {
        final maskedUrl = Uri.tryParse(url)?.host ??
            url.substring(0, url.length.clamp(0, 20));
        _logger.info('[Fallback] 直连: $maskedUrl');
        client = HttpClient();
        client.findProxy = (_) => 'DIRECT';
        client.badCertificateCallback = (_, __, ___) => true;
        client.connectionTimeout = const Duration(seconds: 15);

        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) {
          _logger.warning('[Fallback] HTTP ${response.statusCode}');
          continue;
        }
        final body = await response.transform(utf8.decoder).join();
        if (body.trim().isEmpty) continue;

        // 解密
        String decrypted;
        try {
          json.decode(body.trim());
          decrypted = body.trim(); // 明文 JSON
        } catch (_) {
          // XOR+Base64
          final keyBytes = utf8.encode(xorKey);
          final encBytes = base64.decode(body.trim());
          final decBytes = Uint8List(encBytes.length);
          for (var i = 0; i < encBytes.length; i++) {
            decBytes[i] = encBytes[i] ^ keyBytes[i % keyBytes.length];
          }
          decrypted = utf8.decode(decBytes);
        }

        final configJson = json.decode(decrypted) as Map<String, dynamic>;
        _logger.info('[Fallback] 解密成功: ${configJson.keys}');

        // 归一化为内部 panels 格式（和 configuration_parser 一致）
        Map<String, dynamic> normalized;
        if (configJson.containsKey('domains')) {
          final domains = configJson['domains'] as List<dynamic>? ?? [];
          final pt = (configJson['panel_type'] as String?)?.isNotEmpty == true
              ? configJson['panel_type'] as String
              : 'xboard';
          normalized = <String, dynamic>{
            'panelType': pt,
            'panels': {
              pt: domains
                  .map(
                      (d) => {'url': d.toString(), 'description': d.toString()})
                  .toList(),
            },
          };
          // 保留其他字段
          for (final key in [
            'contact',
            'features',
            'announcement',
            'update',
            'subscription',
            'api_prefix',
            'gateway_urls',
            'gateway_url',
            'ticket'
          ]) {
            if (configJson.containsKey(key)) normalized[key] = configJson[key];
          }
        } else {
          normalized = configJson;
        }

        await XBoardConfig.loadParsedConfig(normalized);
        _logger.info(
            '[Fallback] ✅ 成功注入面板URL: ${XBoardConfig.allPanelUrls.length}');
        return;
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('FormatException') || errStr.contains('decode')) {
          _logger.error('[Fallback] $url 解密/解析失败（密钥不匹配或OSS文件内容异常）: $e');
        } else {
          _logger.warning('[Fallback] $url 网络请求失败: $e');
        }
      } finally {
        client?.close();
      }
    }
    _logger.warning(
        '[Fallback] 所有 OSS URL 均失败（请检查：1.OSS文件是否已上传 2.XOR密钥是否与加密时一致 3.OSS地址是否可访问）');
  }

  /// 写诊断文件到应用数据目录（release 版无法看 console，用文件排查）
  Future<void> _writeDiagnosticFile(String errorMsg) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final file = File(p.join(appDir.path, 'xboard_diagnostic.log'));
      final buf = StringBuffer();
      buf.writeln('=== XBoard 诊断日志 ===');
      buf.writeln('时间: ${DateTime.now()}');
      buf.writeln('错误: $errorMsg');
      buf.writeln('');

      // dart-define 检查
      const ossUrl1 = String.fromEnvironment('OSS_URL_1');
      const ossUrl2 = String.fromEnvironment('OSS_URL_2');
      const xorKey = String.fromEnvironment('XOR_KEY',
          defaultValue: 'CHANGE_ME_TO_YOUR_SECRET_KEY_32C');
      const panelType = String.fromEnvironment('PANEL_TYPE');
      buf.writeln('[dart-define]');
      buf.writeln('  OSS_URL_1: ${ossUrl1.isEmpty ? "(空)" : ossUrl1}');
      buf.writeln('  OSS_URL_2: ${ossUrl2.isEmpty ? "(空)" : ossUrl2}');
      buf.writeln(
          '  XOR_KEY: ${xorKey == "CHANGE_ME_TO_YOUR_SECRET_KEY_32C" ? "⚠️ 默认占位符(未注入)" : "已注入(${xorKey.length}字符)"}');
      buf.writeln('  PANEL_TYPE: ${panelType.isEmpty ? "(空)" : panelType}');
      buf.writeln('');

      // 配置模块状态
      buf.writeln('[XBoardConfig]');
      buf.writeln('  state: ${XBoardConfig.state}');
      buf.writeln('  lastError: ${XBoardConfig.lastError ?? "(无)"}');
      buf.writeln('');

      // 面板URL
      final panelUrls = XBoardConfig.allPanelUrls;
      buf.writeln('[面板URL] 数量: ${panelUrls.length}');
      for (final url in panelUrls) {
        buf.writeln('  - $url');
      }
      buf.writeln('');

      // 实际网络请求测试
      if (ossUrl1.isNotEmpty) {
        buf.writeln('[网络诊断] 尝试直连 OSS...');
        HttpClient? client;
        try {
          client = HttpClient();
          client.findProxy = (_) => 'DIRECT';
          client.badCertificateCallback = (_, __, ___) => true;
          client.connectionTimeout = const Duration(seconds: 10);
          final request = await client.getUrl(Uri.parse(ossUrl1));
          final response = await request.close();
          final body = await response.transform(utf8.decoder).join();
          buf.writeln('  HTTP 状态码: ${response.statusCode}');
          buf.writeln('  响应长度: ${body.length} 字符');
          buf.writeln(
              '  前50字符: ${body.length > 50 ? body.substring(0, 50) : body}');

          // 尝试解密
          if (response.statusCode == 200 && body.isNotEmpty) {
            try {
              json.decode(body.trim());
              buf.writeln('  内容类型: 明文JSON');
            } catch (_) {
              // 尝试 XOR 解密
              try {
                final keyBytes = xorKey.codeUnits;
                final encrypted = base64.decode(body.trim());
                final decrypted = List<int>.generate(encrypted.length,
                    (i) => encrypted[i] ^ keyBytes[i % keyBytes.length]);
                final result = String.fromCharCodes(decrypted);
                final parsed = json.decode(result);
                buf.writeln('  内容类型: XOR+Base64 加密');
                buf.writeln('  解密: 成功');
                buf.writeln('  domains: ${parsed['domains']}');
              } catch (decErr) {
                buf.writeln('  内容类型: XOR+Base64 加密');
                buf.writeln('  解密: 失败 — $decErr');
              }
            }
          }
        } catch (netErr) {
          buf.writeln('  请求失败: $netErr');
        } finally {
          client?.close();
        }
      }
      buf.writeln('');
      buf.writeln('=== 诊断结束 ===');

      file.writeAsStringSync(buf.toString());
      _logger.info('[Initialization] 诊断文件已写入: ${file.path}');
    } catch (e) {
      _logger.warning('[Initialization] 写诊断文件失败: $e');
    }
  }
}

/// XBoard 统一初始化 Provider
final initializationProvider =
    StateNotifierProvider<XBoardInitializationNotifier, InitializationState>(
  (ref) => XBoardInitializationNotifier(ref),
);

/// 便捷 Provider: 是否已初始化
final isInitializedProvider = Provider<bool>((ref) {
  return ref.watch(initializationProvider).isReady;
});

/// 便捷 Provider: 是否正在初始化
final isInitializingProvider = Provider<bool>((ref) {
  return ref.watch(initializationProvider).isInitializing;
});

/// 便捷 Provider: 初始化进度百分比
final initializationProgressProvider = Provider<int>((ref) {
  return ref.watch(initializationProvider).progressPercentage;
});
