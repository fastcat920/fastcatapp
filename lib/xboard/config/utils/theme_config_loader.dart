import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

final _logger = FileLogger('theme_config_loader.dart');

/// 加载 assets/config/config.yaml 中的客户端统一主题色。
class ThemeConfigLoader {
  static const configPath = 'assets/config/config.yaml';

  static Future<int> loadThemeColor() async {
    try {
      final yamlString = await rootBundle.loadString(configPath);
      final yamlDoc = loadYaml(yamlString);
      return parseThemeColor(
          yamlDoc is YamlMap ? yamlDoc['theme_color'] : null);
    } catch (e) {
      _logger.warning('读取 theme_color 失败，使用默认主题色: $e');
      return defaultPrimaryColor;
    }
  }

  /// 主题色仅接受 #RRGGBB，错误值统一回退到内置默认色。
  static int parseThemeColor(dynamic value) {
    if (value is! String) return defaultPrimaryColor;
    final normalized = value.trim();
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(normalized)) {
      _logger.warning(
        'theme_color 格式无效: $value，应使用 #RRGGBB，已回退默认色',
      );
      return defaultPrimaryColor;
    }
    return 0xFF000000 | int.parse(normalized.substring(1), radix: 16);
  }
}
