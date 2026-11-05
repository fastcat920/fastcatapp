import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_status_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => system.setTVForTesting(false));

  for (final isTv in [true, false]) {
    for (final scenario in [
      (SubscriptionStatusType.noSubscription, false),
      (SubscriptionStatusType.expired, false),
      (SubscriptionStatusType.exhausted, false),
      (SubscriptionStatusType.exhausted, true),
    ]) {
      testWidgets('subscription actions TV=$isTv scenario=$scenario',
          (tester) async {
        system.setTVForTesting(isTv);
        var purchases = 0;
        var recoveries = 0;
        var refreshes = 0;
        String? result;
        late BuildContext pageContext;
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Builder(builder: (context) {
            pageContext = context;
            return const Scaffold();
          }),
        ));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(pageContext);
        Future<void> openDialog() async {
          result = await SubscriptionStatusDialog.show(
            pageContext,
            SubscriptionStatusResult(
              type: scenario.$1,
              messageBuilder: (_) => 'Subscription unavailable',
            ),
            useNewPeriod: scenario.$2,
            onPurchase: () {
              purchases++;
            },
            onTrafficRecovery: () {
              recoveries++;
            },
            onRefresh: () {
              refreshes++;
            },
          );
        }

        final dialog = openDialog();
        await tester.pumpAndSettle();
        final actionLabel = switch (scenario.$1) {
          SubscriptionStatusType.noSubscription => l10n.xboardBuyPlan,
          SubscriptionStatusType.expired => l10n.xboardRenewPlan,
          _ =>
            scenario.$2 ? l10n.xboardStartNewPeriod : l10n.xboardResetTraffic,
        };
        if (isTv) {
          for (final label in [
            l10n.xboardBuyPlan,
            l10n.xboardRenewPlan,
            l10n.xboardResetTraffic,
          ]) {
            expect(find.text(label), findsNothing);
          }
          final hasRefresh =
              scenario.$1 != SubscriptionStatusType.noSubscription;
          final hasNewPeriod =
              scenario.$1 == SubscriptionStatusType.exhausted && scenario.$2;
          expect(find.text(l10n.xboardStartNewPeriod),
              hasNewPeriod ? findsOneWidget : findsNothing);
          expect(find.byType(TVFocusable),
              findsNWidgets(1 + (hasRefresh ? 1 : 0) + (hasNewPeriod ? 1 : 0)));
          // The default remote action must dismiss, not open checkout.
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
          await tester.pumpAndSettle();
          await dialog;
          expect(result, 'later');
          expect(purchases, 0);
          expect(recoveries, 0);
          if (hasRefresh) {
            final reopened = openDialog();
            await tester.pumpAndSettle();
            await tester.tap(find.text(l10n.xboardRefreshStatus));
            await tester.pumpAndSettle();
            await reopened;
            expect(refreshes, 1);
            expect(result, 'refresh');
          }
          if (hasNewPeriod) {
            final reopened = openDialog();
            await tester.pumpAndSettle();
            await tester.tap(find.text(l10n.xboardStartNewPeriod));
            await tester.pumpAndSettle();
            await reopened;
            expect(recoveries, 1);
            expect(purchases, 0);
          }
        } else {
          // Phone/desktop retain purchase and traffic-recovery actions.
          expect(find.text(actionLabel), findsOneWidget);
          await tester.tap(find.text(actionLabel));
          await tester.pumpAndSettle();
          await dialog;
          final isRecovery = scenario.$1 == SubscriptionStatusType.exhausted;
          expect(result, isRecovery ? 'reset_traffic' : 'purchase');
          expect(purchases, isRecovery ? 0 : 1);
          expect(recoveries, isRecovery ? 1 : 0);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
