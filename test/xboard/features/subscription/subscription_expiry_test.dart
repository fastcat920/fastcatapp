import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/models/auth_state.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('subscription expiry', () {
    test('status service does not extend expiry to the end of day', () {
      final expirySeconds = DateTime.now()
              .subtract(const Duration(minutes: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final result = subscriptionStatusService.checkSubscriptionStatus(
        userState: const UserAuthState(isAuthenticated: true),
        profileSubscriptionInfo: SubscriptionInfo(
          total: 1024,
          expire: expirySeconds,
        ),
      );

      expect(result.type, SubscriptionStatusType.expired);
      expect(
        result.expiredAt,
        DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000),
      );
    });

    test('subscription remains valid before the exact expiry time', () {
      final expirySeconds = DateTime.now()
              .add(const Duration(minutes: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final result = subscriptionStatusService.checkSubscriptionStatus(
        userState: const UserAuthState(isAuthenticated: true),
        profileSubscriptionInfo: SubscriptionInfo(
          total: 1024,
          expire: expirySeconds,
        ),
      );

      expect(result.type, SubscriptionStatusType.valid);
    });

    test('domain models expire at the exact backend timestamp', () {
      final expiredAt = DateTime.now().subtract(const Duration(minutes: 1));
      final subscription = DomainSubscription(
        subscribeUrl: '',
        email: '',
        uuid: '',
        planId: 1,
        transferLimit: 1,
        uploadedBytes: 0,
        downloadedBytes: 0,
        expiredAt: expiredAt,
      );
      final user = DomainUser(
        email: '',
        uuid: '',
        avatarUrl: '',
        transferLimit: 1,
        uploadedBytes: 0,
        downloadedBytes: 0,
        balanceInCents: 0,
        commissionBalanceInCents: 0,
        expiredAt: expiredAt,
      );

      expect(subscription.isExpired, isTrue);
      expect(user.isExpired, isTrue);
    });
  });
}
