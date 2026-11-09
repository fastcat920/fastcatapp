/// Routing restoration must complete before the process that serves it is killed.
/// No non-cancelling timeout is allowed to turn an unfinished cleanup into success.
Future<void> runOrderedDesktopShutdown({
  required Future<bool> Function() restoreRouting,
  required Future<void> Function() shutdownCore,
  required Future<void> Function() destroyService,
}) async {
  if (!await restoreRouting()) {
    throw StateError('Network settings could not be restored');
  }
  await shutdownCore();
  await destroyService();
}
