import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_clash/xboard/features/shared/widgets/privacy_gate.dart';

void main() {
  for (final language in ['zh-CN', 'en']) {
    for (final width in [320.0, 800.0]) {
      testWidgets('privacy actions are centered with agreement above decline at $width in $language',
          (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(PrivacyGate(
            preferences: prefs, localeTag: language, child: const SizedBox()));
        final zh = language.startsWith('zh');
        final privacy = find.text(zh ? '阅读隐私政策' : 'Read Privacy Policy');
        final terms = find.text(zh ? '阅读服务条款' : 'Read Terms of Service');
        final decline = find.text(zh ? '暂不使用' : 'Not now');
        final proceed = find.text(zh ? '同意并继续' : 'Agree and Continue');
        await tester.scrollUntilVisible(decline, 200);
        await tester.pumpAndSettle();
        expect(tester.getCenter(privacy).dy, tester.getCenter(terms).dy);
        expect(
            tester.getCenter(privacy).dx, lessThan(tester.getCenter(terms).dx));
        expect(tester.getCenter(proceed).dy, lessThan(tester.getCenter(decline).dy));
        expect(tester.getCenter(decline).dx, closeTo(tester.getCenter(proceed).dx, 1));
        final button = tester.widget<TextButton>(
            find.widgetWithText(TextButton, zh ? '暂不使用' : 'Not now'));
        expect(button.style!.foregroundColor!.resolve({}),
            const Color(0xFFB3261E));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'application is not mounted before acknowledgement or after decline',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var mounted = false;
    await tester.pumpWidget(PrivacyGate(
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
    expect(prefs.getString(PrivacyGate.preferenceKey), isNull);
    await tester.ensureVisible(find.text('Agree and Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and Continue'));
    await tester.pumpAndSettle();
    expect(mounted, true);
    expect(prefs.getString(PrivacyGate.preferenceKey), PrivacyGate.version);
  });

  testWidgets(
      'current acknowledgement opens app; outdated acknowledgement asks again',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {PrivacyGate.preferenceKey: PrivacyGate.version});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(PrivacyGate(
        preferences: prefs,
        child: const Text('app', textDirection: TextDirection.ltr)));
    expect(find.text('app'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await prefs.setString(PrivacyGate.preferenceKey, 'old');
    await tester.pumpWidget(PrivacyGate(
        preferences: prefs,
        child: const Text('app', textDirection: TextDirection.ltr)));
    expect(find.text('app'), findsNothing);
    expect(find.text('VPN Data Use'), findsOneWidget);
  });
  testWidgets('legacy iOS consent remains valid', (tester) async {
    SharedPreferences.setMockInitialValues({
      PrivacyGate.legacyApplePreferenceKey: PrivacyGate.version,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(PrivacyGate(
        preferences: prefs,
        child: const Text('app', textDirection: TextDirection.ltr)));
    expect(find.text('app'), findsOneWidget);
  });

  testWidgets('notice follows client language and has no language switch',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(PrivacyGate(
        preferences: prefs, localeTag: 'zh-CN', child: const SizedBox()));
    expect(find.text('VPN 数据使用说明'), findsOneWidget);
    expect(find.text('English'), findsNothing);
    await tester.pumpWidget(PrivacyGate(
        preferences: prefs, localeTag: 'en', child: const SizedBox()));
    expect(find.text('VPN Data Use'), findsOneWidget);
    expect(find.text('中文'), findsNothing);
  });
}
