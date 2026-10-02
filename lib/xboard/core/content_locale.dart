import 'dart:ui';

/// The API only supports Chinese and English content.  Keep this conversion in
/// one place, matching MaterialApp's English fallback for unsupported locales.
String xboardContentLocale(String? configuredLocale) {
  final configured = configuredLocale?.trim().replaceAll('_', '-');
  final language = (configured == null || configured.isEmpty)
      ? PlatformDispatcher.instance.locale.languageCode
      : configured.split('-').first;
  return language.toLowerCase() == 'zh' ? 'zh-CN' : 'en-US';
}
