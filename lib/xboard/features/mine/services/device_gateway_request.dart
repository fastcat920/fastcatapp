import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

/// Device operations share the SDK's authenticated, bounded failover path.
/// Replaying here after SDK exhaustion could repeat mutations and stale tokens.
Future<T> requestDeviceGateway<T>({
  required XBoardSDK sdk,
  required bool Function() isCurrent,
  required Future<T> Function(HttpService, Map<String, String>) request,
}) async {
  void checkSession() {
    if (!isCurrent()) throw const DeviceGatewaySessionChanged();
  }

  checkSession();
  final token = await sdk.getToken();
  checkSession();
  final credential = token
      ?.replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
      .trim();
  if (credential == null || !credential.startsWith('dg_')) {
    throw const DeviceGatewaySessionChanged();
  }
  final response = await request(sdk.httpService, {'Authorization': token!});
  checkSession();
  return response;
}

class DeviceGatewaySessionChanged implements Exception {
  const DeviceGatewaySessionChanged();
}
