import 'package:dio/dio.dart';
import 'token_manager.dart';
import 'auth_events.dart';
import '../logging/sdk_logger.dart';

/// 认证拦截器（简化版）
/// 自动为HTTP请求添加token，不处理自动刷新和重试
class AuthInterceptor extends Interceptor {
  final TokenManager _tokenManager;
  final Set<String> _publicEndpoints;
  /// 是否在 Authorization 头中使用 Bearer 前缀。
  /// XBoard 使用 Bearer，v2board 需要裸 JWT（无前缀）。
  final bool useBearerPrefix;

  AuthInterceptor({
    required TokenManager tokenManager,
    Set<String>? publicEndpoints,
    this.useBearerPrefix = true,
  })  : _tokenManager = tokenManager,
        _publicEndpoints = publicEndpoints ?? _defaultPublicEndpoints;

  /// 默认的公开端点后缀（无需token的接口，不含 apiPrefix）
  static const Set<String> _defaultPublicEndpoints = {
    '/passport/auth/login',
    '/passport/auth/register',
    '/passport/comm/sendEmailVerify',
    '/passport/auth/forget',
    '/guest/comm/config',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // 检查是否为公开端点
      if (_isPublicEndpoint(options.path)) {
        handler.next(options);
        return;
      }

      // 获取token并添加到请求头
      // token 已按后端原值保存：新版 XBoard 含 "Bearer xxx"，老版/V2Board 是裸 JWT
      // 直接发送原值，不做前缀处理
      final token = await _tokenManager.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = token;
      }

      handler.next(options);
    } catch (e, stackTrace) {
      SdkLogger.e('[AuthInterceptor] Error in onRequest', e, stackTrace);
      handler.next(options); // 继续请求，让服务器返回401
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    // Xboard 用 403 表示 token 过期/无效，与 401 同等处理
    if (statusCode == 401 || statusCode == 403) {
      SdkLogger.w('[AuthInterceptor] $statusCode Unauthorized: ${err.requestOptions.path}');
      XBoardAuthEvents.notifyUnauthorized();
    }
    handler.next(err);
  }

  /// 检查是否为公开端点
  ///
  /// 公开端点存储的是不含 apiPrefix 的后缀路径（如 '/passport/auth/login'），
  /// 实际请求路径含前缀（如 '/api/v1/passport/auth/login'），用 endsWith 匹配。
  bool _isPublicEndpoint(String path) {
    // 去掉查询参数部分
    final pathWithoutQuery = path.contains('?') ? path.substring(0, path.indexOf('?')) : path;

    for (final endpoint in _publicEndpoints) {
      if (pathWithoutQuery.endsWith(endpoint)) {
        return true;
      }
    }

    return false;
  }

  /// 添加公开端点
  void addPublicEndpoint(String endpoint) {
    _publicEndpoints.add(endpoint);
  }

  /// 移除公开端点
  void removePublicEndpoint(String endpoint) {
    _publicEndpoints.remove(endpoint);
  }

  /// 获取所有公开端点
  Set<String> get publicEndpoints => Set.unmodifiable(_publicEndpoints);
}
