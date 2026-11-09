import 'package:fl_clash/common/serial_operation_queue.dart';

class _DnsLease {
  _DnsLease(this.original, this.installed);
  final List<String> original;
  final List<String> installed;
}

/// Restore only the same service and only values still owned by this process.
class MacosDnsLease {
  MacosDnsLease(
      {required this.currentService, required this.read, required this.write});
  final Future<String?> Function() currentService;
  final Future<List<String>?> Function(String) read;
  final Future<bool> Function(String, List<String>) write;
  final _queue = SerialOperationQueue();
  final _leases = <String, _DnsLease>{};

  bool _same(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

  Future<bool> apply() => _queue.run(() async {
        final service = await currentService();
        if (service == null) return false;
        final before = await read(service);
        if (before == null) return false;
        var lease = _leases[service];
        if (lease != null && !_same(before, lease.installed)) {
          _leases.remove(service);
          lease = null;
        }
        if (before.contains('223.5.5.5')) return true;
        final desired = [...before, '223.5.5.5'];
        final succeeded = await write(service, desired);
        final after = await read(service);
        if (after == null || _same(after, desired)) {
          _leases[service] =
              _DnsLease(List.of(lease?.original ?? before), desired);
        }
        return succeeded && after != null && _same(after, desired);
      });

  Future<bool> restore() => _queue.run(() async {
        var restored = true;
        for (final service in List.of(_leases.keys)) {
          final lease = _leases[service]!;
          final current = await read(service);
          if (current == null) {
            restored = false;
            continue;
          }
          if (!_same(current, lease.installed)) {
            _leases
                .remove(service); // Another writer owns the current settings.
            continue;
          }
          final written = await write(service, lease.original);
          final after = await read(service);
          if (written && after != null && _same(after, lease.original)) {
            _leases.remove(service);
          } else {
            restored = false;
          }
        }
        return restored;
      });
}

/// Keep full service names (for example "USB 10/100/1000 LAN").
String? macosServiceForDevice(String output, String device) {
  String? service;
  final devicePattern = RegExp('Device: *${RegExp.escape(device)}' r'(?:,|\))');
  for (final line in output.split('\n')) {
    final match = RegExp(r'^\((\d+|\*)\)\s*(.+)$').firstMatch(line.trim());
    if (match != null) {
      service = match.group(1) == '*' ? null : match.group(2)!.trim();
    }
    if (devicePattern.hasMatch(line)) {
      return service;
    }
  }
  return null;
}
