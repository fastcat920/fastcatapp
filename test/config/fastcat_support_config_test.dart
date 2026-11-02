import 'package:fl_clash/xboard/config/utils/config_file_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled FastCat Support fallback is complete and uses HTTPS', () async {
    final config = await ConfigFileLoaderHelper.getFallbackFastCatSupport();

    expect(config['enabled'], isTrue);
    final baseUrl = Uri.parse(config['base_url'] as String);
    expect(baseUrl.scheme, 'https');
    expect(baseUrl.host, isNotEmpty);
    expect((config['app_key'] as String).trim(), isNotEmpty);
  });
}
