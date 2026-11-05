import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
import 'package:tgo_widget/src/ui/widgets/emoji_picker.dart';
import 'display_config_refresh_test.dart' show FakePlatform;

class TestProvider extends ChatProvider {
  TestProvider()
      : super(
            config: const TgoWidgetConfig(embedded: true, title: 'Support'),
            platformService: FakePlatform(),
            visitorService: VisitorService(
                apiBase: 'https://example.invalid', apiKey: 'test'),
            imService: IMService(apiBase: 'https://example.invalid'));
  @override
  Future<void> refreshStaffProfiles() async {}

  int sendCalls = 0;
  List<File> uploaded = [];
  @override
  ChatState get state => super
      .state
      .copyWith(staffInfoCache: {'staff': const StaffInfo(name: 'Alice')});
  @override
  Future<void> sendMessage(String text) async {
    sendCalls++;
  }

  @override
  Future<void> uploadFiles(List<File> files) async {
    uploaded = files;
  }
}

class TestPicker extends FilePicker {
  FileType? requestedType;
  FilePickerResult? result;
  @override
  Future<FilePickerResult?> pickFiles(
      {String? dialogTitle,
      String? initialDirectory,
      FileType type = FileType.any,
      List<String>? allowedExtensions,
      Function(FilePickerStatus)? onFileLoading,
      bool allowCompression = true,
      int compressionQuality = 30,
      bool allowMultiple = false,
      bool withData = false,
      bool withReadStream = false,
      bool lockParentWindow = false,
      bool readSequential = false}) async {
    requestedType = type;
    return result;
  }
}

void main() {
  testWidgets(
      'control events are hidden; receipts and support identity use real state',
      (tester) async {
    final provider = TestProvider();
    addTearDown(provider.dispose);
    provider.addMessage(ChatMessage(
        id: 'command',
        role: 'agent',
        payload: const CommandPayload(cmd: 'presence', param: {}),
        time: DateTime.now()));
    provider.addMessage(ChatMessage(
        id: 'agent',
        role: 'agent',
        fromUid: 'staff',
        payload: const TextPayload(content: 'How can I help?'),
        time: DateTime.now()));
    provider.addMessage(ChatMessage(
        id: 'sent',
        role: 'user',
        messageSeq: 10,
        status: MessageStatus.sent,
        payload: const TextPayload(content: 'Hello'),
        time: DateTime.now()));
    provider.addMessage(ChatMessage(
        id: 'failed',
        role: 'user',
        status: MessageStatus.failed,
        payload: const TextPayload(content: 'Unsent'),
        time: DateTime.now()));
    await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
            provider: provider, config: provider.config, fullScreen: true)));
    await tester.pumpAndSettle();
    expect(provider.sendCalls, 0);
    expect(find.text('[Message]'), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Support'),
        findsOneWidget); // Header remains in embedded mode.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
    provider.staffReadSeq = 10;
    provider.recordSent('sent', 10);
    await tester.pump();
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    await tester.tap(find.byTooltip('Mute message sound'));
    await tester.pump();
    expect(provider.soundEnabled, isFalse);
    expect(find.text('Powered by tgo.ai'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'emoji is a bounded popup and attachment opens the general picker directly',
      (tester) async {
    final provider = TestProvider();
    addTearDown(provider.dispose);
    final oldPicker = FilePicker.platform;
    final picker = TestPicker();
    FilePicker.platform = picker;
    addTearDown(() => FilePicker.platform = oldPicker);
    await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
            provider: provider, config: provider.config, fullScreen: true)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byType(EmojiPicker)).width, lessThanOrEqualTo(340));
    await tester.tap(find.text('😀').last);
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPicker), findsNothing);
    expect(find.text('Draft😀'), findsOneWidget);
    expect(provider.sendCalls, 0);
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPicker), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(EmojiPicker), findsNothing);
    picker.result = FilePickerResult(
        [PlatformFile(name: 'photo.png', size: 12, path: '/tmp/photo.png')]);
    await tester.tap(find.byTooltip('Attach'));
    await tester.pumpAndSettle();
    expect(picker.requestedType, FileType.any);
    expect(provider.uploaded.single.path, '/tmp/photo.png');
    expect(find.text('Gallery'), findsNothing);
    provider.uploaded = [];
    picker.result = null;
    await tester.tap(find.byTooltip('Attach'));
    await tester.pumpAndSettle();
    expect(provider.uploaded, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
