import 'dart:async';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/features/diagnostics/services/network_diagnostic_snapshot.dart';
import 'package:fl_clash/xboard/features/shared/services/diagnostic_bundle_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Self-service diagnostics for DNS and HTTPS reachability.
class NetCheckPage extends ConsumerStatefulWidget {
  const NetCheckPage({super.key, this.showVpnStatus = true});

  final bool showVpnStatus;

  @override
  ConsumerState<NetCheckPage> createState() => _NetCheckPageState();
}

class _NetCheckPageState extends ConsumerState<NetCheckPage> {
  static const _defaultDomain = 'www.google.com';
  static const _targets = [
    'https://www.gstatic.com/generate_204',
    'https://cp.cloudflare.com/generate_204',
    'https://www.apple.com/library/test/success.html',
  ];

  final _domainController = TextEditingController(text: _defaultDomain);
  bool _running = false;
  bool _copyingReport = false;
  bool? _vpnConnected;
  String? _vpnStatus;
  List<_StepResult> _dnsResults = [];
  List<_StepResult> _directResults = [];
  List<_StepResult> _proxyResults = [];
  List<_StepResult> _ipResults = [];
  List<_StepResult> _nodeLayerResults = [];
  NetworkDiagnosticSnapshot? _reportSnapshot;
  String? _networkType;
  String? _nodeName;
  String? _conclusion;

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) return;
    final domain = _domainController.text.trim();
    if (domain.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _running = true;
      _vpnStatus = null;
      _dnsResults = [];
      _directResults = [];
      _proxyResults = [];
      _ipResults = [];
      _nodeLayerResults = [];
      _reportSnapshot = null;
      _networkType = null;
      _nodeName = null;
      _conclusion = null;
    });

    final networkType = await _resolveNetworkType(l10n);
    if (!mounted) return;
    setState(() => _networkType = networkType);

    final connected = globalState.isStart;
    final startTime = globalState.startTime;
    var elapsedText = '';
    if (startTime != null) {
      final elapsed = DateTime.now().difference(startTime);
      elapsedText =
          '${l10n.xboardNetworkDiagnosticsRunningTime} ${elapsed.inMinutes}m${elapsed.inSeconds % 60}s';
    }
    if (!mounted) return;
    setState(() {
      _vpnConnected = connected;
      _vpnStatus = connected
          ? '${l10n.xboardNetworkDiagnosticsConnected} $elapsedText'.trim()
          : l10n.xboardNetworkDiagnosticsDisconnected;
    });

    final dnsMode = ref.read(patchClashConfigProvider).dns.enhancedMode;
    final dnsResults = await _checkDns(domain, l10n, dnsMode);
    if (!mounted) return;
    setState(() => _dnsResults = dnsResults);

    final nodeName = connected ? await _resolveCurrentNodeName() : null;
    final results = await Future.wait<Object>([
      Future.wait(_targets.map((url) => _checkRoute(url, 'DIRECT', l10n))),
      nodeName == null
          ? Future.value(<_StepResult>[])
          : Future.wait(
              _targets.map((url) => _checkRoute(url, nodeName, l10n)),
            ),
      _checkIpConnectivity(l10n),
      nodeName == null
          ? Future.value(<String, dynamic>{})
          : clashCore.diagnoseProxy(_targets.first, nodeName),
    ]);
    if (!mounted) return;
    final directResults = results[0] as List<_StepResult>;
    final proxyResults = results[1] as List<_StepResult>;
    final ipResults = results[2] as List<_StepResult>;
    final rawNodeDiagnostic = results[3] as Map<String, dynamic>;
    final nodeDiagnostic = connected
        ? rawNodeDiagnostic
        : <String, dynamic>{
            'diagnostic-status': 'skipped_not_connected',
            'dns-status': 'skipped',
            'tcp-status': 'skipped',
            'proxy-status': 'skipped',
          };
    final nodeLayerResults = _buildNodeLayerResults(nodeDiagnostic, l10n);
    final conclusion = _buildConclusion(
      l10n,
      dnsResults,
      directResults,
      proxyResults,
      ipResults,
      connected,
      nodeDiagnostic,
    );
    final snapshot = NetworkDiagnosticSnapshot(
      generatedAt: DateTime.now(),
      networkType: networkType,
      vpnConnected: connected,
      vpnStatus: _vpnStatus ?? '-',
      nodeAvailable: nodeName != null,
      conclusion: conclusion,
      dnsResults: _toSnapshotItems(dnsResults),
      ipResults: _toSnapshotItems(ipResults),
      nodeLayerResults: _toSnapshotItems(nodeLayerResults),
      directResults: _toSnapshotItems(directResults),
      proxyResults: _toSnapshotItems(proxyResults),
      nodeResult: Map<String, dynamic>.from(nodeDiagnostic),
    );
    NetworkDiagnosticSnapshotStore.latest = snapshot;
    setState(() {
      _nodeName = nodeName;
      _directResults = directResults;
      _proxyResults = proxyResults;
      _ipResults = ipResults;
      _nodeLayerResults = nodeLayerResults;
      _reportSnapshot = snapshot;
      _conclusion = conclusion;
      _running = false;
    });
  }

  List<NetworkDiagnosticItem> _toSnapshotItems(List<_StepResult> results) {
    return results
        .map(
          (result) => NetworkDiagnosticItem(
            label: result.label,
            detail: _maskDetail(result.detail),
            elapsedMs: result.elapsedMs,
            status: result.skipped
                ? NetworkDiagnosticItemStatus.skipped
                : result.ok
                    ? NetworkDiagnosticItemStatus.success
                    : NetworkDiagnosticItemStatus.failure,
          ),
        )
        .toList(growable: false);
  }

  Future<String> _resolveNetworkType(AppLocalizations l10n) async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return l10n.xboardNetworkDiagnosticsNetworkNone;
      }
      return results.map((result) {
        switch (result) {
          case ConnectivityResult.wifi:
            return 'Wi-Fi';
          case ConnectivityResult.mobile:
            return l10n.xboardNetworkDiagnosticsNetworkMobile;
          case ConnectivityResult.ethernet:
            return l10n.xboardNetworkDiagnosticsNetworkEthernet;
          case ConnectivityResult.vpn:
            return 'VPN';
          case ConnectivityResult.bluetooth:
            return 'Bluetooth';
          case ConnectivityResult.other:
            return l10n.xboardNetworkDiagnosticsNetworkOther;
          case ConnectivityResult.satellite:
            return l10n.xboardNetworkDiagnosticsNetworkOther;
          case ConnectivityResult.none:
            return l10n.xboardNetworkDiagnosticsNetworkNone;
        }
      }).join(' + ');
    } catch (_) {
      return l10n.xboardNetworkDiagnosticsUnavailable;
    }
  }

  List<_StepResult> _buildNodeLayerResults(
    Map<String, dynamic> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) return const [];
    if (data['diagnostic-status'] == 'skipped_not_connected') {
      return [
        _StepResult.skipped(
          l10n.xboardNetworkDiagnosticsNodeLayers,
          l10n.xboardNetworkDiagnosticsVpnRequired,
        ),
      ];
    }
    if (data['diagnostic-status'] == 'unavailable') {
      return [
        _StepResult.skipped(
          l10n.xboardNetworkDiagnosticsNodeLayers,
          l10n.xboardNetworkDiagnosticsCoreUnavailable,
        ),
      ];
    }
    final results = <_StepResult>[];
    final host = data['host']?.toString() ?? '';
    final port = data['port']?.toString() ?? '';
    final type = data['proxy-type']?.toString() ?? '-';
    final network = data['network']?.toString().toUpperCase() ?? '-';
    if (host.isNotEmpty && port.isNotEmpty) {
      results.add(_StepResult(
        label: l10n.xboardNetworkDiagnosticsNodeEndpoint,
        ok: true,
        detail: '$type · $network · ${_maskHost(host)}:$port',
      ));
    }

    final dnsStatus = data['dns-status']?.toString();
    results.add(_StepResult(
      label: l10n.xboardNetworkDiagnosticsNodeDns,
      ok: dnsStatus == 'success',
      detail: dnsStatus == 'success'
          ? l10n.xboardNetworkDiagnosticsNodeDnsSuccess
          : l10n.xboardNetworkDiagnosticsNodeDnsFailed,
      elapsedMs: _asInt(data['dns-elapsed-ms']),
    ));

    final tcpStatus = data['tcp-status']?.toString();
    if (tcpStatus == 'skipped') {
      results.add(_StepResult.skipped(
        l10n.xboardNetworkDiagnosticsNodeTcp,
        l10n.xboardNetworkDiagnosticsTcpSkippedUdp,
      ));
    } else {
      results.add(_StepResult(
        label: l10n.xboardNetworkDiagnosticsNodeTcp,
        ok: tcpStatus == 'success',
        detail: _tcpStatusText(tcpStatus, l10n),
        elapsedMs: _asInt(data['tcp-elapsed-ms']),
      ));
    }

    final proxyStatus = data['proxy-status']?.toString();
    final failureStage = data['failure-stage']?.toString();
    results.add(_StepResult(
      label: failureStage == 'tls'
          ? l10n.xboardNetworkDiagnosticsNodeTls
          : l10n.xboardNetworkDiagnosticsNodeHandshake,
      ok: proxyStatus == 'success',
      detail: proxyStatus == 'success'
          ? l10n.xboardNetworkDiagnosticsNodeHttpSuccess
          : _proxyFailureText(failureStage, l10n),
      elapsedMs: _asInt(data['http-elapsed-ms']),
    ));
    return results;
  }

  String _tcpStatusText(String? status, AppLocalizations l10n) {
    switch (status) {
      case 'success':
        return l10n.xboardNetworkDiagnosticsTcpSuccess;
      case 'timeout':
        return l10n.xboardNetworkDiagnosticsTcpTimeout;
      case 'refused':
        return l10n.xboardNetworkDiagnosticsTcpRefused;
      case 'unreachable':
        return l10n.xboardNetworkDiagnosticsTcpUnreachable;
      default:
        return l10n.xboardNetworkDiagnosticsUnreachable;
    }
  }

  String _proxyFailureText(String? stage, AppLocalizations l10n) {
    switch (stage) {
      case 'dns':
        return l10n.xboardNetworkDiagnosticsNodeDnsFailed;
      case 'tls':
        return l10n.xboardNetworkDiagnosticsTlsFailed;
      case 'udp':
        return l10n.xboardNetworkDiagnosticsUdpFailed;
      case 'tcp':
        return l10n.xboardNetworkDiagnosticsTcpTimeout;
      case 'http':
        return l10n.xboardNetworkDiagnosticsHttpFailed;
      case 'configuration':
        return l10n.xboardNetworkDiagnosticsEndpointUnavailable;
      default:
        return l10n.xboardNetworkDiagnosticsProtocolFailed;
    }
  }

  int _asInt(dynamic value) => value is num ? value.toInt() : 0;

  String _maskHost(String host) {
    if (InternetAddress.tryParse(host) != null) return '[masked-ip]';
    final parts = host.split('.');
    return parts.length > 2
        ? '***.${parts.sublist(parts.length - 2).join('.')}'
        : '[masked-host]';
  }

  Future<List<_StepResult>> _checkDns(
    String domain,
    AppLocalizations l10n,
    DnsMode dnsMode,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final addresses = await InternetAddress.lookup(domain)
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      if (addresses.isEmpty) {
        return [
          _StepResult.fail(
            'DNS',
            '${stopwatch.elapsedMilliseconds}ms — ${l10n.xboardNetworkDiagnosticsEmptyResult}',
          ),
        ];
      }
      return addresses.map((address) {
        final classification = _classifyAddress(address, dnsMode);
        return _StepResult(
          label: address.type == InternetAddressType.IPv4 ? 'A' : 'AAAA',
          ok: classification != _AddressClassification.suspicious,
          detail: classification == _AddressClassification.suspicious
              ? '${address.address} — ${l10n.xboardNetworkDiagnosticsSuspiciousAddress}'
              : classification == _AddressClassification.expectedFakeIp
                  ? '${address.address} — ${l10n.xboardNetworkDiagnosticsExpectedFakeIp}'
                  : address.address,
          elapsedMs: stopwatch.elapsedMilliseconds,
        );
      }).toList();
    } on TimeoutException {
      stopwatch.stop();
      return [
        _StepResult.fail(
          'DNS',
          '${stopwatch.elapsedMilliseconds}ms — ${l10n.xboardNetworkDiagnosticsTimeout}',
        ),
      ];
    } on SocketException catch (error) {
      stopwatch.stop();
      return [
        _StepResult.fail(
          'DNS',
          '${stopwatch.elapsedMilliseconds}ms — ${error.osError?.message ?? error.message}',
        ),
      ];
    } catch (error) {
      stopwatch.stop();
      return [
        _StepResult.fail(
          'DNS',
          '${stopwatch.elapsedMilliseconds}ms — $error',
        ),
      ];
    }
  }

  _AddressClassification _classifyAddress(
    InternetAddress address,
    DnsMode dnsMode,
  ) {
    final raw = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      if (raw.length != 4) return _AddressClassification.suspicious;
      final a = raw[0];
      final b = raw[1];
      if (a == 198 && (b == 18 || b == 19) && dnsMode == DnsMode.fakeIp) {
        return _AddressClassification.expectedFakeIp;
      }
      final suspicious = a == 0 ||
          a == 10 ||
          a == 127 ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          (a == 100 && b >= 64 && b <= 127) ||
          (a == 198 && (b == 18 || b == 19)) ||
          a >= 224;
      return suspicious
          ? _AddressClassification.suspicious
          : _AddressClassification.public;
    }
    if (raw.length != 16) return _AddressClassification.suspicious;
    final suspicious = raw.every((byte) => byte == 0) ||
        (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80) ||
        (raw[0] & 0xfe) == 0xfc;
    return suspicious
        ? _AddressClassification.suspicious
        : _AddressClassification.public;
  }

  Future<String?> _resolveCurrentNodeName() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final controller = globalState.appController;
        final groups = controller.getCurrentGroups();
        final currentGroupName = controller.getCurrentGroupName()?.toString();
        final candidates = [
          ...groups.where((group) => group.name == currentGroupName),
          ...groups.where((group) => group.realNow.isNotEmpty),
        ];
        for (final group in candidates) {
          final selected =
              controller.getSelectedProxyName(group.name)?.toString();
          final candidate =
              selected?.isNotEmpty == true ? selected! : group.realNow;
          if (candidate.isEmpty) continue;
          final state = controller.getProxyCardState(candidate);
          return state.proxyName.isEmpty ? candidate : state.proxyName;
        }
      } catch (_) {
        // Core groups may still be synchronizing immediately after connect.
      }
      if (attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    return null;
  }

  Future<_StepResult> _checkRoute(
    String url,
    String proxyName,
    AppLocalizations l10n,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final delay = await clashCore
          .getDelay(url, proxyName)
          .timeout(const Duration(seconds: 8));
      stopwatch.stop();
      final value = delay.value;
      return _StepResult(
        label: Uri.parse(url).host,
        ok: value != null && value > 0,
        detail: proxyName == 'DIRECT'
            ? 'DIRECT'
            : l10n.xboardNetworkDiagnosticsViaNode,
        elapsedMs: value ?? 0,
      );
    } on TimeoutException {
      stopwatch.stop();
      return _StepResult.fail(
          Uri.parse(url).host, l10n.xboardNetworkDiagnosticsTimeout,
          elapsedMs: stopwatch.elapsedMilliseconds);
    } catch (error) {
      stopwatch.stop();
      return _StepResult.fail(Uri.parse(url).host, error.toString(),
          elapsedMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<List<_StepResult>> _checkIpConnectivity(
    AppLocalizations l10n,
  ) async {
    return Future.wait([
      _checkAddressFamily('https://ipv4.icanhazip.com', 'IPv4', l10n),
      _checkAddressFamily(
        'https://ipv6.icanhazip.com',
        'IPv6',
        l10n,
      ),
    ]);
  }

  Future<_StepResult> _checkAddressFamily(
    String url,
    String label,
    AppLocalizations l10n,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final delay = await clashCore
          .getDelay(url, 'DIRECT')
          .timeout(const Duration(seconds: 8));
      stopwatch.stop();
      final value = delay.value;
      if (value == null || value <= 0) {
        return _StepResult.fail(
          label,
          l10n.xboardNetworkDiagnosticsUnreachable,
          elapsedMs: stopwatch.elapsedMilliseconds,
        );
      }
      return _StepResult(
        label: label,
        ok: true,
        detail: l10n.xboardNetworkDiagnosticsReachable,
        elapsedMs: value,
      );
    } catch (_) {
      stopwatch.stop();
      return _StepResult.fail(
        label,
        l10n.xboardNetworkDiagnosticsUnreachable,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  String _buildConclusion(
    AppLocalizations l10n,
    List<_StepResult> dns,
    List<_StepResult> direct,
    List<_StepResult> proxy,
    List<_StepResult> ip,
    bool connected,
    Map<String, dynamic> nodeDiagnostic,
  ) {
    final dnsOk = dns.isNotEmpty && dns.every((item) => item.ok);
    final directOk = direct.any((item) => item.ok);
    final directAllOk = direct.isNotEmpty && direct.every((item) => item.ok);
    final proxyOk = proxy.any((item) => item.ok);
    final ipOk = ip.any((item) => item.ok);
    if (!connected) {
      if (!dnsOk) {
        return l10n.xboardNetworkDiagnosticsConclusionDisconnectedDns;
      }
      if (!directOk || !ipOk) {
        return l10n.xboardNetworkDiagnosticsConclusionDisconnectedNetwork;
      }
      return l10n.xboardNetworkDiagnosticsConclusionDisconnectedHealthy;
    }
    final failureStage = nodeDiagnostic['failure-stage']?.toString();
    final tcpStatus = nodeDiagnostic['tcp-status']?.toString();
    final diagnosticUnavailable =
        nodeDiagnostic['diagnostic-status'] == 'unavailable';
    if (!diagnosticUnavailable && failureStage == 'dns') {
      return l10n.xboardNetworkDiagnosticsConclusionNodeDns;
    }
    if (!diagnosticUnavailable && failureStage == 'tcp') {
      return tcpStatus == 'refused'
          ? l10n.xboardNetworkDiagnosticsConclusionTcpRefused
          : l10n.xboardNetworkDiagnosticsConclusionTcp;
    }
    if (!diagnosticUnavailable && failureStage == 'tls') {
      return l10n.xboardNetworkDiagnosticsConclusionTls;
    }
    if (!diagnosticUnavailable && failureStage == 'protocol') {
      return l10n.xboardNetworkDiagnosticsConclusionProtocol;
    }
    if (!diagnosticUnavailable && failureStage == 'udp') {
      return l10n.xboardNetworkDiagnosticsConclusionUdp;
    }
    if (connected && proxy.isEmpty) {
      return l10n.xboardNetworkDiagnosticsConclusionNodeUnknown;
    }
    if (connected && !proxyOk) {
      return l10n.xboardNetworkDiagnosticsConclusionProxy;
    }
    if (!directAllOk && proxyOk) {
      return l10n.xboardNetworkDiagnosticsConclusionProxyWorking;
    }
    if (directOk && (!connected || proxyOk)) {
      return l10n.xboardNetworkDiagnosticsConclusionHealthy;
    }
    if (!dnsOk) return l10n.xboardNetworkDiagnosticsConclusionDns;
    if (!ipOk) return l10n.xboardNetworkDiagnosticsConclusionNetwork;
    return l10n.xboardNetworkDiagnosticsConclusionNetwork;
  }

  Future<void> _copyReport() async {
    if (_copyingReport) return;
    final l10n = AppLocalizations.of(context);
    final snapshot = _reportSnapshot;
    if (snapshot == null) return;
    setState(() => _copyingReport = true);
    try {
      final networkReport =
          DiagnosticBundleService.buildNetworkReport(snapshot, l10n);
      final serviceReport = await DiagnosticBundleService.buildReport(
        context,
        ref,
        l10n,
        includeNetworkDiagnostics: false,
        includeMetadata: false,
      );
      final report = '$networkReport\n$serviceReport';
      await Clipboard.setData(ClipboardData(text: report));
      XBoardNotification.showSuccess(l10n.xboardNetworkDiagnosticsCopied);
    } finally {
      if (mounted) setState(() => _copyingReport = false);
    }
  }

  String _maskDetail(String value) {
    final ipv4Masked = value.replaceAll(
      RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
      '[redacted-ip]',
    );
    return ipv4Masked.replaceAllMapped(
      RegExp(r'[0-9a-fA-F:]{2,}'),
      (match) {
        final candidate = match.group(0)!;
        final address = InternetAddress.tryParse(candidate);
        return address?.type == InternetAddressType.IPv6
            ? '[redacted-ipv6]'
            : candidate;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _domainController,
                  enabled: !_running,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _start(),
                  decoration: InputDecoration(
                    labelText: l10n.xboardNetworkDiagnosticsTestDomain,
                    hintText: _defaultDomain,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _running ? null : _start,
                      icon: _running
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(
                        _running
                            ? l10n.xboardNetworkDiagnosticsRunning
                            : l10n.xboardNetworkDiagnosticsStart,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _running || _copyingReport || _vpnStatus == null
                              ? null
                              : _copyReport,
                      icon: _copyingReport
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.copy_outlined),
                      label: Text(l10n.xboardNetworkDiagnosticsCopyReport),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.showVpnStatus && _vpnStatus != null) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsVpnStatus),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                _vpnConnected == true ? Icons.shield : Icons.shield_outlined,
                color: _vpnConnected == true ? Colors.green : Colors.grey,
              ),
              title: Text(_vpnStatus!),
            ),
          ),
        ],
        if (_conclusion != null) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsConclusion),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: Text(_conclusion!),
            ),
          ),
        ],
        if (_networkType != null) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsNetworkType),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.lan_outlined),
              title: Text(_networkType!),
            ),
          ),
        ],
        if (_dnsResults.isNotEmpty) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsDns),
          _ResultList(results: _dnsResults),
        ],
        if (_ipResults.isNotEmpty) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsIpConnectivity),
          _ResultList(results: _ipResults),
        ],
        if (_nodeLayerResults.isNotEmpty) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsNodeLayers),
          _ResultList(results: _nodeLayerResults),
        ],
        if (_directResults.isNotEmpty) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsDirectHttps),
          _ResultList(results: _directResults),
        ],
        if (_proxyResults.isNotEmpty) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsProxyHttps),
          if (_nodeName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${l10n.xboardNetworkDiagnosticsNode}: $_nodeName',
                style: theme.textTheme.bodySmall,
              ),
            ),
          _ResultList(results: _proxyResults),
        ],
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              l10n.xboardNetworkDiagnosticsDescription,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.results});

  final List<_StepResult> results;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < results.length; index++) ...[
            ListTile(
              dense: true,
              leading: Icon(
                results[index].skipped
                    ? Icons.remove_circle_outline
                    : results[index].ok
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                color: results[index].skipped
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : results[index].ok
                        ? Colors.green
                        : Colors.red,
              ),
              title: Text(results[index].label),
              subtitle: Text(results[index].detail),
              trailing: results[index].elapsedMs > 0
                  ? Text('${results[index].elapsedMs}ms')
                  : null,
            ),
            if (index != results.length - 1) const Divider(height: 0),
          ],
        ],
      ),
    );
  }
}

class _StepResult {
  const _StepResult({
    required this.label,
    required this.ok,
    required this.detail,
    this.elapsedMs = 0,
    this.skipped = false,
  });

  factory _StepResult.fail(
    String label,
    String detail, {
    int elapsedMs = 0,
  }) =>
      _StepResult(
        label: label,
        ok: false,
        detail: detail,
        elapsedMs: elapsedMs,
      );

  factory _StepResult.skipped(String label, String detail) => _StepResult(
        label: label,
        ok: true,
        detail: detail,
        skipped: true,
      );

  final String label;
  final bool ok;
  final String detail;
  final int elapsedMs;
  final bool skipped;
}

enum _AddressClassification { public, expectedFakeIp, suspicious }
