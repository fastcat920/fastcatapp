import 'package:fl_clash/xboard/features/auth/widgets/customer_service_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<MediaQueryData> render(WidgetTester tester,
      {required EdgeInsets consumed,
      EdgeInsets padding = EdgeInsets.zero,
      EdgeInsets viewPadding = EdgeInsets.zero,
      EdgeInsets keyboard = EdgeInsets.zero}) async {
    late MediaQueryData local;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          size: const Size(800, 600),
          padding: padding,
          viewPadding: viewPadding,
          viewInsets: keyboard),
      child: Stack(children: [
        Positioned.fill(
            left: consumed.left,
            top: consumed.top,
            right: consumed.right,
            bottom: consumed.bottom,
            child: CustomerServiceViewport(
                consumed: consumed,
                child: Builder(builder: (context) {
                  local = MediaQuery.of(context);
                  final sdk = Scaffold(
                      body: SafeArea(
                          child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                  key: const Key('composer'), height: 50))));
                  return Scaffold(
                      appBar: AppBar(title: const Text('Host')), body: sdk);
                }))),
      ]),
    )));
    return local;
  }

  for (final bottom in [34.0, 24.0, 0.0]) {
    testWidgets('portrait navigation consumes safe inset exactly once: $bottom',
        (tester) async {
      final reserved = 68 + bottom;
      final local = await render(tester,
          consumed: EdgeInsets.only(bottom: reserved),
          padding: EdgeInsets.only(top: 44, bottom: bottom),
          viewPadding: EdgeInsets.only(top: 44, bottom: bottom));
      expect(local.padding.bottom, 0);
      expect(local.viewPadding.bottom, 0);
      expect(local.padding.top, 44);
      expect(tester.getBottomLeft(find.byKey(const Key('composer'))).dy,
          600 - reserved);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('keyboard only obscures its intersection with the chat',
      (tester) async {
    final local = await render(tester,
        consumed: const EdgeInsets.only(bottom: 68),
        viewPadding: const EdgeInsets.only(bottom: 34),
        keyboard: const EdgeInsets.only(bottom: 300));
    expect(local.viewInsets.bottom, 232);
    expect(tester.getBottomLeft(find.byKey(const Key('composer'))).dy, 300);
    // On hide, the same mounted viewport must return to the navigation edge.
    await render(tester,
        consumed: const EdgeInsets.only(bottom: 102),
        padding: const EdgeInsets.only(bottom: 34),
        viewPadding: const EdgeInsets.only(bottom: 34));
    expect(tester.getBottomLeft(find.byKey(const Key('composer'))).dy, 498);
  });
  testWidgets(
      'landscape rail consumes left inset but preserves actual bottom and right',
      (tester) async {
    final local = await render(tester,
        consumed: const EdgeInsets.only(left: 96),
        padding: const EdgeInsets.fromLTRB(44, 0, 44, 21),
        viewPadding: const EdgeInsets.fromLTRB(44, 0, 44, 21));
    expect(local.padding, const EdgeInsets.fromLTRB(0, 0, 44, 21));
    expect(local.size, const Size(704, 600));
    expect(tester.getBottomLeft(find.byKey(const Key('composer'))).dy, 579);
  });
  testWidgets('full-screen bounds retain the real home-indicator safe area',
      (tester) async {
    final local = await render(tester,
        consumed: EdgeInsets.zero,
        padding: const EdgeInsets.only(bottom: 34),
        viewPadding: const EdgeInsets.only(bottom: 34));
    expect(local.padding.bottom, 34);
    expect(tester.getBottomLeft(find.byKey(const Key('composer'))).dy, 566);
  });
  testWidgets('desktop zero insets add no artificial bottom gap',
      (tester) async {
    final local =
        await render(tester, consumed: const EdgeInsets.only(left: 96));
    expect(local.padding, EdgeInsets.zero);
    expect(tester.getBottomLeft(find.byKey(const Key('composer'))).dy, 600);
  });
}
