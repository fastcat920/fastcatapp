import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keep the saved preference as "system"; resolve the native TV snapshot only
/// at the application boundary. Mobile and desktop retain Flutter's behavior.
abstract final class AndroidTvTheme {
  static const channel = MethodChannel('fastcat/tv_theme');
  static Future<Brightness?> readSystemBrightness() async {
    try {
      return switch (await channel.invokeMethod<String>('systemBrightness')) {
        'dark' => Brightness.dark,
        'light' => Brightness.light,
        _ => null,
      };
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static ThemeMode materialMode(ThemeMode selected, Brightness brightness,
      {required bool isTV}) {
    if (!isTV || selected != ThemeMode.system) return selected;
    return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }
}
