import 'package:fl_clash/xboard/features/subscription/widgets/mobile_home_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(390, 650),
    const Size(1032, 1250),
    const Size(740, 300)
  ]) {
    testWidgets('Home cards align and remain reachable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const top = Key('information');
      const center = Key('connection');
      const bottom = Key('node');
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
        body: MobileHomeLayout(
          information: SizedBox.expand(key: top),
          connection: SizedBox.expand(key: center),
          nodeSelector: SizedBox.expand(key: bottom),
          informationHeight: 148,
          connectionHeight: 284,
          nodeHeight: 64,
        ),
      )));
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.byKey(top)), const Offset(16, 12));
      expect(tester.getSize(find.byKey(bottom)).width, size.width - 32);
      if (size.height >= 580) {
        expect(tester.getBottomRight(find.byKey(bottom)).dy, size.height - 24);
        final gapAbove = tester.getTopLeft(find.byKey(center)).dy -
            tester.getBottomRight(find.byKey(top)).dy;
        final gapBelow = tester.getTopLeft(find.byKey(bottom)).dy -
            tester.getBottomRight(find.byKey(center)).dy;
        expect(gapAbove, closeTo(gapBelow, 0.01));
      } else {
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.getBottomRight(find.byKey(bottom)).dy,
            lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      }
    });
  }
}
