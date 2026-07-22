import 'package:fl_clash/common/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('softens ordinary titles and labels without changing body text', () {
    final typography = buildAppTypography(
      platform: TargetPlatform.android,
      colorScheme: const ColorScheme.light(),
    );

    for (final theme in [
      typography.englishLike,
      typography.dense,
      typography.tall,
    ]) {
      expect(theme.titleMedium?.fontWeight, FontWeight.w400);
      expect(theme.titleSmall?.fontWeight, FontWeight.w400);
      expect(theme.labelLarge?.fontWeight, FontWeight.w400);
      expect(theme.labelMedium?.fontWeight, FontWeight.w400);
      expect(theme.labelSmall?.fontWeight, FontWeight.w400);
      expect(theme.bodyLarge?.fontWeight, FontWeight.w400);
      expect(theme.bodyMedium?.fontWeight, FontWeight.w400);
      expect(theme.bodySmall?.fontWeight, FontWeight.w400);
    }
  });

  test('keeps major headings at their Material weights', () {
    final typography = buildAppTypography(
      platform: TargetPlatform.android,
      colorScheme: const ColorScheme.dark(),
    );

    expect(typography.dense.titleLarge?.fontWeight, FontWeight.w400);
    expect(typography.dense.headlineMedium?.fontWeight, FontWeight.w400);
  });
}
