import '../../api/interfaces/order_api.dart';
import '../../api/models/order_model.dart';
import '../../api/models/payment_model.dart';
import '../../api/models/coupon_model.dart';
import '../../panels/v2board/apis/v2board_order_api.dart';
import '../../panels/v2board/apis/v2board_coupon_api.dart';
import '../../panels/xboard/models/xboard_order_models.dart';
import '../../panels/xboard/models/xboard_coupon_models.dart'; // Reusing XBoard models if compatible, or V2Board models

class V2BoardOrderAdapter implements OrderApi {
  final V2BoardOrderApi _api;
  final V2BoardCouponApi _couponApi;

  V2BoardOrderAdapter(this._api, this._couponApi);

  @override
  Future<List<OrderModel>> getOrders({int page = 1, int pageSize = 20}) async {
    final allOrders = <Order>[];
    var currentPage = page;
    while (true) {
      final response = await _api.fetchUserOrders(page: currentPage, pageSize: pageSize);
      final data = response.data;
      if (data.isEmpty) break;
      allOrders.addAll(data);
      if (data.length < pageSize) break;
      currentPage++;
    }
    return allOrders.map(_mapOrder).toList();
  }

  @override
  Future<String> createOrder(int planId, String period,
      {String? couponCode, int? depositAmount}) async {
    final response = await _api.createOrder(
      planId: planId,
      period: period,
      couponCode: couponCode,
      depositAmount: depositAmount,
    );
    if (response.data == null) {
      throw Exception('Order creation failed: no data returned');
    }
    return response.data!;
  }

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods(String tradeNo) async {
    // V2Board API returns all payment methods, tradeNo is not used in this specific API call
    final response = await _api.getPaymentMethods();
    if (response.data == null) return [];
    return response.data!.map(_mapPaymentMethod).toList();
  }

  @override
  Future<PaymentResultModel> checkoutOrder(
      String tradeNo, String method) async {
    final response = await _api.submitPayment(tradeNo: tradeNo, method: method);

    if (response.type == -1) {
      // 免费/余额支付成功
      return PaymentResultModel.success(message: 'Payment successful');
    } else if (response.type == 0) {
      // 二维码支付（AlipayF2F 等），data 是二维码 URL
      return PaymentResultModel.redirect(url: response.data as String);
    } else if (response.type == 1) {
      // URL 跳转支付
      return PaymentResultModel.redirect(url: response.data as String);
    } else if (response.type == 2) {
      // 即时完成（Stripe 扣款）
      return PaymentResultModel.success(message: 'Payment successful');
    } else {
      return PaymentResultModel.failed(
          message: 'Unknown payment result type: ${response.type}');
    }
  }

  @override
  Future<bool> cancelOrder(String tradeNo) async {
    final response = await _api.cancelOrder(tradeNo);
    return response.data ==
        null; // Assuming null data means success for void return
  }

  Future<PaymentMethodModel?> getOrderPaymentMethod(String tradeNo) async {
    // V2BoardOrderApi doesn't have getOrderPaymentMethod.
    // It has getPaymentMethods() which returns all methods.
    return null;
  }

  @override
  Future<OrderModel> getOrder(String tradeNo) async {
    final order = await _api.getOrderDetails(tradeNo);
    return _mapOrder(order);
  }

  OrderModel _mapOrder(Order order) {
    return OrderModel(
      planId: order.planId,
      tradeNo: order.tradeNo,
      totalAmount: order.totalAmount,
      balanceAmount: order.balanceAmount,
      period: order.period,
      status: order.status,
      createdAt: order.createdAt,
      orderPlan:
          order.orderPlan != null ? _mapOrderPlan(order.orderPlan!) : null,
    );
  }

  OrderPlanModel _mapOrderPlan(OrderPlan plan) {
    return OrderPlanModel(
      id: plan.id,
      name: plan.name,
      onetimePrice: plan.onetimePrice,
      content: plan.content,
    );
  }

  PaymentMethodModel _mapPaymentMethod(PaymentMethod method) {
    return PaymentMethodModel(
      id: method.id,
      name: method.name,
      paymentMethod: method.name, // Fallback to name
      icon: method.icon,
      isAvailable: method.isAvailable,
      config: method.config,
    );
  }

  @override
  Future<CouponModel?> checkCoupon(String code, int planId) async {
    try {
      final response = await _couponApi.checkCoupon(code, planId);
      if (response.data == null) return null;
      return _mapCoupon(response.data!);
    } catch (e) {
      return null;
    }
  }

  CouponModel _mapCoupon(CouponData coupon) {
    return CouponModel(
      id: coupon.id,
      name: coupon.name,
      code: coupon.code,
      type: coupon.type,
      value: coupon.value,
      limitUse: coupon.limitUse,
      limitUseWithUser: coupon.limitUseWithUser,
      limitPlanIds: coupon.limitPlanIds,
      limitPeriod: coupon.limitPeriod,
      startedAt: coupon.startedAt,
      endedAt: coupon.endedAt,
      show: coupon.show,
      createdAt: coupon.createdAt,
      updatedAt: coupon.updatedAt,
    );
  }
}
