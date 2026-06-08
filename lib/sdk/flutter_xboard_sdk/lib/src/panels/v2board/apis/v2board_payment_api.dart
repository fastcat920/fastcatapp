import '../../../core/http/http_service.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../../xboard/models/xboard_payment_models.dart';

/// V2Board 支付 API 实现
class V2BoardPaymentApi {
  final HttpService _httpService;

  V2BoardPaymentApi(this._httpService);

  Future<ApiResponse<List<PaymentMethodInfo>>> getPaymentMethods() async {
    try {
      final result =
          await _httpService.getRequest('/user/order/getPaymentMethod');

      return ApiResponse(
        success: true,
        data: parseResponseMapList(
          result,
          listKeys: const [
            'data',
            'payment_methods',
            'methods',
            'items',
            'list'
          ],
        ).map(PaymentMethodInfo.fromJson).toList(),
        message: result['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取支付方式失败: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> submitOrderPayment(
      PaymentRequest request) async {
    try {
      final result = await _httpService.postRequest(
        '/user/order/checkout',
        {
          'trade_no': request.tradeNo,
          'method': request.method,
        },
      );

      return ApiResponse(
        success: true,
        data: result['data'] as Map<String, dynamic>?,
        message: result['message'],
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 提交支付失败: $e');
    }
  }

  Future<ApiResponse<PaymentStatusResult>> checkPaymentStatus(
      String tradeNo) async {
    try {
      final result = await _httpService.getRequest(
        '/user/order/check?trade_no=$tradeNo',
      );

      final status = PaymentStatusResult.fromJson(result);
      return ApiResponse(
        success: true,
        data: status,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 查询支付状态失败: $e');
    }
  }

  Future<ApiResponse<PaymentStatusResult>> checkOrderStatus(
      String tradeNo) async {
    return checkPaymentStatus(tradeNo);
  }

  Future<ApiResponse<void>> cancelPayment(String tradeNo) async {
    try {
      final result = await _httpService.postRequest(
        '/user/order/cancel',
        {'trade_no': tradeNo},
      );

      return ApiResponse.fromJson(result, null);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 取消支付失败: $e');
    }
  }
}
