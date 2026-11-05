/// A windows-service Helper must be started by SCM. Running that executable
/// directly cannot replace service registration, even with administrator rights.
Future<bool> startRegisteredWindowsHelper({
  required bool Function() launchService,
  required Future<bool> Function() waitForService,
  required Future<bool> Function() waitForHelper,
}) async {
  if (!launchService() || !await waitForService()) return false;
  return waitForHelper();
}
