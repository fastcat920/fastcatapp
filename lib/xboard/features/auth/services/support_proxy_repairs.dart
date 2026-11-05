import 'dart:convert';
import 'dart:io';
import 'package:fastcat_support/fastcat_support.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_clash/common/proxy.dart';

bool _busy = false;
Map<String, FastCatRepairHandler> supportProxyRepairs(
    {required String accountId,
    required String deviceId,
    required bool Function() identityValid,
    required int Function() port,
    required List<String> Function() bypass}) {
  const key = 'support_proxy_repairs_v1';
  Future<Map<String, dynamic>> load() async => Map<String, dynamic>.from(
      jsonDecode((await SharedPreferences.getInstance()).getString(key) ?? '{}')
          as Map);
  bool owns(Map row) =>
      row['account'] == accountId && row['device'] == deviceId;
  FastCatRepairResult? result(Map? row) => row?['result'] is Map
      ? FastCatRepairResult(
          outcome: row!['result']['outcome'],
          summary: row['result']['summary'],
          verified: row['result']['verified'],
          snapshotAvailable: row['result']['snapshotAvailable'],
          rollback: row['result']['rollback'])
      : null;
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux) ||
      proxy == null) return {};
  return {
    for (final operation in ['reapply_proxy', 'restore_settings'])
      operation: FastCatRepairHandler(
          supportsRollback: true,
          recover: (request) async {
            final row = (await load())[request.id];
            return row is Map && owns(row) ? result(row) : null;
          },
          execute: (request) async {
            request.throwIfCannotStart();
            if (!identityValid() || _busy)
              throw StateError('Repair unavailable');
            _busy = true;
            try {
              final journal = await load();
              final old = journal[request.id];
              if (old is Map) {
                if (!owns(old) || old['operation'] != operation)
                  throw StateError('Identity mismatch');
                final known = result(old);
                if (known == null) throw StateError('Repair result unknown');
                return known;
              }
              if (journal.length >= 200)
                throw StateError('Repair journal full');
              final before = await proxy!.captureConfiguration();
              final row = <String, dynamic>{
                'account': accountId,
                'device': deviceId,
                'operation': operation,
                'before': before,
                'status': 'prepared'
              };
              Future<void> save() async {
                journal[request.id] = row;
                if (!await (await SharedPreferences.getInstance())
                    .setString(key, jsonEncode(journal))) {
                  throw StateError('Cannot persist repair');
                }
              }

              await save();
              request.throwIfCannotStart();
              if (!identityValid()) throw StateError('Account changed');
              row['status'] = 'executing';
              await save();
              bool ok;
              if (operation == 'restore_settings') {
                final source = journal[request.restoreRequestId];
                if (source is! Map ||
                    !owns(source) ||
                    source['after'] is! Map ||
                    source['before'] is! Map) {
                  ok = false;
                } else {
                  ok = await proxy!.restoreConfiguration(
                      Map<String, dynamic>.from(source['before']),
                      Map<String, dynamic>.from(source['after']));
                }
              } else {
                ok = await proxy!.repairProxy(port(), bypass());
                row['after'] = await proxy!.captureConfiguration();
                await save();
                final actual = await proxy!.getSystemProxyStatus();
                ok =
                    ok && actual.enabled && actual.matches('127.0.0.1', port());
              }
              var rollback = 'not_needed';
              if (!ok && row['after'] is Map) {
                rollback = await proxy!.restoreConfiguration(
                        before, Map<String, dynamic>.from(row['after']))
                    ? 'succeeded'
                    : 'failed';
              }
              final finalResult = FastCatRepairResult(
                  outcome: ok
                      ? 'succeeded'
                      : rollback == 'succeeded'
                          ? 'rolled_back'
                          : 'failed',
                  summary: ok ? '代理设置操作完成并已复查' : '代理操作未完成或检测到设置冲突，请人工检查',
                  verified: ok,
                  snapshotAvailable: ok && operation == 'reapply_proxy',
                  rollback: rollback);
              row['result'] = finalResult.toJson();
              row['status'] = 'completed';
              await save();
              return finalResult;
            } finally {
              _busy = false;
            }
          })
  };
}
