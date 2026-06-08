import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/infrastructure/http/user_agent_config.dart';
import 'package:fl_clash/xboard/features/subscription/utils/subscription_url_helper.dart';
import 'package:socks5_proxy/socks_client.dart';

// 初始化文件级日志器
final _logger = FileLogger('subscription_downloader.dart');

/// XBoard 订阅下载服务（直连）
class SubscriptionDownloader {
  static const Duration _downloadTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// 下载订阅并返回 Profile
  static Future<Profile> downloadSubscription(String url) async {
    final sw = Stopwatch()..start();
    try {
      _logger.info('📥 开始下载订阅: $url');

      final _DownloadResult result;

      // 直连下载
      _logger.info('🌐 发起直连 HTTP 请求...');
      result = await _downloadWithMethod(
        url,
        useProxy: false,
        cancelToken: _CancelToken(),
        taskIndex: 0,
      );
      _logger.info('✅ HTTP 下载完成，耗时 ${sw.elapsedMilliseconds}ms，大小 ${result.bytes.length} bytes');
      
      // 直接写文件，跳过 saveFileWithString 内部的 validateConfig IPC 调用。
      // 桌面端 ClashCore.exe 进程未就绪时 validateConfig 默认等 30s，是导入卡死的根因。
      // 配置格式合法性由 applyProfile → setupConfig 阶段的 ClashCore 权威验证。
      _logger.info('💾 写入配置文件（跳过 validateConfig IPC）...');
      
      // 🔍 诊断：检查下载的配置内容是否为有效的 Clash YAML 格式
      final contentLines = result.content.split('\n');
      final hasProxies = result.content.contains('proxies:');
      final hasProxyGroups = result.content.contains('proxy-groups:');
      _logger.info('🔍 配置内容诊断: 总行数=${contentLines.length}, hasProxies=$hasProxies, hasProxyGroups=$hasProxyGroups');
      
      // 检测服务端是否返回了非 YAML 格式（如 Base64 编码的通用订阅）
      // 这通常是因为服务端未识别到客户端的 User-Agent 中的 Clash Meta 标识，
      // 从而使用了通用协议（返回 ss://、trojan:// 等 URI 的 Base64 编码）。
      if (!hasProxies && !hasProxyGroups) {
        final trimmedContent = result.content.trim();
        final isLikelyBase64 = !trimmedContent.contains(':') || 
            RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(trimmedContent);
        final isLikelyUriList = trimmedContent.contains('ss://') || 
            trimmedContent.contains('trojan://') ||
            trimmedContent.contains('vmess://') ||
            trimmedContent.contains('vless://');
        
        if (isLikelyBase64 || isLikelyUriList) {
          _logger.error('❌ 服务端返回了通用订阅格式（Base64/URI列表），而非 Clash YAML 配置！');
          _logger.error('   这通常是因为服务端未识别客户端 UA 中的 meta/flclash 标识。');
          _logger.error('   当前 UA: ${await UserAgentConfig.get(UserAgentScenario.subscription)}');
          _logger.error('   前200字符: ${trimmedContent.substring(0, trimmedContent.length > 200 ? 200 : trimmedContent.length)}');
          throw Exception(
            '订阅格式错误：服务端返回了通用订阅格式，而非 Clash Meta 配置。\n'
            '请检查：\n'
            '1. 服务端是否支持 Clash Meta 订阅格式\n'
            '2. 订阅链接是否正确（可尝试在 URL 后加 &flag=meta）'
          );
        }
        
        _logger.error('⚠️ 警告: 下载的配置文件中没有找到 proxies 字段！前100字符: ${result.content.substring(0, result.content.length > 100 ? 100 : result.content.length)}');
      }
      
      final profile = Profile.normal(url: url);
      final profileFile = await profile.getFile();
      await profileFile.writeAsString(result.content);
      final savedProfile = profile.copyWith(lastUpdateDate: DateTime.now());
      _logger.info('✅ 配置文件写入完成，总耗时 ${sw.elapsedMilliseconds}ms');
      
      // 更新订阅信息
      final finalProfile = savedProfile.copyWith(
        label: result.label ?? savedProfile.id,
        subscriptionInfo: result.subscriptionInfo,
        lastUpdateDate: DateTime.now(),
      );
      
      _logger.info('✅ 订阅下载成功: ${finalProfile.label}');
      return finalProfile;
      
    } on TimeoutException catch (e) {
      _logger.error('订阅下载超时', e);
      throw Exception('下载超时: ${e.message}');
    } on SocketException catch (e) {
      _logger.error('网络连接失败', e);
      throw Exception('网络连接失败: ${e.message}');
    } on HttpException catch (e) {
      _logger.error('HTTP请求失败', e);
      throw Exception('HTTP请求失败: ${e.message}');
    } catch (e) {
      _logger.error('订阅下载失败', e);
      rethrow;
    }
  }
  
  /// 使用指定方式下载完整订阅内容（含自动重试）
  ///
  /// 登录后立即下载订阅时，后端可能因会话同步延迟或速率限制返回 HTTP 4xx/5xx，
  /// 短暂等待后重试通常能成功。最多重试 [_maxRetries] 次，每次间隔 [_retryDelay]。
  static Future<_DownloadResult> _downloadWithMethod(
    String url, {
    required bool useProxy,
    String? proxyUrl,
    required _CancelToken cancelToken,
    required int taskIndex,
  }) async {
    final connectionType = useProxy ? '代理($proxyUrl)' : '直连';
    _logger.info('[任务$taskIndex] 开始下载: $connectionType');

    Object? lastError;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final result = await _downloadWithProxy(
          url,
          useProxy: useProxy,
          proxyUrl: proxyUrl,
          cancelToken: cancelToken,
        );

        _logger.info('[任务$taskIndex] 下载成功: $connectionType，大小: ${result.bytes.length} bytes');

        return _DownloadResult(
          content: result.content,
          connectionType: connectionType,
          label: result.label,
          subscriptionInfo: result.subscriptionInfo,
          bytes: result.bytes,
        );

      } catch (e) {
        lastError = e;
        if (cancelToken.isCancelled) {
          _logger.info('[任务$taskIndex] 已取消: $connectionType');
          rethrow;
        }

        // 仅对 HTTP 错误和网络错误重试，格式/解析错误不重试
        final isRetryable = e is HttpException || e is SocketException || e is TimeoutException;
        if (!isRetryable || attempt == _maxRetries) {
          _logger.warning('[任务$taskIndex] 下载失败(第$attempt次，不再重试): $connectionType - $e');
          rethrow;
        }

        _logger.warning('[任务$taskIndex] 下载失败(第$attempt/$_maxRetries次，${_retryDelay.inSeconds}s后重试): $connectionType - $e');
        await Future.delayed(_retryDelay);
      }
    }
    // 理论上不会到这里，但为了类型安全
    throw lastError ?? Exception('下载失败');
  }
  
  /// 使用代理下载订阅内容
  static Future<_DownloadRawResult> _downloadWithProxy(
    String url, {
    required bool useProxy,
    String? proxyUrl,
    required _CancelToken cancelToken,
  }) async {
    HttpClient? client;
    
    try {
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        throw Exception('任务已取消');
      }
      
      // 创建 HttpClient（绕过 FastcatHttpOverrides，订阅下载不走本地 Clash 代理）
      client = HttpClient();
      client.connectionTimeout = _downloadTimeout;
      client.badCertificateCallback = (cert, host, port) => true;
      client.findProxy = (_) => 'DIRECT';
      
      // 如果使用代理，配置 SOCKS5 代理
      if (useProxy && proxyUrl != null) {
        final proxyConfig = _parseProxyConfig(proxyUrl);
        final proxySettings = ProxySettings(
          InternetAddress(proxyConfig['host']!),
          int.parse(proxyConfig['port']!),
          username: proxyConfig['username'],
          password: proxyConfig['password'],
        );
        
        SocksTCPClient.assignToHttpClient(client, [proxySettings]);
      }
      
      // 发起请求（追加 flag=meta 确保后端返回 ClashMeta 格式）
      final uri = Uri.parse(SubscriptionUrlHelper.ensureMetaFlag(url));
      final request = await client.getUrl(uri);
      
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }
      
      // 设置请求头
      final userAgent = await UserAgentConfig.get(UserAgentScenario.subscription);
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }
      
      // 获取响应
      final response = await request.close().timeout(
        _downloadTimeout,
        onTimeout: () {
          throw TimeoutException('下载超时', _downloadTimeout);
        },
      );
      
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }
      
      // 读取响应内容（加超时，防止服务端发完 header 后卡住 body 读取永久挂死）
      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) {
          if (cancelToken.isCancelled) {
            throw Exception('任务已取消');
          }
          return previous..addAll(element);
        },
      ).timeout(
        _downloadTimeout,
        onTimeout: () => throw TimeoutException('读取订阅内容超时', _downloadTimeout),
      );
      final content = utf8.decode(bytes);
      
      // 解析响应头
      final disposition = response.headers.value('content-disposition');
      final userinfo = response.headers.value('subscription-userinfo');
      
      String? label;
      if (disposition != null) {
        // 从 content-disposition 提取文件名
        final match = RegExp(r'filename="?([^";\n]+)"?').firstMatch(disposition);
        if (match != null) {
          label = match.group(1)?.trim();
        }
      }
      
      final subscriptionInfo = userinfo != null 
          ? SubscriptionInfo.formHString(userinfo) 
          : null;
      
      return _DownloadRawResult(
        content: content,
        label: label,
        subscriptionInfo: subscriptionInfo,
        bytes: bytes,
      );
      
    } finally {
      if (cancelToken.isCancelled) {
        client?.close(force: true);
      } else {
        client?.close();
      }
    }
  }
  
  /// 解析代理配置
  ///
  /// 输入格式:
  /// - `socks5://user:pass@host:port`
  /// - `socks5://host:port`
  /// - `http://user:pass@host:port`
  ///
  /// 返回: { host, port, username?, password? }
  static Map<String, String?> _parseProxyConfig(String proxyUrl) {
    String url = proxyUrl.trim();

    // 去除协议前缀
    if (url.toLowerCase().startsWith('socks5://')) {
      url = url.substring(9);
    } else if (url.toLowerCase().startsWith('http://')) {
      url = url.substring(7);
    } else if (url.toLowerCase().startsWith('https://')) {
      url = url.substring(8);
    }

    String? username;
    String? password;
    String hostPort = url;

    // 解析认证信息 user:pass@host:port
    if (url.contains('@')) {
      final atIndex = url.lastIndexOf('@');
      final authPart = url.substring(0, atIndex);
      hostPort = url.substring(atIndex + 1);

      if (authPart.contains(':')) {
        final colonIndex = authPart.indexOf(':');
        username = authPart.substring(0, colonIndex);
        password = authPart.substring(colonIndex + 1);
      }
    }

    // 解析 host:port
    final colonIndex = hostPort.lastIndexOf(':');
    if (colonIndex == -1) {
      throw FormatException('代理配置格式错误，缺少端口号: $proxyUrl');
    }

    final host = hostPort.substring(0, colonIndex);
    final port = hostPort.substring(colonIndex + 1);

    if (host.isEmpty || port.isEmpty) {
      throw FormatException('代理配置格式错误: $proxyUrl');
    }

    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }
}

/// 取消令牌
class _CancelToken {
  bool _isCancelled = false;
  
  bool get isCancelled => _isCancelled;
  
  void cancel() {
    _isCancelled = true;
  }
}

/// 下载结果（含连接类型）
class _DownloadResult {
  final String content;
  final String connectionType;
  final String? label;
  final SubscriptionInfo? subscriptionInfo;
  final List<int> bytes;
  
  _DownloadResult({
    required this.content,
    required this.connectionType,
    this.label,
    this.subscriptionInfo,
    required this.bytes,
  });
}

/// 下载原始结果
class _DownloadRawResult {
  final String content;
  final String? label;
  final SubscriptionInfo? subscriptionInfo;
  final List<int> bytes;
  
  _DownloadRawResult({
    required this.content,
    this.label,
    this.subscriptionInfo,
    required this.bytes,
  });
}
