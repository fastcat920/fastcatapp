// ignore_for_file: avoid_print
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';

part 'generated/order_state.g.dart';

/// 订单状态管理

/// 获取订单列表
@riverpod
Future<List<OrderModel>> getOrders(Ref ref) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  final orders = await ApiRequestCache.get<List<OrderModel>>(
    'xboard:orders:$epoch:${identityHashCode(sdk)}',
    ttl: const Duration(minutes: 1),
    fetch: sdk.order.getOrders,
  );
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  if (orders.isEmpty) {
    print('[fastcat][getOrders] ⚠️ 订单列表为空 sdkHash=${identityHashCode(sdk)}');
  }
  return orders;
}

/// 获取单个订单
@riverpod
Future<OrderModel?> getOrder(Ref ref, String tradeNo) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) return null;
  final order = await ApiRequestCache.get<OrderModel?>(
    'xboard:order:$epoch:${identityHashCode(sdk)}:$tradeNo',
    ttl: const Duration(seconds: 30),
    fetch: () => sdk.order.getOrder(tradeNo),
  );
  if (!active || ref.read(sessionEpochProvider) != epoch) return null;
  return order;
}

/// 获取订单支付方式
@riverpod
Future<List<PaymentMethodModel>> getOrderPaymentMethods(
    Ref ref, String tradeNo) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  final methods = await ApiRequestCache.get<List<PaymentMethodModel>>(
    'xboard:order_payment_methods:$epoch:${identityHashCode(sdk)}:$tradeNo',
    ttl: const Duration(minutes: 5),
    fetch: () => sdk.order.getPaymentMethods(tradeNo),
  );
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  return methods;
}

/// 检查优惠券
@riverpod
Future<CouponModel?> checkCoupon(Ref ref,
    {required String code, required int planId}) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) return null;
  final coupon = await sdk.order.checkCoupon(code, planId);
  if (!active || ref.read(sessionEpochProvider) != epoch) return null;
  return coupon;
}

void clearGetOrdersCache() {
  ApiRequestCache.invalidatePrefix('xboard:orders:');
}

void clearGetOrderCache(String tradeNo) {
  ApiRequestCache.invalidatePrefix('xboard:order:');
}

void clearGetOrderPaymentMethodsCache(String tradeNo) {
  ApiRequestCache.invalidatePrefix('xboard:order_payment_methods:');
}
