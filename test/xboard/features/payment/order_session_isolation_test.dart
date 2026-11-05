import 'dart:async';

import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/adapter/state/payment_state.dart';
import 'package:fl_clash/xboard/features/auth/models/auth_state.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class _Orders extends Fake implements OrderApi {
  Future<OrderModel?> order = Future.value(null);
  Future<OrdersPageResult> page =
      Future.value(const OrdersPageResult(orders: [], total: 0));
  int detailCalls = 0;
  int pageCalls = 0;
  int cancellations = 0;
  int creations = 0;

  @override
  Future<OrderModel?> getOrder(String tradeNo) {
    detailCalls++;
    return order;
  }

  @override
  Future<OrdersPageResult> getOrdersPage(
      {required int page, int pageSize = 30}) {
    pageCalls++;
    return this.page;
  }

  @override
  Future<bool> cancelOrder(String tradeNo) async {
    cancellations++;
    return true;
  }

  @override
  Future<String> createOrder(int planId, String period,
      {String? couponCode, int? depositAmount}) async {
    creations++;
    return 'created-order';
  }
}

class _Sdk extends Fake implements XBoardSDK {
  _Sdk(this.order);

  @override
  final OrderApi order;
}

class _Auth extends XBoardUserAuthNotifier {
  @override
  UserAuthState build() => const UserAuthState(isAuthenticated: true);

  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);
}

void main() {
  setUp(ApiRequestCache.clear);
  tearDown(ApiRequestCache.clear);

  test('same SDK cannot reuse order cache or late result across sessions',
      () async {
    final old = Completer<OrderModel?>();
    final orders = _Orders()..order = old.future;
    final sdk = _Sdk(orders);
    final container = ProviderContainer(overrides: [
      xboardSdkProvider.overrideWith((ref) async => sdk),
    ]);
    addTearDown(container.dispose);
    container.listen(getOrderProvider('same-order'), (_, __) {});
    final oldRequest = container.read(getOrderProvider('same-order').future);
    await Future<void>.delayed(Duration.zero);
    expect(orders.detailCalls, 1);
    orders.order = Future.value(const OrderModel(tradeNo: 'new-account-order'));
    container.read(sessionEpochProvider.notifier).state++;
    final newOrder =
        await container.read(getOrderProvider('same-order').future);
    expect(newOrder?.tradeNo, 'new-account-order');
    expect(orders.detailCalls, 2);
    old.complete(const OrderModel(tradeNo: 'old-account-order'));
    await oldRequest;
    expect(container.read(getOrderProvider('same-order')).value?.tradeNo,
        'new-account-order');
  });

  test('late pending orders do not repopulate the next account', () async {
    final old = Completer<OrdersPageResult>();
    final orders = _Orders()..page = old.future;
    final container = ProviderContainer(overrides: [
      xboardUserAuthProvider.overrideWith(_Auth.new),
      xboardSdkProvider.overrideWith((ref) async => _Sdk(orders)),
      getPaymentMethodsProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    container.read(xboardPaymentProvider);
    await Future<void>.delayed(Duration.zero);
    expect(orders.pageCalls, 1);
    orders.page = Future.value(OrdersPageResult(
      orders: [
        OrderModel(tradeNo: 'new-order', status: 0, createdAt: DateTime.now())
      ],
      total: 1,
    ));
    container.read(sessionEpochProvider.notifier).state++;
    expect(container.read(pendingOrdersProvider), isEmpty);
    container.read(xboardPaymentProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pendingOrdersProvider).single.tradeNo, 'new-order');
    old.complete(OrdersPageResult(
      orders: [
        OrderModel(tradeNo: 'old-order', status: 0, createdAt: DateTime.now())
      ],
      total: 1,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pendingOrdersProvider).single.tradeNo, 'new-order');
  });

  test('a caller retaining the raw old order Future receives no account data',
      () async {
    final old = Completer<OrderModel?>();
    final orders = _Orders()..order = old.future;
    final container = ProviderContainer(overrides: [
      xboardSdkProvider.overrideWith((ref) async => _Sdk(orders)),
    ]);
    addTearDown(container.dispose);
    // Unlike FutureProvider.future this preserves the exact Future returned by
    // the adapter, so the post-await discard is exercised directly.
    final rawOrder =
        Provider<Future<OrderModel?>>((ref) => getOrder(ref, 'same-order'));
    final oldRequest = container.read(rawOrder);
    await Future<void>.delayed(Duration.zero);
    orders.order = Future.value(const OrderModel(tradeNo: 'new-order'));
    container.read(sessionEpochProvider.notifier).state++;
    expect((await container.read(rawOrder))?.tradeNo, 'new-order');
    old.complete(const OrderModel(tradeNo: 'old-order'));
    expect(await oldRequest, isNull);
  });

  test('account change aborts create flow before cancelling or creating orders',
      () async {
    final old = Completer<OrdersPageResult>();
    final orders = _Orders()..page = old.future;
    final container = ProviderContainer(overrides: [
      xboardUserAuthProvider.overrideWith(_Auth.new),
      xboardSdkProvider.overrideWith((ref) async => _Sdk(orders)),
      getPaymentMethodsProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    final request = container.read(xboardPaymentProvider.notifier).createOrder(
          planId: 1,
          period: 'month_price',
        );
    await Future<void>.delayed(Duration.zero);
    container.read(sessionEpochProvider.notifier).state++;
    old.complete(OrdersPageResult(
      orders: [
        OrderModel(tradeNo: 'old-order', status: 0, createdAt: DateTime.now())
      ],
      total: 1,
    ));
    expect(await request, isNull);
    expect(orders.cancellations, 0);
    expect(orders.creations, 0);
    await Future<void>.delayed(Duration.zero);
  });

  test('initial payment loading waits for authentication to finish', () async {
    final orders = _Orders();
    final container = ProviderContainer(overrides: [
      xboardUserAuthProvider.overrideWith(_Auth.new),
      xboardSdkProvider.overrideWith((ref) async => _Sdk(orders)),
      getPaymentMethodsProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(container.dispose);
    final auth = container.read(xboardUserAuthProvider.notifier) as _Auth;
    auth.setLoading(true);
    container.read(xboardPaymentProvider);
    await Future<void>.delayed(Duration.zero);
    expect(orders.pageCalls, 0);
    auth.setLoading(false);
    await Future<void>.delayed(Duration.zero);
    expect(orders.pageCalls, 1);
  });
}
