import '../../../core/http/http_service.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../models/invite_info.dart';
import '../../xboard/models/xboard_invite_models.dart' show CommissionDetail;

/// V2Board 邀请 API 实现
class V2BoardInviteApi {
  final HttpService _httpService;

  V2BoardInviteApi(this._httpService);

  Future<ApiResponse<InviteInfo>> getInviteInfo() async {
    try {
      final result = await _httpService.getRequest('/user/invite/fetch');
      final dynamic data = result['data'];

      final InviteInfo inviteInfo;
      if (data is Map<String, dynamic>) {
        // 新版 V2Board：{codes: [...], stat: {...} 或 stat: [n, n, n, n]}
        final statData = data['stat'];
        final Map<String, dynamic> adaptedData;
        if (statData is List) {
          // 旧版 V2Board stat 是数组 [register_count, commission_balance, pending_balance, commission_rate]
          adaptedData = Map<String, dynamic>.from(data);
          adaptedData['stat'] = {
            'register_count': statData.isNotEmpty ? statData[0] : 0,
            'commission_balance': statData.length > 1 ? statData[1] : 0,
            'commission_pending_balance': statData.length > 2 ? statData[2] : 0,
            'commission_rate': statData.length > 3 ? statData[3] : 0,
          };
        } else {
          adaptedData = data;
        }
        inviteInfo = InviteInfo.fromJson(adaptedData);
      } else if (data is List) {
        // 旧版 V2Board：data 直接是 codes 数组
        inviteInfo = InviteInfo(
          codes: data
              .map((e) => InviteCode.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      } else {
        inviteInfo = const InviteInfo();
      }

      return ApiResponse(success: true, data: inviteInfo);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取邀请信息失败: $e');
    }
  }

  Future<ApiResponse<InviteCode>> generateInviteCode() async {
    try {
      // V2Board /user/invite/save 只支持 GET
      await _httpService.getRequest('/user/invite/save');
      // 生成后重新获取邀请信息拿到新码
      final inviteInfoResult = await getInviteInfo();
      final codes = inviteInfoResult.data?.codes ?? [];
      if (codes.isEmpty) {
        throw ApiException('No invite code found after generation');
      }
      return ApiResponse(success: true, data: codes.first);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 生成邀请码失败: $e');
    }
  }

  Future<ApiResponse<List<CommissionDetail>>> fetchCommissionDetails({
    required int current,
    required int pageSize,
  }) async {
    try {
      final result = await _httpService.getRequest(
        '/user/invite/details?current=$current&page_size=$pageSize',
      );
      return ApiResponse(
        success: true,
        data: parseResponseMapList(
          result,
          listKeys: const ['data', 'details', 'items', 'list', 'records'],
        ).map(CommissionDetail.fromJson).toList(),
        message: result['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取佣金详情失败: $e');
    }
  }

  Future<String> generateInviteLink(String baseUrl) async {
    try {
      final inviteInfo = await getInviteInfo();
      final codes = inviteInfo.data?.codes ?? [];
      if (codes.isEmpty) {
        throw ApiException('没有可用的邀请码');
      }
      return '$baseUrl/#/register?code=${codes.first.code ?? ''}';
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 生成邀请链接失败: $e');
    }
  }
}
