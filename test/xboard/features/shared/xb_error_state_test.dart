import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  Future<void> pumpError(
    WidgetTester tester, {
    required Object? message,
    VoidCallback? onRetry,
    bool compact = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: XbErrorState(
            message: message,
            onRetry: onRetry ?? () {},
            compact: compact,
          ),
        ),
      ),
    );
  }

  testWidgets('hides raw HTML and uses the generic retry message',
      (tester) async {
    await pumpError(
      tester,
      message: '<html><head><title>404 Not Found</title></head></html>',
    );

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('未知错误，请重试'), findsOneWidget);
    expect(find.textContaining('<html>'), findsNothing);
    expect(find.textContaining('404 Not Found'), findsNothing);
  });

  testWidgets('keeps an actionable network message and retry action',
      (tester) async {
    var retries = 0;
    await pumpError(
      tester,
      message: const SocketExceptionForTest(),
      onRetry: () => retries++,
      compact: true,
    );

    expect(find.text('无网络连接，请检查网络设置'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });
}

class SocketExceptionForTest {
  const SocketExceptionForTest();

  @override
  String toString() => 'SocketException: network is unreachable';
}
