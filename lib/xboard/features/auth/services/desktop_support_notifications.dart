import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/xboard/core/core.dart';

/// One notification owner per signed-in support session, independent of views.
class DesktopSupportNotifications {
  DesktopSupportNotifications(
      {required this.openConversation,
      required this.chatVisible,
      required this.soundEnabled,
      required this.playSound}) {
    if (Platform.isMacOS) {
      _badge.setMethodCallHandler((call) async {
        if (call.method == 'open' && !_closed) await _open();
      });
    }
  }

  final Future<void> Function() openConversation;
  final bool Function() chatVisible, soundEnabled;
  final Future<void> Function() playSound;
  static const _badge = MethodChannel('fastcat/support_desktop');
  static const _log = FileLogger('desktop_support_notifications.dart');
  final _seen = <String>{};
  LocalNotification? _notification;
  Future<void>? _setup;
  Timer? _batch;
  DBusClient? _bus;
  StreamSubscription<DBusSignal>? _linuxActions;
  int _linuxNotification = 0;
  bool _closed = false;
  int _unread = 0;
  Future<void> _tail = Future.value();

  static bool get supported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<bool> _foreground() async =>
      await windowManager.isVisible() &&
      !await windowManager.isMinimized() &&
      await windowManager.isFocused();

  void incoming(Map<String, dynamic> message) {
    final id = message['id'];
    if (_closed || id is! String || !_seen.add(id)) return;
    if (_seen.length > 256) _seen.remove(_seen.first);
    _tail = _tail.then<void>((_) async {
      if (_closed) return;
      if (await _foreground()) {
        if (!chatVisible() && soundEnabled()) await playSound();
      } else {
        // Collapse bursts into one system alert and never also play app audio.
        _batch?.cancel();
        _batch = Timer(const Duration(milliseconds: 700), () {
          _tail = _tail.then((_) => _show()).catchError(_error);
        });
      }
    }).catchError(_error);
  }

  Future<void> _show() async {
    if (_closed || _unread == 0) return;
    if (await _foreground()) {
      if (!chatVisible() && soundEnabled()) await playSound();
      return;
    }
    try {
      if (Platform.isMacOS) {
        await _badge.invokeMethod<void>('notify', {
          'count': _unread,
          'sound': soundEnabled(),
        });
        return;
      }
      if (Platform.isLinux) {
        _bus ??= DBusClient.session();
        final remote = DBusRemoteObject(_bus!,
            name: 'org.freedesktop.Notifications',
            path: DBusObjectPath('/org/freedesktop/Notifications'));
        _linuxActions ??= DBusRemoteObjectSignalStream(
                object: remote,
                interface: 'org.freedesktop.Notifications',
                name: 'ActionInvoked')
            .listen((signal) {
          if (!_closed && signal.values[0].asUint32() == _linuxNotification) {
            unawaited(_open().catchError(_error));
          }
        }, onError: _error);
        final response = await remote.callMethod(
            'org.freedesktop.Notifications',
            'Notify',
            [
              const DBusString('FastCat'),
              DBusUint32(_linuxNotification),
              const DBusString('com.fastcat.app'),
              const DBusString('FastCat 客服'),
              DBusString('你有 $_unread 条未读客服消息，点击查看'),
              DBusArray.string(['default', '查看']),
              DBusDict.stringVariant({
                'desktop-entry': const DBusString('com.fastcat.app'),
                'suppress-sound': DBusBoolean(!soundEnabled()),
                if (soundEnabled())
                  'sound-name': const DBusString('message-new-instant')
              }),
              const DBusInt32(-1),
            ],
            replySignature: DBusSignature('u'));
        _linuxNotification = response.returnValues.first.asUint32();
        return;
      }
      await (_setup ??= localNotifier.setup(appName: 'FastCat'));
      if (_closed || _unread == 0) return;
      final notification = _notification ??=
          LocalNotification(title: 'FastCat 客服', body: '', silent: true, actions: []);
      notification.body = '你有 $_unread 条未读客服消息，点击查看';
      notification.silent = !soundEnabled();
      notification.onClick = () {
        if (_closed) return;
        unawaited(_open().catchError(_error));
      };
      await notification.show();
    } catch (error) {
      _setup = null;
      _error(error);
      if (!_closed && soundEnabled()) await playSound();
    }
  }

  Future<void> _open() async {
    await window?.show();
    if (!_closed) await openConversation();
    // Opening the window is not a read receipt; the chat acknowledges visibility.
  }

  void unread(int count) {
    if (_closed) return;
    _unread = count;
    _tail = _tail.then<void>((_) async {
      if (_closed) return;
      final current = _unread;
      await tray.updateSupportUnread(current);
      try {
        if (Platform.isLinux) {
          _bus ??= DBusClient.session();
          await _bus!.emitSignal(
              path: DBusObjectPath('/com/fastcat/app'),
              interface: 'com.canonical.Unity.LauncherEntry',
              name: 'Update',
              values: [
                const DBusString('application://com.fastcat.app.desktop'),
                DBusDict.stringVariant({
                  'count': DBusInt64(current),
                  'count-visible': DBusBoolean(current > 0)
                }),
              ]);
        } else {
          await _badge.invokeMethod<void>('badge', current);
        }
      } catch (error) {
        _error(error);
      }
      if (current == 0) {
        _batch?.cancel();
        await _clear();
      }
    }).catchError(_error);
  }

  void _error(Object error) =>
      _log.debug('Desktop notification unavailable: ${error.runtimeType}');

  Future<void> _clear() async {
    await _notification?.close();
    if (Platform.isMacOS) await _badge.invokeMethod<void>('clear');
    if (_linuxNotification != 0 && _bus != null) {
      final remote = DBusRemoteObject(_bus!,
          name: 'org.freedesktop.Notifications',
          path: DBusObjectPath('/org/freedesktop/Notifications'));
      await remote.callMethod('org.freedesktop.Notifications',
          'CloseNotification', [DBusUint32(_linuxNotification)]);
      _linuxNotification = 0;
    }
  }

  Future<void> close() async {
    _closed = true;
    _batch?.cancel();
    await _tail;
    try {
      await _clear();
    } catch (error) {
      _error(error);
    }
    await _notification?.destroy();
    _notification = null;
    await _linuxActions?.cancel();
    await _bus?.close();
    await tray.updateSupportUnread(0);
    if (!Platform.isLinux) {
      try {
        await _badge.invokeMethod<void>('badge', 0);
      } catch (_) {}
    }
  }
}
