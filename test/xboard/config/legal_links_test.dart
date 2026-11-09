import 'package:fl_clash/xboard/config/models/legal_links.dart';
import 'package:fl_clash/xboard/config/parsers/configuration_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final local = LegalLinks.fromJson({
    'privacy_policy_url': 'https://local.example/privacy',
    'terms_of_service_url': 'https://local.example/terms',
  });
  test('OSS links override individually and malformed fields fall back', () {
    for (final invalid in [null, '', 12, [], 'javascript:alert(1)', '/terms',
      'https://user:password@example.com/terms', 'https://bad host/terms']) {
      final resolved = LegalLinks.fromJson({
        'privacy_policy_url': ' https://oss.example/privacy ',
        'terms_of_service_url': invalid,
      }).fallbackTo(local);
      expect(resolved.privacyPolicy.toString(), 'https://oss.example/privacy');
      expect(resolved.termsOfService, local.termsOfService);
    }
    expect(LegalLinks.fromJson([]).fallbackTo(local).privacyPolicy, local.privacyPolicy);
  });
  test('OSS normalization preserves legal links across supported formats', () {
    final parser = ConfigurationParser();
    final legal = {'privacy_policy_url': 'https://oss.example/privacy'};
    for (final document in [
      {'domains': ['https://api.example'], 'legal': legal},
      {'panels': {'xboard': []}, 'legal': legal},
      {'panel_urls': ['https://api.example'], 'legal': legal},
    ]) {
      expect(parser.extractConfigFromRemoteResult(document)!['legal'], legal);
    }
  });
}
