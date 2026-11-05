import 'package:fl_clash/security/profile_yaml_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts a profile to ordinary Dart maps without losing rules', () {
    final profile = parseProfileYaml('''
proxies:
  - name: node-a
    type: ss
proxy-groups:
  - name: select
    type: select
    proxies: [node-a]
rules:
  - MATCH,select
''');

    expect(profile['rules'], ['MATCH,select']);
    expect((profile['proxies'] as List).first, isA<Map<String, dynamic>>());
    expect(
      ((profile['proxy-groups'] as List).first as Map)['proxies'],
      ['node-a'],
    );
  });

  test('rejects a non-mapping YAML root', () {
    expect(
      () => parseProfileYaml('- one\n- two\n'),
      throwsA(isA<FormatException>()),
    );
  });
}
