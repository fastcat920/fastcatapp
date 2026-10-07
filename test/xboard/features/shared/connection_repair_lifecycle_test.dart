import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/widgets/connection_health_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _marker = Provider<String>((ref) => 'container still alive');

void main() {
  testWidgets('repair survives source page disposal and reads app container',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = Completer<void>();
    Future<void>? repair;
    String? readAfterDispose;
    var calls = 0;
    Widget app({required bool showPage}) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            home: showPage
                ? Builder(
                    builder: (context) => Scaffold(
                          body: TextButton(
                              onPressed: () {
                                repair = showConnectionRepair(context,
                                    repairOperation: (appContainer) async {
                                  calls++;
                                  await gate.future;
                                  readAfterDispose = appContainer.read(_marker);
                                  return null;
                                });
                              },
                              child: const Text('Repair')),
                        ))
                : const Scaffold(body: Text('Another page')),
          ),
        );
    await tester.pumpWidget(app(showPage: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始修复'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.pumpWidget(app(showPage: false));
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    await repair;
    expect(readAfterDispose, 'container still alive');
    expect(tester.takeException(), isNull);
  });
}
