import 'package:fl_clash/xboard/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('coupon wallet belongs to the plans navigation branch', () {
    final shell = routes.whereType<StatefulShellRoute>().single;
    final plansRoute = shell.branches[1].routes.whereType<GoRoute>().single;
    final mineRoute = shell.branches[3].routes.whereType<GoRoute>().single;

    expect(plansRoute.path, '/plans');
    expect(
      plansRoute.routes.whereType<GoRoute>().map((route) => route.path),
      contains('coupons'),
    );
    expect(
      mineRoute.routes.whereType<GoRoute>().map((route) => route.path),
      isNot(contains('coupons')),
    );
  });
}
