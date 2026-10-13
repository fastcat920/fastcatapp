import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/adapter/state/invite_state.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class _InviteApi extends Fake implements InviteApi {
  int withdrawals = 0;

  @override
  Future<bool> withdrawCommission({
    required double amount,
    required String method,
    required Map<String, dynamic> params,
  }) async {
    withdrawals++;
    return true;
  }
}

class _Sdk extends Fake implements XBoardSDK {
  _Sdk(this.invite);

  @override
  final InviteApi invite;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async => AppLocalizations.load(const Locale('en')));

  test('invite state resets and rejects the previous account response',
      () async {
    final old = Completer<InviteInfoModel>();
    final fresh = Completer<InviteInfoModel>();
    final container = ProviderContainer(overrides: [
      userInfoProvider.overrideWith((ref) => null),
      getInviteInfoProvider.overrideWith((ref) {
        return ref.watch(sessionEpochProvider) == 0 ? old.future : fresh.future;
      }),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(inviteProvider.notifier);
    final oldRequest = notifier.loadInviteData();
    container.read(sessionEpochProvider.notifier).state++;
    expect(container.read(inviteProvider).inviteData, isNull);
    expect(container.read(inviteProvider).isLoading, isFalse);
    final newRequest = container.read(inviteProvider.notifier).loadInviteData();
    fresh.complete(const InviteInfoModel(codes: [], stat: [2, 200]));
    await newRequest;
    expect(container.read(inviteProvider).totalInvites, 2);
    old.complete(const InviteInfoModel(codes: [], stat: [9, 900]));
    await oldRequest;
    expect(container.read(inviteProvider).totalInvites, 2);
    await Future<void>.delayed(Duration.zero);
  });

  test('late commission error cannot clear new account history', () async {
    final old = Completer<List<CommissionDetailModel>>();
    final fresh = CommissionDetailModel(
      id: 2,
      orderAmount: 100,
      tradeNo: 'new-account-order',
      getAmount: 10,
      createdAt: DateTime(2026),
    );
    final container = ProviderContainer(overrides: [
      userInfoProvider.overrideWith((ref) => null),
      getCommissionDetailsProvider(page: 1).overrideWith((ref) async {
        return ref.watch(sessionEpochProvider) == 0
            ? await old.future
            : [fresh];
      }),
    ]);
    addTearDown(container.dispose);
    final oldRequest =
        container.read(inviteProvider.notifier).loadCommissionHistory();
    container.read(sessionEpochProvider.notifier).state++;
    await container.read(inviteProvider.notifier).loadCommissionHistory();
    old.completeError(StateError('Old account request failed'));
    await oldRequest;
    final state = container.read(inviteProvider);
    expect(state.commissionHistory.single.id, 2);
    expect(state.isLoadingHistory, isFalse);
    expect(state.errorMessage, isNull);
    await Future<void>.delayed(Duration.zero);
  });

  test('switching account while awaiting SDK prevents withdrawal dispatch',
      () async {
    final ready = Completer<XBoardSDK>();
    final api = _InviteApi();
    final container = ProviderContainer(overrides: [
      userInfoProvider.overrideWith((ref) => null),
      getInviteInfoProvider.overrideWith((ref) async =>
          const InviteInfoModel(codes: [], stat: [0, 0, 0, 0, 50000])),
      xboardSdkProvider.overrideWith((ref) => ready.future),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(inviteProvider.notifier);
    await notifier.loadInviteData();
    final request = notifier.withdrawCommission(
      amountInCents: 100,
      withdrawMethod: 'Alipay',
      withdrawAccount: 'test-account',
    );
    container.read(sessionEpochProvider.notifier).state++;
    ready.complete(_Sdk(api));
    expect(await request, isFalse);
    expect(api.withdrawals, 0);
    expect(container.read(inviteProvider).isLoading, isFalse);
    await Future<void>.delayed(Duration.zero);
  });

  test('completion after provider disposal does not access its ref', () async {
    final result = Completer<InviteInfoModel>();
    final container = ProviderContainer(overrides: [
      userInfoProvider.overrideWith((ref) => null),
      getInviteInfoProvider.overrideWith((ref) => result.future),
    ]);
    final request = container.read(inviteProvider.notifier).loadInviteData();
    container.dispose();
    result.complete(const InviteInfoModel(codes: [], stat: []));
    await request;
    await Future<void>.delayed(Duration.zero);
  });
}
