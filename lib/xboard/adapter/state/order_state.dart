import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';

part 'generated/order_state.g.dart';

/// 订单状态管理

/// 获取订单列表
@riverpod
Future<List<OrderModel>> getOrders(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return ApiRequestCache.get<List<OrderModel>>(
    'xboard:orders',
    ttl: const Duration(minutes: 1),
    fetch: sdk.order.getOrders,
  );
}

/// 获取单个订单
@riverpod
Future<OrderModel?> getOrder(Ref ref, String tradeNo) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return ApiRequestCache.get<OrderModel?>(
    'xboard:order:$tradeNo',
    ttl: const Duration(seconds: 30),
    fetch: () => sdk.order.getOrder(tradeNo),
  );
}

/// 获取订单支付方式
@riverpod
Future<List<PaymentMethodModel>> getOrderPaymentMethods(
    Ref ref, String tradeNo) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return ApiRequestCache.get<List<PaymentMethodModel>>(
    'xboard:order_payment_methods:$tradeNo',
    ttl: const Duration(minutes: 5),
    fetch: () => sdk.order.getPaymentMethods(tradeNo),
  );
}

/// 检查优惠券
@riverpod
Future<CouponModel?> checkCoupon(Ref ref,
    {required String code, required int planId}) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  return await sdk.order.checkCoupon(code, planId);
}

void clearGetOrdersCache() {
  ApiRequestCache.invalidate('xboard:orders');
}

void clearGetOrderCache(String tradeNo) {
  ApiRequestCache.invalidate('xboard:order:$tradeNo');
}

void clearGetOrderPaymentMethodsCache(String tradeNo) {
  ApiRequestCache.invalidate('xboard:order_payment_methods:$tradeNo');
}
