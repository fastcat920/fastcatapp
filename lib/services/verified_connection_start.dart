/// Publish a connection only after its live core state has been verified.
/// Rollback remains inside the operation, so callers cannot begin another
/// connection while failed routing is still being stopped.
Future<bool> runVerifiedConnectionStart({
  required Future<bool> Function() start,
  required Future<void> Function() verify,
  required void Function() commit,
  required Future<void> Function() rollback,
}) async {
  var committed = false;
  try {
    if (!await start()) {
      return false;
    }
    await verify();
    commit();
    committed = true;
    return true;
  } finally {
    if (!committed) await rollback();
  }
}
