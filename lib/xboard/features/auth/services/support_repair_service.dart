import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Only these operations may be offered by the future SDK adapter.
enum SupportRepairOperation {
  reconnect,
  restartKernel,
  reapplyProxy,
  restoreProxy
}

/// Host implementation must snapshot only non-secret, JSON-compatible settings.
abstract interface class SupportRepairAdapter {
  Future<Map<String, dynamic>> snapshot();
  Future<void> execute(SupportRepairOperation operation);
  Future<bool> verify();
  Future<void> rollback(Map<String, dynamic> previous);
}

/// Durable at-most-once execution. Interrupted records require inspection, never replay.
class SupportRepairService {
  static const _key = 'support_repair_journal_v1';
  bool _busy = false;

  Future<Map<String, dynamic>?> result(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final journal = jsonDecode(prefs.getString(_key) ?? '{}') as Map;
    final row = journal[id];
    return row is Map ? Map<String, dynamic>.from(row) : null;
  }

  Future<Map<String, dynamic>> execute({
    required String requestId,
    required String accountId,
    required String deviceId,
    required SupportRepairOperation operation,
    required DateTime expiresAt,
    required bool Function() authorized,
    required SupportRepairAdapter adapter,
  }) async {
    if (_busy) throw StateError('Repair already in progress');
    void check() {
      if (!authorized() ||
          !DateTime.now().toUtc().isBefore(expiresAt.toUtc())) {
        throw StateError('Repair authorization ended');
      }
    }

    check();
    if (requestId.isEmpty ||
        requestId.length > 128 ||
        accountId.isEmpty ||
        deviceId.isEmpty) {
      throw ArgumentError('Invalid repair identity');
    }
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final journal = Map<String, dynamic>.from(
          jsonDecode(prefs.getString(_key) ?? '{}') as Map);
      final existing = journal[requestId];
      if (existing is Map) {
        if (existing['accountId'] != accountId ||
            existing['deviceId'] != deviceId ||
            existing['operation'] != operation.name)
          throw StateError('Repair identity mismatch');
        return Map<String, dynamic>.from(existing);
      }
      // Refuse new work rather than evict IDs and accidentally allow a replay.
      if (journal.length >= 200) throw StateError('Repair journal full');
      final row = <String, dynamic>{
        'requestId': requestId,
        'accountId': accountId,
        'deviceId': deviceId,
        'operation': operation.name,
        'status': 'preparing',
        'createdAt': DateTime.now().toUtc().toIso8601String()
      };
      Future<void> save() async {
        journal[requestId] = row;
        if (!await prefs.setString(_key, jsonEncode(journal))) {
          throw StateError('Cannot persist repair journal');
        }
      }

      await save();
      final previous = await adapter.snapshot();
      check();
      row['previous'] = previous;
      row['status'] = 'executing';
      await save(); // Must commit before any system setting is changed.
      try {
        await adapter.execute(operation);
        row['verified'] = await adapter.verify();
        if (row['verified'] != true)
          throw StateError('Repair verification failed');
        row['status'] = 'succeeded';
      } catch (_) {
        row['status'] = 'rollingBack';
        await save();
        try {
          // Safety rollback remains allowed after user revokes further operations.
          await adapter.rollback(previous);
          row['status'] = 'failed';
          row['rollback'] = 'succeeded';
        } catch (_) {
          row['status'] = 'failed';
          row['rollback'] = 'failed';
        }
      }
      row['completedAt'] = DateTime.now().toUtc().toIso8601String();
      await save();
      return Map<String, dynamic>.from(row);
    } finally {
      _busy = false;
    }
  }
}
