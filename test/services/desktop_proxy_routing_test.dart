import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/services/desktop_proxy_routing.dart';
import 'package:fl_clash/services/verified_connection_start.dart';

void main() {
  test('connection stays unpublished until OS proxy readback succeeds',
      () async {
    final gate = Completer<bool>();
    var published = false;
    final started = runVerifiedConnectionStart(
      start: () async => true,
      verify: () => startVerifiedDesktopProxy(
          enabled: true, start: () async => true, matches: () => gate.future),
      commit: () => published = true,
      rollback: () async {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(published, isFalse);
    gate.complete(true);
    expect(await started, isTrue);
    expect(published, isTrue);
  });
  for (final writeSucceeds in [false, true]) {
    test('proxy write/readback failure rolls startup back', () async {
      var rolledBack = false;
      await expectLater(
          runVerifiedConnectionStart(
            start: () async => true,
            verify: () => startVerifiedDesktopProxy(
                enabled: true,
                start: () async => writeSucceeds,
                matches: () async => false),
            commit: () => fail('must not publish'),
            rollback: () async => rolledBack = true,
          ),
          throwsStateError);
      expect(rolledBack, isTrue);
    });
  }
  test('manual proxy mode does not change OS proxy', () async {
    await startVerifiedDesktopProxy(
        enabled: false,
        start: () async {
          fail('unexpected write');
        },
        matches: () async {
          fail('unexpected read');
        });
  });
}
