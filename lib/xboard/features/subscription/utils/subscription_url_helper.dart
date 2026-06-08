/// 订阅URL辅助工具
/// 
/// 用于解析和处理订阅URL，提取token等信息
class SubscriptionUrlHelper {
  static bool _initialized = false;

  /// 初始化URL辅助工具
  /// 
  /// 执行必要的初始化操作
  static void initialize() {
    if (_initialized) return;
    _initialized = true;
  }

  /// 从订阅URL中提取token
  /// 
  /// 支持多种URL格式：
  /// - https://domain.com/api/v1/client/subscribe?token=xxx
  /// - https://domain.com/api/v2/subscription-encrypt/xxx
  /// - https://domain.com/subscription/xxx
  static String? extractTokenFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // 方式1: 查询参数中的token
      if (uri.queryParameters.containsKey('token')) {
        return uri.queryParameters['token'];
      }
      
      // 方式2: 路径中的最后一段作为token
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        // 验证是否像token（一般是32位或更长的十六进制字符串）
        if (lastSegment.length >= 16 && RegExp(r'^[a-f0-9]+$').hasMatch(lastSegment)) {
          return lastSegment;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查URL是否为加密订阅URL
  /// 
  /// 通过路径中是否包含 encrypt 关键字判断
  static bool isEncryptedSubscriptionUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      
      return path.contains('encrypt');
    } catch (e) {
      return false;
    }
  }

  /// 判断URL是否需要使用加密订阅服务
  ///
  /// 只有路径中明确包含 "encrypt" 关键字才走加密路径。
  /// 注意：不能用"能提取到 token"来判断，因为 v2board 和 XBoard 的普通订阅链接
  /// 都带有 ?token=xxx 参数，误判为加密路径会导致 v2board 订阅加载失败。
  static bool shouldUseEncryptedService(String url) {
    return isEncryptedSubscriptionUrl(url);
  }

  /// 确保订阅 URL 包含 flag=meta 参数，强制后端返回 ClashMeta 格式。
  ///
  /// Xboard/v2board 后端优先读取 flag 查询参数（而非 UA）来决定下发格式，
  /// 这样无论用户自定义什么 UA 都不影响节点正常获取。
  /// 如果 URL 已有 flag 参数则不覆盖。
  static String ensureMetaFlag(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.containsKey('flag')) return url;
      return uri.replace(queryParameters: {
        ...uri.queryParameters,
        'flag': 'meta',
      }).toString();
    } catch (_) {
      return url;
    }
  }
}