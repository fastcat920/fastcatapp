import 'package:fl_clash/xboard/features/subscription/utils/subscription_url_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FCN v3 requires an encrypted URL and a capable core', () {
    for (final path in ['/subscription/encrypt/abc', '/subscribe']) {
      for (final version in [0, 1, 2, 3, 4]) {
        final uri = Uri.parse(SubscriptionUrlHelper.ensureFastCatFlag(
          'https://example.com$path?fc_fcn3=0&fc_fcn3=1&token=secret',
          supportsFCN: false,
          fcnVersion: version,
        ));
        final expected = version >= 3 && path.contains('encrypt') ? ['1'] : null;
        expect(uri.queryParametersAll['fc_fcn3'], expected);
        expect(uri.queryParameters['fc_fcn'], isNull);
        expect(uri.queryParameters['token'], 'secret');
      }
    }
  });

  test('pinned FCN nodes require the new native capability', () {
    for (final enabled in [false, true]) {
      final url = Uri.parse(SubscriptionUrlHelper.ensureFastCatFlag(
        'https://example.com/subscribe?fc_fcn_pin=1', supportsFCN: true,
        supportsFCNPinning: enabled));
      expect(url.queryParameters['fc_fcn_pin'], enabled ? '1' : isNull);
    }
    final disabled = Uri.parse(SubscriptionUrlHelper.ensureFastCatFlag(
      'https://example.com/subscribe?fc_fcn_pin=1', supportsFCN: false,
      supportsFCNPinning: true));
    expect(disabled.queryParameters.containsKey('fc_fcn_pin'), isFalse);
  });

  test('FCN capability follows the installed core, never the incoming link', () {
    for (final enabled in [false, true]) {
      final url = Uri.parse(SubscriptionUrlHelper.ensureFastCatFlag(
        'https://example.com/subscribe?fc_fcn=1&token=secret', supportsFCN: enabled));
      expect(url.queryParameters['fc_fcn'], enabled ? '1' : isNull);
      expect(url.queryParameters['token'], 'secret');
    }
  });

  test('forces the encrypted FastCat flag even when a plaintext flag exists',
      () {
    final result = SubscriptionUrlHelper.ensureFastCatFlag(
      'https://example.com/api/v1/client/subscribe?token=secret&flag=meta',
    );
    expect(Uri.parse(result).queryParameters['flag'], 'fastcat-v1');
    expect(Uri.parse(result).queryParameters['token'], 'secret');
  });

  test('removes retired transport flags and preserves FCN capabilities', () {
    final url = Uri.parse(SubscriptionUrlHelper.ensureFastCatFlag(
      'https://example.com/subscribe?fc_auto=1&fc_v2=1&fc_transport=1&t=a&t=b#fragment',
      fcnVersion: 3,
    ));
    for (final flag in ['fc_auto', 'fc_v2', 'fc_transport']) {
      expect(url.queryParameters.containsKey(flag), isFalse);
    }
    expect(url.queryParameters['fc_fcn'], '1');
    expect(url.queryParameters['fc_fcn_pin'], '1');
    expect(url.queryParametersAll['t'], ['a', 'b']);
    expect(url.fragment, 'fragment');
  });
}
