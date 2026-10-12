import 'dart:async';

import 'package:fl_clash/controller.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in [false, true]) {
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
        globalState.updateCoreSwitchStatus(CoreSwitchStage.checkingHelper);
        await gate.future;
        if (failure) throw StateError('Helper unavailable');
      });
      final checked = failure ? expectLater(repair, throwsStateError) : repair;
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
