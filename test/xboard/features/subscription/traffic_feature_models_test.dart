import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  group('V2Board traffic feature fields', () {
    test('parses allow_new_period integer values', () {
      expect(
        SubscriptionModel.fromJson(const {'allow_new_period': 1})
            .allowNewPeriod,
        isTrue,
      );
      expect(
        SubscriptionModel.fromJson(const {}).allowNewPeriod,
        isFalse,
      );
    });

    test('parses auto_renewal integer values', () {
      expect(
        UserModel.fromJson(const {
          'email': 'user@example.com',
          'auto_renewal': 1,
        }).autoRenewal,
        isTrue,
      );
      expect(
        UserModel.fromJson(const {'email': 'user@example.com'}).autoRenewal,
        isFalse,
      );
    });

    test('domain metadata exposes both feature switches', () {
      final user = DomainUser(
        email: 'user@example.com',
        uuid: 'uuid',
        avatarUrl: '',
        transferLimit: 0,
        uploadedBytes: 0,
        downloadedBytes: 0,
        balanceInCents: 0,
        commissionBalanceInCents: 0,
        metadata: const {'autoRenewal': true},
      );
      final subscription = DomainSubscription(
        subscribeUrl: '',
        email: 'user@example.com',
        uuid: 'uuid',
        planId: 1,
        transferLimit: 100,
        uploadedBytes: 100,
        downloadedBytes: 0,
        metadata: const {'allowNewPeriod': true},
      );

      expect(user.autoRenewal, isTrue);
      expect(subscription.allowNewPeriod, isTrue);
    });
  });
}
