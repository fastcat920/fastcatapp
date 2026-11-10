import 'package:fl_clash/services/android_tv_theme.dart';
import 'package:fl_clash/widgets/tv_version_link.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    system.setTVForTesting(false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidTvTheme.channel, null);
  });
  test(
      'auto follows native TV brightness without overriding explicit or mobile preferences',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidTvTheme.channel, (_) async => 'dark');
    final brightness = await AndroidTvTheme.readSystemBrightness();
    expect(brightness, Brightness.dark);
    expect(
        AndroidTvTheme.materialMode(ThemeMode.system, brightness!, isTV: true),
        ThemeMode.dark);
    expect(
        AndroidTvTheme.materialMode(ThemeMode.system, Brightness.light,
            isTV: true),
        ThemeMode.light);
    expect(AndroidTvTheme.materialMode(ThemeMode.light, brightness, isTV: true),
        ThemeMode.light);
    expect(
        AndroidTvTheme.materialMode(ThemeMode.dark, Brightness.light,
            isTV: true),
        ThemeMode.dark);
    expect(
        AndroidTvTheme.materialMode(ThemeMode.system, brightness, isTV: false),
        ThemeMode.system);
  });
  test('unknown native theme falls back instead of assuming darkness',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidTvTheme.channel, (_) async => null);
    expect(await AndroidTvTheme.readSystemBrightness(), isNull);
  });
  testWidgets('version focus encloses only its label in a stretched column',
      (tester) async {
    system.setTVForTesting(true);
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 600,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          height: 24,
                          child: TVVersionLink(
                              label: 'Current version: V3.6.2',
                              hasUpdate: true,
                              onPressed: () => presses++)),
                    ])))));
    final focus = find.byKey(const Key('tv-version-focus'));
    final text = find.byKey(const Key('tv-current-version'));
    expect(tester.getSize(focus).width, lessThan(600));
    expect(tester.getSize(focus).width,
        closeTo(tester.getSize(text).width + 16, 0.01));
    await tester.tap(text);
    await tester.pump();
    expect(presses, 1);
    expect(find.byType(Badge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
