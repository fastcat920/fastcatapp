import 'dart:convert';

import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/infrastructure/storage/storage_interface.dart';
import 'package:fl_clash/xboard/services/storage/xboard_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart'
    show CatboardReferralProgram;

class _MemoryStorage extends Fake implements StorageInterface {
  final values = <String, String>{};

  @override
  Future<Result<String?>> getString(String key) async =>
      Result.success(values[key]);

  @override
  Future<Result<bool>> setString(String key, String value) async {
    values[key] = value;
    return Result.success(true);
  }
}

void main() {
  test('invite and commission caches require matching owner envelopes',
      () async {
    final memory = _MemoryStorage();
    final storage = XBoardStorageService(memory);
    const invite = DomainInvite(stats: InviteStats(invitedCount: 8));
    final commission = DomainCommission(
        id: 1,
        tradeNo: 'test-order',
        amount: 10,
        status: 2,
        createdAt: DateTime(2026));
    await storage.saveDomainInvite(invite, scope: 'account-a');
    await storage.saveDomainCommissionHistory([commission], scope: 'account-a');
    await storage.saveCatboardReferralProgram(
        const CatboardReferralProgram(effectiveInvites: 7),
        scope: 'account-a');
    expect(
        (await storage.getCatboardReferralProgram(scope: 'account-a'))
            .dataOrNull
            ?.effectiveInvites,
        7);
    expect(
        (await storage.getCatboardReferralProgram(scope: 'account-b'))
            .dataOrNull,
        isNull);
    expect(
        (await storage.getDomainInvite(scope: 'account-a')).dataOrNull, invite);
    expect(
        (await storage.getDomainCommissionHistory(scope: 'account-a'))
            .dataOrNull,
        [commission]);
    expect(
        (await storage.getDomainInvite(scope: 'account-b')).dataOrNull, isNull);
    expect(
        (await storage.getDomainCommissionHistory(scope: 'account-b'))
            .dataOrNull,
        isEmpty);
  });

  test('legacy unscoped caches are not assigned to the next login', () async {
    final memory = _MemoryStorage();
    memory.values['xboard_domain_invite'] = jsonEncode(
        const DomainInvite(stats: InviteStats(invitedCount: 8)).toJson());
    memory.values['xboard_domain_commission_history'] = jsonEncode([]);
    final storage = XBoardStorageService(memory);
    expect(
        (await storage.getDomainInvite(scope: 'account-b')).dataOrNull, isNull);
    expect(
        (await storage.getDomainCommissionHistory(scope: 'account-b'))
            .dataOrNull,
        isEmpty);
  });
}
