import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection clock accumulates hours and stops at 999:59:59', () {
    expect(utils.getTimeText(null), '00:00:00');
    expect(utils.getTimeText(-1000), '00:00:00');
    expect(utils.getTimeText(3661999), '01:01:01');
    expect(utils.getTimeText(86399000), '23:59:59');
    expect(utils.getTimeText(86400000), '24:00:00');
    expect(utils.getTimeText(2 * 86400000 + 44289000), '60:18:09');
    expect(utils.getTimeText(100 * 3600000), '100:00:00');
    expect(utils.getTimeText(1000 * 3600000 - 2000), '999:59:58');
    expect(utils.getTimeText(1000 * 3600000 - 1000), '999:59:59');
    expect(utils.getTimeText(1000 * 3600000), '999:59:59');
    expect(utils.getTimeText(99 * 86400000), '999:59:59');
  });
}
