import 'dart:async';
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/features/mine/pages/account_info_page.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_usage_card.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/tv_subscription_info_card.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends XBoardUserAuthNotifier {
  int refreshes = 0;
  bool? importRequested;
  final refreshGate = Completer<void>();
  @override
  Future<void> refreshSubscriptionInfo(
      {bool importProfile = true, String source = '手动刷新'}) async {
    refreshes++;
    importRequested = importProfile;
    await refreshGate.future;
  }

  @override
  UserAuthState build() =>
      const UserAuthState(email: 'test@example.com', isInitialized: true);
}

class _Plans extends XBoardSubscriptionNotifier {
  @override
  List<DomainPlan> build() => [];
}

class _Reminders extends _Auth {
  final expiry = Completer<bool>();
  final traffic = Completer<bool>();
  @override
  Future<bool> updateReminderSettings(
          {bool? remindExpire, bool? remindTraffic}) =>
      remindExpire != null ? expiry.future : traffic.future;
}

void main() {
  testWidgets('each reminder stays busy until its own request completes',
      (tester) async {
    system.setTVForTesting(false);
    final container = ProviderContainer(overrides: [
      xboardUserProvider.overrideWith(_Reminders.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AccountInfoPage(),
      ),
    ));
    await tester.pumpAndSettle();
    List<SwitchListTile> switches() =>
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    switches()[0].onChanged!(false);
    switches()[1].onChanged!(false);
    await tester.pump();
    expect(switches().every((tile) => tile.onChanged == null), isTrue);
    final auth = container.read(xboardUserProvider.notifier) as _Reminders;
    auth.expiry.complete(true);
    await tester.pump();
    expect(switches()[0].onChanged, isNotNull);
    expect(switches()[1].onChanged, isNull);
    auth.traffic.complete(true);
    await tester.pumpAndSettle();
    expect(switches().every((tile) => tile.onChanged != null), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
    testWidgets(
        'TV account shows only email, read-only plan and account actions: $locale',
        (tester) async {
      system.setTVForTesting(true);
      addTearDown(() => system.setTVForTesting(false));
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final subscription = DomainSubscription(
          subscribeUrl: '',
          email: 'test@example.com',
          uuid: 'test',
          planId: 1,
          planName: 'Test plan',
          transferLimit: 100000000000,
          uploadedBytes: 1000,
          downloadedBytes: 2000,
          expiredAt: DateTime.now().add(const Duration(days: 30)));
      final container = ProviderContainer(overrides: [
        xboardUserProvider.overrideWith(_Auth.new),
        xboardSubscriptionProvider.overrideWith(_Plans.new),
        currentProfileProvider.overrideWith((_) => null),
        subscriptionInfoProvider.overrideWith((_) => subscription),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: const AccountInfoPage(),
          )));
      await tester.pumpAndSettle();
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.byType(TVSubscriptionInfoCard), findsOneWidget);
      final card = tester
          .widget<SubscriptionUsageCard>(find.byType(SubscriptionUsageCard));
      expect(card.showActions, isFalse);
      expect(card.profileSubscriptionInfo?.total, subscription.transferLimit);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text(AppLocalizations.current.xboardLogout), findsOneWidget);
      expect(find.text(locale.languageCode == 'zh' ? '注销账号' : 'Delete account'),
          findsOneWidget);
      expect(find.byType(TVFocusable), findsNWidgets(4));
      expect(
          find.ancestor(
              of: find.byType(TVSubscriptionInfoCard),
              matching: find.byType(Card)),
          findsNothing);
      final auth = container.read(xboardUserProvider.notifier) as _Auth;
      final refresh = find.byKey(const Key('tv-account-plan-refresh'));
      final planTitle =
          find.descendant(of: refresh, matching: find.text('Test plan'));
      final spinner = find.descendant(
          of: refresh, matching: find.byType(CircularProgressIndicator));
      final planHeight = tester.getSize(refresh).height;
      final titleBounds = tester.getRect(planTitle);
      expect(planHeight, 148);
      expect(spinner, findsNothing);
      await tester.tap(refresh);
      await tester.tap(refresh);
      await tester.pump();
      expect(auth.refreshes, 1);
      expect(tester.getSize(refresh).height, planHeight);
      expect(tester.getRect(planTitle), titleBounds);
      expect(spinner, findsOneWidget);
      expect(tester.getCenter(spinner).dx,
          greaterThan(tester.getCenter(refresh).dx));
      expect(
          tester.getCenter(spinner).dy, lessThan(tester.getCenter(refresh).dy));
      expect(find.text(AppLocalizations.current.xboardSyncingSubscription),
          findsNothing);
      expect(auth.importRequested, isFalse);
      expect(
          tester
              .widget<SubscriptionUsageCard>(find.byType(SubscriptionUsageCard))
              .isSyncing,
          isTrue);
      container.read(subscriptionInfoProvider.notifier).state =
          subscription.copyWith(downloadedBytes: 123456);
      auth.refreshGate.complete();
      await tester.pumpAndSettle();
      expect(tester.getSize(refresh).height, planHeight);
      expect(spinner, findsNothing);
      final updated = tester
          .widget<SubscriptionUsageCard>(find.byType(SubscriptionUsageCard));
      expect(updated.isSyncing, isFalse);
      expect(updated.subscriptionInfo?.downloadedBytes, 123456);
      expect(tester.takeException(), isNull);
    });
  }
}
