import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => system.setTVForTesting(true));
  tearDown(() => system.setTVForTesting(false));

  testWidgets('uses one inner focus border and handles the select key',
      (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var presses = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: Center(
            child: TVFocusable(
              focusNode: focusNode,
              borderRadius: BorderRadius.circular(10),
              onPressed: () => presses++,
              child: TextButton(
                onPressed: () => presses++,
                child: const Text('Action'),
              ),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(TVFocusable),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.foregroundDecoration! as BoxDecoration;
    expect(decoration.border, isA<Border>());
    expect((decoration.border! as Border).top.width, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(presses, 1);
  });
}
