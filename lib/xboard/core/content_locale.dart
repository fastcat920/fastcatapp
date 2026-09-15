import 'dart:ui';

/// The API only supports Chinese and English content.  Keep this conversion in
/// one place so system locales such as zh-Hant and Japanese consistently use
/// the Chinese content supplied by the panel.
String xboardContentLocale(String? configuredLocale) {
  final configured = configuredLocale?.trim().replaceAll('_', '-');
  final language = (configured == null || configured.isEmpty)
      ? PlatformDispatcher.instance.locale.languageCode
      : configured.split('-').first;
  return language.toLowerCase() == 'en' ? 'en-US' : 'zh-CN';
}
