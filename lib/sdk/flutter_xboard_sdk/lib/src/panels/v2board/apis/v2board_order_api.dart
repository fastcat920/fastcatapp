import '../../../core/http/http_service.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';
import '../../xboard/models/xboard_order_models.dart';

/// V2Board 订单 API 实现
class V2BoardOrderApi {
  final HttpService _httpService;

  V2BoardOrderApi(this._httpService);

  Future<OrderResponse> fetchUserOrders() async {
    try {
      final result = await _httpService.getRequest('/user/order/fetch');
      return _parseOrderResponse(result);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取订单列表失败: $e');
    }
  }

  OrderResponse _parseOrderResponse(Map<String, dynamic> result) {
    final dataField = result['data'];
    final List<dynamic> rawOrders;
    int? total = (result['total'] as num?)?.toInt();

    if (dataField is List) {
      rawOrders = dataField;
    } else if (dataField is Map<String, dynamic>) {
      final nestedData = dataField['data'];
      final nestedOrders = dataField['orders'];
      rawOrders = nestedData is List
          ? nestedData
          : nestedOrders is List
              ? nestedOrders
              : dataField.values
                  .whereType<List>()
                  .expand((list) => list)
                  .toList();
      total ??= (dataField['total'] as num?)?.toInt();
    } else {
      rawOrders = const [];
    }

    final orders = rawOrders
        .whereType<Map>()
        .map((item) => Order.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();

    return OrderResponse(data: orders, total: total);
  }

  Future<Order> getOrderDetails(String tradeNo) async {
    try {
      final result = await _httpService.getRequest(
        '/user/order/detail?trade_no=$tradeNo',
      );

      return Order.fromJson(result['data'] as Map<String, dynamic>);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取订单详情失败: $e');
    }
  }

  Future<ApiResponse<dynamic>> cancelOrder(String tradeNo) async {
    try {
      final result = await _httpService.postRequest(
        '/user/order/cancel',
        {'trade_no': tradeNo},
      );

      return ApiResponse.fromJson(result, null);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 取消订单失败: $e');
    }
  }

  Future<ApiResponse<String>> createOrder({
    required int planId,
    required String period,
    String? couponCode,
    int? depositAmount,
  }) async {
    try {
      final data = {
        'plan_id': planId,
        'period': period,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
        if (depositAmount != null) 'deposit_amount': depositAmount,
      };

      final result = await _httpService.postRequest('/user/order/save', data);

      final tradeNo = result['data'] as String?;
      return ApiResponse(
        success: tradeNo != null,
        data: tradeNo,
        message: result['message'],
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 创建订单失败: $e');
    }
  }

  Future<ApiResponse<List<PaymentMethod>>> getPaymentMethods() async {
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
        ).map(PaymentMethod.fromJson).toList(),
        message: result['message'] as String?,
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 获取支付方式失败: $e');
    }
  }

  Future<CheckoutResult> submitPayment({
    required String tradeNo,
    required String method,
  }) async {
    try {
      final result = await _httpService.postRequest(
        '/user/order/checkout',
        {
          'trade_no': tradeNo,
          'method': method,
        },
      );

      return CheckoutResult.fromJson(result);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('V2Board 提交支付失败: $e');
    }
  }
}
