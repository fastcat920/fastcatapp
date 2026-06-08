import 'dart:async';

/// SDK 全局事件总线 — 当前仅用于 401 未授权通知
///
/// SDK 内部（AuthInterceptor）探测到 401 时写入此 Stream；
/// Flutter 层（xboard_user_provider）订阅后触发重新登录引导。
class XBoardAuthEvents {
  XBoardAuthEvents._();

  static final _unauthorizedController =
      StreamController<void>.broadcast();

  /// 订阅此流以获得"token 失效"通知。
  static Stream<void> get onUnauthorized =>
      _unauthorizedController.stream;

  /// SDK 内部调用：触发 401 事件（已去重：仅在有监听者时发送）。
  static void notifyUnauthorized() {
    if (!_unauthorizedController.isClosed) {
      _unauthorizedController.add(null);
    }
  }
}
