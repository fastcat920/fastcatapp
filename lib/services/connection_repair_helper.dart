/// A failed optional Helper must not break a working system-proxy connection.
/// registerService owns bounded waits; do not time out the entire future and
/// allow late background work to restart services after repair has ended.
Future<bool> prepareConnectionRepairHelper({
  required bool isWindows,
  required bool tunRequested,
  required Future<bool> Function() ensureHelper,
}) async {
  if (!isWindows || !tunRequested) return true;
  return ensureHelper();
}
