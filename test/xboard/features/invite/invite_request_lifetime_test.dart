import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/adapter/state/invite_state.dart';

class _Invite extends Fake implements InviteApi {
  final response = Completer<InviteInfoModel>();
  @override
  Future<InviteInfoModel> getInviteInfo() => response.future;
}

class _Sdk extends Fake implements XBoardSDK {
  _Sdk(this.invite);
  @override
  final InviteApi invite;
}

void main() {
  test(
      'imperative invite refresh survives disposal frames before HTTP completes',
      () async {
    final api = _Invite();
    final c = ProviderContainer(
        overrides: [xboardSdkProvider.overrideWith((ref) async => _Sdk(api))]);
    addTearDown(c.dispose);
    final request = c.read(getInviteInfoProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await c.pump();
    api.response.complete(InviteInfoModel(codes: [
      InviteCodeModel(
          userId: 1,
          code: 'fixture-only',
          pv: 0,
          status: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026))
    ], stat: const []));
    expect((await request).codes.single.code, 'fixture-only');
  });
}
