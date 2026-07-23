enum ServiceConnectivityStatus {
  online,
  degraded,
  offline,
  recovering,
}

enum ServiceConnectivityCause {
  none,
  noNetwork,
  gatewayUnavailable,
  networkRestricted,
  initializationFailed,
}

ServiceConnectivityCause classifyServiceConnectivityFailure({
  required bool hasNetworkInterface,
  required bool baseNetworkReachable,
}) {
  if (!hasNetworkInterface) {
    return ServiceConnectivityCause.noNetwork;
  }
  if (baseNetworkReachable) {
    return ServiceConnectivityCause.gatewayUnavailable;
  }
  return ServiceConnectivityCause.networkRestricted;
}

class ServiceConnectivityState {
  const ServiceConnectivityState({
    this.status = ServiceConnectivityStatus.recovering,
    this.cause = ServiceConnectivityCause.none,
    this.consecutiveFailures = 0,
    this.consecutiveSuccesses = 0,
    this.lastOnlineAt,
    this.lastCheckedAt,
    this.reason,
  });

  final ServiceConnectivityStatus status;
  final ServiceConnectivityCause cause;
  final int consecutiveFailures;
  final int consecutiveSuccesses;
  final DateTime? lastOnlineAt;
  final DateTime? lastCheckedAt;
  final String? reason;

  bool get isOnline => status == ServiceConnectivityStatus.online;
  bool get isDegraded => status == ServiceConnectivityStatus.degraded;
  bool get isOffline => status == ServiceConnectivityStatus.offline;
  bool get isRecovering => status == ServiceConnectivityStatus.recovering;

  ServiceConnectivityState copyWith({
    ServiceConnectivityStatus? status,
    ServiceConnectivityCause? cause,
    int? consecutiveFailures,
    int? consecutiveSuccesses,
    DateTime? lastOnlineAt,
    DateTime? lastCheckedAt,
    String? reason,
    bool clearReason = false,
    bool clearCause = false,
  }) {
    return ServiceConnectivityState(
      status: status ?? this.status,
      cause: clearCause ? ServiceConnectivityCause.none : cause ?? this.cause,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
      lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      reason: clearReason ? null : reason ?? this.reason,
    );
  }
}
