import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

// Regenerate intentionally with:
// flutter test test/design/shared_tv_contract_test.dart --dart-define=UPDATE_TV_CONTRACT=true
void main() {
  test('tvOS theme and unambiguous shared copy match Flutter resources', () {
    final config =
        loadYaml(File('assets/config/config.yaml').readAsStringSync()) as Map;
    final color = config['theme_color'] as String;
    final seed = Color(0xff000000 | int.parse(color.substring(1), radix: 16));
    Map<String, int> palette(Brightness brightness) {
      final c = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.content);
      return {
        'primary': c.primary.toARGB32(),
        'onPrimary': c.onPrimary.toARGB32(),
        'primaryContainer': c.primaryContainer.toARGB32(),
        'onPrimaryContainer': c.onPrimaryContainer.toARGB32(),
        'surface': c.surface.toARGB32(),
        'surfaceContainerLow': c.surfaceContainerLow.toARGB32(),
        'surfaceContainer': c.surfaceContainer.toARGB32(),
        'surfaceContainerHighest': c.surfaceContainerHighest.toARGB32(),
        'onSurface': c.onSurface.toARGB32(),
        'onSurfaceVariant': c.onSurfaceVariant.toARGB32(),
        'outline': c.outline.toARGB32(),
        'outlineVariant': c.outlineVariant.toARGB32(),
        'error': c.error.toARGB32(),
        'errorContainer': c.errorContainer.toARGB32(),
      };
    }

    final zh = jsonDecode(File('arb/intl_zh_CN.arb').readAsStringSync()) as Map;
    final en = jsonDecode(File('arb/intl_en.arb').readAsStringSync()) as Map;
    expect(zh.keys.where((k) => !k.toString().startsWith('@')).toSet(),
        en.keys.where((k) => !k.toString().startsWith('@')).toSet());
    final candidates = <String, Set<String>>{};
    for (final key in zh.keys) {
      final chinese = zh[key];
      final english = en[key];
      if (key.toString().startsWith('@') ||
          chinese is! String ||
          english is! String ||
          chinese.contains('{') ||
          english.contains('{')) {
        continue;
      }
      candidates.putIfAbsent(chinese, () => {}).add(english);
    }
    final strings = <String, String>{};
    final keys = candidates.keys.toList()..sort();
    for (final key in keys) {
      if (candidates[key]!.length == 1) strings[key] = candidates[key]!.single;
    }
    final expected = {
      'version': 1,
      'light': palette(Brightness.light),
      'dark': palette(Brightness.dark),
      'strings': strings
    };
    final target = File('assets/config/tv_design_contract.json');
    if (const bool.fromEnvironment('UPDATE_TV_CONTRACT')) {
      target.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(expected)}\n');
    }
    expect(target.existsSync(), isTrue,
        reason: 'Generate the shared tvOS contract');
    expect(jsonDecode(target.readAsStringSync()), expected,
        reason:
            'Regenerate tv_design_contract.json after changing theme or translations');
  });
}
