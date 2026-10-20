import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_clash/xboard/features/shared/widgets/apple_privacy_gate.dart';

void main() {
  testWidgets(
      'application is not mounted before acknowledgement or after decline',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var mounted = false;
    await tester.pumpWidget(ApplePrivacyGate(
        preferences: prefs,
        child: Builder(builder: (_) {
          mounted = true;
          return const SizedBox();
        })));
    expect(mounted, false);
    await tester.scrollUntilVisible(find.text('Not now'), 200);
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(mounted, false);
    expect(prefs.getString(ApplePrivacyGate.preferenceKey), isNull);
    await tester.ensureVisible(find.text('I understand — Continue'));
    await tester.tap(find.text('I understand — Continue'));
    await tester.pumpAndSettle();
    expect(mounted, true);
    expect(prefs.getString(ApplePrivacyGate.preferenceKey),
        ApplePrivacyGate.version);
  });

  testWidgets(
      'current acknowledgement opens app; outdated acknowledgement asks again',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {ApplePrivacyGate.preferenceKey: ApplePrivacyGate.version});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ApplePrivacyGate(
        preferences: prefs,
        child: const Text('app', textDirection: TextDirection.ltr)));
    expect(find.text('app'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await prefs.setString(ApplePrivacyGate.preferenceKey, 'old');
    await tester.pumpWidget(ApplePrivacyGate(
        preferences: prefs,
        child: const Text('app', textDirection: TextDirection.ltr)));
    expect(find.text('app'), findsNothing);
    expect(find.text('VPN Data Use'), findsOneWidget);
  });
}
