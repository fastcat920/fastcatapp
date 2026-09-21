import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:flutter_xboard_sdk/src/panels/v2board/models/plan.dart'
    as v2board;
import 'package:flutter_xboard_sdk/src/panels/xboard/models/xboard_plan_models.dart'
    as xboard;

void main() {
  const base = <String, dynamic>{
    'id': 1,
    'group_id': 1,
    'transfer_enable': 100,
    'name': 'Plan',
    'show': 1,
    'renew': 1,
  };

  test('all plan models tolerate the legacy empty flash-sale list', () {
    final json = <String, dynamic>{
      ...base,
      'active_flash_sales': <dynamic>[],
    };

    expect(v2board.Plan.fromJson(json).activeFlashSales, isEmpty);
    expect(xboard.Plan.fromJson(json).activeFlashSales, isEmpty);
    expect(PlanModel.fromJson(json).activeFlashSales, isEmpty);
  });

  test('all plan models preserve keyed flash-sale objects', () {
    final json = <String, dynamic>{
      ...base,
      'active_flash_sales': {
        'month_price': {'final_amount': 1500},
      },
    };

    expect(
        v2board.Plan.fromJson(json).activeFlashSales, contains('month_price'));
    expect(
        xboard.Plan.fromJson(json).activeFlashSales, contains('month_price'));
    expect(PlanModel.fromJson(json).activeFlashSales, contains('month_price'));
  });
}
