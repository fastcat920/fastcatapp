import 'package:fl_clash/services/windows_service_start.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    (authorized: false, running: false, ready: false),
    (authorized: true, running: false, ready: false),
    (authorized: true, running: true, ready: false),
    (authorized: true, running: true, ready: true),
  ]) {
    test('SCM-only Helper startup: $scenario', () async {
      final calls = <String>[];
      final result = await startRegisteredWindowsHelper(
        launchService: () {
          calls.add('SCM');
          return scenario.authorized;
        },
        waitForService: () async {
          calls.add('service');
          return scenario.running;
        },
        waitForHelper: () async {
          calls.add('HTTP');
          return scenario.ready;
        },
      );
      expect(result, scenario.ready);
      expect(calls, [
        'SCM',
        if (scenario.authorized) 'service',
        if (scenario.authorized && scenario.running) 'HTTP',
      ]);
    });
  }
}
