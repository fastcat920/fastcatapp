import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/models/invite.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/withdraw_dialog.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Invite extends InviteNotifier {
  final pending = Completer<bool>();
  final amounts = <int>[];
  String? method;
  String? account;

  @override
  InviteState build() => const InviteState(
        inviteData: DomainInvite(stats: InviteStats(availableCommission: 1000)),
        withdrawEnabled: true,
        withdrawMethods: ['Alipay'],
      );

  @override
  Future<bool> withdrawCommission(
      {required int amountInCents,
      required String withdrawMethod,
      required String withdrawAccount}) {
    amounts.add(amountInCents);
    method = withdrawMethod;
    account = withdrawAccount;
    return pending.future;
  }
}

Widget _app(_Invite invite, Locale locale) => ProviderScope(
      overrides: [inviteProvider.overrideWith(() => invite)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const Scaffold(body: WithdrawDialog()),
      ),
    );

void main() {
  for (final locale in [const Locale('zh', 'CN'), const Locale('en')]) {
    testWidgets('validates and submits custom amount in $locale',
        (tester) async {
      final invite = _Invite();
      await tester.pumpWidget(_app(invite, locale));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.current;
      final amount = find.byKey(const ValueKey('withdraw-amount'));
      expect(find.text(l10n.xboardWithdrawAmount), findsOneWidget);
      for (final value in ['', '0', '-1', '1.001', '1000.01']) {
        await tester.enterText(amount, value);
        await tester.tap(find.text(l10n.submit));
        await tester.pumpAndSettle();
        expect(
            find.text(value == '1000.01'
                ? l10n.xboardWithdrawAmountExceeded('1000.00')
                : l10n.xboardInvalidWithdrawAmount),
            findsOneWidget);
        expect(invite.amounts, isEmpty);
      }
      await tester.enterText(amount, '100.50');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alipay').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('withdraw-account')), ' test-account ');
      await tester.ensureVisible(find.text(l10n.submit));
      await tester.tap(find.text(l10n.submit));
      await tester.pump();
      expect(invite.amounts, [10050]);
      expect(invite.method, 'Alipay');
      expect(invite.account, 'test-account');
      expect(find.text(l10n.submit), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      invite.pending.complete(false);
      await tester.pump();
    });
  }
  testWidgets('amount form scrolls on short screens with the keyboard open',
      (tester) async {
    tester.view.physicalSize = const Size(400, 520);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final invite = _Invite();
    await tester.pumpWidget(_app(invite, const Locale('zh', 'CN')));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
