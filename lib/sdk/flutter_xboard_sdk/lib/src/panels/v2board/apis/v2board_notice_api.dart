import '../../../core/http/http_service.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../../xboard/models/xboard_notice_models.dart';

/// V2Board 公告 API 实现
class V2BoardNoticeApi {
  final HttpService _httpService;

  V2BoardNoticeApi(this._httpService);

  Future<ApiResponse<List<Notice>>> fetchNotices() async {
    try {
      final result = await _httpService.getRequest('/user/notice/fetch');
      return ApiResponse(
        success: true,
        data: parseResponseMapList(
          result,
          listKeys: const ['data', 'notices', 'items', 'list', 'records'],
        ).map(Notice.fromJson).toList(),
        message: result['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取公告列表失败: $e');
    }
  }
}
