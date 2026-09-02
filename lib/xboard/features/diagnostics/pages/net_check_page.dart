import 'dart:async';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/xboard/features/diagnostics/services/network_diagnostic_snapshot.dart';
import 'package:fl_clash/xboard/features/shared/services/diagnostic_bundle_service.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
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
  static const _directTargets = [
    'https://connect.rom.miui.com/generate_204',
    'https://wifi.vivo.com.cn/generate_204',
    'https://connectivitycheck.platform.hicloud.com/generate_204',
  ];
  static const _proxyTargets = [
    'https://www.gstatic.com/generate_204',
    'https://www.google.com/generate_204',
    'https://www.youtube.com/generate_204',
  ];

  final _domainController = TextEditingController(text: _defaultDomain);
  bool _running = false;
  bool _copyingReport = false;
  int _runGeneration = 0;
  String? _vpnStatus;
  List<_StepResult> _dnsResults = [];
  List<_StepResult> _directResults = [];
  List<_StepResult> _proxyResults = [];
  List<_StepResult> _ipResults = [];
  List<_StepResult> _nodeLayerResults = [];
  NetworkDiagnosticSnapshot? _reportSnapshot;
  String? _networkType;
  String? _nodeName;
  NetworkDiagnosticDecision? _conclusion;

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) return;
    final l10n = AppLocalizations.of(context);
    if (ref.read(runTimeProvider) == null) {
      XBoardNotification.showInfo(
        l10n.xboardNetworkDiagnosticsConnectFirst,
      );
      return;
    }
    final domain = _domainController.text.trim();
    if (domain.isEmpty) return;
    final generation = ++_runGeneration;

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
    if (!_isRunValid(generation)) return;
    setState(() => _networkType = networkType);

    final connected = ref.read(runTimeProvider) != null;
    final startTime = globalState.startTime;
    var elapsedText = '';
    if (startTime != null) {
      final elapsed = DateTime.now().difference(startTime);
      elapsedText =
          '${l10n.xboardNetworkDiagnosticsRunningTime} ${elapsed.inMinutes}m${elapsed.inSeconds % 60}s';
    }
    if (!mounted) return;
    setState(() {
      _vpnStatus = connected
          ? '${l10n.xboardNetworkDiagnosticsConnected} $elapsedText'.trim()
          : l10n.xboardNetworkDiagnosticsDisconnected;
    });

    final dnsMode = ref.read(patchClashConfigProvider).dns.enhancedMode;
    final dnsResults = await _checkDns(domain, l10n, dnsMode);
    if (!_isRunValid(generation)) return;
    setState(() => _dnsResults = dnsResults);

    final nodeName = connected ? await _resolveCurrentNodeName() : null;
    if (!_isRunValid(generation)) return;
    final results = await Future.wait<Object>([
      Future.wait(
        _directTargets.map((url) => _checkRoute(url, 'DIRECT', l10n)),
      ),
      nodeName == null
          ? Future.value(<_StepResult>[])
          : Future.wait(
              _proxyTargets.map((url) => _checkRoute(url, nodeName, l10n)),
            ),
      _checkIpConnectivity(l10n),
      nodeName == null
          ? Future.value(<String, dynamic>{})
          : clashCore.diagnoseProxy(_proxyTargets.first, nodeName),
      nodeName == null
          ? Future.value(_StepResult.fail(
              l10n.xboardCurrentNode,
              l10n.xboardNetworkDiagnosticsEndpointUnavailable,
            ))
          : _checkCurrentNode(nodeName, l10n),
    ]);
    if (!_isRunValid(generation)) return;
    final directResults = results[0] as List<_StepResult>;
    final proxyResults = results[1] as List<_StepResult>;
    final ipResults = results[2] as List<_StepResult>;
    final rawNodeDiagnostic = results[3] as Map<String, dynamic>;
    final currentNodeResult = results[4] as _StepResult;
    final nodeDiagnostic = connected
        ? rawNodeDiagnostic
        : <String, dynamic>{
            'diagnostic-status': 'skipped_not_connected',
            'dns-status': 'skipped',
            'tcp-status': 'skipped',
            'proxy-status': 'skipped',
          };
    final nodeLayerResults = _buildNodeLayerResults(
      nodeDiagnostic,
      l10n,
      currentNodeResult,
    );
    final conclusion = _buildConclusion(
      dnsResults,
      directResults,
      proxyResults,
      ipResults,
      connected,
      nodeDiagnostic,
      networkDisconnected:
          networkType == l10n.xboardNetworkDiagnosticsNetworkNone,
    );
    final conclusionMessage = _conclusionMessage(conclusion, l10n);
    final snapshot = NetworkDiagnosticSnapshot(
      generatedAt: DateTime.now(),
      networkType: networkType,
      vpnConnected: connected,
      vpnStatus: _vpnStatus ?? '-',
      nodeAvailable: nodeName != null,
      conclusion: conclusionMessage,
      conclusionSeverity: conclusion.severity,
      conclusionReason: conclusion.reason,
      dnsResults: _toSnapshotItems(dnsResults),
      ipResults: _toSnapshotItems(ipResults),
      nodeLayerResults: _toSnapshotItems(nodeLayerResults),
      directResults: _toSnapshotItems(directResults),
      proxyResults: _toSnapshotItems(proxyResults),
      nodeResult: sanitizeNetworkDiagnosticNodeResult(nodeDiagnostic),
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

  bool _isRunValid(int generation) {
    return mounted &&
        generation == _runGeneration &&
        ref.read(runTimeProvider) != null;
  }

  void _invalidateForDisconnect(AppLocalizations l10n) {
    _runGeneration++;
    if (!mounted) return;
    setState(() {
      _running = false;
      _vpnStatus = l10n.xboardNetworkDiagnosticsDisconnected;
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
    XBoardNotification.showInfo(
      l10n.xboardNetworkDiagnosticsDisconnectedInvalidated,
    );
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
    _StepResult currentNodeResult,
  ) {
    final results = <_StepResult>[currentNodeResult];
    if (data.isEmpty) return results;
    if (data['diagnostic-status'] == 'skipped_not_connected') {
      return [
        ...results,
        _StepResult.skipped(
          l10n.xboardNetworkDiagnosticsNodeLayers,
          l10n.xboardNetworkDiagnosticsVpnRequired,
        ),
      ];
    }
    if (data['diagnostic-status'] == 'unavailable') {
      return [
        ...results,
        _StepResult.skipped(
          l10n.xboardNetworkDiagnosticsNodeLayers,
          l10n.xboardNetworkDiagnosticsCoreUnavailable,
        ),
      ];
    }
    final host = data['host']?.toString() ?? '';
    final port = data['port']?.toString() ?? '';
    final type = data['proxy-type']?.toString() ?? '-';
    final network = data['network']?.toString().toUpperCase() ?? '-';
    if (host.isNotEmpty && port.isNotEmpty) {
      results.add(_StepResult(
        label: l10n.xboardNetworkDiagnosticsNodeEndpoint,
        ok: true,
        detail: '$type · $network · ${_maskHost(host)}:${_maskPort(port)}',
      ));
    }

    final dnsStatus = data['dns-status']?.toString();
    final resolvedIps = (data['resolved-ips'] as List<dynamic>? ?? const [])
        .map((value) => _maskIp(value.toString()))
        .where((value) => value.isNotEmpty)
        .join(', ');
    results.add(_StepResult(
      label: l10n.xboardNetworkDiagnosticsNodeDns,
      ok: dnsStatus == 'success',
      detail: dnsStatus == 'success'
          ? resolvedIps.isEmpty
              ? l10n.xboardNetworkDiagnosticsNodeDnsSuccess
              : '${l10n.xboardNetworkDiagnosticsNodeDnsSuccess} · $resolvedIps'
          : l10n.xboardNetworkDiagnosticsNodeDnsFailed,
      elapsedMs: _asInt(data['dns-elapsed-ms']),
    ));

    final failureStage = data['failure-stage']?.toString();
    final tcpStatus = data['tcp-status']?.toString();
    if (tcpStatus == 'skipped') {
      results.add(_StepResult.skipped(
        l10n.xboardNetworkDiagnosticsNodeTcp,
        network == 'UDP'
            ? l10n.xboardNetworkDiagnosticsTcpSkippedUdp
            : failureStage == 'dns'
                ? l10n.xboardNetworkDiagnosticsNodeDnsFailed
                : l10n.xboardNetworkDiagnosticsUnavailable,
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
    if (InternetAddress.tryParse(host) != null) return _maskIp(host);
    final parts = host.split('.');
    if (parts.isEmpty) return '[masked-host]';
    return parts.map(_maskDomainPart).join('.');
  }

  String _maskDomainPart(String value) {
    if (value.isEmpty) return '*';
    if (value.length == 1) return '*';
    if (value.length == 2) return '${value[0]}*';
    return '${value[0]}${'*' * (value.length - 2)}${value[value.length - 1]}';
  }

  String _maskPort(String value) {
    return SensitiveMasker.maskPort(value);
  }

  String _maskIp(String value) {
    final address = InternetAddress.tryParse(value);
    if (address == null) return '';
    if (address.type == InternetAddressType.IPv4) {
      final parts = address.address.split('.');
      return '${parts.first}.***.***.${parts.last}';
    }
    final parts = address.address.split(':');
    return '${parts.first}:***:***:${parts.last}';
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
            l10n.xboardNetworkDiagnosticsEmptyResult,
            elapsedMs: stopwatch.elapsedMilliseconds,
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
          l10n.xboardNetworkDiagnosticsTimeout,
          elapsedMs: stopwatch.elapsedMilliseconds,
        ),
      ];
    } on SocketException catch (error) {
      stopwatch.stop();
      return [
        _StepResult.fail(
          'DNS',
          error.osError?.message ?? error.message,
          elapsedMs: stopwatch.elapsedMilliseconds,
        ),
      ];
    } catch (error) {
      stopwatch.stop();
      return [
        _StepResult.fail(
          'DNS',
          error.toString(),
          elapsedMs: stopwatch.elapsedMilliseconds,
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

  Future<_StepResult> _checkCurrentNode(
    String nodeName,
    AppLocalizations l10n,
  ) async {
    try {
      final controller = globalState.appController;
      final proxyState = controller.getProxyCardState(nodeName);
      final resolvedName =
          proxyState.proxyName.isEmpty ? nodeName : proxyState.proxyName;
      final testUrl = controller.getRealTestUrl(proxyState.testUrl);
      final delay = await clashCore
          .getDelay(testUrl, resolvedName)
          .timeout(const Duration(seconds: 8));
      final value = delay.value;
      if (value == null || value <= 0) {
        return _StepResult.fail(
          l10n.xboardCurrentNode,
          '$resolvedName · ${l10n.xboardTimeout}',
        );
      }
      return _StepResult(
        label: l10n.xboardCurrentNode,
        ok: true,
        detail: resolvedName,
        elapsedMs: value,
      );
    } on TimeoutException {
      return _StepResult.fail(
        l10n.xboardCurrentNode,
        '$nodeName · ${l10n.xboardTimeout}',
      );
    } catch (_) {
      return _StepResult.fail(
        l10n.xboardCurrentNode,
        '$nodeName · ${l10n.xboardNetworkDiagnosticsUnreachable}',
      );
    }
  }

  Future<_StepResult> _checkRoute(
    String url,
    String proxyName,
    AppLocalizations l10n,
  ) async {
    final stopwatch = Stopwatch()..start();
    final label = _routeTargetLabel(url, l10n);
    try {
      final delay = await clashCore
          .getDelay(url, proxyName)
          .timeout(const Duration(seconds: 8));
      stopwatch.stop();
      final value = delay.value;
      return _StepResult(
        label: label,
        ok: value != null && value > 0,
        detail: proxyName == 'DIRECT'
            ? 'DIRECT'
            : l10n.xboardNetworkDiagnosticsViaNode,
        elapsedMs: value ?? 0,
      );
    } on TimeoutException {
      stopwatch.stop();
      return _StepResult.fail(label, l10n.xboardNetworkDiagnosticsTimeout,
          elapsedMs: stopwatch.elapsedMilliseconds);
    } catch (error) {
      stopwatch.stop();
      return _StepResult.fail(label, error.toString(),
          elapsedMs: stopwatch.elapsedMilliseconds);
    }
  }

  String _routeTargetLabel(String url, AppLocalizations l10n) {
    return switch (Uri.parse(url).host) {
      'connect.rom.miui.com' => l10n.xboardNetworkDiagnosticsTargetXiaomi204,
      'wifi.vivo.com.cn' => l10n.xboardNetworkDiagnosticsTargetVivo204,
      'connectivitycheck.platform.hicloud.com' =>
        l10n.xboardNetworkDiagnosticsTargetHuawei204,
      'www.gstatic.com' => 'gstatic',
      'www.google.com' => 'Google',
      'www.youtube.com' => 'YouTube',
      final host => host,
    };
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

  NetworkDiagnosticDecision _buildConclusion(
    List<_StepResult> dns,
    List<_StepResult> direct,
    List<_StepResult> proxy,
    List<_StepResult> ip,
    bool connected,
    Map<String, dynamic> nodeDiagnostic, {
    required bool networkDisconnected,
  }) {
    final dnsOk = dns.isNotEmpty && dns.every((item) => item.ok);
    final directOk = direct.any((item) => item.ok);
    final directAllOk = direct.isNotEmpty && direct.every((item) => item.ok);
    final proxyOk = proxy.any((item) => item.ok);
    final ipOk = ip.any((item) => item.ok);
    final failureStage = nodeDiagnostic['failure-stage']?.toString();
    final tcpStatus = nodeDiagnostic['tcp-status']?.toString();
    final diagnosticUnavailable =
        nodeDiagnostic['diagnostic-status'] == 'unavailable';
    return evaluateNetworkDiagnostic(
      networkDisconnected: networkDisconnected,
      connected: connected,
      dnsOk: dnsOk,
      directOk: directOk,
      directAllOk: directAllOk,
      proxyOk: proxyOk,
      proxyEmpty: proxy.isEmpty,
      ipOk: ipOk,
      diagnosticUnavailable: diagnosticUnavailable,
      failureStage: failureStage,
      tcpStatus: tcpStatus,
    );
  }

  String _conclusionMessage(
    NetworkDiagnosticDecision conclusion,
    AppLocalizations l10n,
  ) {
    return switch (conclusion.reason) {
      NetworkDiagnosticReason.noNetwork =>
        l10n.xboardNetworkDiagnosticsConclusionNoNetwork,
      NetworkDiagnosticReason.disconnectedHealthy =>
        l10n.xboardNetworkDiagnosticsConclusionDisconnectedHealthy,
      NetworkDiagnosticReason.disconnectedDns =>
        l10n.xboardNetworkDiagnosticsConclusionDisconnectedDns,
      NetworkDiagnosticReason.disconnectedNetwork =>
        l10n.xboardNetworkDiagnosticsConclusionDisconnectedNetwork,
      NetworkDiagnosticReason.dns => l10n.xboardNetworkDiagnosticsConclusionDns,
      NetworkDiagnosticReason.network =>
        l10n.xboardNetworkDiagnosticsConclusionNetwork,
      NetworkDiagnosticReason.nodeDns =>
        l10n.xboardNetworkDiagnosticsConclusionNodeDns,
      NetworkDiagnosticReason.tcp => l10n.xboardNetworkDiagnosticsConclusionTcp,
      NetworkDiagnosticReason.tcpRefused =>
        l10n.xboardNetworkDiagnosticsConclusionTcpRefused,
      NetworkDiagnosticReason.tls => l10n.xboardNetworkDiagnosticsConclusionTls,
      NetworkDiagnosticReason.protocol =>
        l10n.xboardNetworkDiagnosticsConclusionProtocol,
      NetworkDiagnosticReason.udp => l10n.xboardNetworkDiagnosticsConclusionUdp,
      NetworkDiagnosticReason.nodeUnknown =>
        l10n.xboardNetworkDiagnosticsConclusionNodeUnknown,
      NetworkDiagnosticReason.proxy =>
        l10n.xboardNetworkDiagnosticsConclusionProxy,
      NetworkDiagnosticReason.proxyWorking =>
        l10n.xboardNetworkDiagnosticsConclusionProxyWorking,
      NetworkDiagnosticReason.healthy =>
        l10n.xboardNetworkDiagnosticsConclusionHealthy,
    };
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
      final latencyReport =
          DiagnosticBundleService.buildCurrentNodeLatencyReport(ref);
      final report = '$networkReport\n$serviceReport\n$latencyReport';
      await Clipboard.setData(ClipboardData(text: report));
      XBoardNotification.showSuccess(l10n.xboardNetworkDiagnosticsCopied);
    } finally {
      if (mounted) setState(() => _copyingReport = false);
    }
  }

  String _maskDetail(String value) {
    return SensitiveMasker.maskText(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final connected = ref.watch(runTimeProvider) != null;
    ref.listen(runTimeProvider, (previous, next) {
      if (previous != null &&
          next == null &&
          (_running || _reportSnapshot != null)) {
        _invalidateForDisconnect(l10n);
      }
    });
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _DiagnosticPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _domainController,
                  enabled: connected && !_running,
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
                      onPressed: !connected || _running ? null : _start,
                      style: XbUiButton.filledPrimary(
                        context,
                        busy: _running,
                      ),
                      icon: _running
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(
                        _running
                            ? l10n.xboardNetworkDiagnosticsRunning
                            : l10n.xboardNetworkDiagnosticsStart,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: !connected ||
                              _running ||
                              _copyingReport ||
                              _reportSnapshot == null
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
        if (!connected) ...[
          const SizedBox(height: 12),
          _ConnectionRequiredCard(
            message: l10n.xboardNetworkDiagnosticsConnectFirst,
          ),
        ],
        if (widget.showVpnStatus) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsVpnStatus),
          _DiagnosticStatusRow(
            icon: connected ? Icons.shield : Icons.shield_outlined,
            title: l10n.xboardNetworkDiagnosticsVpnStatus,
            detail: _vpnStatus ??
                (connected
                    ? l10n.xboardNetworkDiagnosticsConnected
                    : l10n.xboardNetworkDiagnosticsDisconnected),
            healthy: connected,
          ),
        ],
        if (_conclusion != null) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsConclusion),
          _DiagnosticStatusRow(
            icon: Icons.analytics_outlined,
            title: l10n.xboardNetworkDiagnosticsConclusion,
            detail: _conclusionMessage(_conclusion!, l10n),
            healthy: switch (_conclusion!.severity) {
              NetworkDiagnosticSeverity.healthy => true,
              NetworkDiagnosticSeverity.warning => null,
              NetworkDiagnosticSeverity.error => false,
            },
          ),
        ],
        if (_networkType != null) ...[
          _SectionHeader(l10n.xboardNetworkDiagnosticsNetworkType),
          _DiagnosticStatusRow(
            icon: Icons.lan_outlined,
            title: l10n.xboardNetworkDiagnosticsNetworkType,
            detail: _networkType!,
            healthy: _networkType != l10n.xboardNetworkDiagnosticsNetworkNone,
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
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: XbFontWeight.bold,
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
    return Column(
      children: [
        for (final result in results)
          _DiagnosticStatusRow(
            icon: result.skipped
                ? Icons.remove_circle_outline
                : result.ok
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
            title: result.label,
            detail: result.detail,
            trailing: result.elapsedMs > 0 ? '${result.elapsedMs}ms' : null,
            healthy: result.skipped ? null : result.ok,
          ),
      ],
    );
  }
}

class _DiagnosticPanel extends StatelessWidget {
  const _DiagnosticPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: XbUiCardStyle.background(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: XbUiTokens.cardBorder(context)),
      ),
      child: child,
    );
  }
}

class _ConnectionRequiredCard extends StatelessWidget {
  const _ConnectionRequiredCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = XbUiStatusColor.pending(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _DiagnosticStatusRow extends StatelessWidget {
  const _DiagnosticStatusRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.trailing,
    this.healthy,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? trailing;
  final bool? healthy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = healthy == true
        ? XbUiStatusColor.success(context)
        : healthy == false
            ? XbUiStatusColor.error(context)
            : XbUiStatusColor.pending(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: XbUiCardStyle.background(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: XbUiTokens.cardBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: XbFontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                trailing!,
                style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
              ),
            ),
          Icon(
            healthy == true
                ? Icons.check_circle
                : healthy == false
                    ? Icons.error
                    : Icons.info,
            color: statusColor,
            size: 18,
          ),
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
