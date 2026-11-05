import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/models/auth_state.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/connectivity/models/service_connectivity_state.dart';
import 'package:fl_clash/xboard/features/connectivity/providers/service_connectivity_provider.dart';
import 'package:fl_clash/xboard/features/invite/dialogs/logout_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Avoid real network listeners, initialization and probes in widget tests.
class _Connectivity extends StateNotifier<ServiceConnectivityState>
    implements ServiceConnectivityNotifier {
  _Connectivity(ServiceConnectivityStatus status)
      : super(ServiceConnectivityState(status: status));

  void change(ServiceConnectivityStatus status) {
    state = ServiceConnectivityState(status: status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends XBoardUserAuthNotifier {
  final pending = Completer<void>();
  final forces = <bool>[];
  @override
  UserAuthState build() => const UserAuthState(isAuthenticated: true);

  @override
  Future<void> logout({
    bool allowWhenServiceUnavailable = false,
    bool preserveSavedCredentials = true,
  }) async {
    forces.add(allowWhenServiceUnavailable);
    await pending.future;
  }
}

Widget app(ProviderContainer container, {bool dark = false}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const LogoutDialog(),
                  ),
                  child: const Text('Open'),
                ),
              )),
    ),
  );
}

void main() {
  tearDown(() => system.setTVForTesting(false));
  for (final tv in [false, true]) {
    for (final initiallyOnline in [true, false]) {
      testWidgets(
          'logout copy stays stable and reopens fresh: TV=$tv online=$initiallyOnline',
          (tester) async {
        system.setTVForTesting(tv);
        final connectivity = _Connectivity(initiallyOnline
            ? ServiceConnectivityStatus.online
            : ServiceConnectivityStatus.offline);
        final container = ProviderContainer(overrides: [
          serviceConnectivityProvider.overrideWith((ref) => connectivity),
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(app(container));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.current;
        final title = initiallyOnline
            ? l10n.xboardLogoutConfirmTitle
            : l10n.xboardLogoutProtectedTitle;
        final content = initiallyOnline
            ? l10n.xboardLogoutConfirmContent
            : l10n.xboardLogoutProtectedContent;
        final button =
            initiallyOnline ? l10n.exit : l10n.xboardLogoutForceAction;
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        for (final status in [
          ServiceConnectivityStatus.recovering,
          ServiceConnectivityStatus.degraded,
          ServiceConnectivityStatus.offline,
          ServiceConnectivityStatus.online
        ]) {
          connectivity.change(status);
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          expect(find.text(content), findsOneWidget);
          expect(find.text(button), findsOneWidget);
        }
        // Force an unrelated inherited-widget rebuild with the opposite status.
        connectivity.change(initiallyOnline
            ? ServiceConnectivityStatus.offline
            : ServiceConnectivityStatus.online);
        await tester.pumpWidget(app(container, dark: true));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(find.text(content), findsOneWidget);
        if (!initiallyOnline) {
          // The existing second confirmation remains intact, even after recovery.
          await tester.tap(find.text(l10n.xboardLogoutForceAction));
          await tester.pumpAndSettle();
          expect(find.text(l10n.xboardLogoutForceConfirmTitle), findsOneWidget);
          await tester.tap(find.text(l10n.cancel).last);
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
        }
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
            find.text(initiallyOnline
                ? l10n.xboardLogoutProtectedTitle
                : l10n.xboardLogoutConfirmTitle),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('disconnect during logout does not change copy: TV=$tv',
        (tester) async {
      system.setTVForTesting(tv);
      final connectivity = _Connectivity(ServiceConnectivityStatus.online);
      final auth = _Auth();
      final container = ProviderContainer(overrides: [
        serviceConnectivityProvider.overrideWith((ref) => connectivity),
        xboardUserProvider.overrideWith(() => auth),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(app(container));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.current;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.exit));
      await tester.pump();
      connectivity.change(ServiceConnectivityStatus.recovering);
      await tester.pump();
      connectivity.change(ServiceConnectivityStatus.offline);
      await tester.pump();
      expect(find.text(l10n.xboardLogoutConfirmTitle), findsOneWidget);
      expect(find.text(l10n.xboardLogoutConfirmContent), findsOneWidget);
      expect(find.text(l10n.xboardLogoutProtectedTitle), findsNothing);
      expect(find.text(l10n.xboardLogoutForceConfirmTitle), findsNothing);
      expect(auth.forces, [false]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.pending.complete();
      await tester.pump();
    });
  }
}
