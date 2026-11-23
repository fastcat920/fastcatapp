import 'dart:convert';
import 'package:fl_clash/security/local_test_profile_scope.dart';
import 'package:fl_clash/xboard/features/settings/models/fastcat_direct_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = 'test-only-HTTP2-local-credential';
  const descriptor = {
    'name': 'server display name',
    'type': 'fastcat-auto',
    'server': 'gateway.test',
    'port': 18445,
    'h3-port': 23456,
    'udp': true,
    'token': token,
    'h3-token': 'test-only-HTTP3-local-credential'
  };

  test('server descriptor becomes an isolated H2/H3 core configuration', () {
    final node = FastCatDirectNode.parse(jsonEncode(descriptor));
    final cfg = jsonDecode(node.configuration());
    final proxy = cfg['proxies'].single;
    expect(proxy['name'], fastCatDirectNodeName);
    expect(proxy['sni'], 'gateway.test');
    for (final key in [
      'type',
      'server',
      'port',
      'h3-port',
      'udp',
      'token',
      'h3-token'
    ]) {
      expect(proxy[key], descriptor[key]);
    }
    expect(proxy['ca-file'], isNull);
    expect(cfg['proxy-groups'].single['proxies'], [fastCatDirectNodeName]);
    expect(cfg['rules'], ['MATCH,$fastCatDirectGroup']);
  });

  test('imports the two entry DoH settings together', () {
    final node = FastCatDirectNode.parse(jsonEncode({
      ...descriptor,
      'entry-doh': 'https://dns.example/dns-query',
      'entry-doh-ip': '192.0.2.1',
    }));
    final proxy = jsonDecode(node.configuration())['proxies'].single;
    expect(proxy['type'], 'fastcat-auto-ech');
    expect(proxy['entry-doh'], 'https://dns.example/dns-query');
    expect(proxy['entry-doh-ip'], '192.0.2.1');
    expect(
      () => FastCatDirectNode.parse(
        jsonEncode({...descriptor, 'entry-doh-ip': '192.0.2.1'}),
      ),
      throwsFormatException,
    );
  });

  test(
      'rejects TLS overrides, arbitrary paths, broken ports and missing credentials',
      () {
    for (final patch in [
      {'skip-cert-verify': true},
      {'ca-file': '/elsewhere'},
      {'sni': 'other.test'},
      {'h3-port': 65536},
      {'port': 0},
      {'h3-token': 'tiny'},
      {'udp': false},
      {'ca-pem': '-----BEGIN PRIVATE KEY-----'},
      {
        'rules': ['MATCH,DIRECT']
      },
    ]) {
      expect(
          () => FastCatDirectNode.parse(jsonEncode({...descriptor, ...patch})),
          throwsFormatException);
    }
    try {
      FastCatDirectNode.parse('{"token":"$token",');
      fail('malformed JSON accepted');
    } on FormatException catch (e) {
      expect(e.toString(), isNot(contains(token)));
      expect(e.source, isNull);
    }
  });

  test(
      'CA comes only from the imported public certificate and its app-selected path',
      () {
    const pem =
        '-----BEGIN CERTIFICATE-----\nYWJj\n-----END CERTIFICATE-----\n';
    final node =
        FastCatDirectNode.parse(jsonEncode({...descriptor, 'ca-pem': pem}));
    final cfg =
        jsonDecode(node.configuration(privateCAPath: '/private/app/ca.pem'));
    expect(node.caPem, pem);
    expect(cfg['proxies'].single['ca-file'], '/private/app/ca.pem');
    expect(cfg['proxies'].single['ca-pem'], isNull);
  });
}
