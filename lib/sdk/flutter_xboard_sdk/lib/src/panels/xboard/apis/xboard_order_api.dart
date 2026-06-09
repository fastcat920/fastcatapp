import '../../../core/http/http_service.dart';
import '../models/xboard_order_models.dart';
import '../../../core/exceptions/xboard_exceptions.dart';
import '../../../core/models/api_response.dart';
import '../../../core/models/response_list_parser.dart';

/// XBoard 订单 API 实现
class XBoardOrderApi {
  final HttpService _httpService;

  XBoardOrderApi(this._httpService);

  Future<OrderResponse> fetchUserOrders() async {
    try {
      final result = await _httpService.getRequest("/user/order/fetch");
      final response = _parseOrderResponse(result);
      if (response.data.isEmpty) {
        // ignore: avoid_print
        print('[fastcat][XBoardOrderApi] fetchUserOrders: 解析后订单列表为空。'
          ' raw data 类型: ${result['data']?.runtimeType}',
        );
      }
      return response;
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('获取订单列表失败: $e');
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
      // ── 兜底：data 不是 List/Map，尝试从其他 key 提取 ──
      final altKeys = ['orders', 'list', 'items'];
      rawOrders = altKeys
          .map((k) => result[k])
          .whereType<List>()
          .firstOrNull ??
          const [];

      // ignore: avoid_print
        print('[fastcat][XBoardOrderApi] _parseOrderResponse: data 字段类型异常'
        ' (${dataField.runtimeType})，'
        'rawOrders 从 altKeys 提取: ${rawOrders.length} 条。'
        ' result keys: ${result.keys}',
      );
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
        "/user/order/detail?trade_no=$tradeNo",
      );
      if (result['data'] != null) {
        return Order.fromJson(result['data'] as Map<String, dynamic>);
      }
      throw ApiException('获取订单详情失败: ${result['message'] ?? 'Unknown error'}');
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('获取订单详情失败: $e');
    }
  }

  Future<ApiResponse<dynamic>> cancelOrder(String tradeNo) async {
    try {
      final result = await _httpService.postRequest(
        "/user/order/cancel",
        {"trade_no": tradeNo},
      );
      return ApiResponse.fromJson(result, (json) => json);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('取消订单失败: $e');
    }
  }

  Future<ApiResponse<String>> createOrder({
    required int planId,
    required String period,
    String? couponCode,
    int? depositAmount,
  }) async {
    try {
      final json = CreateOrderRequest(
        planId: planId,
        period: period,
        couponCode: couponCode,
      ).toJson();
      if (depositAmount != null) json['deposit_amount'] = depositAmount;

      final result = await _httpService.postRequest(
        "/user/order/save",
        json,
      );
      return ApiResponse.fromJson(result, (data) => data.toString());
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('创建订单失败: $e');
    }
  }

  Future<ApiResponse<List<PaymentMethod>>> getPaymentMethods() async {
    try {
      final result =
          await _httpService.getRequest("/user/order/getPaymentMethod");
      return ApiResponse(
        success: true,
        message: result['message'] as String?,
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
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('获取支付方式失败: $e');
    }
  }

  Future<CheckoutResult> submitPayment({
    required String tradeNo,
    required String method,
  }) async {
    try {
      final request = SubmitOrderRequest(
        tradeNo: tradeNo,
        method: method,
      );

      final result = await _httpService.postRequest(
        "/user/order/checkout",
        request.toJson(),
      );

      // XBoard 返回: {type: -1, data: true} (免费) 或 {type: 0/1, data: "url"} (付费)
      final dynamic resultData = result['data'];

      // 兼容两种返回格式
      if (resultData is Map<String, dynamic>) {
        // 格式1: {data: {type: 0, data: "url"}}
        return CheckoutResult(
          type: resultData['type'] as int? ?? 0,
          data: resultData['data'], // 保持动态类型
        );
      } else {
        // 格式2: {type: -1/0/1, data: bool/String}
        final typeValue = result['type'] as int? ?? 0;
        return CheckoutResult(
          type: typeValue,
          data: resultData, // 保持动态类型，可以是 bool 或 String
        );
      }
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('提交支付失败: $e');
    }
  }
}
