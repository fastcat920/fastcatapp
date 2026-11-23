import 'package:fl_clash/security/local_test_profile_scope.dart';
import 'package:fl_clash/xboard/features/settings/models/fastcat_paired_probe.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/settings/pages/fastcat_device_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Profiles extends Profiles {
  @override
  List<Profile> build() => [];
  void show(Iterable<FastCatTestProtocol> protocols) {
    state = [
      for (final node in protocols)
        Profile.normal(label: node.node).copyWith(id: node.profileId)
    ];
  }

  @override
  void onUpdate(List<Profile> value) {}
}

class _Connection extends RunTime {
  @override
  int? build() => null;
  void connect() => state = 1;
  @override
  void onUpdate(int? value) {}
}

Map<String, dynamic> response(
  int firstByte, {
  int status = 204,
  Map<String, Object> phases = const {},
}) =>
    {
      'ok': true,
      'status-code': status,
      'first-byte-ms': firstByte,
      'phases': phases
    };

void main() {
  const v1 = FastCatTestProtocol.https;
  const h2 = FastCatTestProtocol.h2;

  testWidgets(
      'comparison available only with a VPN connection and both saved profiles',
      (tester) async {
    final providers = ProviderContainer(overrides: [
      profilesProvider.overrideWith(_Profiles.new),
      runTimeProvider.overrideWith(_Connection.new),
    ]);
    addTearDown(providers.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
            home: Scaffold(body: FastCatDeviceProbe(nodeName: v1.node)))));
    final button = find.text('Compare v1 / HTTP/2 on this network');
    final profiles = providers.read(profilesProvider.notifier) as _Profiles;
    profiles.show([v1, h2]);
    await tester.pump();
    expect(button, findsNothing);
    (providers.read(runTimeProvider.notifier) as _Connection).connect();
    await tester.pump();
    expect(button, findsOneWidget);
    final targetPicker = find.byWidgetPredicate((w) => w is SegmentedButton);
    SegmentedButton picker() => tester.widget(targetPicker);
    expect((picker().selected.single as Enum).name, 'google');
    await tester.tap(find.text('Cloudflare'));
    await tester.pump();
    expect((picker().selected.single as Enum).name, 'cloudflare');
    profiles.show([h2]);
    await tester.pump();
    expect(button, findsNothing);
    expect(targetPicker, findsNothing);
  });

  test(
      'first requests separate, paired order reverses each round, only successful 204s count',
      () async {
    final order = <FastCatTestProtocol>[];
    final samples = [
      response(900, phases: {'gateway-reused': false, 'gateway-tcp-ms': 600}),
      response(800),
      response(100, phases: {'connect-response-ms': 15}),
      response(200),
      response(70, status: 302),
      response(300, phases: {'connect-response-ms': 85}),
      response(2, status: 500, phases: {'connect-response-ms': 9000}),
      response(100),
    ];
    final pair = FastCatPairedProbe();
    await pair.run(
        rounds: 3,
        valid: () => true,
        onRound: (_) {},
        sample: (node) async {
          final i = order.length;
          order.add(node);
          return samples[i];
        });
    expect(order, [v1, h2, v1, h2, h2, v1, v1, h2]);
    final a = pair.arms[v1]!;
    expect(a.first!.firstByte, 900);
    expect(a.following.length, 3);
    expect(a.successes, 2);
    expect(a.p50, 200);
    expect(a.p95, 300);
    expect(a.phaseMedian('connect-response-ms'), 50);
    expect(a.slowestLogFields(),
        'round=2 first_byte_ms=300 reused=unknown connect-response-ms=85');
    expect(PairedProbeArm().slowestLogFields(), isNull);
    expect(a.logFields(), contains('first_gateway-tcp-ms=600'));
    expect(a.logFields(), isNot(contains('median_gateway-tcp-ms')));
    expect(pair.arms[h2]!.p50, 150);
  });

  test('stop on missing runtime node, or when both first requests fail',
      () async {
    final missing = FastCatPairedProbe();
    await missing.run(
        valid: () => true,
        onRound: (_) {},
        sample: (node) async => node == h2
            ? {'ok': false, 'error': 'proxy not found'}
            : response(44));
    expect(missing.missingNode, h2);
    expect(missing.arms.values.every((a) => a.following.isEmpty), true);
    final errors = FastCatPairedProbe();
    var calls = 0;
    await errors.run(
        valid: () => true,
        onRound: (_) {},
        sample: (_) async {
          calls++;
          throw StateError('transport not ready');
        });
    expect(calls, 2);
    expect(errors.arms[v1]!.first!.firstByte, isNull);
  });

  test(
      'native path change within one request or between requests discards comparison',
      () async {
    for (final mode in ['during', 'between']) {
      final pair = FastCatPairedProbe();
      var calls = 0;
      await pair.run(
          valid: () => true,
          onRound: (_) {},
          sample: (_) async {
            calls++;
            return response(19, phases: {
              'path-generation': calls == 2 && mode == 'between' ? 2 : 1,
              'path-changed': calls == 2 && mode == 'during',
            });
          });
      expect(pair.pathChanged, true);
      expect(calls, 2);
    }
  });

  test(
      'when canceled, an in-flight response is discarded and no next request is sent',
      () async {
    var current = true;
    var calls = 0;
    final pair = FastCatPairedProbe();
    await pair.run(
        valid: () => current,
        onRound: (_) {},
        sample: (_) async {
          calls++;
          current = false;
          return response(100);
        });
    expect(calls, 1);
    expect(pair.arms[v1]!.first, isNull);
  });
}
