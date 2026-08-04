abstract final class SessionTerminationCode {
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const deviceSessionExpired = 'DEVICE_SESSION_EXPIRED';
  static const deviceKickedByNewLogin = 'DEVICE_KICKED_BY_NEW_LOGIN';
  static const deviceRevoked = 'DEVICE_REVOKED';
  static const deviceSessionInvalid = 'DEVICE_SESSION_INVALID';

  static const values = {
    tokenExpired,
    deviceSessionExpired,
    deviceKickedByNewLogin,
    deviceRevoked,
    deviceSessionInvalid,
  };
}

bool isSessionTerminationCode(String? code) =>
    SessionTerminationCode.values.contains(code);

String? sessionTerminationCodeFromError(Object error) {
  final message = error.toString().toUpperCase();
  for (final code in const [
    SessionTerminationCode.deviceKickedByNewLogin,
    SessionTerminationCode.deviceRevoked,
    SessionTerminationCode.deviceSessionExpired,
    SessionTerminationCode.deviceSessionInvalid,
    SessionTerminationCode.tokenExpired,
  ]) {
    if (message.contains(code)) return code;
  }

  if (message.contains('401') ||
      message.contains('403') ||
      message.contains('UNAUTHORIZED') ||
      message.contains('UNAUTHENTICATED')) {
    return SessionTerminationCode.tokenExpired;
  }
  return null;
}

String preferSpecificSessionTerminationCode(
  String? currentCode,
  String incomingCode,
) {
  if (!isSessionTerminationCode(currentCode)) return incomingCode;
  return _terminationPriority(incomingCode) > _terminationPriority(currentCode!)
      ? incomingCode
      : currentCode;
}

int _terminationPriority(String code) => switch (code) {
      SessionTerminationCode.deviceKickedByNewLogin ||
      SessionTerminationCode.deviceRevoked =>
        3,
      SessionTerminationCode.deviceSessionExpired ||
      SessionTerminationCode.deviceSessionInvalid =>
        2,
      _ => 1,
    };
