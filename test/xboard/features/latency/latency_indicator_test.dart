import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/latency/widgets/latency_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failure tooltip distinguishes a known timeout', (tester) async {
    Future<void> show({required bool timedOut}) =>
        tester.pumpWidget(MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: LatencyIndicator(delayValue: -1, timedOut: timedOut),
          ),
        ));

    await show(timedOut: false);
    await tester.pumpAndSettle();
    expect(find.byTooltip('测速失败'), findsOneWidget);
    expect(find.byTooltip('超时'), findsNothing);

    await show(timedOut: true);
    await tester.pumpAndSettle();
    expect(find.byTooltip('超时'), findsOneWidget);
    expect(find.byTooltip('测速失败'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('signal states, no visible numbers, and taps: $brightness',
        (tester) async {
      var taps = 0;
      Future<void> show(int? delay) => tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: Scaffold(
                body: LatencyIndicator(delayValue: delay, onTap: () => taps++)),
          ));
      for (final delay in [80, 499, 500, 900, -1]) {
        await show(delay);
        final paint = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<LatencySignalPainter>()
            .single;
        expect(
            paint.activeBars,
            delay < 0
                ? 1
                : delay < 500
                    ? 3
                    : 2);
        expect(paint.failed, delay < 0);
        expect(find.byType(Text), findsNothing);
        await tester.tap(find.byType(LatencyIndicator));
      }
      expect(taps, 5);
      await show(null);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      await show(0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(LatencyIndicator));
      expect(taps, 5);
      expect(tester.takeException(), isNull);
    });
  }
}
