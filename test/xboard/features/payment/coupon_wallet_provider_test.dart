import 'dart:async';
import 'dart:io';

import 'package:fl_clash/xboard/features/auth/models/auth_state.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/payment/providers/coupon_wallet_provider.dart';
import 'package:fl_clash/xboard/features/payment/widgets/coupon_entry_button.dart';
import 'package:fl_clash/xboard/features/mine/pages/coupon_wallet_page.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class _Auth extends XBoardUserAuthNotifier {
  @override
  UserAuthState build() =>
      const UserAuthState(isAuthenticated: true, email: 'first@example.test');

  void set(UserAuthState value) => state = value;
}

class _Plans extends XBoardSubscriptionNotifier {
  @override
  List<DomainPlan> build() => [];

  @override
  Future<void> refreshPlans() async {}
}

final _coupon = CatboardCoupon.fromJson({
  'id': 1,
  'status': 'available',
  'template': {'id': 1, 'name': 'Test coupon'},
});

ProviderContainer _container(Future<List<CatboardCoupon>> Function() load) =>
    ProviderContainer(overrides: [
      xboardUserAuthProvider.overrideWith(_Auth.new),
      couponWalletLoaderProvider.overrideWithValue(load),
      isInitializedProvider.overrideWithValue(true),
    ]);

Future<void> _flush(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('cached login waits for startup readiness before wallet loading',
      (tester) async {
    final ready = StateProvider((ref) => false);
    var calls = 0;
    final container = ProviderContainer(overrides: [
      xboardUserAuthProvider.overrideWith(_Auth.new),
      isInitializedProvider.overrideWith((ref) => ref.watch(ready)),
      couponWalletLoaderProvider.overrideWithValue(() async {
        calls++;
        return [_coupon];
      }),
    ]);
    container.listen(couponWalletProvider, (_, __) {});
    await _flush(tester);
    expect(calls, 0);
    container.read(ready.notifier).state = true;
    await _flush(tester);
    expect(calls, 1);
    expect(container.read(couponWalletProvider).valueOrNull, [_coupon]);
    container.dispose();
  });
  testWidgets('desktop refresh action reloads coupons and prevents double taps',
      (tester) async {
    var calls = 0;
    Completer<List<CatboardCoupon>>? pending;
    final container = ProviderContainer(overrides: [
      xboardUserAuthProvider.overrideWith(_Auth.new),
      xboardSubscriptionProvider.overrideWith(_Plans.new),
      isInitializedProvider.overrideWithValue(true),
      couponWalletLoaderProvider.overrideWithValue(() {
        calls++;
        return pending?.future ?? Future.value([]);
      }),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CouponWalletPage()),
    ));
    await _flush(tester);
    expect(calls, 1);
    final refresh = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Refresh');
    expect(refresh, findsOneWidget);
    pending = Completer();
    await tester.tap(refresh);
    await _flush(tester);
    expect(calls, 2);
    expect(tester.widget<IconButton>(refresh).onPressed, isNull);
    pending.complete([_coupon]);
    await _flush(tester);
    expect(find.text('Test coupon'), findsOneWidget);
    expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, skip: !(Platform.isMacOS || Platform.isWindows || Platform.isLinux));

  testWidgets('login reloads wallet; profile-only changes retain the badge',
      (tester) async {
    var calls = 0;
    final container = _container(() async {
      calls++;
      return [_coupon];
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: CouponEntryButton()),
        ),
      ),
    ));
    await _flush(tester);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(calls, 1);
    final auth = container.read(xboardUserAuthProvider.notifier) as _Auth;
    auth.set(const UserAuthState(
        isAuthenticated: true,
        email: 'first@example.test',
        errorMessage: 'unrelated user information update'));
    await _flush(tester);
    expect(calls, 1);
    expect(find.byType(ShaderMask), findsOneWidget);
    auth.set(const UserAuthState());
    await _flush(tester);
    expect(find.byType(ShaderMask), findsNothing);
    auth.set(const UserAuthState(
        isAuthenticated: true, email: 'first@example.test', isLoading: true));
    await _flush(tester);
    expect(calls, 1, reason: 'Do not fetch before login completes');
    auth.set(const UserAuthState(
        isAuthenticated: true, email: 'first@example.test'));
    await _flush(tester);
    expect(calls, 2);
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('refresh deduplicates and retains data on network failure',
      (tester) async {
    var calls = 0;
    Completer<List<CatboardCoupon>>? pending;
    final container = _container(() {
      calls++;
      return pending?.future ?? Future.value([_coupon]);
    });
    container.listen(couponWalletProvider, (_, __) {});
    await _flush(tester);
    pending = Completer();
    final notifier = container.read(couponWalletProvider.notifier);
    final first = notifier.refresh();
    final second = notifier.refresh();
    expect(identical(first, second), isTrue);
    expect(container.read(couponWalletProvider).valueOrNull, [_coupon]);
    await _flush(tester);
    expect(calls, 2);
    pending.completeError(StateError('offline'));
    await _flush(tester);
    await first;
    expect(container.read(couponWalletProvider).hasError, isTrue);
    expect(container.read(couponWalletProvider).valueOrNull, [_coupon]);
    pending = Completer();
    notifier.refresh();
    await _flush(tester);
    pending.complete([]);
    await _flush(tester);
    expect(container.read(couponWalletProvider).valueOrNull, isEmpty);
    container.dispose();
  });

  testWidgets('late response from a previous account cannot replace new wallet',
      (tester) async {
    final oldRequest = Completer<List<CatboardCoupon>>();
    var calls = 0;
    final container = _container(() {
      return ++calls == 1 ? oldRequest.future : Future.value([]);
    });
    container.listen(couponWalletProvider, (_, __) {});
    await _flush(tester);
    final auth = container.read(xboardUserAuthProvider.notifier) as _Auth;
    auth.set(const UserAuthState(
        isAuthenticated: true, email: 'second@example.test'));
    await _flush(tester);
    oldRequest.complete([_coupon]);
    await _flush(tester);
    expect(calls, 2);
    expect(container.read(couponWalletProvider).valueOrNull, isEmpty);
    container.dispose();
  });

  testWidgets('foreground polls new coupons and background pauses requests',
      (tester) async {
    var calls = 0;
    final container = _container(() async {
      return ++calls == 1 ? [] : [_coupon];
    });
    container.listen(couponWalletProvider, (_, __) {});
    await _flush(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    final afterResume = calls;
    await tester.pump(const Duration(seconds: 61));
    await _flush(tester);
    expect(calls, afterResume + 1);
    expect(container.read(couponWalletProvider).valueOrNull, [_coupon]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 61));
    await _flush(tester);
    expect(calls, afterResume + 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    expect(calls, afterResume + 2);
    container.dispose();
    await tester.pump(const Duration(seconds: 61));
    expect(calls, afterResume + 2);
  });
}
