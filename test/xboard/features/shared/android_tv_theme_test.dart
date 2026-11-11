import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  testWidgets('native dark survives engine light and light-to-auto switching',
      (tester) async {
    final engine = StateProvider<Brightness>((ref) => Brightness.light);
    final selected = StateProvider<ThemeMode>((ref) => ThemeMode.system);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(androidTvSystemBrightnessProvider.notifier).state =
        Brightness.dark;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final brightness = AndroidTvTheme.resolveSystemBrightness(
                isTV: true,
                native: ref.watch(androidTvSystemBrightnessProvider),
                flutter: ref.watch(engine))!;
            return MaterialApp(
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeAnimationDuration: Duration.zero,
                themeMode: AndroidTvTheme.materialMode(
                    ref.watch(selected), brightness,
                    isTV: true),
                home: const Scaffold(body: SizedBox(key: Key('theme-probe'))));
          },
        )));
    Brightness actual() =>
        Theme.of(tester.element(find.byKey(const Key('theme-probe'))))
            .brightness;
    expect(actual(), Brightness.dark);
    container.read(selected.notifier).state = ThemeMode.light;
    await tester.pumpAndSettle();
    expect(actual(), Brightness.light);
    container.read(engine.notifier).state = Brightness.dark;
    await tester.pump();
    container.read(engine.notifier).state = Brightness.light;
    container.read(selected.notifier).state = ThemeMode.system;
    await tester.pumpAndSettle();
    expect(actual(), Brightness.dark);
    container.read(androidTvSystemBrightnessProvider.notifier).state =
        Brightness.light;
    await tester.pumpAndSettle();
    expect(actual(), Brightness.light);
    expect(
        AndroidTvTheme.resolveSystemBrightness(
            isTV: false, native: Brightness.dark, flutter: Brightness.light),
        Brightness.light);
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
