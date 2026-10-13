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
    bool? localProxyOk,
    bool directMayUseTun = false,
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
      localProxyOk: localProxyOk,
      directMayUseTun: directMayUseTun,
    );
  }

  test('missing proxy skips node stages instead of failing node DNS', () {
    final raw = <String, dynamic>{
      'diagnostic-status': 'complete',
      'failure-stage': 'configuration',
      'dns-status': 'unavailable',
      'tcp-status': 'skipped',
      'proxy-status': 'failed',
      'error': 'proxy not found',
    };
    final normalized = normalizeNodeDiagnosticResult(raw);

    expect(normalized['dns-status'], 'skipped');
    expect(normalized['tcp-status'], 'skipped');
    expect(normalized['proxy-status'], 'skipped');
    expect(nodeDiagnosticHasMissingPrerequisite(normalized), isTrue);
    expect(raw['dns-status'], 'unavailable');
    expect(raw['proxy-status'], 'failed');
  });

  test('legacy proxy-not-found error identifies missing configuration', () {
    final normalized = normalizeNodeDiagnosticResult({
      'error': 'proxy not found',
      'dns-status': 'failed',
    });
    expect(normalized['failure-stage'], 'configuration');
    expect(normalized['dns-status'], 'skipped');
    expect(nodeDiagnosticHasMissingPrerequisite(normalized), isTrue);
  });

  test('unavailable core skips checks that did not run', () {
    for (final source in <Map<String, dynamic>>[
      {},
      {'diagnostic-status': 'unavailable', 'proxy-status': 'failed'},
      {'diagnostic-status': 'core_unavailable'},
    ]) {
      final normalized = normalizeNodeDiagnosticResult(source);
      expect(normalized['dns-status'], 'skipped');
      expect(normalized['tcp-status'], 'skipped');
      expect(normalized['proxy-status'], 'skipped');
    }
  });

  test('real DNS failure remains failed but downstream checks are skipped', () {
    final normalized = normalizeNodeDiagnosticResult({
      'diagnostic-status': 'complete',
      'failure-stage': 'dns',
      'dns-status': 'failed',
      'tcp-status': 'unavailable',
      'proxy-status': 'failed',
    });
    expect(normalized['dns-status'], 'failed');
    expect(normalized['tcp-status'], 'skipped');
    expect(normalized['proxy-status'], 'skipped');
    expect(nodeDiagnosticHasMissingPrerequisite(normalized), isFalse);
  });

  test('real TCP failure does not claim the proxy handshake was performed', () {
    final normalized = normalizeNodeDiagnosticResult({
      'diagnostic-status': 'complete',
      'failure-stage': 'tcp',
      'dns-status': 'success',
      'tcp-status': 'refused',
      'proxy-status': 'failed',
    });
    expect(normalized['dns-status'], 'success');
    expect(normalized['tcp-status'], 'refused');
    expect(normalized['proxy-status'], 'skipped');
  });

  test('proxy not found is not diagnosed as a broken LAN or DNS', () {
    final result = evaluate(
      dnsOk: false,
      directOk: false,
      directAllOk: false,
      ipOk: false,
      proxyOk: false,
      proxyEmpty: true,
      failureStage: 'configuration',
      tcpStatus: 'skipped',
    );
    expect(result.reason, NetworkDiagnosticReason.configuration);
    expect(result.severity, NetworkDiagnosticSeverity.error);
  });

  test('empty core is distinct from network failure even if its DIRECT fails',
      () {
    // Core DIRECT URL tests used to share the unavailable core and all fail.
    // Missing configuration is decisive, not those dependent failures.
    for (final nativeBaselineOk in [false, true]) {
      final result = evaluate(
        directOk: nativeBaselineOk,
        directAllOk: nativeBaselineOk,
        ipOk: nativeBaselineOk,
        proxyOk: false,
        failureStage: 'configuration',
        diagnosticUnavailable: true,
      );
      expect(result.reason, NetworkDiagnosticReason.configuration);
    }
  });

  test('unavailable diagnostic does not infer a physical network failure', () {
    final result = evaluate(
      dnsOk: false,
      directOk: false,
      directAllOk: false,
      ipOk: false,
      proxyOk: false,
      diagnosticUnavailable: true,
    );
    expect(result.reason, NetworkDiagnosticReason.coreUnavailable);
    expect(result.severity, NetworkDiagnosticSeverity.warning);
  });

  test('failed native probes under TUN do not isolate the physical network',
      () {
    final result = evaluate(
      dnsOk: false,
      directOk: false,
      directAllOk: false,
      ipOk: false,
      proxyOk: false,
      directMayUseTun: true,
      failureStage: 'tcp',
      tcpStatus: 'timeout',
    );
    expect(result.reason, NetworkDiagnosticReason.routeUncertain);
    expect(result.severity, NetworkDiagnosticSeverity.warning);
  });

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

  test('successful node test does not hide failure of actual local proxy route',
      () {
    final result = evaluate(localProxyOk: false);
    expect(result.reason, NetworkDiagnosticReason.localProxy);
    expect(result.severity, NetworkDiagnosticSeverity.error);
    expect(
        evaluate(localProxyOk: true).reason, NetworkDiagnosticReason.healthy);
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

  test('working proxy overrides failed direct and IP probes', () {
    final result = evaluate(
      networkDisconnected: true,
      directOk: false,
      directAllOk: false,
      ipOk: false,
      failureStage: 'dns',
    );

    expect(result.reason, NetworkDiagnosticReason.proxyWorking);
    expect(result.severity, NetworkDiagnosticSeverity.warning);
  });

  test('working proxy overrides a contradictory node DNS failure', () {
    final result = evaluate(failureStage: 'dns');

    expect(result.reason, NetworkDiagnosticReason.healthy);
    expect(result.severity, NetworkDiagnosticSeverity.healthy);
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
