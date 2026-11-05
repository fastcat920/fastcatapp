import 'dart:convert';

import 'package:fl_clash/common/diagnostic_log_buffer.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:flutter_test/flutter_test.dart';

Log record(String text, {int second = 0, LogLevel level = LogLevel.info}) =>
    Log(
      payload: text,
      logLevel: level,
      dateTime: DateTime(2026, 10, 7, 20, 0, second).toString(),
    );

void main() {
  test(
      'export keeps actionable stack frames through repeated privacy filtering',
      () {
    final buffer = DiagnosticLogBuffer(normalLimit: 1);
    buffer.add(record('[快猫] panic: nil pointer\n'
        'main.updateConfig(0x1234)\n'
        '\t/Users/private-user/app/core/common.go:199 +0xbc'));
    buffer.add(record('[快猫] created by main.startServer in goroutine 1\n'
        '\t/Users/private-user/app/core/server.go:86 +0x384'));
    buffer.add(record('normal 1'));
    buffer.add(record('normal 2'));
    final report = buffer.export(chinese: true);
    expect(buffer.importantCount, 2);
    expect(report, contains('main.updateConfig(0x1234)'));
    expect(report, contains('common.go:199 +0xbc'));
    expect(report, contains('main.startServer in goroutine 1'));
    expect(report, isNot(contains('private-user')));
  });
  test('ordinary floods cannot evict repair records; each quota is independent',
      () {
    final buffer = DiagnosticLogBuffer(importantLimit: 3, normalLimit: 10);
    buffer.add(record('[ConnectionHealth] repair started id=1'));
    for (var i = 0; i < 500; i++) {
      buffer.add(record('normal $i', second: i));
    }
    buffer.add(record('[ConnectionHealth] repair completed id=1', second: 501));
    expect(buffer.importantCount, 2);
    expect(buffer.normalCount, 10);
    expect(buffer.evictedRecords, 490);
    expect(buffer.export(chinese: true), contains('repair started'));
    expect(buffer.export(chinese: true), contains('repair completed'));
    for (var i = 0; i < 3; i++) {
      buffer.add(record('failure $i', second: 502 + i, level: LogLevel.error));
    }
    expect(buffer.importantCount, 3);
    expect(buffer.normalCount, 10);
    expect(buffer.evictedRecords, 492);
  });

  test('repetitions preserve first and last time without merging repair steps',
      () {
    final buffer = DiagnosticLogBuffer();
    buffer.add(record('gateway synced'));
    buffer.add(record('heartbeat', second: 1));
    buffer.add(record('gateway synced', second: 2));
    buffer.add(record('gateway synced', second: 5));
    expect(buffer.normalCount, 2);
    expect(buffer.mergedOccurrences, 2);
    final report = buffer.export(chinese: true);
    expect(report, contains('共出现 3 次'));
    expect(report, contains('首次：2026-10-07 20:00:00.000'));
    expect(report, contains('最后：2026-10-07 20:00:05.000'));
    buffer.add(record('gateway synced', second: 6));
    expect(buffer.normalCount, 3);
    buffer.add(record('[ConnectionHealth] step=write_system_proxy id=1'));
    buffer.add(
        record('[ConnectionHealth] step=write_system_proxy id=1', second: 1));
    expect(buffer.importantCount, 2);
  });

  test('different original endpoints and correlation IDs are not merged', () {
    final buffer = DiagnosticLogBuffer();
    buffer.add(record('request to 10.10.10.1'));
    buffer.add(record('request to 10.20.20.1', second: 1));
    buffer.add(record('request id=1'));
    buffer.add(record('request id=1', second: 1));
    expect(buffer.length, 4);
    expect(buffer.export(chinese: false), isNot(contains('10.10.10.1')));
    expect(buffer.export(chinese: false), isNot(contains('10.20.20.1')));
  });

  test('only noisy debug successes are suppressed, never warnings or errors',
      () {
    final buffer = DiagnosticLogBuffer();
    buffer.add(record('[DNS] cache hit', level: LogLevel.debug));
    buffer.add(record('XTLS Vision padding', level: LogLevel.debug));
    buffer.add(record('[DNS] failed', level: LogLevel.debug));
    buffer.add(record('[DNS] cache hit', level: LogLevel.warning));
    buffer.add(record('XTLS Vision padding', level: LogLevel.error));
    expect(buffer.suppressedDebug, 2);
    expect(buffer.importantCount, 3);
  });

  test(
      'byte limits bound both buckets and oversize unicode is visibly truncated',
      () {
    final buffer =
        DiagnosticLogBuffer(bytesPerBucket: 512, entryByteLimit: 256);
    for (var i = 0; i < 5; i++) {
      buffer.add(record('ordinary $i ${'a' * 150}', second: i));
    }
    buffer.add(record('failed ${'中' * 1000}', level: LogLevel.error));
    expect(buffer.textBytes, lessThanOrEqualTo(1024));
    expect(buffer.truncatedRecords, 1);
    expect(buffer.evictedRecords, greaterThan(0));
    expect(buffer.export(chinese: false), contains('truncated'));
    expect(
        utf8.encode(buffer.list.last.payload).length, lessThanOrEqualTo(256));
  });

  test('copy isolates mutations; clear also resets counters', () {
    final original = DiagnosticLogBuffer(normalLimit: 1);
    original.add(record('first'));
    final next = original.copyWith();
    next.add(record('second'));
    expect(original.list.single.payload, 'first');
    expect(original.evictedRecords, 0);
    expect(next.evictedRecords, 1);
    next.clear();
    expect(next.length, 0);
    expect(next.evictedRecords, 0);
    expect(next.textBytes, 0);
    expect(next.export(chinese: true), contains('时间范围：—'));
    expect(original.length, 1);
  });

  test('export merges buckets in time order and explains actual retained scope',
      () {
    final buffer = DiagnosticLogBuffer();
    buffer.add(record('normal', second: 2));
    buffer.add(record('warning', second: 1, level: LogLevel.warning));
    buffer.add(record('late', second: 3));
    final report = buffer.export(
        chinese: false, clientVersion: '3.6.0+8', systemVersion: 'macOS');
    expect(report.indexOf('20:00:01.000 warning'),
        lessThan(report.indexOf('20:00:02.000 normal')));
    expect(report, contains('not complete history'));
    expect(report, contains('Client version: 3.6.0+8'));
    expect(report, contains('Retained: 3'));
  });
}
