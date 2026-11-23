import 'dart:convert';

import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/xboard/features/settings/models/fastcat_paired_config.dart';
import 'package:fl_clash/xboard/features/settings/models/fastcat_test_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profiles = [
    for (final p in FastCatTestProtocol.values)
      Profile.normal().copyWith(id: p.profileId),
  ];
  final records = {
    for (final p in FastCatTestProtocol.values)
      p.profileId: FastCatTestNode(
        protocol: p,
        server: 'gateway.example',
        port: p.port,
        token: 'credential-used-in-tests-only-${p.type}',
      ).configuration(),
  };
  Map<String, dynamic> config(FastCatTestProtocol p) =>
      jsonDecode(records[p.profileId]!);

  for (final active in FastCatTestProtocol.values) {
    final peer = FastCatTestProtocol.values.singleWhere((p) => p != active);
    test('${active.name} retains its original routes and selector options',
        () async {
      final input = config(active);
      final result = await pairedTestRuntimeConfig(input,
          activeId: active.profileId, profiles: profiles, readText: (id) async {
        expect(id, peer.profileId);
        return records[id]!;
      });
      expect(result['proxies'], [
        ...config(active)['proxies'],
        ...config(peer)['proxies'],
      ]);
      expect(result['rules'], input['rules']);
      expect(result['proxy-groups'], [
        ...input['proxy-groups'],
        {
          'name': 'GLOBAL',
          'type': 'select',
          'proxies': ['DIRECT', 'REJECT', active.node, active.group]
        },
      ]);
      expect(input, config(active));
    });
  }

  test(
      'ownership and the original graph are checked before reading credentials',
      () async {
    const active = FastCatTestProtocol.https;
    final altered = config(active);
    altered['proxy-groups'][0]['include-all'] = true;
    var reads = 0;
    Future<void> unchanged(
        String id, List<Profile> entries, Map<String, dynamic> input) async {
      final result = await pairedTestRuntimeConfig(input,
          activeId: id, profiles: entries, readText: (_) async {
        reads++;
        return '';
      });
      expect(identical(result, input), isTrue);
    }

    await unchanged('ordinary', profiles, config(active));
    for (final entry in profiles) {
      await unchanged(
          active.profileId,
          [
            for (final p in profiles)
              p == entry ? p.copyWith(url: 'https://example.com/sub') : p,
          ],
          config(active));
    }
    await unchanged(active.profileId, [profiles.first], config(active));
    await unchanged(active.profileId, profiles, altered);
    expect(reads, 0);
  });

  test('an absent, damaged or mismatched peer never breaks the active profile',
      () async {
    const active = FastCatTestProtocol.https;
    final input = config(active);
    final bad = config(FastCatTestProtocol.h2);
    bad['proxies'][0]['port'] = 0;
    for (final load in <Future<String> Function(String)>[
      (_) async => throw StateError('unreadable'),
      (_) async => 'not valid JSON',
      (_) async => records[active.profileId]!,
      (_) async => jsonEncode(bad),
    ]) {
      final result = await pairedTestRuntimeConfig(input,
          activeId: active.profileId, profiles: profiles, readText: load);
      expect(identical(result, input), isTrue);
    }
  });
}
