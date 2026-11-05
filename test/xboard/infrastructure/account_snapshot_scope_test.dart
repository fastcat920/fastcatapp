import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/infrastructure/cache/content_cache_scope.dart';
import 'package:fl_clash/xboard/infrastructure/storage/storage_interface.dart';
import 'package:fl_clash/xboard/services/storage/xboard_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends Fake implements StorageInterface {
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
  const user = DomainUser(
      email: 'a@example.test',
      uuid: 'a',
      avatarUrl: '',
      transferLimit: 100,
      uploadedBytes: 0,
      downloadedBytes: 0,
      balanceInCents: 0,
      commissionBalanceInCents: 0);
  const subscription = DomainSubscription(
      subscribeUrl: 'https://example.test/sub',
      email: 'a@example.test',
      uuid: 'a',
      planId: 1,
      transferLimit: 100,
      uploadedBytes: 0,
      downloadedBytes: 0);

  test('account scope is stable, opaque and different across device tokens',
      () {
    final a = ContentCacheScope.accountForToken('test-token-a');
    expect(a, ContentCacheScope.accountForToken('test-token-a'));
    expect(a, isNot(ContentCacheScope.accountForToken('test-token-b')));
    expect(a, isNot(contains('test-token')));
    expect(ContentCacheScope.accountForToken(''), isNull);
  });

  test('account snapshots only load for the token that owns the data',
      () async {
    final storage = XBoardStorageService(_Storage());
    await storage.saveUserEmail(user.email, scope: 'a');
    await storage.saveDomainUser(user, scope: 'a');
    await storage.saveDomainSubscription(subscription, scope: 'a');
    expect((await storage.getUserEmail(scope: 'a')).dataOrNull, user.email);
    expect((await storage.getDomainUser(scope: 'a')).dataOrNull, user);
    expect((await storage.getDomainSubscription(scope: 'a')).dataOrNull,
        subscription);
    expect((await storage.getUserEmail(scope: 'b')).dataOrNull, isNull);
    expect((await storage.getDomainUser(scope: 'b')).dataOrNull, isNull);
    expect(
        (await storage.getDomainSubscription(scope: 'b')).dataOrNull, isNull);
  });

  test('unowned legacy snapshots are not adopted by a new account', () async {
    final storage = XBoardStorageService(_Storage());
    await storage.saveUserEmail(user.email);
    await storage.saveDomainUser(user);
    await storage.saveDomainSubscription(subscription);
    expect((await storage.getUserEmail(scope: 'b')).dataOrNull, isNull);
    expect((await storage.getDomainUser(scope: 'b')).dataOrNull, isNull);
    expect(
        (await storage.getDomainSubscription(scope: 'b')).dataOrNull, isNull);
  });

  test('a late old-account disk write cannot be read under the new account',
      () async {
    final storage = XBoardStorageService(_Storage());
    await storage.saveDomainUser(user.copyWith(email: 'b@example.test'),
        scope: 'b');
    await storage.saveDomainUser(user, scope: 'a');
    expect((await storage.getDomainUser(scope: 'b')).dataOrNull, isNull);
  });
}
