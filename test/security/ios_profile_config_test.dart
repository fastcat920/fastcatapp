import 'package:fl_clash/security/ios_profile_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'provider cache paths do not cross sandbox boundaries or expose URL credentials',
      () {
    final original = <String, dynamic>{
      'proxy-providers': {
        'subscription': {
          'type': 'http',
          'url': 'https://example.com/?token=secret',
          'path': '/private/app/profile.yaml'
        },
      },
      'rule': ['MATCH,DIRECT'],
    };
    final patched = iosProfileConfig(original);
    final path = patched['proxy-providers']['subscription']['path'] as String;
    expect(path, startsWith('providers/proxy-providers/'));
    expect(path, isNot(contains('secret')));
    expect(original['proxy-providers']['subscription']['path'],
        '/private/app/profile.yaml');
    expect(patched['rule'], ['MATCH,DIRECT']);
  });
}
