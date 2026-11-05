import 'dart:async';

import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/features/invite/providers/referral_program_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class _Catboard extends Fake implements CatboardApi {
  Future<CatboardReferralProgram?> result = Future.value(null);
  int calls = 0;

  @override
  Future<CatboardReferralProgram?> getReferralProgram() {
    calls++;
    return result;
  }
}

class _Sdk extends Fake implements XBoardSDK {
  _Sdk(this.catboard);

  @override
  final CatboardApi catboard;
}

void main() {
  test(
      'referral program cannot reuse old in-flight refresh after account switch',
      () async {
    final old = Completer<CatboardReferralProgram?>();
    final fresh = Completer<CatboardReferralProgram?>();
    final api = _Catboard()..result = old.future;
    final sdk = _Sdk(api);
    final container = ProviderContainer(overrides: [
      xboardSdkProvider.overrideWith((ref) async => sdk),
    ]);
    addTearDown(container.dispose);
    container.read(referralProgramProvider);
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, 1);
    api.result = fresh.future;
    container.read(sessionEpochProvider.notifier).state++;
    expect(container.read(referralProgramProvider).program, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, 2);
    fresh.complete(const CatboardReferralProgram(effectiveInvites: 2));
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(referralProgramProvider).program?.effectiveInvites, 2);
    old.complete(const CatboardReferralProgram(effectiveInvites: 99));
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(referralProgramProvider).program?.effectiveInvites, 2);
  });
}
