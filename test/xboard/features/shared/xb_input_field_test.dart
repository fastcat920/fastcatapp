import 'package:fl_clash/xboard/features/shared/widgets/xb_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
