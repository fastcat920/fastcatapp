import 'package:fastcat_support/fastcat_support.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/diagnostics/services/local_proxy_probe.dart';
import 'support_repair_service.dart';

final _executor = SupportRepairService();

Map<String, FastCatRepairHandler> supportConnectionRepairs({
  required String accountId,
  required String deviceId,
  required bool Function() identityValid,
  required int Function() proxyPort,
}) {
  FastCatRepairResult? convert(Map<String, dynamic>? row) {
    if (row == null || !['succeeded', 'failed'].contains(row['status']))
      return null;
    final ok = row['status'] == 'succeeded';
    final restored = row['rollback'] == 'succeeded';
    return FastCatRepairResult(
        outcome: ok
            ? 'succeeded'
            : restored
                ? 'rolled_back'
                : 'failed',
        summary: ok ? '连接操作完成，代理链路复查通过' : '连接修复未通过，请查看本地连接状态',
        verified: ok,
        rollback: restored
            ? 'succeeded'
            : row['rollback'] == 'failed'
                ? 'failed'
                : 'not_needed');
  }

  return {
    for (final entry in {
      'reconnect': SupportRepairOperation.reconnect,
      'restart_core': SupportRepairOperation.restartKernel
    }.entries)
      entry.key: FastCatRepairHandler(
        execute: (request) async {
          request.throwIfCannotStart();
          final row = await _executor.execute(
              requestId: request.id,
              accountId: accountId,
              deviceId: deviceId,
              operation: entry.value,
              expiresAt: request.expiresAt,
              authorized: identityValid,
              adapter: _ConnectionAdapter(entry.value, proxyPort));
          final result = convert(row);
          if (result == null)
            throw StateError('Repair result requires recovery');
          return result;
        },
        recover: (request) async {
          final row = await _executor.result(request.id);
          if (row?['accountId'] != accountId ||
              row?['deviceId'] != deviceId ||
              row?['operation'] != entry.value.name) return null;
          return convert(row);
        },
      ),
  };
}

class _ConnectionAdapter implements SupportRepairAdapter {
  _ConnectionAdapter(this.operation, this.port);
  final SupportRepairOperation operation;
  final int Function() port;
  bool wasConnected = false;
  @override
  Future<Map<String, dynamic>> snapshot() async {
    wasConnected = globalState.isStart;
    if (!wasConnected)
      throw StateError('Connect before requesting connection repair');
    return {'connected': wasConnected};
  }

  @override
  Future<void> execute(SupportRepairOperation _) async {
    if (operation == SupportRepairOperation.restartKernel) {
      await globalState.appController.restartCore();
    } else {
      if (!await globalState.appController.updateStatus(false))
        throw StateError('Disconnect failed');
      if (!await globalState.appController.updateStatus(true))
        throw StateError('Reconnect failed');
    }
  }

  @override
  Future<bool> verify() async {
    if (!globalState.isStart) return false;
    final probe = await probeLocalProxy(
        port: port(),
        target: Uri.parse('https://www.gstatic.com/generate_204'));
    return probe.ok;
  }

  @override
  Future<void> rollback(Map<String, dynamic> previous) async {
    final wanted = previous['connected'] == true;
    if (globalState.isStart != wanted &&
        !await globalState.appController.updateStatus(wanted)) {
      throw StateError('Connection state restore failed');
    }
  }
}
