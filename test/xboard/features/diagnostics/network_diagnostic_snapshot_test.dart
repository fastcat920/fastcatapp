import 'package:fl_clash/xboard/features/diagnostics/services/network_diagnostic_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NetworkDiagnosticDecision evaluate({
    bool networkDisconnected = false,
    bool connected = true,
    bool dnsOk = true,
    bool directOk = true,
    bool directAllOk = true,
    bool proxyOk = true,
    bool proxyEmpty = false,
    bool ipOk = true,
    bool diagnosticUnavailable = false,
    String? failureStage,
    String? tcpStatus,
  }) {
    return evaluateNetworkDiagnostic(
      networkDisconnected: networkDisconnected,
      connected: connected,
      dnsOk: dnsOk,
      directOk: directOk,
      directAllOk: directAllOk,
      proxyOk: proxyOk,
      proxyEmpty: proxyEmpty,
      ipOk: ipOk,
      diagnosticUnavailable: diagnosticUnavailable,
      failureStage: failureStage,
      tcpStatus: tcpStatus,
    );
  }

  test('no underlying network wins over downstream TCP failure', () {
    final result = evaluate(
      networkDisconnected: true,
      dnsOk: false,
      directOk: false,
      directAllOk: false,
      proxyOk: false,
      ipOk: false,
      failureStage: 'tcp',
      tcpStatus: 'unreachable',
    );

    expect(result.reason, NetworkDiagnosticReason.noNetwork);
    expect(result.severity, NetworkDiagnosticSeverity.error);
  });

  test('successful probes override a stale disconnected interface result', () {
    final result = evaluate(networkDisconnected: true);

    expect(result.reason, NetworkDiagnosticReason.healthy);
    expect(result.severity, NetworkDiagnosticSeverity.healthy);
  });

  test('unavailable base network wins over node failure', () {
    final result = evaluate(
      directOk: false,
      directAllOk: false,
      proxyOk: false,
      ipOk: false,
      failureStage: 'tcp',
      tcpStatus: 'timeout',
    );

    expect(result.reason, NetworkDiagnosticReason.network);
    expect(result.severity, NetworkDiagnosticSeverity.error);
  });

  test('TCP failure is reported after base network succeeds', () {
    final result = evaluate(
      proxyOk: false,
      failureStage: 'tcp',
      tcpStatus: 'refused',
    );

    expect(result.reason, NetworkDiagnosticReason.tcpRefused);
    expect(result.severity, NetworkDiagnosticSeverity.error);
  });

  test('healthy result is green', () {
    final result = evaluate();

    expect(result.reason, NetworkDiagnosticReason.healthy);
    expect(result.severity, NetworkDiagnosticSeverity.healthy);
  });

  test('healthy base network without VPN is a warning', () {
    final result = evaluate(
      connected: false,
      proxyOk: false,
      proxyEmpty: true,
    );

    expect(result.reason, NetworkDiagnosticReason.disconnectedHealthy);
    expect(result.severity, NetworkDiagnosticSeverity.warning);
  });

  test('working proxy with partial direct access is a warning', () {
    final result = evaluate(directAllOk: false);

    expect(result.reason, NetworkDiagnosticReason.proxyWorking);
    expect(result.severity, NetworkDiagnosticSeverity.warning);
  });

  test('stored node diagnostics do not retain plaintext endpoints', () {
    final source = <String, dynamic>{
      'host': 'node.fastcat.wang',
      'port': '10086',
      'resolved-ips': ['109.244.50.201', '2400:3200:baba::1'],
      'error': 'dial tcp node.fastcat.wang:10086: i/o timeout',
      'tcp-status': 'timeout',
    };

    final sanitized = sanitizeNetworkDiagnosticNodeResult(source);

    expect(sanitized.toString(), isNot(contains('node.fastcat.wang')));
    expect(sanitized.toString(), isNot(contains('10086')));
    expect(sanitized.toString(), isNot(contains('109.244.50.201')));
    expect(sanitized.toString(), isNot(contains('2400:3200:baba::1')));
    expect(sanitized['port'], '1***6');
    expect(sanitized['tcp-status'], 'timeout');
    expect(source['host'], 'node.fastcat.wang');
  });
}
