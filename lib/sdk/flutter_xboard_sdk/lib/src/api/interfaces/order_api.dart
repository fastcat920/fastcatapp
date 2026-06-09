import '../models/order_model.dart';
import '../models/payment_model.dart';
import '../models/coupon_model.dart';

class OrdersPageResult {
  final List<OrderModel> orders;
  final int total;
  const OrdersPageResult({required this.orders, required this.total});
}

abstract class OrderApi {
  Future<List<OrderModel>> getOrders({int page = 1, int pageSize = 10});
  Future<OrdersPageResult> getOrdersPage({required int page, int pageSize = 30});
  Future<String> createOrder(int planId, String period, {String? couponCode, int? depositAmount});
  Future<PaymentResultModel> checkoutOrder(String tradeNo, String method);
  Future<OrderModel?> getOrder(String tradeNo);
  Future<bool> cancelOrder(String tradeNo);
  Future<List<PaymentMethodModel>> getPaymentMethods(String tradeNo);
  Future<CouponModel?> checkCoupon(String code, int planId);
}
