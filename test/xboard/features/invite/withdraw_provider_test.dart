import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/adapter/state/invite_state.dart';
import 'package:fl_clash/xboard/adapter/state/user_state.dart';
import 'package:fl_clash/xboard/domain/models/invite.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class _Notifier extends InviteNotifier {
  @override
  InviteState build() => const InviteState(
        inviteData: DomainInvite(stats: InviteStats(availableCommission: 1000)),
        withdrawEnabled: true,
        withdrawMethods: ['Alipay'],
      );
}

class _InviteApi extends Fake implements InviteApi {
  final pending = Completer<bool>();
  final amounts = <double>[];
  @override
  Future<bool> withdrawCommission(
      {required double amount,
      required String method,
      required Map<String, dynamic> params}) {
    amounts.add(amount);
    return pending.future;
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

  ProviderContainer containerFor(_InviteApi api) =>
      ProviderContainer(overrides: [
        inviteProvider.overrideWith(_Notifier.new),
        xboardSdkProvider.overrideWith((ref) async => _Sdk(api)),
        getInviteInfoProvider.overrideWith(
            (ref) async => throw Exception('refresh unavailable')),
        getCommissionDetailsProvider(page: 1).overrideWith((ref) async => []),
        getUserInfoProvider.overrideWith(
            (ref) async => throw Exception('refresh unavailable')),
      ]);

  test(
      'provider passes custom amount rather than balance and blocks duplicate submit',
      () async {
    final api = _InviteApi();
    final container = containerFor(api);
    addTearDown(container.dispose);
    final notifier = container.read(inviteProvider.notifier);
    final request = notifier.withdrawCommission(
      amountInCents: 10050,
      withdrawMethod: 'Alipay',
      withdrawAccount: 'test-account',
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.amounts, [100.50]);
    expect(
        await notifier.withdrawCommission(
          amountInCents: 10050,
          withdrawMethod: 'Alipay',
          withdrawAccount: 'test-account',
        ),
        isFalse);
    expect(api.amounts, hasLength(1));
    api.pending.complete(true);
    // Balance/history failure must not invite a repeat withdrawal.
    expect(await request, isTrue);
    expect(container.read(inviteProvider).isLoading, isFalse);
    expect(container.read(inviteProvider).errorMessage, isNull);
  });

  test('provider rejects invalid/over-balance amounts before using SDK',
      () async {
    final api = _InviteApi();
    final container = containerFor(api);
    addTearDown(container.dispose);
    for (final cents in [0, -1, 100001]) {
      expect(
          await container.read(inviteProvider.notifier).withdrawCommission(
                amountInCents: cents,
                withdrawMethod: 'Alipay',
                withdrawAccount: 'test-account',
              ),
          isFalse);
      expect(container.read(inviteProvider).errorMessage, isNotEmpty);
    }
    expect(api.amounts, isEmpty);
  });
}
