import '../../../core/http/http_service.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../../xboard/models/xboard_login_models.dart'; // 复用 XBoard 的 LoginResult

/// V2Board 登录 API 实现
class V2BoardLoginApi {
  final HttpService _httpService;
  final void Function(List<String> gatewayUrls)? onGatewayUrls;

  V2BoardLoginApi(this._httpService, {this.onGatewayUrls});

  Future<LoginResult> login(
    String email,
    String password, {
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final result = await _httpService.postRequest(
        '/passport/auth/login',
        {
          'email': email,
          'password': password,
          ...?deviceInfo,
        },
      );

      // V2Board API 返回格式：{ "data": { "auth_data": "token", ...} }
      final data = result['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw ApiException('登录响应数据为空');
      }

      // 提取设备网关故障转移地址列表
      _extractGatewayUrls(data);

      final token = data['token'] as String?;
      final authData = data['auth_data'] as String?;

      // 当 token 和 auth_data 均为 null 时，后端实际上拒绝了登录（如账号禁用），
      // 但 success 字段可能仍为 true。此时应从响应中提取真实错误信息并抛出异常，
      // 以便上层 Provider 的 _normalizeLoginError 能正确识别业务错误码。
      if (!_hasValue(token) && !_hasValue(authData)) {
        final message = result['message']?.toString() ??
            data['message']?.toString() ??
            '登录失败，请稍后重试';
        throw ApiException(message);
      }

      // 返回统一的 LoginResult
      return LoginResult(
        token: token,
        authData: authData,
        user: data['user'] as Map<String, dynamic>?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 登录失败: $e');
    }
  }

  void _extractGatewayUrls(Map<String, dynamic> data) {
    final raw = data['gateway_urls'];
    if (raw is List && raw.isNotEmpty) {
      final urls = raw
          .map((e) => e.toString().trim())
          .where((u) => u.isNotEmpty)
          .toList();
      if (urls.isNotEmpty) onGatewayUrls?.call(urls);
    }
  }

  bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
