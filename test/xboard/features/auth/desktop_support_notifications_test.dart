import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/auth/services/desktop_support_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('foreground sound, background batching, mute, dedup and read cancellation', () async {
    var focused = true, visible = false, sound = true, tones = 0;
    final calls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('window_manager'), (call) async {
      switch (call.method) {
        case 'isVisible': return true;
        case 'isFocused': return focused;
        case 'isMinimized': return false;
        default: return null;
      }
    });
    messenger.setMockMethodCallHandler(const MethodChannel('fastcat/support_desktop'), (call) async {
      calls.add(call);
      return null;
    });
    final service = DesktopSupportNotifications(openConversation: () async {},
      chatVisible: () => visible, soundEnabled: () => sound,
      playSound: () async { tones++; });
    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      service.unread(4);
      service.incoming({'id': 'one'});
      await settle();
      expect(tones, 1);
      service.incoming({'id': 'one'});
      visible = true;
      service.incoming({'id': 'two'});
      await settle();
      expect(tones, 1); // Visible chat owns its own sound.
      visible = false;
      focused = false;
      service.incoming({'id': 'three'});
      service.incoming({'id': 'four'});
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(calls.where((c) => c.method == 'notify').length, 1);
      expect(tones, 1); // No second app sound behind the system notification.
      sound = false;
      service.incoming({'id': 'five'});
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect((calls.lastWhere((c) => c.method == 'notify').arguments as Map)['sound'], false);
      service.incoming({'id': 'six'});
      await settle();
      service.unread(0);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(calls.where((c) => c.method == 'notify').length, 2);
      expect(calls.any((c) => c.method == 'clear'), true);
    } finally {
      await service.close();
      messenger.setMockMethodCallHandler(const MethodChannel('window_manager'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('fastcat/support_desktop'), null);
    }
  }, skip: !Platform.isMacOS);
}
