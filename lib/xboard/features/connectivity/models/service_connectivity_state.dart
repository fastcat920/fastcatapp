enum ServiceConnectivityStatus {
  online,
  degraded,
  offline,
  recovering,
}

class ServiceConnectivityState {
  const ServiceConnectivityState({
    this.status = ServiceConnectivityStatus.recovering,
    this.consecutiveFailures = 0,
    this.consecutiveSuccesses = 0,
    this.lastOnlineAt,
    this.lastCheckedAt,
    this.reason,
  });

  final ServiceConnectivityStatus status;
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
    int? consecutiveFailures,
    int? consecutiveSuccesses,
    DateTime? lastOnlineAt,
    DateTime? lastCheckedAt,
    String? reason,
    bool clearReason = false,
  }) {
    return ServiceConnectivityState(
      status: status ?? this.status,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
      lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      reason: clearReason ? null : reason ?? this.reason,
    );
  }
}
