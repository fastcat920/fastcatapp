import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../core/core.dart';

const _logger = FileLogger('website_url_resolver.dart');

/// 官网 URL 解析器
///
/// 按优先级收集候选 URL，逐个探测连通性，打开第一个可达的。
class WebsiteUrlResolver {
  /// 探测单个 URL 是否可达
  ///
  /// 发送 GET 请求，连接超时 3 秒，总超时 5 秒。
  /// 返回 <500 的 HTTP 状态码视为可达。
  static Future<bool> isReachable(String url) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 3);
      client.badCertificateCallback = (_, __, ___) => true;

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'FastCat/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      await response.drain<void>();
      return response.statusCode < 500;
    } catch (e) {
      _logger.info('[isReachable] $url 不可达: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  /// 按优先级探测候选 URL，打开第一个可达的
  ///
  /// [primaryUrls] 远程 OSS 配置的候选列表（优先级最高，逐个探测）
  /// [fallbackLocalUrl] 本地 config.yaml 兜底
  /// [fallbackApiUrl] 面板 API 兜底
  ///
  /// 返回 true 表示成功打开，false 表示所有候选均不可达。
  static Future<bool> openWithFallback({
    required List<String> primaryUrls,
    required Future<String> Function() fallbackLocalUrl,
    required Future<String> Function() fallbackApiUrl,
  }) async {
    // 1. 收集所有非空候选 URL（去重，保持优先级）
    final candidates = <String>[];

    for (final url in primaryUrls) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty && !candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }
    }

    // 2. 收集本地兜底
    final localUrl = (await fallbackLocalUrl()).trim();
    if (localUrl.isNotEmpty && !candidates.contains(localUrl)) {
      candidates.add(localUrl);
    }

    // 3. 收集面板 API 兜底
    final apiUrl = (await fallbackApiUrl()).trim();
    if (apiUrl.isNotEmpty && !candidates.contains(apiUrl)) {
      candidates.add(apiUrl);
    }

    if (candidates.isEmpty) return false;

    // 4. 逐个探测，打开第一个可达的
    for (final url in candidates) {
      if (await isReachable(url)) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      }
    }

    return false;
  }
}
