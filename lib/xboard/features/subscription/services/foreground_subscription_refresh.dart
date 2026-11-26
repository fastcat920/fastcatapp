/// Recheck the foreground and session after the asynchronous VPN status query.
Future<void> refreshConnectedSubscriptionOnResume({
  required bool Function() isCurrent,
  required Future<bool> Function() isConnected,
  required Future<void> Function() refresh,
}) async {
  if (!isCurrent() || !await isConnected() || !isCurrent()) return;
  await refresh();
}
