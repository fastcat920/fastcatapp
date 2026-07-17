import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/xboard/config/utils/theme_config_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeConfigLoader', () {
    test('parses #RRGGBB as opaque ARGB', () {
      expect(ThemeConfigLoader.parseThemeColor('#4566AE'), 0xFF4566AE);
      expect(ThemeConfigLoader.parseThemeColor('#abcdef'), 0xFFABCDEF);
    });

    test('falls back for malformed values', () {
      expect(
        ThemeConfigLoader.parseThemeColor('4566AE'),
        defaultPrimaryColor,
      );
      expect(
        ThemeConfigLoader.parseThemeColor('#12345'),
        defaultPrimaryColor,
      );
      expect(ThemeConfigLoader.parseThemeColor(null), defaultPrimaryColor);
    });
  });
}
