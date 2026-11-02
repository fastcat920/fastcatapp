import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgo_widget/src/config/tgo_config.dart';
import 'package:tgo_widget/src/models/message.dart';
import 'package:tgo_widget/src/models/api_types.dart';
import 'package:tgo_widget/src/services/im_service.dart';
import 'package:tgo_widget/src/services/visitor_service.dart';
import 'package:tgo_widget/src/state/chat_provider.dart';
import 'package:tgo_widget/src/state/chat_state.dart';
import 'package:tgo_widget/src/ui/chat_screen.dart';

class PreviewProvider extends ChatProvider {
  PreviewProvider(TgoWidgetConfig config)
      : super(
          config: config,
          visitorService: VisitorService(
              apiBase: 'https://example.invalid', apiKey: 'test'),
          imService: IMService(apiBase: 'https://example.invalid'),
        ) {
    staffReadSeq = 1;
  }
  @override
  Future<void> refreshDisplayConfig() async {}

  @override
  ChatState get state => ChatState(staffInfoCache: {
        'staff': const StaffInfo(name: 'Alice')
      }, messages: [
        ChatMessage(
            id: '1',
            messageSeq: 1,
            status: MessageStatus.sent,
            role: 'user',
            payload: const TextPayload(content: 'Hello'),
            time: DateTime.now()),
        ChatMessage(
            id: '2',
            fromUid: 'staff',
            role: 'agent',
            payload: const TextPayload(
                content: 'Welcome! How can we help you today?'),
            time: DateTime.now()),
        ChatMessage(
            id: '3',
            messageSeq: 3,
            status: MessageStatus.sent,
            role: 'user',
            payload: const TextPayload(
                content:
                    'Please help me check my order. This longer message should wrap within the chat container.'),
            time: DateTime.now()),
      ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const previewFont = String.fromEnvironment('TGO_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      final loader = FontLoader('Roboto');
      loader.addFont(Future.value(
          ByteData.sublistView(await File(previewFont).readAsBytes())));
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  for (final dark in [false, true]) {
    for (final size in [const Size(390, 844), const Size(800, 600)]) {
      testWidgets('web styling ${size.width} dark=$dark', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final config = TgoWidgetConfig(title: 'Tgo', darkMode: dark);
        final provider = PreviewProvider(config);
        addTearDown(provider.dispose);
        await tester.pumpWidget(MaterialApp(
            home: RepaintBoundary(
          key: const ValueKey('preview'),
          child:
              ChatScreen(provider: provider, config: config, fullScreen: true),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Powered by tgo.ai'), findsNothing);
        final input = find.byType(TextField);
        final send = find.byKey(const ValueKey('tgo-send'));
        expect(tester.getTopLeft(send).dy,
            greaterThan(tester.getBottomLeft(input).dy));
        expect(tester.widget<IconButton>(send).onPressed, isNull);
        await expectLater(
            find.byKey(const ValueKey('preview')),
            matchesGoldenFile(
                '${previewFont.isEmpty ? 'goldens' : 'previews'}/chat_${size.width.toInt()}_${dark ? 'dark' : 'light'}.png'));
        await tester.enterText(input, 'Test');
        await tester.pump();
        expect(tester.widget<IconButton>(send).onPressed, isNotNull);
        await tester.tap(find.byTooltip('Emoji'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
