import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/settings/widgets/routing_rule_card.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => system.setTVForTesting(true));
  tearDown(() => system.setTVForTesting(false));
  for (final chinese in [false, true]) {
    for (final direct in [false, true]) {
      testWidgets(
          'compact rule presentation wraps actions on mobile: zh=$chinese direct=$direct',
          (tester) async {
        system.setTVForTesting(false);
        await tester.binding.setSurfaceSize(const Size(320, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Align(
          alignment: Alignment.topCenter,
          child: RoutingRuleCard(
              value: 'DOMAIN-SUFFIX,example.com,${direct ? "DIRECT" : "快猫"}',
              chinese: chinese,
              onEdit: () {},
              onDelete: () {},
              onUp: () {},
              onDown: () {}),
        ))));
        final destination = find.text('example.com');
        final tag = find.text(
            direct ? (chinese ? '直连' : 'Direct') : (chinese ? '代理' : 'Proxy'));
        expect(destination, findsOneWidget);
        expect(tester.getRect(find.byKey(const Key('routing-mode-label'))).left,
            closeTo(tester.getRect(destination).right + 12, 0.1));
        expect(tag, findsOneWidget);
        expect(find.textContaining('DOMAIN-SUFFIX'), findsNothing);
        expect(find.text('快猫'), findsNothing);
        expect(find.text('DIRECT'), findsNothing);
        final edit = find.byKey(const ValueKey('rule-action-edit'));
        final delete = find.byKey(const ValueKey('rule-action-delete'));
        final up = find.byKey(const ValueKey('rule-action-up'));
        final down = find.byKey(const ValueKey('rule-action-down'));
        expect(tester.getTopLeft(edit).dy,
            greaterThan(tester.getBottomLeft(destination).dy));
        expect(
            tester.getTopLeft(edit).dx, lessThan(tester.getTopLeft(delete).dx));
        expect(
            tester.getTopLeft(delete).dx, lessThan(tester.getTopLeft(up).dx));
        expect(tester.getTopLeft(up).dx, lessThan(tester.getTopLeft(down).dx));
        expect(tester.getBottomRight(down).dx, 308);
        expect(tester.getCenter(tag).dx,
            greaterThan(tester.getCenter(destination).dx));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'TV rule actions stay on one row and disabled moves are focusable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var edits = 0, deletes = 0, moves = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TVPageFrame(
      child: Align(
          alignment: Alignment.topCenter,
          child: RoutingRuleCard(
            value: 'DOMAIN-SUFFIX,a-very-long-domain-name.example.com,Proxy',
            chinese: false,
            onEdit: () => edits++,
            onDelete: () => deletes++,
            onUp: null,
            onDown: () => moves++,
          )),
    ))));
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey('rule-action-edit'));
    final delete = find.byKey(const ValueKey('rule-action-delete'));
    final up = find.byKey(const ValueKey('rule-action-up'));
    final down = find.byKey(const ValueKey('rule-action-down'));
    Focus focus(Finder finder) => tester.widget<Focus>(
        find.descendant(of: finder, matching: find.byType(Focus)).first);
    focus(edit).focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(edits, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focus(delete).focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focus(up).focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(moves, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focus(down).focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(moves, 1);
    expect(deletes, 0);
    expect(tester.getCenter(edit).dy, tester.getCenter(down).dy);
    final card = tester.getRect(find.byType(Card));
    expect(card.left, 25);
    expect(card.right, 935);
    expect(card.height, lessThan(90));
    expect(tester.takeException(), isNull);
  });
  testWidgets('TV frame uses home gutters and platform safe areas',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const content = Key('content');
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MediaQuery(
      data: MediaQueryData(
          size: Size(1600, 900),
          padding: EdgeInsets.only(left: 10, right: 10, bottom: 8)),
      child: TVPageFrame(child: SizedBox.expand(key: content)),
    ))));
    expect(tester.getRect(find.byKey(content)),
        const Rect.fromLTRB(43, 19, 1557, 869));
  });
}
