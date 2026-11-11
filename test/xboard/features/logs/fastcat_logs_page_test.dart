import 'package:fl_clash/common/common.dart' show system;
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:fl_clash/common/fixed.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/logs/pages/fastcat_logs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Logs extends Logs {
  @override
  FixedList<Log> build() => FixedList(500, list: [
        const Log(
            logLevel: LogLevel.app,
            payload: 'app marker',
            dateTime: '10:00:01'),
        const Log(
            logLevel: LogLevel.debug,
            payload: 'debug marker',
            dateTime: '10:00:02'),
        const Log(
            logLevel: LogLevel.error,
            payload: 'error marker\nsecond line',
            dateTime: '10:00:03'),
        const Log(
            logLevel: LogLevel.warning,
            payload: 'account=test@example.com',
            dateTime: '10:00:04'),
      ]);

  @override
  onUpdate(value) {}
}

void main() {
  testWidgets(
      'TV logs keep toolbar and passive records in remote focus navigation',
      (tester) async {
    system.setTVForTesting(true);
    addTearDown(() => system.setTVForTesting(false));
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [logsProvider.overrideWith(_Logs.new)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const FastCatLogsPage(),
      ),
    ));
    await tester.pumpAndSettle();
    final copy = find.ancestor(
        of: find.byIcon(Icons.content_copy_outlined),
        matching: find.byType(TVFocusable));
    expect(copy, findsOneWidget);
    final row = find.ancestor(
        of: find.text('debug marker'), matching: find.byType(TVFocusable));
    expect(row, findsOneWidget);
    final focus = tester
        .widget<Focus>(
            find.descendant(of: row, matching: find.byType(Focus)).first)
        .focusNode!;
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(find.text('debug marker'), findsOneWidget);
    expect(tester.getRect(find.byType(Card)).left, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'all levels displayed; copy includes all cached logs despite search',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'fastcat_log_level_filter': 'error'});
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = call.arguments['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(ProviderScope(
      overrides: [logsProvider.overrideWith(_Logs.new)],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const FastCatLogsPage(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('app marker'), findsOneWidget);
    expect(find.text('debug marker'), findsOneWidget);
    expect(find.text('error marker\nsecond line'), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    await tester.enterText(find.byType(SearchBar), 'debug marker');
    await tester.pumpAndSettle();
    expect(find.text('app marker'), findsNothing);
    await tester.tap(find.byIcon(Icons.content_copy_outlined));
    await tester.pumpAndSettle();
    expect(clipboard, contains('app marker'));
    expect(clipboard, contains('debug marker'));
    expect(clipboard, contains('error marker\nsecond line'));
    expect(clipboard, isNot(contains('test@example.com')));
    expect(clipboard!.indexOf('app marker'),
        lessThan(clipboard!.indexOf('error marker')));
  });
}
