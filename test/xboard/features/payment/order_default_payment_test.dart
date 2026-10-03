import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/pages/order_detail_page.dart';
import 'package:fl_clash/xboard/features/payment/providers/xboard_payment_provider.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class _Payment extends XBoardPaymentNotifier {
  final submitted = <String>[];
  @override
  void build() {}
  @override
  Future<void> loadPaymentMethods({bool forceRefresh = false}) async {}
  @override
  Future<Map<String, dynamic>?> submitPayment({
    required String tradeNo,
    required String method,
  }) async {
    submitted.add(method);
    // No real payment, navigation or success side effects.
    return {'type': -2, 'data': 'Test payment intercepted'};
  }
}

class _Plans extends XBoardSubscriptionNotifier {
  @override
  List<DomainPlan> build() => [_plan];
  @override
  Future<void> refreshPlans() async {}
}

const _plan = DomainPlan(
  id: 1,
  name: 'Test plan',
  groupId: 1,
  transferQuota: 1000,
  monthlyPrice: 19,
);

void main() {
  tearDown(() => system.setTVForTesting(false));
  for (final tv in [false, true]) {
    for (final useOrderMethods in [true, false]) {
      testWidgets(
          'default and explicit payment agree with UI: TV=$tv order=$useOrderMethods',
          (tester) async {
        system.setTVForTesting(tv);
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final payment = _Payment();
        var liveOrderMethods = [
          PaymentMethodModel.fromJson(
              {'id': '5', 'name': 'Order Five', 'handling_fee_percent': 10}),
          PaymentMethodModel.fromJson({'id': '2', 'name': 'Order Two'}),
        ];
        final container = ProviderContainer(overrides: [
          xboardPaymentProvider.overrideWith(() => payment),
          xboardSubscriptionProvider.overrideWith(_Plans.new),
          subscriptionInfoProvider.overrideWith((ref) => null),
          userInfoProvider.overrideWith((ref) => null),
          getOrderProvider('test-order')
              .overrideWith((ref) async => const OrderModel(
                    tradeNo: 'test-order',
                    planId: 1,
                    period: 'month_price',
                    status: 0,
                    totalAmount: 1300,
                    balanceAmount: 100,
                    discountAmount: 500,
                    couponDiscountAmount: 500,
                  )),
          getOrderPaymentMethodsProvider('test-order').overrideWith(
              (ref) async => useOrderMethods ? liveOrderMethods : []),
          xboardAvailablePaymentMethodsProvider.overrideWithValue(const [
            DomainPaymentMethod(id: 9, name: 'Global Nine'),
            DomainPaymentMethod(id: 8, name: 'Global Eight'),
          ]),
        ]);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: const OrderDetailPage(tradeNo: 'test-order', plan: _plan),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(useOrderMethods ? 'Order Five' : 'Global Nine'),
            findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('Order amount'), findsNothing);
        expect(find.text('Amount due'), findsOneWidget);
        if (useOrderMethods) expect(find.text('¥14.30'), findsOneWidget);
        await tester.tap(find.text('Pay now'));
        await tester.pumpAndSettle();
        expect(payment.submitted, [useOrderMethods ? '5' : '9']);
        await tester
            .tap(find.text(useOrderMethods ? 'Order Two' : 'Global Eight'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pay now'));
        await tester.pumpAndSettle();
        expect(payment.submitted.last, useOrderMethods ? '2' : '8');
        if (useOrderMethods) {
          liveOrderMethods = [liveOrderMethods.first];
          container.invalidate(getOrderPaymentMethodsProvider('test-order'));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.check_circle), findsNothing);
          await tester.tap(find.text('Pay now'));
          await tester.pumpAndSettle();
          expect(payment.submitted, ['5', '2'],
              reason:
                  'An unavailable selection must not submit another method silently');
        }
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      });
    }
  }
}
