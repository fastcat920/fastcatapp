import 'package:fl_clash/xboard/features/connectivity/models/service_connectivity_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyServiceConnectivityFailure', () {
    test('reports no network when no network interface is available', () {
      expect(
        classifyServiceConnectivityFailure(
          hasNetworkInterface: false,
          baseNetworkReachable: false,
        ),
        ServiceConnectivityCause.noNetwork,
      );
    });

    test('reports gateway unavailable when the public network is reachable',
        () {
      expect(
        classifyServiceConnectivityFailure(
          hasNetworkInterface: true,
          baseNetworkReachable: true,
        ),
        ServiceConnectivityCause.gatewayUnavailable,
      );
    });

    test('reports restricted network when only an interface is available', () {
      expect(
        classifyServiceConnectivityFailure(
          hasNetworkInterface: true,
          baseNetworkReachable: false,
        ),
        ServiceConnectivityCause.networkRestricted,
      );
    });

    test('does not report restricted network when active proxy is reachable',
        () {
      expect(
        classifyServiceConnectivityFailure(
          hasNetworkInterface: true,
          baseNetworkReachable: false,
          proxyNetworkReachable: true,
        ),
        ServiceConnectivityCause.gatewayUnavailable,
      );
    });

    test('reachable proxy also compensates for a transient interface event',
        () {
      expect(
        classifyServiceConnectivityFailure(
          hasNetworkInterface: false,
          baseNetworkReachable: false,
          proxyNetworkReachable: true,
        ),
        ServiceConnectivityCause.gatewayUnavailable,
      );
    });
  });

  test('copyWith can clear a previous connectivity cause', () {
    const state = ServiceConnectivityState(
      status: ServiceConnectivityStatus.offline,
      cause: ServiceConnectivityCause.gatewayUnavailable,
    );

    expect(
        state.copyWith(clearCause: true).cause, ServiceConnectivityCause.none);
  });
}
