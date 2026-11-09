import 'package:fl_clash/xboard/features/settings/pages/fastcat_background_protection_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app');
  final calls = <MethodCall>[];
  var exempt = false;

  setUp(() {
    calls.clear();
    exempt = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getBackgroundProtection') {
        return {
          'manufacturer': 'HONOR',
          'batteryExempt': exempt,
          'backgroundRestricted': false,
          'notificationsEnabled': false,
        };
      }
      if (call.method == 'openBackgroundProtectionSettings')
        return {'opened': true, 'route': 'battery_list'};
      return true;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('manual refresh shows loading, result and changed status',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FastCatBackgroundProtectionPage()));
    await tester.pumpAndSettle();
    expect(find.text('Connection protection'), findsOneWidget);
    expect(find.text('System VPN settings'), findsNothing);
    final pending = Completer<Map<String, dynamic>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getBackgroundProtection') return pending.future;
      return true;
    });
    await tester.scrollUntilVisible(find.byType(OutlinedButton), 250);
    expect(find.textContaining('Last checked:'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(find.text('Checking…'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    pending.complete({
      'manufacturer': 'HONOR',
      'batteryExempt': true,
      'notificationsEnabled': true,
      'backgroundRestricted': false
    });
    await tester.pumpAndSettle();
    expect(find.text('Status updated'), findsOneWidget);
    expect(find.text('Refresh status'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Not optimized'), -200);
    expect(find.textContaining('Not optimized'), findsOneWidget);
  });

  testWidgets('unchanged status still confirms that refresh completed',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FastCatBackgroundProtectionPage()));
    await tester.pumpAndSettle();
    final before =
        calls.where((c) => c.method == 'getBackgroundProtection').length;
    await tester.scrollUntilVisible(find.byType(OutlinedButton), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'getBackgroundProtection').length,
        before + 1);
    expect(find.text('Status updated'), findsOneWidget);
  });

  testWidgets('failed refresh times out and allows retry', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FastCatBackgroundProtectionPage()));
    await tester.pumpAndSettle();
    final pending = Completer<Map<String, dynamic>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => pending.future);
    await tester.scrollUntilVisible(find.byType(OutlinedButton), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.text('Unable to check status. Please try again.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull);
    pending.complete({'batteryExempt': true});
    await tester.pump();
    await tester.scrollUntilVisible(
        find.text('Status unavailable').first, -200);
    expect(find.textContaining('Not optimized'),
        findsNothing); // Ignore late response.
  });

  testWidgets('Chinese protection page uses the Chinese app name',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: FastCatBackgroundProtectionPage()));
    await tester.pumpAndSettle();
    expect(find.text('连接保护'), findsOneWidget);
    expect(find.textContaining('找到 快猫'), findsNWidgets(2));
    expect(find.textContaining('FastCat'), findsNothing);
    expect(find.text('系统 VPN 设置'), findsNothing);
  });
  testWidgets(
      'reads restrictions without opening settings; refreshes on return',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: FastCatBackgroundProtectionPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Optimized;'), findsOneWidget);
    expect(find.textContaining('Verify manually.'), findsOneWidget);
    expect(calls.where((c) => c.method == 'openBackgroundProtectionSettings'),
        isEmpty);
    exempt = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Not optimized'), findsOneWidget);
    await tester.tap(find.text('Battery optimization'));
    await tester.pumpAndSettle();
    expect(calls.last.method, 'openBackgroundProtectionSettings');
    expect(calls.last.arguments, {'target': 'battery'});
  });

  testWidgets('missing native status is not presented as protected',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel, (call) async => throw MissingPluginException());
    await tester
        .pumpWidget(const MaterialApp(home: FastCatBackgroundProtectionPage()));
    await tester.pumpAndSettle();
    expect(find.text('Status unavailable'), findsNWidgets(2));
    expect(find.textContaining('Not optimized'), findsNothing);
  });
  testWidgets(
      'notification master switch and channel absence are distinguished',
      (tester) async {
    var data = <String, dynamic>{
      'manufacturer': 'Xiaomi',
      'vendorFamily': 'xiaomi',
      'androidVersion': '16',
      'batteryExempt': true,
      'notificationsEnabled': false,
      'appNotificationsEnabled': false,
      'notificationChannelExists': true,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getBackgroundProtection') return data;
      return {'opened': true, 'route': 'app_details'};
    });
    await tester
        .pumpWidget(const MaterialApp(home: FastCatBackgroundProtectionPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('App notifications are off.'), findsOneWidget);
    expect(find.textContaining('HyperOS'), findsOneWidget);
    await tester.tap(find.text('Connection notification'));
    await tester.pumpAndSettle();
    expect(find.textContaining('App info opened.'), findsOneWidget);
    data = {
      ...data,
      'appNotificationsEnabled': true,
      'notificationChannelExists': false
    };
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Connection channel not created yet.'),
        findsOneWidget);
    expect(find.text('Allowed'), findsNothing);
  });

  testWidgets(
      'a missing individual check never becomes a denied or granted result',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel, (call) async => {'manufacturer': 'Other'});
    await tester
        .pumpWidget(const MaterialApp(home: FastCatBackgroundProtectionPage()));
    await tester.pumpAndSettle();
    expect(find.text('Status unavailable'), findsNWidgets(2));
    expect(find.textContaining('cannot be verified automatically'),
        findsOneWidget);
  });
}
