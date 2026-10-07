import 'package:fl_clash/common/app_typography.dart';
import 'package:fl_clash/xboard/features/shared/styles/font_weights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Linux dialog body retains the same CJK fallback as themed text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        platform: TargetPlatform.linux,
        fontFamilyFallback: appFontFamilyFallback,
        dialogTheme: const DialogThemeData(
          titleTextStyle: appDialogTitleStyle,
          contentTextStyle: appDialogContentStyle,
        ),
      ),
      home: const Scaffold(
          body: AlertDialog(
        title: Text('登录保护已开启'),
        content: Text('当前服务连接异常，退出后可能暂时无法重新登录。'),
      )),
    ));
    final bodyContext = tester.element(find.text('当前服务连接异常，退出后可能暂时无法重新登录。'));
    expect(DefaultTextStyle.of(bodyContext).style.fontFamilyFallback,
        appFontFamilyFallback);
    expect(DefaultTextStyle.of(bodyContext).style.fontSize, 14);
    expect(appDialogTitleStyle.fontFamilyFallback, appFontFamilyFallback);
    expect(tester.takeException(), isNull);
  });

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

  test('uses softened explicit emphasis weights for variable fonts', () {
    expect(XbFontWeight.regular, FontWeight.w400);
    expect(XbFontWeight.medium, FontWeight.w500);
    expect(XbFontWeight.semibold, FontWeight.w500);
    expect(XbFontWeight.bold, FontWeight.w500);
    expect(XbFontWeight.heavy, FontWeight.w500);
  });
}
