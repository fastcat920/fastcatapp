/// 日志捕获实现
///
/// 同时输出到控制台和 fl_clash logsProvider，使 XBoard 日志
/// 能在「日志」页面中查看和导出。
library;

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/enum/enum.dart' as fl_enum;
import 'package:fl_clash/models/common.dart' show Log;
import 'package:fl_clash/state.dart';
import 'logger_interface.dart';
import 'console_logger.dart';

/// 将 fl_clash 的 LogLevel 映射到 XBoard 的 LogLevel
///
/// fl_clash: debug, info, warning, error, silent, app
/// XBoard:   debug, info, warning, error
LogLevel mapFastcatLogLevel(fl_enum.LogLevel level) {
  return switch (level) {
    fl_enum.LogLevel.debug => LogLevel.debug,
    fl_enum.LogLevel.info => LogLevel.info,
    fl_enum.LogLevel.warning => LogLevel.warning,
    fl_enum.LogLevel.error => LogLevel.error,
    fl_enum.LogLevel.silent => LogLevel.error, // silent 映射为最高级别，几乎不输出
    fl_enum.LogLevel.app => LogLevel.info, // app 级别映射为 info
  };
}

/// 日志捕获实现
///
/// 将 XBoard 日志转发到 fl_clash 的 logsProvider，同时保留控制台输出。
class CaptureLogger implements LoggerInterface {
  final ConsoleLogger _console;

  CaptureLogger({LogLevel minLevel = LogLevel.info})
      : _console = ConsoleLogger(minLevel: minLevel);

  @override
  LogLevel get minLevel => _console.minLevel;

  @override
  set minLevel(LogLevel level) => _console.minLevel = level;

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _console.debug(message, error, stackTrace);
    if (minLevel.index <= LogLevel.debug.index) {
      _addLog(fl_enum.LogLevel.debug, message);
    }
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _console.info(message, error, stackTrace);
    if (minLevel.index <= LogLevel.info.index) {
      _addLog(fl_enum.LogLevel.info, message);
    }
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _console.warning(message, error, stackTrace);
    if (minLevel.index <= LogLevel.warning.index) {
      _addLog(fl_enum.LogLevel.warning, message);
    }
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _console.error(message, error, stackTrace);
    _addLog(fl_enum.LogLevel.error, message);
  }

  void _addLog(fl_enum.LogLevel level, String message) {
    try {
      if (!globalState.isInit) return;
      globalState.appController.addLog(
        Log(
          logLevel: level,
          payload: '[$appName] $message',
          dateTime: DateTime.now().toString(),
        ),
      );
    } catch (_) {
      // 捕获期间不抛出，避免循环
    }
  }
}
