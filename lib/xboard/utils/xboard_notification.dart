import 'package:flutter/material.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';

/// XBoard 通知工具类
///
/// 使用应用顶层 MessageManager，避免被弹窗、底部 Sheet 或二级页面遮挡。
class XBoardNotification {
  XBoardNotification._();

  /// 显示错误通知（底部顶层通知，自动消失）
  static void showError(String message) {
    _showBottom('❌ $message');
  }

  /// 显示成功通知（底部顶层通知，自动消失）
  static void showSuccess(String message) {
    _showBottom('✅ $message');
  }

  /// 显示普通通知（底部顶层通知，自动消失）
  static void showInfo(String message) {
    _showBottom(message);
  }

  static void _showBottom(String message) {
    final context = globalState.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      final shown = context.showBottomNotifier(message);
      if (shown != null) return;
      context.showSnackBar(message);
      return;
    }
    globalState.showNotifier(message);
  }

  /// 显示确认对话框（需要用户确认）
  static Future<bool> showConfirm(
    String message, {
    String? title,
  }) async {
    final result = await globalState.showMessage(
      title: title ?? appLocalizations.tip,
      message: TextSpan(text: message),
      cancelable: true,
    );
    return result == true;
  }
}
