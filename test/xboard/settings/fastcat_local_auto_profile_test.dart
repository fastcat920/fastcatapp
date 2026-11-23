import 'dart:convert';

import 'package:fl_clash/security/local_auto_profile.dart';
import 'package:fl_clash/xboard/features/settings/models/fastcat_test_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final records = <String, String>{};
  setUp(() {
    for (final p in FastCatTestProtocol.values) {
      records[p.profileId] = FastCatTestNode(
              protocol: p,
              server: '${p.name}.example.test',
              port: p.port,
              token: 'mock-endpoint-token-that-is-only-for-${p.name}')
          .configuration();
    }
  });

  test(
      'both stored endpoints yield one logical node with fresh distinct credentials on each read',
      () async {
    Future<Map> resolve() async =>
        jsonDecode(await resolveLocalAutoProfile((id) async => records[id]!))
            as Map;
    final first = await resolve();
    final node = (first['proxies'] as List).single;
    expect(node['name'], fastCatAutoNode);
    expect(node['type'], 'fastcat-auto');
    expect(node['server'], 'h2.example.test');
    expect(node['port'], 18444);
    expect(node['token'], endsWith('h2'));
    expect(node['fallback-server'], 'https.example.test');
    expect(node['fallback-port'], 8443);
    expect(node['fallback-token'], endsWith('https'));
    expect(first['proxy-groups'].single['proxies'], [fastCatAutoNode]);
    final v1 = FastCatTestProtocol.https.profileId;
    records[v1] = records[v1]!
        .replaceAll('mock-endpoint-token', 'test-rotated-auth-token');
    expect((await resolve())['proxies'].single['fallback-token'],
        startsWith('test-rotated-auth'));
    records[v1] = '{"token":"sensitive-test-value" broken data}';
    await expectLater(
        resolve(),
        throwsA(isA<FormatException>()
            .having((e) => e.source, 'source omitted', isNull)));
  });

  test('local selections stay scoped to the automatic profile', () {
    final picks = {
      fastCatAutoGroup: fastCatAutoNode,
      'GLOBAL': fastCatAutoGroup,
      'Region': 'HK'
    };
    expect(scopedProfileSelections(fastCatAutoProfileId, picks), picks);
    expect(scopedProfileSelections('subscription', picks), {'Region': 'HK'});
  });
}
