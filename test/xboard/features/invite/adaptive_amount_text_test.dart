import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/invite/widgets/adaptive_amount_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('large invite amounts are never abbreviated with k', () {
    expect(formatInviteAmount(12888.66), '¥12888.66');
    expect(
      formatInviteAmount(12888.66, showDecimals: false),
      '¥12888',
    );
  });

  testWidgets('keeps decimals when the available width is sufficient',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          child: AdaptiveAmountText(
            value: '¥12888.66',
            compactValue: '¥12888',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );

    expect(find.text('¥12888.66'), findsOneWidget);
    expect(find.text('¥12888'), findsNothing);
  });

  testWidgets('drops decimals instead of abbreviating when width is tight',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 90,
            child: AdaptiveAmountText(
              value: '¥12888.66',
              compactValue: '¥12888',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );

    expect(find.text('¥12888'), findsOneWidget);
    expect(find.textContaining('k'), findsNothing);
  });
}
