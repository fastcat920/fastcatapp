import 'dart:async';

import 'package:fl_clash/common/common.dart' show FixedList;
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/models/models.dart' hide Result;
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/adapter/state/plan_state.dart';
import 'package:fl_clash/xboard/adapter/state/subscription_state.dart';
import 'package:fl_clash/xboard/adapter/state/user_state.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/features/connectivity/connectivity.dart';
import 'package:fl_clash/xboard/features/invite/providers/referral_program_provider.dart';
import 'package:fl_clash/xboard/features/notice/providers/notice_provider.dart';
import 'package:fl_clash/xboard/features/profile/profile.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_downloader.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_guard_service.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart'
    show SubscriptionModel, UserModel;
import 'package:shared_preferences/shared_preferences.dart';

class _Connectivity extends StateNotifier<ServiceConnectivityState>
    implements ServiceConnectivityNotifier {
  _Connectivity()
      : super(const ServiceConnectivityState(
          status: ServiceConnectivityStatus.online,
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements XBoardStorageService {
  _Storage(this.events);

  final List<String> events;

  @override
  Future<String?> getSavedEmail() async => null;

  @override
  Future<String?> getSavedPassword() async => null;

  @override
  Future<bool> getRememberPassword() async => false;

  @override
  Future<Result<bool>> clearAuthData() async {
    events.add('clear identity');
    return Result.success(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Referral extends ReferralProgramNotifier {
  @override
  ReferralProgramState build() => const ReferralProgramState();

  @override
  Future<void> clear() async {}
}

class _Notice extends StateNotifier<NoticeState> implements NoticeNotifier {
  _Notice() : super(const NoticeState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LogoutController extends AppController {
  _LogoutController(super.context, super.ref, this.events);

  final List<String> events;
  bool failDisconnect = false;

  @override
  Future<void> disconnectAfterPendingOperations() async {
    events.add('disconnect');
    if (failDisconnect) throw StateError('Disconnect was not acknowledged');
    globalState.startTime = null;
  }

  @override
  Future<void> savePreferences() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    globalState.appState = AppState(
      viewSize: Size.zero,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
    );
    globalState.config = Config(themeProps: defaultThemeProps);
  });

  tearDown(() {
    globalState.startTime = null;
    subscriptionGuardService.stopGuard();
  });

  test('cancellation drains rollback even when import UI state was cleared',
      () async {
    final applied = Completer<void>();
    final rolledBack = Completer<void>();
    late SubscriptionDownloadCancelToken cancellation;
    var operationCount = 0;
    final container = ProviderContainer(overrides: [
      xboardProfileImportServiceProvider.overrideWith((ref) {
        return XBoardProfileImportService.forTesting(
          ref,
          importOperation: (token) async {
            operationCount++;
            cancellation = token;
            await applied.future;
            // Completion is deliberately successful: invalidating the caller
            // generation must suppress even a late success from old work.
            await rolledBack.future;
            return ImportResult.success();
          },
        );
      }),
    ]);
    addTearDown(container.dispose);
    final importer = container.read(profileImportProvider.notifier);
    final service = container.read(xboardProfileImportServiceProvider);
    final importing = importer.importSubscription('https://example.test/sub');
    importer.clearState();
    expect(container.read(profileImportProvider).isImporting, isFalse);
    var drained = false;
    final draining = importer.cancelImportAndWait().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(cancellation.isCancelled, isTrue);
    expect(service.hasPendingImport, isTrue);
    expect(container.read(profileImportProvider).isImporting, isTrue);
    expect(drained, isFalse);
    expect(await importer.importSubscription('https://example.test/other'),
        isFalse);
    expect(operationCount, 1);
    applied.complete();
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);
    rolledBack.complete();
    await draining;
    expect(await importing, isFalse);
    expect(service.hasPendingImport, isFalse);
    expect(container.read(profileImportProvider).status, ImportStatus.idle);
    expect(container.read(profileImportProvider).lastSuccessTime, isNull);
  });

  for (final failsDisconnect in [false, true]) {
    testWidgets(
        'logout drains rollback before disconnect and identity clearing '
        '(disconnect fails=$failsDisconnect)', (tester) async {
      final events = <String>[];
      final applying = Completer<void>();
      final rollback = Completer<void>();
      final oldSubscription = Completer<SubscriptionModel>();
      late SubscriptionDownloadCancelToken cancellation;
      late _LogoutController controller;
      late WidgetRef appRef;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          initialTokenProvider.overrideWithValue(true),
          serviceConnectivityProvider.overrideWith((ref) => _Connectivity()),
          storageServiceProvider.overrideWithValue(_Storage(events)),
          referralProgramProvider.overrideWith(_Referral.new),
          noticeProvider.overrideWith((ref) => _Notice()),
          getUserInfoProvider
              .overrideWith((ref) => Completer<UserModel>().future),
          getSubscriptionProvider.overrideWith((ref) => oldSubscription.future),
          getPlansProvider.overrideWith((ref) async => []),
          getOrdersProvider.overrideWith((ref) async => []),
          xboardProfileImportServiceProvider.overrideWith((ref) {
            return XBoardProfileImportService.forTesting(
              ref,
              importOperation: (token) async {
                cancellation = token;
                await applying.future;
                events.add('rollback started');
                await rollback.future;
                // A rollback may restore the previous connected profile.
                globalState.startTime =
                    DateTime.now().subtract(const Duration(seconds: 1));
                events.add('rollback complete');
                return ImportResult.failure(
                  errorMessage: 'Cancelled',
                  errorType: ImportErrorType.unknownError,
                );
              },
            );
          }),
        ],
        child: MaterialApp(home: Consumer(builder: (context, ref, child) {
          appRef = ref;
          controller = _LogoutController(context, ref, events)
            ..failDisconnect = failsDisconnect;
          globalState.appController = controller;
          return const SizedBox();
        })),
      ));
      final importer = appRef.read(profileImportProvider.notifier);
      final importing = importer.importSubscription('https://example.test/sub');
      final auth = appRef.read(xboardUserAuthProvider.notifier);
      final refreshing =
          auth.refreshSubscriptionForConnect(const Duration(minutes: 1));
      await tester.pump();
      // Initially disconnected; logout must re-check after rollback, not use a
      // snapshot taken before cancelling the import.
      expect(globalState.isStart, isFalse);
      final logout = auth.logout();
      // A repeated click must join the same cleanup, not run another logout.
      expect(identical(auth.logout(), logout), isTrue);
      final checked =
          failsDisconnect ? expectLater(logout, throwsStateError) : logout;
      await tester.pump();
      expect(cancellation.isCancelled, isTrue);
      expect(appRef.read(xboardUserAuthProvider).isLoading, isTrue);
      expect(events, isEmpty);
      applying.complete();
      await tester.pump();
      expect(events, ['rollback started']);
      rollback.complete();
      await tester.pump();
      await checked;
      expect(appRef.read(sessionEpochProvider), greaterThan(0));
      oldSubscription
          .complete(const SubscriptionModel(email: 'old@example.test'));
      await tester.pump();
      expect(await refreshing, isFalse);
      expect(appRef.read(subscriptionInfoProvider), isNull);
      expect(await importing, isFalse);
      expect(events, [
        'rollback started',
        'rollback complete',
        'disconnect',
        if (!failsDisconnect) 'clear identity'
      ]);
      final state = appRef.read(xboardUserAuthProvider);
      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, failsDisconnect);
      expect(globalState.isStart, failsDisconnect);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
