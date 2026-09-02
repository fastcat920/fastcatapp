import 'package:fl_clash/xboard/features/nodes/utils/node_country_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps an existing flag', () {
    expect(NodeCountryResolver.resolveFlag('🇯🇵 日本 01'), '🇯🇵');
  });

  test('recognizes localized country names', () {
    expect(NodeCountryResolver.resolveFlag('香港高速节点'), '🇭🇰');
    expect(NodeCountryResolver.resolveFlag('澳门节点'), '🇲🇴');
    expect(NodeCountryResolver.resolveFlag('Singapore Premium'), '🇸🇬');
  });

  test('recognizes standalone country codes case-insensitively', () {
    expect(NodeCountryResolver.resolveFlag('us-01'), '🇺🇸');
    expect(NodeCountryResolver.resolveFlag('Node_HKG_02'), '🇭🇰');
  });

  test('does not match a country code embedded in another word', () {
    expect(
      NodeCountryResolver.resolveFlag('RUSH server'),
      NodeCountryResolver.unknownFlag,
    );
  });

  test('uses globe for an unknown node', () {
    expect(
      NodeCountryResolver.resolveFlag('专线节点 01'),
      NodeCountryResolver.unknownFlag,
    );
  });
}
