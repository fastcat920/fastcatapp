import 'package:fl_clash/xboard/features/subscription/utils/subscription_url_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forces the encrypted FastCat flag even when a plaintext flag exists',
      () {
    final result = SubscriptionUrlHelper.ensureFastCatFlag(
      'https://example.com/api/v1/client/subscribe?token=secret&flag=meta',
    );
    expect(Uri.parse(result).queryParameters['flag'], 'fastcat-v1');
    expect(Uri.parse(result).queryParameters['token'], 'secret');
  });
}
