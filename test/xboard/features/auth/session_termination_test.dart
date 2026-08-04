import 'package:fl_clash/xboard/features/auth/models/session_termination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('session termination reason', () {
    test('extracts a specific gateway code before generic auth markers', () {
      final code = sessionTerminationCodeFromError(
        Exception(
          '[DEVICE_KICKED_BY_NEW_LOGIN] request failed with status 401',
        ),
      );

      expect(code, SessionTerminationCode.deviceKickedByNewLogin);
    });

    test('does not classify unrelated network failures as token expiry', () {
      expect(
        sessionTerminationCodeFromError(Exception('connection timed out')),
        isNull,
      );
    });

    test('upgrades a generic reason regardless of event arrival order', () {
      expect(
        preferSpecificSessionTerminationCode(
          SessionTerminationCode.tokenExpired,
          SessionTerminationCode.deviceKickedByNewLogin,
        ),
        SessionTerminationCode.deviceKickedByNewLogin,
      );
      expect(
        preferSpecificSessionTerminationCode(
          SessionTerminationCode.deviceKickedByNewLogin,
          SessionTerminationCode.tokenExpired,
        ),
        SessionTerminationCode.deviceKickedByNewLogin,
      );
    });

    test('keeps revoked and expired reasons above generic expiry', () {
      expect(
        preferSpecificSessionTerminationCode(
          SessionTerminationCode.deviceSessionExpired,
          SessionTerminationCode.tokenExpired,
        ),
        SessionTerminationCode.deviceSessionExpired,
      );
      expect(
        preferSpecificSessionTerminationCode(
          SessionTerminationCode.tokenExpired,
          SessionTerminationCode.deviceRevoked,
        ),
        SessionTerminationCode.deviceRevoked,
      );
    });
  });
}
