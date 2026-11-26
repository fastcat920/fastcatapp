import 'dart:ui';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/diagnostics/services/network_diagnostic_snapshot.dart';
import 'package:fl_clash/xboard/features/shared/services/diagnostic_bundle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  test('failed download reports the endpoint HTTP status', () {
    final download = NetworkDiagnosticDownload.fromProbe({
      'status': 'failed',
      'http-status': 403,
    });
    expect(
        download.describe(AppLocalizations.current), ['未能测得下载速度', 'HTTP 403']);
  });

  test('network report includes client and system versions', () {
    final snapshot = NetworkDiagnosticSnapshot(
      generatedAt: DateTime.utc(2026, 9, 1),
      networkType: 'Wi-Fi',
      vpnConnected: true,
      vpnStatus: 'connected',
      nodeAvailable: true,
      conclusion: 'ok',
      conclusionSeverity: NetworkDiagnosticSeverity.healthy,
      conclusionReason: NetworkDiagnosticReason.healthy,
      dnsResults: const [],
      ipResults: const [
        NetworkDiagnosticItem(
          label: 'IPv4',
          detail: '可连接',
          elapsedMs: 123,
          status: NetworkDiagnosticItemStatus.success,
        ),
        NetworkDiagnosticItem(
          label: 'IPv6',
          detail: '可连接',
          elapsedMs: 456,
          status: NetworkDiagnosticItemStatus.success,
        ),
      ],
      nodeLayerResults: const [],
      directResults: const [],
      proxyResults: const [],
      nodeResult: const {},
      download: const NetworkDiagnosticDownload(
        NetworkDiagnosticDownloadStatus.complete,
        bytes: 50000000,
        sampleUs: 5000000,
      ),
    );

    final report = DiagnosticBundleService.buildNetworkReport(
      snapshot,
      AppLocalizations.current,
      clientVersion: '3.6.0+8',
      systemVersion: 'macOS 15.6.1',
    );

    expect(report, contains('客户端版本: 3.6.0+8'));
    expect(
      report,
      contains('下载测速:\n'
          '  平均下载速度: 80.00 Mbps\n'
          '  采样用时: 5.00 秒\n'
          '  总下载量: 50.00 MB'),
    );
    expect(report, contains('IPv4: 可连接 (123ms)'));
    expect(report, contains('IPv6: 可连接 (456ms)'));
    expect('经系统路由测试，可能受 VPN 影响。'.allMatches(report), hasLength(1));
    expect(report, contains('系统: macOS 15.6.1'));
  });
}
