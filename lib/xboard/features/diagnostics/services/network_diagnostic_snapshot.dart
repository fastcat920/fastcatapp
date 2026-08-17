import 'package:fl_clash/common/sensitive_masker.dart';

Map<String, dynamic> sanitizeNetworkDiagnosticNodeResult(
  Map<String, dynamic> source,
) {
  final sanitized = Map<String, dynamic>.from(source);
  final host = source['host']?.toString();
  if (host != null && host.isNotEmpty) {
    sanitized['host'] = SensitiveMasker.maskText(host);
  }
  final port = source['port']?.toString();
  if (port != null && port.isNotEmpty) {
    sanitized['port'] = SensitiveMasker.maskPort(port);
  }
  final resolvedIps = source['resolved-ips'];
  if (resolvedIps is List) {
    sanitized['resolved-ips'] = resolvedIps
        .map((value) => SensitiveMasker.maskText(value.toString()))
        .toList(growable: false);
  }
  final error = source['error']?.toString();
  if (error != null && error.isNotEmpty) {
    sanitized['error'] = SensitiveMasker.maskText(error);
  }
  return sanitized;
}

class NetworkDiagnosticSnapshot {
  const NetworkDiagnosticSnapshot({
    required this.generatedAt,
    required this.networkType,
    required this.vpnConnected,
    required this.vpnStatus,
    required this.nodeAvailable,
    required this.conclusion,
    required this.conclusionSeverity,
    required this.conclusionReason,
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
  final NetworkDiagnosticSeverity conclusionSeverity;
  final NetworkDiagnosticReason conclusionReason;
  final List<NetworkDiagnosticItem> dnsResults;
  final List<NetworkDiagnosticItem> ipResults;
  final List<NetworkDiagnosticItem> nodeLayerResults;
  final List<NetworkDiagnosticItem> directResults;
  final List<NetworkDiagnosticItem> proxyResults;
  final Map<String, dynamic> nodeResult;
}

enum NetworkDiagnosticSeverity { healthy, warning, error }

enum NetworkDiagnosticReason {
  noNetwork,
  disconnectedHealthy,
  disconnectedDns,
  disconnectedNetwork,
  dns,
  network,
  nodeDns,
  tcp,
  tcpRefused,
  tls,
  protocol,
  udp,
  nodeUnknown,
  proxy,
  proxyWorking,
  healthy,
}

class NetworkDiagnosticDecision {
  const NetworkDiagnosticDecision(this.reason, this.severity);

  final NetworkDiagnosticReason reason;
  final NetworkDiagnosticSeverity severity;
}

NetworkDiagnosticDecision evaluateNetworkDiagnostic({
  required bool networkDisconnected,
  required bool connected,
  required bool dnsOk,
  required bool directOk,
  required bool directAllOk,
  required bool proxyOk,
  required bool proxyEmpty,
  required bool ipOk,
  required bool diagnosticUnavailable,
  required String? failureStage,
  required String? tcpStatus,
}) {
  const error = NetworkDiagnosticSeverity.error;

  // Loss of the underlying network makes every node-layer failure a
  // downstream symptom, so it must always win over DNS/TCP/TLS conclusions.
  if (networkDisconnected && !directOk && !ipOk) {
    return const NetworkDiagnosticDecision(
      NetworkDiagnosticReason.noNetwork,
      error,
    );
  }
  if (!directOk && !ipOk) {
    return NetworkDiagnosticDecision(
      connected
          ? NetworkDiagnosticReason.network
          : NetworkDiagnosticReason.disconnectedNetwork,
      error,
    );
  }
  if (!dnsOk) {
    return NetworkDiagnosticDecision(
      connected
          ? NetworkDiagnosticReason.dns
          : NetworkDiagnosticReason.disconnectedDns,
      error,
    );
  }
  if (!connected) {
    return const NetworkDiagnosticDecision(
      NetworkDiagnosticReason.disconnectedHealthy,
      NetworkDiagnosticSeverity.warning,
    );
  }

  if (!diagnosticUnavailable) {
    switch (failureStage) {
      case 'dns':
        return const NetworkDiagnosticDecision(
          NetworkDiagnosticReason.nodeDns,
          error,
        );
      case 'tcp':
        return NetworkDiagnosticDecision(
          tcpStatus == 'refused'
              ? NetworkDiagnosticReason.tcpRefused
              : NetworkDiagnosticReason.tcp,
          error,
        );
      case 'tls':
        return const NetworkDiagnosticDecision(
          NetworkDiagnosticReason.tls,
          error,
        );
      case 'protocol':
        return const NetworkDiagnosticDecision(
          NetworkDiagnosticReason.protocol,
          error,
        );
      case 'udp':
        return const NetworkDiagnosticDecision(
          NetworkDiagnosticReason.udp,
          error,
        );
    }
  }
  if (proxyEmpty) {
    return const NetworkDiagnosticDecision(
      NetworkDiagnosticReason.nodeUnknown,
      NetworkDiagnosticSeverity.warning,
    );
  }
  if (!proxyOk) {
    return const NetworkDiagnosticDecision(
      NetworkDiagnosticReason.proxy,
      error,
    );
  }
  if (!directAllOk) {
    return const NetworkDiagnosticDecision(
      NetworkDiagnosticReason.proxyWorking,
      NetworkDiagnosticSeverity.warning,
    );
  }
  return const NetworkDiagnosticDecision(
    NetworkDiagnosticReason.healthy,
    NetworkDiagnosticSeverity.healthy,
  );
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
