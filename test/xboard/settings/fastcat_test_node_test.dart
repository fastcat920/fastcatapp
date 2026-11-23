import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/settings/models/fastcat_test_node.dart';
import 'package:yaml/yaml.dart';

void main() {
  const token = 'test-token-with-at-least-24-characters';
  test('produces a separate TCP test route with verified TLS and no providers',
      () {
    final text = const FastCatTestNode(
            server: 'zlhk.fastcat.ink', port: 8443, token: token)
        .configuration();
    final config = loadYaml(text) as YamlMap;
    final proxy = (config['proxies'] as YamlList).single as YamlMap;
    expect(proxy['type'], 'fastcat-https');
    expect(proxy['sni'], 'zlhk.fastcat.ink');
    expect(proxy['port'], 8443);
    expect(proxy['token'], token);
    expect(proxy.containsKey('skip-cert-verify'), isFalse);
    expect(proxy.containsKey('udp'), isFalse);
    expect(config['rules'], ['MATCH,$fastCatTestGroup']);
    expect(config.containsKey('proxy-providers'), isFalse);
  });
  test('rejects malformed addresses, invalid ports and token injection', () {
    for (final host in [
      '',
      'https://host.test',
      'host.test/path',
      'host.test\nheader',
      'bad..test',
      '-bad.test'
    ]) {
      expect(FastCatTestNode.validServer(host), isFalse);
    }
    for (final value in [
      'short',
      '$token\r\nheader:value',
      '$token ',
      '$token\t'
    ]) {
      expect(FastCatTestNode.validToken(value), isFalse);
    }
    for (final port in [0, -1, 65536]) {
      expect(
          () => FastCatTestNode(server: 'host.test', port: port, token: token)
              .configuration(),
          throwsFormatException);
    }
  });
  test('preserves quoted token characters without YAML structure injection',
      () {
    const value = 'test-token-with-quote"-and-backslash\\';
    final config = jsonDecode(
        const FastCatTestNode(server: 'host.test', port: 443, token: value)
            .configuration()) as Map;
    expect((config['proxies'] as List).single['token'], value);
  });

  test('HTTP/2 writes a dedicated TLS node and its own selection group', () {
    const p = FastCatTestProtocol.h2;
    final data = jsonDecode(FastCatTestNode(
      protocol: p,
      server: 'zlhk.fastcat.ink',
      port: p.port,
      token: token,
    ).configuration()) as Map;
    final node = (data['proxies'] as List).single;
    expect(node, {
      'name': p.node,
      'type': 'fastcat-h2',
      'port': 18444,
      'sni': 'zlhk.fastcat.ink',
      'server': 'zlhk.fastcat.ink',
      'token': token,
    });
    expect(data['rules'], ['MATCH,${p.group}']);
    expect(p.profileId, isNot(fastCatTestProfileId));
    expect(p.group, isNot(fastCatTestGroup));
    expect(
        (data['proxy-groups'] as List).single['proxies'], [p.node, 'DIRECT']);
  });
}
