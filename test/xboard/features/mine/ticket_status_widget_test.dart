import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/ticket_state.dart';
import 'package:fl_clash/xboard/features/mine/pages/ticket_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/mine/utils/ticket_presentation.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

void main() {
  for (final locale in [const Locale('zh', 'CN'), const Locale('en')]) {
    for (final width in [320.0, 1100.0]) {
      testWidgets('ticket reply layout and actions $locale width=$width',
          (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l10n = await AppLocalizations.load(locale);
        final time = DateTime(2026, 11, 8, 9, 12, 34);
        final detail = TicketDetailModel(
            id: 477,
            level: 1,
            replyStatus: 0,
            status: 0,
            subject: 'fixture ticket',
            createdAt: time,
            updatedAt: time,
            userId: 1,
            messages: [
              TicketMessageModel(
                  id: 1,
                  ticketId: 477,
                  isMe: false,
                  message: 'support response',
                  createdAt: time,
                  updatedAt: time),
              TicketMessageModel(
                  id: 2,
                  ticketId: 477,
                  isMe: true,
                  message: 'visitor reply',
                  createdAt: time,
                  updatedAt: time),
            ]);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              getTicketProvider(477).overrideWith((ref) async => detail)
            ],
            child: MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.delegate.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate
                ],
                home: const TicketDetailPage(ticketId: 477))));
        await tester.pumpAndSettle();
        expect(find.text(l10n.xboardTicketPendingProcessing), findsOneWidget);
        expect(find.text('#477'), findsNothing);
        expect(find.text('2026-11-08 09:12:34'), findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(AppBar),
                matching: find.text(l10n.xboardCloseTicket)),
            findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsNothing);
        expect(tester.getCenter(find.byIcon(Icons.support_agent)).dx,
            lessThan(tester.getCenter(find.byIcon(Icons.person)).dx));
        final send = find.widgetWithIcon(IconButton, Icons.send);
        expect(tester.widget<IconButton>(send).onPressed, isNull);
        final style = tester.widget<IconButton>(send).style!;
        final theme = Theme.of(tester.element(send));
        expect(style.backgroundColor!.resolve({WidgetState.disabled}),
            theme.colorScheme.onSurface.withValues(alpha: 0.12));
        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        expect(tester.widget<IconButton>(send).onPressed, isNull);
        await tester.enterText(find.byType(TextField), 'draft');
        await tester.pump();
        expect(tester.widget<IconButton>(send).onPressed, isNotNull);
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();
        expect(tester.widget<IconButton>(send).onPressed, isNull);
        await tester.tap(find.text(l10n.xboardCloseTicket));
        await tester.pumpAndSettle();
        expect(find.text(l10n.xboardCloseTicketConfirm), findsOneWidget);
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    test('ticket status follows backend reply flag $locale', () async {
      final l10n = await AppLocalizations.load(locale);
      expect(ticketStatusLabel(l10n, 0, 0), l10n.xboardTicketPendingProcessing);
      expect(ticketStatusLabel(l10n, 0, 1), l10n.xboardTicketReplied);
      expect(ticketStatusLabel(l10n, 1, 1), l10n.xboardTicketClosed);
      expect(ticketStatusLabel(l10n, 2, 0), l10n.xboardTicketClosed);
    });
  }

  for (final locale in [const Locale('zh', 'CN'), const Locale('en')]) {
    testWidgets('closed ticket has no reply or close actions: $locale',
        (tester) async {
      final l10n = await AppLocalizations.load(locale);
      final detail = TicketDetailModel(
          id: 477,
          level: 1,
          replyStatus: 0,
          status: 1,
          subject: 'fixture ticket',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          userId: 1,
          messages: []);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            getTicketProvider(477).overrideWith((ref) async => detail),
          ],
          child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate
              ],
              home: const TicketDetailPage(ticketId: 477))));
      await tester.pumpAndSettle();
      expect(find.text(l10n.xboardTicketClosed), findsOneWidget);
      expect(find.text(l10n.xboardTicketClosedMessage), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip(l10n.xboardCloseTicket), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
