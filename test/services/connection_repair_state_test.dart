import 'dart:async';

import 'package:fl_clash/controller.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoIpCheckController extends AppController {
  _NoIpCheckController(super.context, super.ref);

  @override
  void addCheckIpNumDebounce() {}
}

class _SessionExitController extends AppController {
  _SessionExitController(super.context, super.ref);

  final stops = <bool>[];
  bool stopSucceeds = true;

  @override
  Future<bool> updateStatus(bool isStart) async {
    stops.add(isCoreSwitching);
    return stopSucceeds;
  }
}

void main() {
  testWidgets('session exit waits for repair before stopping', (tester) async {
    late _SessionExitController controller;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Consumer(
      builder: (context, ref, child) {
        controller = _SessionExitController(context, ref);
        return const SizedBox();
      },
    ))));
    final gate = Completer<void>();
    final repair = controller.runConnectionRepair(() => gate.future);
    final exit = controller.disconnectAfterPendingOperations();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.stops, isEmpty);
    gate.complete();
    await repair;
    await tester.pump(const Duration(milliseconds: 100));
    await exit;
    expect(controller.stops, [false]);
    controller.stopSucceeds = false;
    await expectLater(
      controller.disconnectAfterPendingOperations(),
      throwsStateError,
    );
  });

  testWidgets('first launch without a profile may finish initialization',
      (tester) async {
    late AppController controller;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(home: Consumer(
          builder: (context, ref, child) {
            controller = _NoIpCheckController(context, ref);
            return const SizedBox();
          },
        ))));
    await controller.applyProfile(silence: true);
    expect(controller.isCoreSwitching, isFalse);
    expect(tester.takeException(), isNull);
    // An import cannot use the same empty state as proof of success.
    await expectLater(
      controller.runProfileImport(() => controller.applyProfile(silence: true)),
      throwsStateError,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('profile import holds its guard through rollback',
      (tester) async {
    late AppController controller;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Consumer(
      builder: (context, ref, child) {
        controller = AppController(context, ref);
        return const SizedBox();
      },
    ))));
    final applying = Completer<void>();
    final rollback = Completer<void>();
    final operation = controller.runProfileImport(() async {
      try {
        await applying.future;
        throw StateError('apply failed');
      } finally {
        await rollback.future;
      }
    });
    final checked = expectLater(operation, throwsStateError);
    await tester.pump();
    expect(controller.isImportApplying, isTrue);
    expect(await controller.updateStatus(true), isFalse);
    applying.complete();
    await tester.pump();
    expect(controller.isCoreSwitching, isTrue);
    expect(controller.isImportApplying, isTrue);
    rollback.complete();
    await checked;
    expect(controller.isCoreSwitching, isFalse);
    expect(controller.isImportApplying, isFalse);
    expect(globalState.isCoreSwitchingNotifier.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final failure in ['none', 'error', 'timeout']) {
    testWidgets(
        'repair restores idle status after completion (failure=$failure)',
        (tester) async {
      late AppController controller;
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Consumer(
        builder: (context, ref, child) {
          controller = AppController(context, ref);
          return const SizedBox();
        },
      ))));
      final gate = Completer<void>();
      final repair = controller.runConnectionRepair(() async {
        globalState.updateCoreSwitchStatus(CoreSwitchStage.coreConnecting);
        await gate.future;
        if (failure == 'error') throw StateError('Helper unavailable');
        if (failure == 'timeout') {
          throw TimeoutException('Core did not respond');
        }
      });
      final checked = switch (failure) {
        'error' => expectLater(repair, throwsStateError),
        'timeout' => expectLater(repair, throwsA(isA<TimeoutException>())),
        _ => repair,
      };
      expect(controller.isCoreSwitching, isTrue);
      expect(globalState.coreSwitchStatusNotifier.value.isBusy, isTrue);
      // Do not start a second repair or race a connect/disconnect operation.
      await expectLater(
          controller.runConnectionRepair(() async {}), throwsStateError);
      expect(await controller.updateStatus(false), isFalse);
      gate.complete();
      await checked;
      expect(controller.isCoreSwitching, isFalse);
      expect(globalState.isCoreSwitchingNotifier.value, isFalse);
      expect(globalState.coreSwitchStatusNotifier.value.stage,
          CoreSwitchStage.idle);
      await controller.runConnectionRepair(() async {});
      expect(tester.takeException(), isNull);
    });
  }
}
