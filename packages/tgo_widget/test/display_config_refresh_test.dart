import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgo_widget/src/config/tgo_config.dart';
import 'package:tgo_widget/src/services/im_service.dart';
import 'package:tgo_widget/src/services/platform_service.dart';
import 'package:tgo_widget/src/services/visitor_service.dart';
import 'package:tgo_widget/src/state/chat_provider.dart';
import 'package:tgo_widget/src/ui/chat_screen.dart';
import 'package:tgo_widget/src/ui/theme/tgo_theme.dart';
import 'package:tgo_widget/src/ui/widgets/header.dart';

class FakePlatform extends PlatformService {
  FakePlatform() : super(apiBase: 'https://example.invalid', apiKey: 'test');
  int calls = 0;
  Future<PlatformInfo> Function() fetch = () async => PlatformInfo();
  @override
  Future<PlatformInfo> fetchPlatformInfo() {
    calls++;
    return fetch();
  }
}

ChatProvider createProvider(FakePlatform platform) => ChatProvider(
      config: const TgoWidgetConfig(
          title: 'Old title', welcomeMessage: 'Keep history', locale: 'en'),
      platformService: platform,
      visitorService:
          VisitorService(apiBase: 'https://example.invalid', apiKey: 'test'),
      imService: IMService(apiBase: 'https://example.invalid'),
    );

void main() {
  test(
      'refresh changes presentation only, failure retains config and next call retries',
      () async {
    final platform = FakePlatform();
    final provider = createProvider(platform);
    addTearDown(provider.dispose);
    provider
        .updateConfig(provider.config); // Seed the existing welcome message.
    final originalState = provider.state;
    platform.fetch = () async => PlatformInfo(
        logoUrl: 'https://example.invalid/logo.png',
        config: PlatformConfig(
          widgetTitle: 'New title',
          themeColor: '#123456',
          welcomeMessage: 'Do not replace',
          locale: 'zh',
        ));
    await provider.refreshDisplayConfig();
    expect(provider.config.title, 'New title');
    expect(provider.config.themeColor, const Color(0xFF123456));
    expect(provider.config.logoUrl, 'https://example.invalid/logo.png');
    expect(provider.config.locale, 'en');
    expect(provider.config.welcomeMessage, 'Keep history');
    expect(identical(provider.state, originalState), isTrue);
    final goodConfig = provider.config;
    platform.fetch = () async => throw Exception('offline');
    await provider.refreshDisplayConfig();
    expect(identical(provider.config, goodConfig), isTrue);
    platform.fetch = () async => PlatformInfo(
        config: PlatformConfig(
            widgetTitle: 'Retry succeeded', themeColor: 'invalid'));
    await provider.refreshDisplayConfig();
    expect(provider.config.title, 'Retry succeeded');
    expect(provider.config.logoUrl, isNull);
    expect(provider.config.themeColor, goodConfig.themeColor);
    expect(platform.calls, 3);
    provider.updateConfig(const TgoWidgetConfig(
        themeColor: Colors.pink,
        title: 'Client title',
        logoUrl: 'old-logo.png',
        darkMode: true));
    expect(provider.config.themeColor, goodConfig.themeColor);
    expect(provider.config.title, 'Retry succeeded');
    expect(provider.config.darkMode, isTrue);
    expect(provider.config.logoUrl, isNull);
  });

  test('coalesces concurrent refresh and ignores result after disposal',
      () async {
    final platform = FakePlatform();
    final provider = createProvider(platform);
    final pending = Completer<PlatformInfo>();
    platform.fetch = () => pending.future;
    final first = provider.refreshDisplayConfig();
    final second = provider.refreshDisplayConfig();
    expect(platform.calls, 1);
    provider.dispose();
    pending.complete(PlatformInfo(displayName: 'Late response'));
    await Future.wait([first, second]);
    expect(provider.config.title, 'Old title');
  });

  for (final embedded in [false, true]) {
    testWidgets(
        'opening refreshes, rebuild retains draft, reopening retries (embedded=$embedded)',
        (tester) async {
      final platform = FakePlatform();
      final provider = createProvider(platform);
      addTearDown(provider.dispose);
      final pending = Completer<PlatformInfo>();
      platform.fetch = () => pending.future;
      final config = provider.config.copyWith(embedded: embedded);
      Widget screen() => MaterialApp(
          home:
              ChatScreen(provider: provider, config: config, fullScreen: true));
      await tester.pumpWidget(screen());
      expect(platform.calls, 1);
      await tester.enterText(find.byType(TextField), 'Unsent draft');
      final before = provider.state;
      pending.complete(PlatformInfo(
          config: PlatformConfig(
              widgetTitle: 'Updated title', themeColor: '#123456')));
      await tester.pumpAndSettle();
      expect(find.text('Unsent draft'), findsOneWidget);
      expect(find.text('Updated title'), findsOneWidget);
      expect(find.byType(ChatHeader), findsOneWidget);
      final theme =
          tester.widget<TgoThemeProvider>(find.byType(TgoThemeProvider)).theme;
      expect(theme.primaryColor, const Color(0xFF123456));
      expect(identical(provider.state, before), isTrue);
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(platform.calls, 1);
      await tester.pump(const Duration(minutes: 2));
      expect(platform.calls, 1); // No polling.
      await tester.pumpWidget(const SizedBox.shrink());
      platform.fetch = () async => throw Exception('offline');
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(platform.calls, 2);
      expect(provider.config.title, 'Updated title');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
