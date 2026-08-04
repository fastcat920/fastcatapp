import 'package:fl_clash/xboard/features/auth/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpResponsiveScaffold(
    WidgetTester tester, {
    required double height,
    double keyboardInset = 0,
    bool isDesktop = false,
  }) async {
    await tester.binding.setSurfaceSize(Size(900, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                viewInsets: EdgeInsets.only(bottom: keyboardInset),
              ),
              child: LoginResponsiveScaffold(
                appBar: AppBar(key: const Key('login-page-app-bar')),
                isDesktop: isDesktop,
                body: const Form(
                  child: Text('登录表单'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('shows the app bar when vertical space is sufficient',
      (tester) async {
    await pumpResponsiveScaffold(tester, height: 800);

    expect(find.byKey(const Key('login-page-app-bar')), findsOneWidget);
  });

  testWidgets('hides the app bar when vertical space is insufficient',
      (tester) async {
    await pumpResponsiveScaffold(tester, height: 560);

    expect(find.byKey(const Key('login-page-app-bar')), findsNothing);
    expect(find.byType(Form), findsOneWidget);
  });

  testWidgets('keeps the app bar when the keyboard opens at sufficient height',
      (tester) async {
    await pumpResponsiveScaffold(tester, height: 800, keyboardInset: 300);

    expect(find.byKey(const Key('login-page-app-bar')), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);
  });

  testWidgets('always shows the default-height app bar on desktop',
      (tester) async {
    await pumpResponsiveScaffold(
      tester,
      height: 560,
      keyboardInset: 300,
      isDesktop: true,
    );

    final appBar = find.byKey(const Key('login-page-app-bar'));
    expect(appBar, findsOneWidget);
    expect(tester.getSize(appBar).height, kToolbarHeight);
  });
}
