class NetworkDiagnosticSnapshot {
  const NetworkDiagnosticSnapshot({
    required this.generatedAt,
    required this.networkType,
    required this.vpnConnected,
    required this.vpnStatus,
    required this.nodeAvailable,
    required this.conclusion,
    required this.dnsResults,
    required this.ipResults,
    required this.nodeLayerResults,
    required this.directResults,
    required this.proxyResults,
    required this.nodeResult,
  });

  final DateTime generatedAt;
  final String networkType;
  final bool vpnConnected;
  final String vpnStatus;
  final bool nodeAvailable;
  final String conclusion;
  final List<NetworkDiagnosticItem> dnsResults;
  final List<NetworkDiagnosticItem> ipResults;
  final List<NetworkDiagnosticItem> nodeLayerResults;
  final List<NetworkDiagnosticItem> directResults;
  final List<NetworkDiagnosticItem> proxyResults;
  final Map<String, dynamic> nodeResult;
}

class NetworkDiagnosticItem {
  const NetworkDiagnosticItem({
    required this.label,
    required this.detail,
    required this.elapsedMs,
    required this.status,
  });

  final String label;
  final String detail;
  final int elapsedMs;
  final NetworkDiagnosticItemStatus status;

  String get marker => switch (status) {
        NetworkDiagnosticItemStatus.success => '✓',
        NetworkDiagnosticItemStatus.warning => '⚠',
        NetworkDiagnosticItemStatus.failure => '✗',
        NetworkDiagnosticItemStatus.skipped => '-',
      };
}

enum NetworkDiagnosticItemStatus { success, warning, failure, skipped }

class NetworkDiagnosticSnapshotStore {
  const NetworkDiagnosticSnapshotStore._();

  static NetworkDiagnosticSnapshot? latest;
}
