import 'dart:async';

import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/adapter/state/subscription_state.dart';
import 'package:fl_clash/xboard/adapter/state/user_state.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class _User extends Fake implements UserApi {
  Future<UserModel> response =
      Future.value(const UserModel(email: 'new@example.test'));
  int calls = 0;
  @override
  Future<UserModel> getUserInfo() {
    calls++;
    return response;
  }
}

class _Subscription extends Fake implements SubscriptionApi {
  Future<SubscriptionModel> response =
      Future.value(const SubscriptionModel(email: 'new@example.test'));
  @override
  Future<SubscriptionModel> getSubscription() => response;
}

class _Sdk extends Fake implements XBoardSDK {
  @override
  final _User user = _User();
  @override
  final _Subscription subscription = _Subscription();
}

void main() {
  setUp(ApiRequestCache.clear);
  tearDown(ApiRequestCache.clear);

  test('retained user Future cannot deliver the previous account after switch',
      () async {
    final old = Completer<UserModel>();
    final sdk = _Sdk()..user.response = old.future;
    final container = ProviderContainer(overrides: [
      xboardSdkProvider.overrideWith((ref) async => sdk),
    ]);
    addTearDown(container.dispose);
    final raw = Provider<Future<UserModel>>((ref) => getUserInfo(ref));
    final request = container.read(raw);
    final staleResult = expectLater(request, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    sdk.user.response =
        Future.value(const UserModel(email: 'new@example.test'));
    container.read(sessionEpochProvider.notifier).state++;
    expect((await container.read(raw)).email, 'new@example.test');
    old.complete(const UserModel(email: 'old@example.test'));
    await staleResult;
    expect(sdk.user.calls, 2);
  });

  test('retained subscription Future cannot import an old account URL',
      () async {
    final old = Completer<SubscriptionModel>();
    final sdk = _Sdk()..subscription.response = old.future;
    final container = ProviderContainer(overrides: [
      xboardSdkProvider.overrideWith((ref) async => sdk),
    ]);
    addTearDown(container.dispose);
    final raw =
        Provider<Future<SubscriptionModel>>((ref) => getSubscription(ref));
    final request = container.read(raw);
    final staleResult = expectLater(request, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    sdk.subscription.response =
        Future.value(const SubscriptionModel(subscribeUrl: 'new-sub'));
    container.read(sessionEpochProvider.notifier).state++;
    expect((await container.read(raw)).subscribeUrl, 'new-sub');
    old.complete(const SubscriptionModel(subscribeUrl: 'old-sub'));
    await staleResult;
  });

  test(
      'account switch while SDK initializes cancels the old request before dispatch',
      () async {
    final ready = Completer<XBoardSDK>();
    final sdk = _Sdk();
    final container = ProviderContainer(overrides: [
      xboardSdkProvider.overrideWith((ref) => ready.future),
    ]);
    addTearDown(container.dispose);
    final raw = Provider<Future<UserModel>>((ref) => getUserInfo(ref));
    final staleResult = expectLater(container.read(raw), throwsStateError);
    container.read(sessionEpochProvider.notifier).state++;
    ready.complete(sdk);
    await staleResult;
    expect(sdk.user.calls, 0);
    expect((await container.read(raw)).email, 'new@example.test');
    expect(sdk.user.calls, 1);
  });
}
