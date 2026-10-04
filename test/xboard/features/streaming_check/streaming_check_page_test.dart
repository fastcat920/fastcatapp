import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/streaming_check/pages/streaming_check_page.dart';
import 'package:fl_clash/xboard/features/streaming_check/services/streaming_check_service.dart';
import 'package:fl_clash/xboard/features/streaming_check/models/streaming_test_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RunTime extends RunTime {
  @override
  int? build() => 1000;

  @override
  void onUpdate(int? value) {}

  void update(int? value) => state = value;
}

class _Groups extends Groups {
  @override
  List<Group> build() => [];
}

// Exercise the page without native core startup or real network requests.
class _Checker extends StreamingCheckService {
  String node = 'Test node';
  Completer<void> gate = Completer<void>();
  int requests = 0;
  bool cancelled = false;
  void Function()? onTarget;

  @override
  StreamingCheckService newRun() {
    cancelled = false;
    return this;
  }

  @override
  Future<String?> resolveCurrentNodeName() async => node;

  @override
  Future<String?> detectRegion(String proxyName) async {
    requests++;
    await gate.future;
    return 'JP';
  }

  @override
  Future<StreamingTestResult> testTarget(
      StreamingTarget target, String proxyName,
      {String? region}) async {
    requests++;
    onTarget?.call();
    return StreamingTestResult(
      target: target,
      status: StreamingTestStatus.accessible,
      elapsedMs: 10,
      region: region,
    );
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

final _profile = StateProvider<Profile?>((ref) => Profile(
      id: 'profile-1',
      lastUpdateDate: DateTime(2026, 10, 1),
      autoUpdateDuration: const Duration(days: 1),
    ));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Checker checker;
  late _RunTime runtime;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    checker = _Checker();
    globalState.startTime = DateTime(2026, 10, 4, 20);
    runtime = _RunTime();
    container = ProviderContainer(overrides: [
      runTimeProvider.overrideWith(() => runtime),
      groupsProvider.overrideWith(_Groups.new),
      currentProfileProvider.overrideWith((ref) => ref.watch(_profile)),
      streamingCheckServiceProvider.overrideWithValue(checker),
    ]);
  });

  tearDown(() {
    if (!checker.gate.isCompleted) checker.gate.complete();
    container.dispose();
    globalState.startTime = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      null,
    );
  });

  Future<void> openAndStart(WidgetTester tester) async {
    // Create the pending probe in the widget test's fake-async zone.
    checker.gate = Completer<void>();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const StreamingCheckPage(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.xboardStreamingStart));
    await tester.pump();
    expect(checker.requests, 1);
  }

  testWidgets(
      'timer ticks do not cancel checks and reuse the same session cache',
      (tester) async {
    await openAndStart(tester);
    var elapsedDuringBatches = 4000;
    checker.onTarget = () => runtime.update(elapsedDuringBatches += 1000);
    for (final elapsed in [2000, 3000, 4000]) {
      runtime.update(elapsed);
      await tester.pump(const Duration(seconds: 1));
      expect(checker.cancelled, isFalse);
    }
    checker.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('订阅或连接已变化，请重新检测'), findsNothing);
    expect(find.text('16/16'), findsWidgets);
    final requestCount = checker.requests;
    expect(requestCount, greaterThan(16));

    // Switch modes and back to clear visible results, but not the valid cache.
    runtime.update(60000);
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完整'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.xboardStreamingStart));
    await tester.pumpAndSettle();
    expect(find.text('已显示 10 分钟内的缓存结果'), findsOneWidget);
    expect(checker.requests, requestCount);
    expect(tester.takeException(), isNull);
  });

  for (final change in ['subscription', 'session']) {
    testWidgets('$change prevents reuse of completed results', (tester) async {
      await openAndStart(tester);
      checker.gate.complete();
      await tester.pumpAndSettle();
      final firstRequests = checker.requests;
      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完整'));
      await tester.pumpAndSettle();
      if (change == 'subscription') {
        container.read(_profile.notifier).state = container
            .read(_profile)!
            .copyWith(lastUpdateDate: DateTime(2026, 10, 4));
      } else {
        globalState.startTime = DateTime(2026, 10, 4, 20, 1);
        runtime.update(100);
      }
      await tester
          .tap(find.text(AppLocalizations.current.xboardStreamingStart));
      await tester.pumpAndSettle();
      expect(find.text('已显示 10 分钟内的缓存结果'), findsNothing);
      expect(checker.requests, firstRequests * 2);
      expect(find.text('16/16'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final change in [
    'subscription',
    'profile',
    'session',
    'node',
    'disconnect'
  ]) {
    testWidgets('$change still invalidates an in-flight check', (tester) async {
      await openAndStart(tester);
      switch (change) {
        case 'subscription':
          container.read(_profile.notifier).state = container
              .read(_profile)!
              .copyWith(lastUpdateDate: DateTime(2026, 10, 4));
        case 'profile':
          container.read(_profile.notifier).state =
              container.read(_profile)!.copyWith(id: 'profile-2');
        case 'session':
          // A reconnect even when a transient null runtime was not observed.
          globalState.startTime = DateTime(2026, 10, 4, 20, 1);
          runtime.update(100);
        case 'node':
          checker.node = 'Another node';
        case 'disconnect':
          globalState.startTime = null;
          runtime.update(null);
      }
      await tester.pump();
      checker.gate.complete();
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.current;
      final expected = switch (change) {
        'node' => l10n.xboardStreamingNodeChanged,
        'disconnect' => l10n.xboardStreamingDisconnected,
        _ => '订阅或连接已变化，请重新检测',
      };
      expect(find.text(expected), findsOneWidget);
      expect(checker.requests, 1);
      expect(checker.cancelled, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
