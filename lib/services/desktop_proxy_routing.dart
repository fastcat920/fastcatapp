/// System routing is part of startup, not a notification after publishing it.
Future<void> startVerifiedDesktopProxy({
  required bool enabled,
  required Future<bool?> Function() start,
  required Future<bool> Function() matches,
}) async {
  if (!enabled) return;
  if (await start() != true || !await matches()) {
    throw StateError('System proxy setup was not verified');
  }
}
