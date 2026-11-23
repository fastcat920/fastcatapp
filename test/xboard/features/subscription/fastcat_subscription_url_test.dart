import 'package:fl_clash/xboard/features/subscription/utils/subscription_url_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('v2 capability is explicit and cannot be injected by a link', () {
    const url = 'https://example.com/subscribe?fc_v2=1';
    for (final enabled in [false, true]) {
      final result = Uri.parse(SubscriptionUrlHelper.ensureFastCatFlag(url,
          supportsAuto: true, supportsV2: enabled));
      expect(result.queryParameters['fc_auto'], '1');
      expect(result.queryParameters['fc_v2'], enabled ? '1' : isNull);
    }
  });

  test('only a capable native core advertises automatic nodes', () {
    const url = 'https://example.com/subscribe?fc_auto=1&t=a&t=b#fragment';
    final old = Uri.parse(
        SubscriptionUrlHelper.ensureFastCatFlag(url, supportsAuto: false));
    final current = Uri.parse(
        SubscriptionUrlHelper.ensureFastCatFlag(url, supportsAuto: true));
    expect(old.queryParameters.containsKey('fc_auto'), isFalse);
    expect(current.queryParametersAll['fc_auto'], ['1']);
    expect(current.queryParametersAll['t'], ['a', 'b']);
    expect(current.fragment, 'fragment');
  });
}
