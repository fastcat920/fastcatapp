import 'dart:convert';

import 'package:dio/dio.dart';
import 'token_manager.dart';
import 'auth_events.dart';
import '../logging/sdk_logger.dart';

/// 认证拦截器（简化版）
/// 自动为HTTP请求添加token，不处理自动刷新和重试
class AuthInterceptor extends Interceptor {
  static const _sessionIdentityKey = 'xboard.auth.sessionIdentity';
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
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // These routes authenticate the QR challenge, not an account session.
      // In particular a rejected delivery ACK must not revoke a new login.
      if (_isAnonymousQrEndpoint(options)) {
        options.headers
            .removeWhere((key, _) => key.toLowerCase() == 'authorization');
        options.extra.remove(_sessionIdentityKey);
        handler.next(options);
        return;
      }
      // 检查是否为公开端点
      if (_isPublicEndpoint(options.path)) {
        handler.next(options);
        return;
      }

      // 获取token并添加到请求头
      // token 已按后端原值保存：新版 XBoard 含 "Bearer xxx"，老版/V2Board 是裸 JWT
      // 直接发送原值，不做前缀处理
      // HttpService retries/failover replay the same RequestOptions. Keep its
      // original owner: replaying an old request must never borrow a new login.
      final identity =
          options.extra[_sessionIdentityKey] ?? _tokenManager.sessionIdentity;
      if (!_tokenManager.isCurrentSession(identity)) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Authentication session changed before request dispatch',
        ));
        return;
      }
      final token = await _tokenManager.getToken();
      if (!_tokenManager.isCurrentSession(identity)) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Authentication session changed before request dispatch',
        ));
        return;
      }
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = token;
      }
      options.extra[_sessionIdentityKey] = identity;

      handler.next(options);
    } catch (e, stackTrace) {
      SdkLogger.e('[AuthInterceptor] Error in onRequest', e, stackTrace);
      handler.next(options); // 继续请求，让服务器返回401
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    // Xboard 用 403 表示 token 过期/无效，与 401 同等处理
    if ((statusCode == 401 || statusCode == 403) &&
        !_isPublicEndpoint(err.requestOptions.path) &&
        !_isAnonymousQrEndpoint(err.requestOptions) &&
        await _belongsToCurrentSession(err.requestOptions)) {
      SdkLogger.w(
          '[AuthInterceptor] $statusCode Unauthorized: ${err.requestOptions.path}');
      final responseData = _parseResponseData(err.response?.data);
      final code = responseData?['code']?.toString();
      final message = responseData?['message']?.toString();
      final reason = switch (code) {
        'DEVICE_KICKED_BY_NEW_LOGIN' =>
          AuthFailureReason.deviceKickedByNewLogin,
        'DEVICE_REVOKED' => AuthFailureReason.deviceRevoked,
        'DEVICE_SESSION_EXPIRED' => AuthFailureReason.deviceSessionExpired,
        'TOKEN_EXPIRED' => AuthFailureReason.tokenExpired,
        _ => AuthFailureReason.unauthorized,
      };
      XBoardAuthEvents.notifyUnauthorized(
        AuthFailureEvent(
          reason: reason,
          code: code,
          message: message,
          sessionIdentity: err.requestOptions.extra[_sessionIdentityKey],
        ),
      );
    }
    handler.next(err);
  }

  bool _isAnonymousQrEndpoint(RequestOptions request) {
    final path = request.path.split('?').first;
    final route =
        RegExp(r'/auth/qr/sessions(?:/([A-Za-z0-9_-]{1,128})(/ack)?)?$')
            .firstMatch(path);
    if (route == null) return false;
    final method = request.method.toUpperCase();
    if (route.group(1) == null) return method == 'POST'; // Create.
    if (route.group(2) != null) return method == 'POST'; // Delivery ACK.
    // POST /sessions/{id} is phone approval and MUST remain authenticated.
    return method == 'GET' || method == 'DELETE';
  }

  Future<bool> _belongsToCurrentSession(RequestOptions request) async {
    final identity = request.extra[_sessionIdentityKey];
    if (!_tokenManager.isCurrentSession(identity)) return false;
    final authorization = request.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value)
        .firstOrNull;
    if (authorization is! String || authorization.isEmpty) return false;
    final token = await _tokenManager.getToken();
    return _tokenManager.isCurrentSession(identity) && token == authorization;
  }

  /// HttpService 使用 plain 响应类型，错误响应到达认证拦截器时可能仍是
  /// JSON 字符串。统一解析后才能保留设备被挤下线、后台移除等具体原因。
  Map<String, dynamic>? _parseResponseData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is List<int>) {
      data = utf8.decode(data, allowMalformed: true);
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// 检查是否为公开端点
  ///
  /// 公开端点存储的是不含 apiPrefix 的后缀路径（如 '/passport/auth/login'），
  /// 实际请求路径含前缀（如 '/api/v1/passport/auth/login'），用 endsWith 匹配。
  bool _isPublicEndpoint(String path) {
    // 去掉查询参数部分
    final pathWithoutQuery =
        path.contains('?') ? path.substring(0, path.indexOf('?')) : path;

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
