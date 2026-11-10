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
  @override
  UserAuthState build() =>
      const UserAuthState(email: 'test@example.com', isInitialized: true);
}

class _Plans extends XBoardSubscriptionNotifier {
  @override
  List<DomainPlan> build() => [];
}

void main() {
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
      expect(find.byType(TVFocusable), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }
}
