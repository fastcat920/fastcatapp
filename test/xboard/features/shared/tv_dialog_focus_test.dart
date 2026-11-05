import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => system.setTVForTesting(true));
  tearDown(() => system.setTVForTesting(false));

  testWidgets('modal captures focus and defaults to the safe cancel action',
      (tester) async {
    var backgroundPresses = 0;
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TVFocusable(
                  autofocus: true,
                  onPressed: () {
                    backgroundPresses++;
                  },
                  child: TextButton(
                      onPressed: () async {
                        result = await XbConfirmDialog.show(context,
                            title: 'Confirm',
                            message: 'Test',
                            confirmLabel: 'Apply',
                            cancelLabel: 'Cancel');
                      },
                      child: const Text('Open')),
                )))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(result, false);
    expect(backgroundPresses, 0);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('replacing a supplied focus node uses the new node',
      (tester) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var calls = 0;
    Widget page(FocusNode node) => MaterialApp(
        home: Scaffold(
            body: TVFocusable(
                focusNode: node,
                onPressed: () => calls++,
                child: const Text('Action'))));
    await tester.pumpWidget(page(first));
    await tester.pumpWidget(page(second));
    second.requestFocus();
    await tester.pumpAndSettle();
    expect(second.hasFocus, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(calls, 1);
  });
}
