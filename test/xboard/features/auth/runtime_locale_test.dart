import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/profile/models/import_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime import labels follow the selected language', () async {
    for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
      final l10n = await AppLocalizations.load(locale);
      for (final status in ImportStatus.values) {
        final text = ImportState(status: status).statusText;
        expect(text, isNotEmpty);
        expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(text),
            locale.languageCode == 'zh');
      }
      expect(const ImportState(status: ImportStatus.success).statusText,
          l10n.xboardImportSuccess);
      expect(l10n.xboardCoreVerifying, isNotEmpty);
      expect(l10n.xboardCameraPermissionDenied, isNotEmpty);
    }
  });
}
