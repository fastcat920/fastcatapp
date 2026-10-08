import 'package:flutter/material.dart';

/// Shared by themed text and explicit dialog styles, which replace rather
/// than merge the theme's body style in AlertDialog.
///
/// Keep emoji fonts out of ordinary text fallback. The bundled Twemoji font
/// maps bare digits, # and * to empty keycap component glyphs; on OEM devices
/// that select it as a fallback, numbers disappear. EmojiText selects Twemoji
/// explicitly for emoji spans instead.
const appFontFamilyFallback = [
  'Noto Sans CJK SC',
  'Noto Sans CJK',
  'Noto Sans SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
  'Microsoft YaHei',
  'PingFang SC',
  'Arial Unicode MS',
  'sans-serif',
];

const appDialogTitleStyle = TextStyle(
  fontFamilyFallback: appFontFamilyFallback,
  color: Color(0xFF1A2138),
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

const appDialogContentStyle = TextStyle(
  fontFamilyFallback: appFontFamilyFallback,
  color: Color(0xFF475467),
  fontSize: 14,
  height: 1.45,
);

/// Keeps the system font while softening Material's medium-weight labels.
///
/// Newer Flutter engines map font weights more precisely on Android variable
/// fonts. Reducing ordinary titles and labels from w500 to w400 restores the
/// previous visual balance without changing intentionally emphasized text.
Typography buildAppTypography({
  required TargetPlatform platform,
  required ColorScheme colorScheme,
}) {
  final base = Typography.material2021(
    platform: platform,
    colorScheme: colorScheme,
  );
  return base.copyWith(
    englishLike: softenAppTextTheme(base.englishLike),
    dense: softenAppTextTheme(base.dense),
    tall: softenAppTextTheme(base.tall),
  );
}

TextTheme softenAppTextTheme(TextTheme theme) {
  return theme.copyWith(
    titleMedium: theme.titleMedium?.copyWith(fontWeight: FontWeight.w400),
    titleSmall: theme.titleSmall?.copyWith(fontWeight: FontWeight.w400),
    labelLarge: theme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
    labelMedium: theme.labelMedium?.copyWith(fontWeight: FontWeight.w400),
    labelSmall: theme.labelSmall?.copyWith(fontWeight: FontWeight.w400),
  );
}
