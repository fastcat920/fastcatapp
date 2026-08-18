import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verified gateway clears stale circuit breaker state', () {
    final failedAt = DateTime(2026, 8, 18);
    final config = GatewayEndpointConfig(
      baseUrl: 'https://gateway.example.com',
      apiPrefix: '/api/v1',
      source: 'test',
      updatedAt: failedAt,
      lastFailureAt: failedAt,
      disabledUntil: failedAt.add(const Duration(minutes: 2)),
      failureCount: 2,
      verificationStatus: GatewayVerificationStatus.circuitOpen,
    );

    final recovered = config.copyWith(
      failureCount: 0,
      verificationStatus: GatewayVerificationStatus.verified,
      clearFailureState: true,
    );

    expect(recovered.lastFailureAt, isNull);
    expect(recovered.disabledUntil, isNull);
    expect(recovered.failureCount, 0);
    expect(recovered.verificationStatus, GatewayVerificationStatus.verified);
  });
}
