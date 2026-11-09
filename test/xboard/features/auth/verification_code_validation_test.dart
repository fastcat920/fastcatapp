import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/pages/register_page.dart';
import 'package:fl_clash/xboard/features/auth/providers/config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  testWidgets(
      'registration accepts exactly six ASCII digits without submitting',
      (tester) async {
    final l10n = await AppLocalizations.load(const Locale('en'));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          configProvider.overrideWith(
              (ref) async => const ConfigModel(isEmailVerify: true)),
        ],
        child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: const RegisterPage())));
    await tester.pumpAndSettle();
    final code = find.byType(TextFormField).at(3);
    for (final invalid in [
      'ABCDEF',
      '12345a',
      '１２３４５６',
      '12345',
      '1234567',
      '123 56'
    ]) {
      await tester.enterText(code, invalid);
      final state = tester.state<FormFieldState<String>>(code);
      expect(state.validate(), isFalse, reason: invalid);
      await tester.pump();
      expect(find.text(l10n.verificationCode6Digits), findsOneWidget);
    }
    await tester.enterText(code, '012345');
    expect(tester.state<FormFieldState<String>>(code).validate(), isTrue);
    await tester.pump();
    expect(find.text(l10n.verificationCode6Digits), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
