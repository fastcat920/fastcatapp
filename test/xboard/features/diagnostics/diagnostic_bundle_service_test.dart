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
      ipResults: const [],
      nodeLayerResults: const [],
      directResults: const [],
      proxyResults: const [],
      nodeResult: const {},
    );

    final report = DiagnosticBundleService.buildNetworkReport(
      snapshot,
      AppLocalizations.current,
      clientVersion: '3.6.0+8',
      systemVersion: 'macOS 15.6.1',
    );

    expect(report, contains('客户端版本: 3.6.0+8'));
    expect(report, contains('系统: macOS 15.6.1'));
  });
}
