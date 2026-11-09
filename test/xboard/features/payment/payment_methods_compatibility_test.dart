import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:flutter_xboard_sdk/src/panels/xboard/models/xboard_order_models.dart'
    as order;
import 'package:flutter_xboard_sdk/src/panels/xboard/models/xboard_payment_models.dart'
    as payment;
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/adapter/state/payment_state.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';

class _Payment extends Fake implements PaymentApi {
  final pending = Completer<List<PaymentMethodModel>>();
  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() => pending.future;
}

class _Sdk extends Fake implements XBoardSDK {
  _Sdk(this.payment);
  @override
  final PaymentApi payment;
}

void main() {
  setUp(ApiRequestCache.clear);
  tearDown(ApiRequestCache.clear);
  for (final flag in [null, true, false]) {
    test('order and global availability agree for flag $flag', () {
      final data = <String, dynamic>{
        'id': 6,
        'name': 'channel',
        'icon': null,
        'handling_fee_fixed': null,
        'handling_fee_percent': null,
        if (flag != null) 'is_available': flag
      };
      expect(order.PaymentMethod.fromJson(data).isAvailable, flag != false);
      expect(
          payment.PaymentMethodInfo.fromJson(data).isAvailable, flag != false);
    });
  }
  test('global fallback survives a request without a widget listener',
      () async {
    final paymentApi = _Payment();
    final container = ProviderContainer(overrides: [
      xboardSdkProvider.overrideWith((ref) async => _Sdk(paymentApi)),
    ]);
    addTearDown(container.dispose);
    final future = container.read(getPaymentMethodsProvider.future);
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    paymentApi.pending
        .complete([const PaymentMethodModel(id: '6', name: 'channel')]);
    expect((await future).single.id, '6');
  });
}
