import '../../../core/http/http_service.dart';
import '../models/xboard_login_models.dart';
import '../../../core/exceptions/xboard_exceptions.dart';

/// XBoard 登录 API 实现
class XBoardLoginApi {
  final HttpService _httpService;
  final void Function(List<String> gatewayUrls)? onGatewayUrls;

  XBoardLoginApi(this._httpService, {this.onGatewayUrls});

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
      final data = result['data'] as Map<String, dynamic>;

      // 提取设备网关故障转移地址列表
      _extractGatewayUrls(data);

      return LoginResult.fromJson(data);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('登录失败: $e');
    }
  }

  void _extractGatewayUrls(Map<String, dynamic> data) {
    final raw = data['gateway_urls'];
    if (raw is List && raw.isNotEmpty) {
      final urls = raw.map((e) => e.toString().trim()).where((u) => u.isNotEmpty).toList();
      if (urls.isNotEmpty) onGatewayUrls?.call(urls);
    }
  }
}
