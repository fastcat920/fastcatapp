import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/shared/utils/tv_focus_restoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    system.setTVForTesting(false);
  });

  testWidgets('restores the focus held before a modal interaction',
      (tester) async {
    system.setTVForTesting(true);
    final originalFocus = FocusNode();
    final modalFocus = FocusNode();
    addTearDown(originalFocus.dispose);
    addTearDown(modalFocus.dispose);

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Column(
              children: [
                TextButton(
                  focusNode: originalFocus,
                  onPressed: () {},
                  child: const Text('Original'),
                ),
                TextButton(
                  focusNode: modalFocus,
                  onPressed: () {},
                  child: const Text('Modal'),
                ),
              ],
            );
          },
        ),
      ),
    );

    originalFocus.requestFocus();
    await tester.pump();
    final captured = TvFocusRestoration.capture();
    expect(captured, same(originalFocus));

    modalFocus.requestFocus();
    await tester.pump();
    expect(modalFocus.hasFocus, isTrue);

    TvFocusRestoration.restore(pageContext, captured);
    await tester.pump();
    expect(originalFocus.hasFocus, isTrue);
  });
}
