import 'package:flutter/material.dart';

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
