import 'package:fl_clash/xboard/features/settings/utils/routing_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single host addresses become valid CIDRs for Mihomo', () {
    expect(buildRoutingRule('8.8.8.8', 'DIRECT'),
        'IP-CIDR,8.8.8.8/32,DIRECT,no-resolve');
    expect(buildRoutingRule('2001:db8::1', 'Proxy'),
        'IP-CIDR6,2001:db8::1/128,Proxy,no-resolve');
    expect(buildRoutingRule('1.2.3.4/24', 'DIRECT'),
        'IP-CIDR,1.2.3.0/24,DIRECT,no-resolve');
    expect(
        () => buildRoutingRule('1.2.3.4/33', 'DIRECT'), throwsFormatException);
  });
  test('destinations are normalized and conflicting actions are detected', () {
    final rule = buildRoutingRule(' +.EXAMPLE.COM ', 'DIRECT');
    expect(rule, 'DOMAIN-SUFFIX,example.com,DIRECT');
    expect(
        sameRoutingDestination(rule, buildRoutingRule('example.com', 'Proxy')),
        isTrue);
    expect(() => buildRoutingRule('https://example.com', 'DIRECT'),
        throwsFormatException);
  });
}
