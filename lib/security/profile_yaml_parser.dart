import 'package:yaml/yaml.dart';

/// Compatibility parser for an older native core that does not yet implement
/// `getConfigContent`. Parsing remains in memory and never creates YAML files.
Map<String, dynamic> parseProfileYaml(String content) {
  final document = loadYaml(content);
  if (document is! YamlMap) {
    throw const FormatException('Profile root must be a YAML mapping');
  }
  return _yamlMapToDart(document);
}

Map<String, dynamic> _yamlMapToDart(YamlMap value) => Map<String, dynamic>.from(
      value.map(
        (key, dynamic item) => MapEntry(
          key.toString(),
          _yamlValueToDart(item),
        ),
      ),
    );

dynamic _yamlValueToDart(dynamic value) {
  if (value is YamlMap) return _yamlMapToDart(value);
  if (value is YamlList) return value.map(_yamlValueToDart).toList();
  return value;
}
