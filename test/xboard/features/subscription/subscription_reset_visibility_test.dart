import 'package:fl_clash/xboard/features/subscription/widgets/subscription_usage_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 1, 12);

  test('permanent plan does not show reset date', () {
    expect(
      shouldShowSubscriptionReset(
        expiredAt: null,
        nextResetAt: now.add(const Duration(days: 10)),
        resetDay: 10,
        now: now,
      ),
      isFalse,
    );
  });

  test('plan ending before a reset does not show reset date', () {
    expect(
      shouldShowSubscriptionReset(
        expiredAt: now.add(const Duration(days: 5)),
        nextResetAt: now.add(const Duration(days: 10)),
        resetDay: 10,
        now: now,
      ),
      isFalse,
    );
  });

  test('plan ending after a reset shows reset date', () {
    expect(
      shouldShowSubscriptionReset(
        expiredAt: now.add(const Duration(days: 20)),
        nextResetAt: now.add(const Duration(days: 10)),
        resetDay: 10,
        now: now,
      ),
      isTrue,
    );
  });

  test('missing or elapsed reset date is hidden', () {
    expect(
      shouldShowSubscriptionReset(
        expiredAt: now.add(const Duration(days: 20)),
        nextResetAt: null,
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldShowSubscriptionReset(
        expiredAt: now.add(const Duration(days: 20)),
        nextResetAt: now.subtract(const Duration(days: 1)),
        now: now,
      ),
      isFalse,
    );
  });

  test('backend reset day works when next reset timestamp is absent', () {
    expect(
      shouldShowSubscriptionReset(
        expiredAt: now.add(const Duration(days: 20)),
        nextResetAt: null,
        resetDay: 10,
        now: now,
      ),
      isTrue,
    );
  });

  test('reset is hidden when it is on the plan expiry day', () {
    expect(
      shouldShowSubscriptionReset(
        expiredAt: now.add(const Duration(days: 10)),
        nextResetAt: null,
        resetDay: 10,
        now: now,
      ),
      isFalse,
    );
  });

  test('reset today is shown for an active non-permanent plan', () {
    expect(
      shouldShowSubscriptionReset(
        expiredAt: now.add(const Duration(days: 1)),
        nextResetAt: null,
        resetDay: 0,
        now: now,
      ),
      isTrue,
    );
  });
}
