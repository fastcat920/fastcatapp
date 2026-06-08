import '../../../core/http/http_service.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../models/xboard_invite_models.dart';

/// XBoard 邀请 API 实现
class XBoardInviteApi {
  final HttpService _httpService;

  XBoardInviteApi(this._httpService);

  Future<ApiResponse<InviteCode>> generateInviteCode() async {
    try {
      // 调用生成邀请码接口（返回 boolean）
      final response = await _httpService.getRequest('/user/invite/save');

      // 检查是否成功
      if (response['data'] != true) {
        throw ApiException('Generate invite code failed');
      }

      // 重新获取邀请信息以获取新生成的邀请码
      final inviteInfoResponse =
          await _httpService.getRequest('/user/invite/fetch');
      _normalizeInviteData(inviteInfoResponse);
      final inviteInfo = InviteInfo.fromJson(
          inviteInfoResponse['data'] as Map<String, dynamic>);

      // 获取最新的邀请码（第一个）
      if (inviteInfo.codes.isEmpty) {
        throw ApiException('No invite code found after generation');
      }

      final newCode = inviteInfo.codes.first;

      return ApiResponse(
        success: true,
        data: newCode,
        message: response['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('Generate invite code failed: $e');
    }
  }

  Future<ApiResponse<InviteInfo>> getInviteInfo() async {
    try {
      final response = await _httpService.getRequest('/user/invite/fetch');
      _normalizeInviteData(response);
      return ApiResponse.fromJson(
        response,
        (json) => InviteInfo.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      throw ApiException('Fetch invite codes failed: $e');
    }
  }

  /// 预处理 XBoard 邀请数据，兼容不同版本的字段格式：
  /// - codes[].status: int (0/1) → bool
  /// - stat: Map → `List<int>`（新版 XBoard 返回 Map）
  void _normalizeInviteData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) return;

    // 修正 codes[].status: int → bool
    final codes = data['codes'];
    if (codes is List) {
      for (int i = 0; i < codes.length; i++) {
        final c = codes[i];
        if (c is Map<String, dynamic> && c['status'] is int) {
          codes[i] = Map<String, dynamic>.from(c)
            ..['status'] = (c['status'] as int) == 1;
        }
      }
    }

    // 修正 stat: Map → List<int>（新版 XBoard 返回对象格式）
    final stat = data['stat'];
    if (stat is Map<String, dynamic>) {
      data['stat'] = [
        (stat['register_count'] as num?)?.toInt() ?? 0,
        (stat['commission_balance'] as num?)?.toInt() ?? 0,
        (stat['commission_pending_balance'] as num?)?.toInt() ?? 0,
        (stat['commission_rate'] as num?)?.toInt() ?? 0,
      ];
    }
  }

  Future<ApiResponse<List<CommissionDetail>>> fetchCommissionDetails({
    required int current,
    required int pageSize,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri =
          '/user/invite/details?current=$current&page_size=$pageSize&t=$timestamp';
      final response = await _httpService.getRequest(uri);

      return ApiResponse(
        success: true,
        data: parseResponseMapList(
          response,
          listKeys: const ['data', 'details', 'items', 'list', 'records'],
        ).map(CommissionDetail.fromJson).toList(),
        message: response['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('Fetch commission details failed: $e');
    }
  }

  Future<String> generateInviteLink(String baseUrl) async {
    // 获取邀请信息以获取邀请码
    final inviteInfo = await getInviteInfo();
    final codes = inviteInfo.data?.codes ?? [];

    if (codes.isEmpty) {
      throw ApiException('No invite codes available');
    }

    // 使用第一个有效的邀请码
    final code = codes
        .firstWhere(
          (c) => c.isActive,
          orElse: () => codes.first,
        )
        .code;

    return '$baseUrl/?code=$code';
  }

  Future<ApiResponse<bool>> withdrawCommission({
    required double amount,
    required String method,
    required Map<String, dynamic> params,
  }) async {
    try {
      final response = await _httpService.postRequest('/user/ticket/withdraw', {
        'amount': amount,
        'method': method,
        ...params,
      });

      return ApiResponse(
        success: true,
        data: true,
        message: response['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('Withdraw commission failed: $e');
    }
  }

  Future<ApiResponse<bool>> transferCommissionToBalance({
    required double amount,
  }) async {
    try {
      final response = await _httpService.postRequest('/user/transfer', {
        'amount': amount,
      });

      return ApiResponse(
        success: true,
        data: true,
        message: response['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('Transfer commission failed: $e');
    }
  }
}
