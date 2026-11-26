import 'dart:async';

import 'package:fl_clash/xboard/features/subscription/services/foreground_subscription_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each connected resume refreshes and a disconnected resume skips',
      () async {
    final refreshed = <bool>[];
    for (final connected in [true, false, true]) {
      await refreshConnectedSubscriptionOnResume(
        isCurrent: () => true,
        isConnected: () async => connected,
        refresh: () async {
          refreshed.add(connected);
        },
      );
    }
    expect(refreshed, [true, true]);
  });

  test('a VPN result received after leaving the foreground is ignored',
      () async {
    var current = true;
    final connection = Completer<bool>();
    final pending = refreshConnectedSubscriptionOnResume(
      isCurrent: () => current,
      isConnected: () => connection.future,
      refresh: () async {
        fail('An obsolete resume cannot refresh a plan');
      },
    );
    current = false;
    connection.complete(true);
    await pending;
  });
}
