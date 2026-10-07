import 'package:fl_clash/widgets/notification_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {
    '❌ ': Icons.error_outline,
    '✅ ': Icons.check_circle_outline,
    '⚠️ ': Icons.warning_amber_rounded,
  }.entries) {
    testWidgets(
        'renders ${entry.key} as a bundled icon in light and dark modes',
        (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(MaterialApp(
          theme:
              ThemeData(platform: TargetPlatform.linux, brightness: brightness),
          home: Scaffold(
              body: SizedBox(
            width: 200,
            child: NotificationMessage('${entry.key}配置加载失败，请稍后重试。请检查网络后再试一次。'),
          )),
        ));
        expect(find.byIcon(entry.value), findsOneWidget);
        expect(find.text('配置加载失败，请稍后重试。请检查网络后再试一次。'), findsOneWidget);
        expect(find.textContaining(entry.key), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('keeps plain messages unchanged', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: NotificationMessage('普通消息'),
    )));
    expect(find.text('普通消息'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });
}
