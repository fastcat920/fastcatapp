import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:fl_clash/xboard/features/shared/widgets/node_recovery_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => system.setTVForTesting(false));

  for (final brightness in Brightness.values) {
    testWidgets('TV recovery focus follows button shape in $brightness',
        (tester) async {
      system.setTVForTesting(true);
      var reloads = 0;
      var switches = 0;
      var busy = false;
      late StateSetter update;
      final scheme =
          ColorScheme.fromSeed(seedColor: Colors.blue, brightness: brightness);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: Center(child: StatefulBuilder(builder: (context, setState) {
            update = setState;
            return NodeRecoveryActions(
              isBusy: busy,
              onReload: () => reloads++,
              onSwitch: () => switches++,
            );
          })),
        ),
      ));
      await tester.pumpAndSettle();

      final wrappers = find.byType(TVFocusable);
      final first = tester.widget<Focus>(find
          .descendant(
            of: wrappers.at(0),
            matching: find.byType(Focus),
          )
          .first);
      first.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(first.focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(reloads, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(switches, 1);

      for (var index = 0; index < 2; index++) {
        final wrapper = wrappers.at(index);
        final focus = tester.widget<Focus>(
            find.descendant(of: wrapper, matching: find.byType(Focus)).first);
        focus.focusNode!.requestFocus();
        await tester.pumpAndSettle();
        final outline = tester.widget<AnimatedContainer>(find
            .descendant(of: wrapper, matching: find.byType(AnimatedContainer))
            .first);
        final decoration = outline.foregroundDecoration! as ShapeDecoration;
        final buttonFinder = find.descendant(
            of: wrapper,
            matching: find
                .byWidgetPredicate((widget) => widget is ButtonStyleButton));
        final material = tester.widget<Material>(find
            .descendant(of: buttonFinder, matching: find.byType(Material))
            .first);
        final shape = material.shape! as RoundedRectangleBorder;
        expect((decoration.shape as RoundedRectangleBorder).borderRadius,
            shape.borderRadius);
        expect((decoration.shape as OutlinedBorder).side.width, 2);
        expect((decoration.shape as OutlinedBorder).side.color,
            index == 0 ? scheme.primary : scheme.onPrimary);
        expect(tester.getSize(wrapper), tester.getSize(buttonFinder));
      }

      update(() => busy = true);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.tap(wrappers.first);
      expect(reloads, 1);
      expect(switches, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
