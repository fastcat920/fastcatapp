import '../../../core/http/http_service.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../models/xboard_notice_models.dart';
import '../../../core/exceptions/xboard_exceptions.dart';

/// XBoard 公告 API 实现
class XBoardNoticeApi {
  final HttpService _httpService;

  XBoardNoticeApi(this._httpService);

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
      throw ApiException('获取公告列表失败: $e');
    }
  }
}
