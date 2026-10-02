import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The app and NetworkExtension have different sandboxes. HTTP provider caches
/// must use paths relative to the core home, never paths in the Flutter app.
Map<String, dynamic> iosProfileConfig(Map<String, dynamic> input) {
  final config = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  for (final kind in ['proxy-providers', 'rule-providers']) {
    final providers = config[kind];
    if (providers is! Map) continue;
    for (final provider in providers.values) {
      if (provider is! Map || provider['type'] != 'http') continue;
      final url = provider['url'];
      if (url is! String || url.isEmpty) continue;
      final id = sha256.convert(utf8.encode(url));
      provider['path'] = 'providers/$kind/$id.yaml';
    }
  }
  return config;
}
