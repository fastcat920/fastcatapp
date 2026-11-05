import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';

import 'fixed.dart';
import 'sensitive_masker.dart';

/// Session-only storage. Normal traffic cannot evict operational/error records.
/// Extends the existing list contract so no persisted model/schema changes are needed.
class DiagnosticLogBuffer extends FixedList<Log> {
  DiagnosticLogBuffer({
    this.importantLimit = 1000,
    this.normalLimit = 2000,
    this.bytesPerBucket = 2 * 1024 * 1024,
    this.entryByteLimit = 64 * 1024,
  })  : assert(importantLimit > 0 && normalLimit > 0),
        assert(bytesPerBucket >= 256 && entryByteLimit >= 128),
        super(importantLimit + normalLimit);

  factory DiagnosticLogBuffer.fromList(FixedList<Log> source) {
    if (source is DiagnosticLogBuffer) return source;
    final result = DiagnosticLogBuffer();
    for (final log in source.list) {
      result.add(log);
    }
    return result;
  }

  final int importantLimit;
  final int normalLimit;
  final int bytesPerBucket;
  final int entryByteLimit;
  final List<_Entry> _important = [];
  final List<_Entry> _normal = [];
  int _importantBytes = 0;
  int _normalBytes = 0;
  int _sequence = 0;
  int evictedRecords = 0;
  int evictedOccurrences = 0;
  int suppressedDebug = 0;
  int truncatedRecords = 0;

  int get importantCount => _important.length;
  int get normalCount => _normal.length;
  int get textBytes => _importantBytes + _normalBytes;
  int get retainedOccurrences =>
      [..._important, ..._normal].fold(0, (sum, entry) => sum + entry.count);
  int get mergedOccurrences => retainedOccurrences - length;

  static bool isImportant(Log log) {
    if (log.logLevel == LogLevel.warning || log.logLevel == LogLevel.error) {
      return true;
    }
    return RegExp(
      r'\[ProxyManager\]|\[Proxy\]|\[ConnectionHealth\]|\[ProfileImport\]|'
      r'\[ProfileVault\]|\[VPN\]|\[Tun\]|\b(failed|failure|error|denied|disconnect|connected|panic|fatal|SIGSEGV|goroutine)\b|'
      r'系统代理|管理员授权|授权失败|订阅导入|配置导入|开始连接|连接成功|断开连接|'
      r'开始登录|登录成功|登录失败|退出登录|节点切换|失败|异常|错误|❌|⚠',
      caseSensitive: false,
    ).hasMatch(log.payload);
  }

  static bool _noisyDebug(Log log) =>
      log.logLevel == LogLevel.debug &&
      RegExp(r'\[DNS\]|\[Rule\]|XTLS Vision|REALITY|fingerprint',
              caseSensitive: false)
          .hasMatch(log.payload);

  @override
  void add(Log item) {
    final log = item;
    final important = isImportant(log);
    if (!important && _noisyDebug(log)) {
      suppressedDebug++;
      return;
    }
    // Identity is computed before masking: two different private endpoints
    // must not collapse merely because their redacted representations match.
    // The digest is private, session-only and never included in exported logs.
    final identity = sha256
        .convert(utf8.encode('${log.logLevel.name}\u0000${log.payload}'))
        .toString();
    final limit = entryByteLimit < bytesPerBucket - 192
        ? entryByteLimit
        : bytesPerBucket - 192;
    var payload = SensitiveMasker.maskText(log.payload);
    final bytes = utf8.encode(payload);
    if (bytes.length > limit) {
      payload =
          '${utf8.decode(bytes.take(limit - 64).toList(), allowMalformed: true)}\n[log truncated / 日志过长已截断]';
      truncatedRecords++;
    }
    final safe = log.copyWith(payload: payload);
    final bucket = important ? _important : _normal;
    final time = DateTime.tryParse(safe.dateTime);
    _Entry? previous;
    // Do not combine operational steps, errors, or records with correlation IDs.
    if (!important &&
        time != null &&
        !RegExp(r'\b(id|runId|requestId|operationId)\s*[:=]',
                caseSensitive: false)
            .hasMatch(log.payload)) {
      for (final entry in bucket.reversed) {
        if (entry.identity != identity) continue;
        final first = DateTime.tryParse(entry.firstTime);
        if (first != null &&
            !time.isBefore(first) &&
            time.difference(first) <= const Duration(seconds: 5)) {
          previous = entry;
        }
        break;
      }
    }
    if (previous != null) {
      bucket.remove(previous);
      _addBytes(important, -previous.bytes);
    }
    final entry = _Entry(
      log: safe,
      firstTime: previous?.firstTime ?? safe.dateTime,
      count: (previous?.count ?? 0) + 1,
      sequence: ++_sequence,
      identity: identity,
    );
    bucket.add(entry);
    _addBytes(important, entry.bytes);
    final maxEntries = important ? importantLimit : normalLimit;
    while (bucket.length > maxEntries ||
        (important ? _importantBytes : _normalBytes) > bytesPerBucket) {
      final removed = bucket.removeAt(0);
      _addBytes(important, -removed.bytes);
      evictedRecords++;
      evictedOccurrences += removed.count;
    }
  }

  void _addBytes(bool important, int amount) {
    if (important) {
      _importantBytes += amount;
    } else {
      _normalBytes += amount;
    }
  }

  List<_Entry> get _ordered => [..._important, ..._normal]..sort((a, b) {
      final left = DateTime.tryParse(a.log.dateTime);
      final right = DateTime.tryParse(b.log.dateTime);
      if (left != null && right != null) {
        final order = left.compareTo(right);
        if (order != 0) return order;
      }
      return a.sequence.compareTo(b.sequence);
    });

  List<Log> displayLogs({required bool chinese}) =>
      List.unmodifiable(_ordered.map((entry) => entry.display(chinese)));

  @override
  List<Log> get list => displayLogs(chinese: false);
  @override
  int get length => _important.length + _normal.length;
  @override
  Log operator [](int index) => list[index];

  String summary({required bool chinese}) {
    final entries = _ordered;
    final times = entries.expand((e) => [e.firstTime, e.log.dateTime]).toList()
      ..sort();
    final range = times.isEmpty ? '—' : '${times.first} ~ ${times.last}';
    return chinese
        ? '日志范围：本次运行中当前保留的记录（非完整历史）\n'
            '保留条数：$length（关键 $importantCount，普通 $normalCount）\n'
            '时间范围：$range\n'
            '已淘汰：$evictedRecords 条记录（含 $evictedOccurrences 次事件）\n'
            '重复合并：当前记录中合并 $mergedOccurrences 次重复事件\n'
            '调试细节默认不采集；额外过滤：$suppressedDebug 条；过长截断：$truncatedRecords 条'
        : 'Scope: retained records from this session (not complete history)\n'
            'Retained: $length (important $importantCount, normal $normalCount)\n'
            'Time range: $range\n'
            'Evicted: $evictedRecords records ($evictedOccurrences events)\n'
            'Merged: $mergedOccurrences repeated events in retained records\n'
            'Debug details are not collected by default; additionally filtered: $suppressedDebug; truncated: $truncatedRecords';
  }

  String export(
      {required bool chinese,
      String? clientVersion,
      String? systemVersion,
      String Function(String)? localize}) {
    final header = <String>[
      '=== FastCat ${chinese ? '运行日志' : 'Runtime logs'} ===',
      if (clientVersion != null)
        '${chinese ? '客户端版本' : 'Client version'}: $clientVersion',
      if (systemVersion != null)
        '${chinese ? '系统版本' : 'System version'}: $systemVersion',
      summary(chinese: chinese),
      '',
    ];
    return [
      ...header,
      ...displayLogs(chinese: chinese).map((log) =>
          '${log.dateTime} ${SensitiveMasker.maskText(localize?.call(log.payload) ?? log.payload)}')
    ].join('\n');
  }

  @override
  DiagnosticLogBuffer copyWith() {
    final copy = DiagnosticLogBuffer(
        importantLimit: importantLimit,
        normalLimit: normalLimit,
        bytesPerBucket: bytesPerBucket,
        entryByteLimit: entryByteLimit);
    copy._important.addAll(_important);
    copy._normal.addAll(_normal);
    copy._importantBytes = _importantBytes;
    copy._normalBytes = _normalBytes;
    copy._sequence = _sequence;
    copy.evictedRecords = evictedRecords;
    copy.evictedOccurrences = evictedOccurrences;
    copy.suppressedDebug = suppressedDebug;
    copy.truncatedRecords = truncatedRecords;
    return copy;
  }

  @override
  void clear() {
    _important.clear();
    _normal.clear();
    _importantBytes = _normalBytes = _sequence = 0;
    evictedRecords =
        evictedOccurrences = suppressedDebug = truncatedRecords = 0;
  }
}

class _Entry {
  _Entry(
      {required this.log,
      required this.firstTime,
      required this.count,
      required this.sequence,
      required this.identity});
  final Log log;
  final String firstTime;
  final int count;
  final int sequence;
  final String identity;
  // Include timestamp text and bounded space for the repetition annotation.
  late final int bytes = utf8.encode(log.payload).length +
      utf8.encode(log.dateTime).length +
      utf8.encode(firstTime).length +
      96;

  Log display(bool chinese) => count == 1
      ? log
      : log.copyWith(
          payload:
              '${log.payload}\n${chinese ? '同一消息共出现 $count 次；首次：$firstTime；最后：${log.dateTime}' : 'Repeated $count times; first: $firstTime; last: ${log.dateTime}'}');
}
