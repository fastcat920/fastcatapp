import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SensitiveMasker.maskText', () {
    test('masks a plain domain and port in core logs', () {
      const input =
          '[UDP] dial fastcat.wang:40101 connect error: context canceled';

      final masked = SensitiveMasker.maskText(input);

      expect(masked, isNot(contains('fastcat.wang')));
      expect(masked, isNot(contains('40101')));
      expect(masked, contains('[redacted-port]'));
      expect(masked, contains('connect error: context canceled'));
    });

    test('masks a plain IP and port without hiding the error reason', () {
      const input = 'dial 203.0.113.7:443: i/o timeout';

      final masked = SensitiveMasker.maskText(input);

      expect(masked, isNot(contains('203.0.113.7')));
      expect(masked, isNot(contains(':443')));
      expect(masked, contains('i/o timeout'));
    });

    test('masks DNS query domains and IPv4 answers without ports', () {
      const input =
          '[DNS] new.fastcat.wang --> [109.244.50.201] A from https://dnsh.pub/dns-query/...';

      final masked = SensitiveMasker.maskText(input);

      expect(masked, isNot(contains('new.fastcat.wang')));
      expect(masked, isNot(contains('109.244.50.201')));
      expect(masked, isNot(contains('dnsh.pub')));
      expect(masked, isNot(contains('.pub')));
      expect(masked, isNot(contains('.wang')));
      expect(masked, contains('p*b'));
      expect(masked, contains('w**g'));
      expect(masked, contains('[DNS]'));
      expect(masked, contains('A from https://'));
    });

    test('masks bare IPv6 DNS answers', () {
      const input =
          '[DNS] cache hit dns.alidns.com --> [2400:3200:baba::1 2400:3200::11] AAAA';

      final masked = SensitiveMasker.maskText(input);

      expect(masked, isNot(contains('dns.alidns.com')));
      expect(masked, isNot(contains('2400:3200:baba::1')));
      expect(masked, isNot(contains('2400:3200::11')));
      expect(masked, contains('[redacted-ipv6]'));
    });

    test('does not mistake timestamps for IPv6 addresses', () {
      const input = '2026-08-17 15:01:34.814602 debug message';

      expect(SensitiveMasker.maskText(input), input);
    });

    test('masks the final domain label in URLs and email addresses', () {
      const input = 'https://api.example.com/path user@example.com';

      final masked = SensitiveMasker.maskText(input);

      expect(masked, isNot(contains('.com')));
      expect(masked, contains('c*m'));
    });

    test('masks named target port fields without hiding other numbers', () {
      const input = 'target_port: 30202\nlatency: 48ms';

      final masked = SensitiveMasker.maskText(input);

      expect(masked, contains('target_port: 3***2'));
      expect(masked, isNot(contains('30202')));
      expect(masked, contains('latency: 48ms'));
    });

    test('masks ports while retaining only their first and final digits', () {
      expect(SensitiveMasker.maskPort('10086'), '1***6');
      expect(SensitiveMasker.maskPort('80'), '8*');
    });

    test('masks endpoint domains, IP addresses, and explicit ports', () {
      expect(
        SensitiveMasker.maskEndpoint('https://api.fastcat.wang:43210/path'),
        'https://a*i.f*****t.w**g:4***0',
      );
      expect(
        SensitiveMasker.maskEndpoint('http://114.117.243.88:4321'),
        'http://114.***.***.88:4**1',
      );
      expect(
        SensitiveMasker.maskUrl('https://api.fastcat.wang:43210/token/value'),
        isNot(contains('43210')),
      );
    });
  });
}
