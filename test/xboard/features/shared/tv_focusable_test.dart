import 'package:fl_clash/widgets/tv_split_focus_row.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => system.setTVForTesting(true));
  tearDown(() => system.setTVForTesting(false));

  test('non-TV buttons remain the original native widget', () {
    system.setTVForTesting(false);
    final button = FilledButton(onPressed: () {}, child: const Text('Pay'));
    expect(identical(button.withTvFocus(), button), isTrue);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'filled nested button preserves shape and visible border: $brightness',
        (tester) async {
      final scheme =
          ColorScheme.fromSeed(seedColor: Colors.blue, brightness: brightness);
      var presses = 0;
      final shape =
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: Scaffold(
            body: Center(
                child: TVFocusable(
          autofocus: true,
          onPressed: () => presses++,
          child: SizedBox(
              width: 200,
              height: 44,
              child: FilledButton(
                onPressed: () => presses++,
                style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary, shape: shape),
                child: const Text('Confirm'),
              )),
        ))),
      ));
      await tester.pumpAndSettle();
      final decoration = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
          .foregroundDecoration! as ShapeDecoration;
      final border = decoration.shape as RoundedRectangleBorder;
      expect(border.borderRadius, shape.borderRadius);
      final a = border.side.color.computeLuminance();
      final b = scheme.primary.computeLuminance();
      expect(a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05),
          greaterThanOrEqualTo(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(presses, 1);
      await tester.tap(find.text('Confirm'));
      expect(presses, 2);
    });
  }

  testWidgets(
      'busy control keeps focus, ignores activation and never steals it',
      (tester) async {
    final connectFocus = FocusNode();
    final nodeFocus = FocusNode();
    addTearDown(connectFocus.dispose);
    addTearDown(nodeFocus.dispose);
    late StateSetter update;
    var busy = false;
    var presses = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return Row(children: [
            TVFocusable(
              autofocus: true,
              focusNode: connectFocus,
              focusableWhenDisabled: true,
              onPressed: busy
                  ? null
                  : () => setState(() {
                        presses++;
                        busy = true;
                      }),
              child: SizedBox(
                width: 180,
                height: 100,
                child: Text(busy ? 'Connecting' : 'Connect'),
              ),
            ),
            TVFocusable(
              focusNode: nodeFocus,
              onPressed: () {},
              child: const SizedBox(
                width: 180,
                height: 100,
                child: Text('Nodes'),
              ),
            ),
          ]);
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(connectFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(busy, isTrue);
    expect(connectFocus.hasFocus, isTrue);
    for (final key in [
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.gameButtonA,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.tap(find.text('Connecting'));
    expect(presses, 1);

    update(() => busy = false);
    await tester.pumpAndSettle();
    expect(connectFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(presses, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(nodeFocus.hasFocus, isTrue);

    update(() => busy = false);
    await tester.pumpAndSettle();
    expect(nodeFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(connectFocus.hasFocus, isTrue);
  });

  testWidgets('disabled controls remain unfocusable by default',
      (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(MaterialApp(
      home: TVFocusable(
        focusNode: focusNode,
        child: const Text('Disabled'),
      ),
    ));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.canRequestFocus, isFalse);
    expect(focusNode.hasFocus, isFalse);
  });

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
    final decoration = container.foregroundDecoration! as ShapeDecoration;
    expect(decoration.shape, isA<StadiumBorder>());
    expect((decoration.shape as OutlinedBorder).side.width, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(presses, 1);
  });
  testWidgets('split card gives selection and latency separate remote actions',
      (tester) async {
    final selection = FocusNode(), action = FocusNode();
    addTearDown(selection.dispose);
    addTearDown(action.dispose);
    var selects = 0, tests = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
      child: SizedBox(
          width: 500,
          height: 66,
          child: TVSplitFocusRow(
            focusNode: selection,
            actionFocusNode: action,
            autofocus: true,
            onSelect: () => selects++,
            onAction: () => tests++,
            content: const Center(child: Text('Node')),
            action: const Icon(Icons.bolt),
          )),
    ))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(selects, 1);
    expect(tests, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(action.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(selects, 1);
    expect(tests, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(selection.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('grouped card focus ring is inset without changing row size',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
      width: 300,
      height: 56,
      child: Material(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: TVFocusable(
              focusNode: focus,
              autofocus: true,
              focusInset: 4,
              borderRadius: BorderRadius.circular(14),
              onPressed: () {},
              child: const SizedBox.expand(child: Text('Menu')))),
    )))));
    await tester.pumpAndSettle();
    final outer = tester.getRect(find.byType(TVFocusable));
    final inner = tester.getRect(find.byKey(const Key('tv-inset-focus-ring')));
    expect(outer.size, const Size(300, 56));
    expect(inner, outer.deflate(4));
    expect(tester.takeException(), isNull);
  });
}
