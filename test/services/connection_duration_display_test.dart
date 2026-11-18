import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection clock rolls over each day and freezes at 99 days', () {
    expect(utils.getTimeText(null), '00:00:00');
    expect(utils.getTimeText(-1), '00:00:00');
    expect(utils.getTimeText(86399000), '23:59:59');
    expect(utils.getTimeText(86400000), '00:00:00');
    expect(utils.getTimeText(86461000), '00:01:01');
    expect(utils.getTimeText(99 * 86400000 - 1000), '23:59:59');
    expect(utils.getTimeText(99 * 86400000), '00:00:00');
    expect(utils.getTimeText(1000 * 86400000), '00:00:00');
  });
}
