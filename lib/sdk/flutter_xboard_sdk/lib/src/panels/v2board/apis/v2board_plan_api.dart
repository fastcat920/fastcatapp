import '../../../core/http/http_service.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../../xboard/models/xboard_plan_models.dart';

/// V2Board 套餐 API 实现
class V2BoardPlanApi {
  final HttpService _httpService;

  V2BoardPlanApi(this._httpService);

  Future<ApiResponse<List<Plan>>> fetchPlans() async {
    try {
      final result = await _httpService.getRequest('/user/plan/fetch');

      return ApiResponse(
        success: true,
        data: parseResponseMapList(
          result,
          listKeys: const ['data', 'plans', 'items', 'list', 'records'],
        ).map(Plan.fromJson).toList(),
        message: result['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取套餐列表失败: $e');
    }
  }
}
