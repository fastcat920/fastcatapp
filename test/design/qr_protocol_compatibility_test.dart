import 'dart:io';

import 'package:fl_clash/xboard/features/auth/services/qr_login_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Source-level guards for the opt-in native client. These are
// protocol checks, not a replacement for a tvOS build or a real QR login test.
String _section(String source, String from, String until) {
  final start = source.indexOf(from);
  final end = source.indexOf(until, start + from.length);
  expect(start, greaterThanOrEqualTo(0),
      reason: 'Missing source marker: $from');
  expect(end, greaterThan(start), reason: 'Missing source marker: $until');
  return source.substring(start, end);
}

void main() {
  final client = File('tvos/FastCatTV/GatewayClient.swift').readAsStringSync();
  final coordinator =
      File('tvos/FastCatTV/TVQRLoginCoordinator.swift').readAsStringSync();

  test('tvOS opts into receipt acknowledgement without changing old fields', () {
    final create = _section(
      client,
      'func createQRSession()',
      'func pollQRSession(',
    );
    expect(create, contains('device_id: String'));
    expect(create, contains('device_name: String'));
    expect(create, contains('platform: String'));
    expect(create, contains('path: "/auth/qr/sessions", method: "POST"'));
    expect(create, contains('delivery_ack = true'));
  });

  test('legacy tvOS polls with the target secret and keeps cancel separate',
      () {
    final poll =
        _section(client, 'func pollQRSession(', 'func cancelQRSession(');
    expect(poll, contains('challenge.pollToken'));
    expect(poll,
        contains(r'/auth/qr/sessions/\(challenge.id)?poll_token=\(token)'));
    final cancel =
        _section(client, 'func cancelQRSession(', 'func fetchGuestConfig(');
    expect(cancel, contains('challenge.pollToken'));
    expect(cancel, contains('method: "DELETE"'));
    expect(poll, isNot(contains('/ack')));
  });

  test('legacy tvOS approved response keeps the existing credential envelope',
      () {
    final response = _section(
        client, 'struct QRLoginResponse:', 'struct TVLoginCredentials:');
    expect(response, contains('let status: String'));
    expect(response, contains('let login: LoginPayload?'));
    expect(response, contains('let authData: String?'));
    expect(response, contains('let token: String?'));
    expect(response, contains('authData = "auth_data"'));
    expect(response, isNot(contains('delivery_ack')));
  });

  test('tvOS only acknowledges negotiated receipts after local sign-in', () {
    expect(coordinator, contains('let token = login.authData ?? login.token'));
    expect(coordinator, contains('if value.deliveryACK, let deliveryID'));
    expect(coordinator.indexOf('onAuthenticated?(token, login.email)'),
        lessThan(coordinator.indexOf('try await acknowledge(value, deliveryID)')));
    expect(client, contains('forKey: .deliveryACK)) ?? false'));
  });

  test('Flutter still accepts legacy create responses with no new fields', () {
    final challenge = QrLoginService.decodeChallenge({
      'success': true,
      'data': {
        'id': 'qrl_test_legacy',
        'poll_token': 'qpt_test_legacy',
        'qr_data': 'fastcat://login/qr?challenge=qrl_test_legacy',
        'expires_at': '2026-01-01T00:02:00Z',
      },
    });
    expect(challenge.id, 'qrl_test_legacy');
    expect(challenge.expiresAt, DateTime.utc(2026, 1, 1, 0, 2));
  });

  test('Flutter legacy approved response still delivers auth_data or token',
      () {
    for (final key in ['auth_data', 'token']) {
      final result = QrLoginService.decodePoll({
        'success': true,
        'data': {
          'status': 'approved',
          'login': {key: 'test-only-token', 'email': 'test@invalid'},
        },
      });
      expect(result?.token, 'test-only-token');
      expect(result?.email, 'test@invalid');
    }
  });
}
