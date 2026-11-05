import 'package:fl_clash/xboard/features/settings/utils/dns_server_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts supported plain and encrypted DNS endpoints', () {
    expect(
      validateDnsServerEntries(const [
        '1.1.1.1',
        '1.1.1.1:53',
        '[2606:4700:4700::1111]:53',
        'https://dns.alidns.com/dns-query',
        'tls://dns.google:853',
        'quic://dns.adguard-dns.com',
        'system://',
        'https://dns.google/dns-query#h3=true',
      ]),
      isNull,
    );
  });

  test('does not accept h3 as a protocol unsupported by the bundled core', () {
    expect(validateDnsServerEntries(['h3://dns.google/dns-query']), isNotNull);
    expect(validateDnsServerEntries(['1.1.1.1:53/unexpected']), isNotNull);
  });

  test('rejects unsafe or malformed endpoints with a line number', () {
    final error = validateDnsServerEntries(const [
      '1.1.1.1',
      'https://user:password@dns.example/dns-query',
    ]);
    expect(error?.line, 2);
  });

  test('default nameservers can be restricted to literal IP endpoints', () {
    expect(
      validateDnsServerEntries(
        const ['https://dns.alidns.com/dns-query'],
        ipOnly: true,
      ),
      isNotNull,
    );
    expect(
      validateDnsServerEntries(const ['223.5.5.5'], ipOnly: true),
      isNull,
    );
  });
}
