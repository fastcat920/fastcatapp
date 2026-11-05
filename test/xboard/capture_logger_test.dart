import 'package:fl_clash/common/diagnostic_log_buffer.dart';
import 'package:fl_clash/xboard/core/logger/capture_logger.dart';
import 'package:fl_clash/xboard/core/logger/logger_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captured errors include cause and stack, retained and exported safely',
      () {
    final buffer = DiagnosticLogBuffer();
    final logger = CaptureLogger(onCapture: buffer.add);
    logger.error(
        'Initialization failed',
        StateError(
            'config not ready at https://private.example.com/?token=abc'),
        StackTrace.fromString(
            '#0 xboardSdk (package:fl_clash/sdk_provider.dart:26:7)'));
    final report = buffer.export(chinese: false);
    expect(buffer.length, 1);
    expect(report, contains('config not ready'));
    expect(report, contains('sdk_provider.dart:26:7'));
    expect(report, isNot(contains('private.example.com')));
    expect(report, isNot(contains('token=abc')));
  });

  test('capture still honors severity threshold without losing warning cause',
      () {
    final buffer = DiagnosticLogBuffer();
    final logger =
        CaptureLogger(minLevel: LogLevel.warning, onCapture: buffer.add);
    logger.debug('hidden');
    logger.info('hidden');
    logger.warning('retry', StateError('temporary failure'));
    expect(buffer.length, 1);
    expect(buffer.list.single.payload, contains('temporary failure'));
  });
}
