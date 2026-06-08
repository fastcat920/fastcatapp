import '../../../core/http/http_service.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../models/xboard_plan_models.dart';
import '../../../core/exceptions/xboard_exceptions.dart';

/// XBoard 套餐 API 实现
class XBoardPlanApi {
  final HttpService _httpService;

  XBoardPlanApi(this._httpService);

  Future<ApiResponse<List<Plan>>> fetchPlans() async {
    try {
      final result = await _httpService.getRequest('/user/plan/fetch');
      return ApiResponse(
        success: true,
        message: result['message'] as String?,
        data: parseResponseMapList(
          result,
          listKeys: const ['data', 'plans', 'items', 'list', 'records'],
        ).map(Plan.fromJson).toList(),
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('获取套餐列表失败: $e');
    }
  }
}
