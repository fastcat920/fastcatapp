import 'package:fl_clash/xboard/features/auth/utils/crisp_url_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support IP rules do not force DNS for unrelated domain traffic', () {
    expect(customerServiceDirectRules('https://192.0.2.1'),
        contains('IP-CIDR,192.0.2.1/32,DIRECT,no-resolve'));
    expect(customerServiceDirectRules('https://[2001:db8::1]'),
        contains('IP-CIDR6,2001:db8::1/128,DIRECT,no-resolve'));
    expect(customerServiceDirectRules('https://support.example.com'),
        contains('DOMAIN,support.example.com,DIRECT'));
  });
}
