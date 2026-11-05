import 'package:fl_clash/services/connection_repair_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system proxy repair never starts Helper or prompts for elevation',
      () async {
    final ready = await prepareConnectionRepairHelper(
      isWindows: true,
      tunRequested: false,
      ensureHelper: () => throw StateError('must not call'),
    );
    expect(ready, isTrue);
  });

  test('non-Windows repair does not use Windows Helper', () async {
    expect(
        await prepareConnectionRepairHelper(
          isWindows: false,
          tunRequested: true,
          ensureHelper: () => throw StateError('must not call'),
        ),
        isTrue);
  });

  for (final ready in [true, false]) {
    test('TUN repair propagates Helper result $ready instead of ignoring it',
        () async {
      var calls = 0;
      expect(
          await prepareConnectionRepairHelper(
            isWindows: true,
            tunRequested: true,
            ensureHelper: () async {
              calls++;
              return ready;
            },
          ),
          ready);
      expect(calls, 1);
    });
  }
}
