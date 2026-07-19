import 'package:fl_clash/common/system.dart';
import 'package:flutter/scheduler.dart';

class Render {
  static Render? _instance;
  final _dispatcher = SchedulerBinding.instance.platformDispatcher;

  Render._internal();

  factory Render() {
    _instance ??= Render._internal();
    return _instance!;
  }

  active() {
    resume();
  }

  /// Flutter owns [PlatformDispatcher.onBeginFrame] and [onDrawFrame].
  /// Clearing those callbacks to save resources can permanently stop desktop
  /// rendering when window lifecycle events race. Let the engine throttle
  /// hidden/minimized windows itself.
  void pause() {}

  void resume() {
    // Requesting a frame is safe even when one is already scheduled and helps
    // the surface repaint immediately after a desktop window is restored.
    _dispatcher.scheduleFrame();
  }
}

final Render? render = system.isDesktop ? Render() : null;
