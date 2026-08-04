import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    system.setTVForTesting(false);
  });

  testWidgets('clears a validation error when the input becomes valid',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XBInputField(
            controller: controller,
            labelText: 'Password',
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => (value?.length ?? 0) < 8
                ? 'Password must contain at least 8 characters'
                : null,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '1234567');
    await tester.pump();
    expect(find.text('Password must contain at least 8 characters'),
        findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '12345678');
    await tester.pump();
    expect(
        find.text('Password must contain at least 8 characters'), findsNothing);
  });

  testWidgets('TV input keeps descendants out of traversal until editing',
      (tester) async {
    system.setTVForTesting(true);
    final controller = TextEditingController();
    final inputFocus = FocusNode();
    final suffixFocus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(inputFocus.dispose);
    addTearDown(suffixFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XBInputField(
            controller: controller,
            focusNode: inputFocus,
            labelText: 'Password',
            suffixIcon: IconButton(
              focusNode: suffixFocus,
              onPressed: () {},
              icon: const Icon(Icons.visibility),
            ),
          ),
        ),
      ),
    );

    inputFocus.requestFocus();
    await tester.pump();
    expect(inputFocus.hasFocus, isTrue);

    suffixFocus.requestFocus();
    await tester.pump();
    expect(suffixFocus.hasFocus, isFalse);
    expect(inputFocus.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final keyDownText = tester.widget<EditableText>(find.byType(EditableText));
    expect(keyDownText.readOnly, isTrue);
    expect(keyDownText.showCursor, isFalse);
    expect(controller.text, isEmpty);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.readOnly, isFalse);
    expect(editableText.showCursor, isTrue);
    expect(controller.text, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    final readOnlyText = tester.widget<EditableText>(find.byType(EditableText));
    expect(readOnlyText.readOnly, isTrue);
    expect(readOnlyText.showCursor, isFalse);
    expect(inputFocus.hasFocus, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final reopenedText = tester.widget<EditableText>(find.byType(EditableText));
    expect(reopenedText.readOnly, isFalse);
    expect(reopenedText.showCursor, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final queuedReopenText =
        tester.widget<EditableText>(find.byType(EditableText));
    expect(queuedReopenText.readOnly, isTrue);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump();
    final reopenedAfterHideText =
        tester.widget<EditableText>(find.byType(EditableText));
    expect(reopenedAfterHideText.readOnly, isFalse);
    expect(reopenedAfterHideText.showCursor, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    final keyboardDismissedText =
        tester.widget<EditableText>(find.byType(EditableText));
    expect(keyboardDismissedText.readOnly, isTrue);
    expect(keyboardDismissedText.showCursor, isFalse);
    expect(inputFocus.hasFocus, isTrue);
    tester.view.resetViewInsets();
  });
}
