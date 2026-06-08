/// 控制台日志实现
///
/// 使用 Dart 原生 print 输出日志，不依赖任何外部包
library;

import 'package:fl_clash/common/constant.dart';
import 'logger_interface.dart';

/// 控制台日志实现
class ConsoleLogger implements LoggerInterface {
  static String get _prefix => '[$appName]';

  @override
  LogLevel minLevel;

  final bool enableTimestamp;
  final bool enableColor;

  ConsoleLogger({
    this.minLevel = LogLevel.info,
    this.enableTimestamp = true,
    this.enableColor = false,
  });

  static const String _resetColor = '\x1B[0m';
  static const String _debugColor = '\x1B[36m';
  static const String _infoColor = '\x1B[32m';
  static const String _warningColor = '\x1B[33m';
  static const String _errorColor = '\x1B[31m';

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (minLevel.index <= LogLevel.debug.index) {
      _log('DEBUG', message, error, stackTrace, _debugColor);
    }
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (minLevel.index <= LogLevel.info.index) {
      _log('INFO', message, error, stackTrace, _infoColor);
    }
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (minLevel.index <= LogLevel.warning.index) {
      _log('WARN', message, error, stackTrace, _warningColor);
    }
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (minLevel.index <= LogLevel.error.index) {
      _log('ERROR', message, error, stackTrace, _errorColor);
    }
  }

  void _log(String level, String message, Object? error, StackTrace? stackTrace, String colorCode) {
    final timestamp = enableTimestamp ? _getTimestamp() : '';
    final prefix = enableColor ? '$colorCode$_prefix' : _prefix;
    final levelStr = '[$level]';
    final resetColor = enableColor ? _resetColor : '';

    final buffer = StringBuffer();
    buffer.write('$prefix$timestamp$levelStr $message$resetColor');

    // ignore: avoid_print
    print(buffer.toString());

    if (error != null) {
      // ignore: avoid_print
      print('$prefix$timestamp$levelStr Error: $error$resetColor');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print('$prefix$timestamp$levelStr StackTrace:\n$stackTrace$resetColor');
    }
  }

  String _getTimestamp() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}]';
  }
}
