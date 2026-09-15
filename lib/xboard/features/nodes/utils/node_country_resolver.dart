class NodeCountryResolver {
  const NodeCountryResolver._();

  static const String unknownFlag = '🌐';

  static final RegExp _existingFlag = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}]{2}',
    unicode: true,
  );

  static const List<_CountryRule> _rules = [
    _CountryRule('🇭🇰', ['香港', 'HONG KONG'], ['HK', 'HKG']),
    _CountryRule('🇲🇴', ['澳门', '澳門', 'MACAU', 'MACAO'], ['MO', 'MAC']),
    _CountryRule('🇹🇼', ['台湾', '台灣', 'TAIWAN'], ['TW', 'TWN']),
    _CountryRule('🇨🇳', ['中国', '中國', 'CHINA'], ['CN', 'CHN']),
    _CountryRule('🇯🇵', ['日本', 'JAPAN', 'TOKYO', 'OSAKA'], ['JP', 'JPN']),
    _CountryRule('🇸🇬', ['新加坡', 'SINGAPORE'], ['SG', 'SGP']),
    _CountryRule('🇰🇷', ['韩国', '韓國', 'KOREA', 'SEOUL'], ['KR', 'KOR']),
    _CountryRule(
        '🇺🇸', ['美国', '美國', 'UNITED STATES', 'AMERICA'], ['US', 'USA']),
    _CountryRule('🇨🇦', ['加拿大', 'CANADA'], ['CA', 'CAN']),
    _CountryRule(
        '🇬🇧', ['英国', '英國', 'UNITED KINGDOM', 'BRITAIN'], ['UK', 'GB', 'GBR']),
    _CountryRule('🇩🇪', ['德国', '德國', 'GERMANY'], ['DE', 'DEU']),
    _CountryRule('🇫🇷', ['法国', '法國', 'FRANCE'], ['FR', 'FRA']),
    _CountryRule('🇳🇱', ['荷兰', '荷蘭', 'NETHERLANDS', 'HOLLAND'], ['NL', 'NLD']),
    _CountryRule('🇷🇺', ['俄罗斯', '俄羅斯', 'RUSSIA'], ['RU', 'RUS']),
    _CountryRule('🇦🇺', ['澳大利亚', '澳大利亞', 'AUSTRALIA'], ['AU', 'AUS']),
    _CountryRule('🇮🇳', ['印度', 'INDIA'], ['IN', 'IND']),
    _CountryRule('🇹🇭', ['泰国', '泰國', 'THAILAND'], ['TH', 'THA']),
    _CountryRule('🇲🇾', ['马来西亚', '馬來西亞', 'MALAYSIA'], ['MY', 'MYS']),
    _CountryRule('🇵🇭', ['菲律宾', '菲律賓', 'PHILIPPINES'], ['PH', 'PHL']),
    _CountryRule('🇮🇩', ['印度尼西亚', '印尼', 'INDONESIA'], ['ID', 'IDN']),
    _CountryRule('🇻🇳', ['越南', 'VIETNAM'], ['VN', 'VNM']),
    _CountryRule('🇧🇷', ['巴西', 'BRAZIL'], ['BR', 'BRA']),
    _CountryRule('🇹🇷', ['土耳其', 'TURKEY', 'TÜRKIYE'], ['TR', 'TUR']),
    _CountryRule(
        '🇦🇪', ['阿联酋', '阿聯酋', 'UNITED ARAB EMIRATES', 'DUBAI'], ['AE', 'UAE']),
  ];

  static String resolveFlag(String nodeName) {
    final existing = _existingFlag.firstMatch(nodeName)?.group(0);
    if (existing != null) return existing;

    final normalized = nodeName.toUpperCase();
    final tokens = normalized
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((value) => value.isNotEmpty)
        .toSet();
    for (final rule in _rules) {
      if (rule.phrases.any(normalized.contains) ||
          rule.codes.any(tokens.contains)) {
        return rule.flag;
      }
    }
    return unknownFlag;
  }
}

class _CountryRule {
  const _CountryRule(this.flag, this.phrases, this.codes);

  final String flag;
  final List<String> phrases;
  final List<String> codes;
}
