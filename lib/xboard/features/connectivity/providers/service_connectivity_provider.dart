import 'dart:async';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/initialization/models/initialization_state.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_connectivity_state.dart';

const _logger = FileLogger('service_connectivity_provider.dart');
const _baseNetworkProbeUrls = <String>[
  'https://connect.rom.miui.com/generate_204',
  'https://wifi.vivo.com.cn/generate_204',
  'https://connectivitycheck.platform.hicloud.com/generate_204',
];
const _mobileConnectionWarmupDuration = Duration(seconds: 8);

class ServiceConnectivityNotifier
    extends StateNotifier<ServiceConnectivityState> {
  ServiceConnectivityNotifier(this.ref)
      : super(const ServiceConnectivityState()) {
    ref.listen<InitializationState>(
      initializationProvider,
      _handleInitializationChanged,
      fireImmediately: true,
    );
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(handleConnectivityChanged);
    globalState.coreSwitchStatusNotifier.addListener(_handleCoreSwitchChanged);
    unawaited(_bootstrap());
  }

  final Ref ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _recoveryDebounce;
  Timer? _networkLossDebounce;
  Timer? _retryTimer;
  Timer? _onlineConfirmationTimer;
  Timer? _mobileConnectionWarmupTimer;
  DateTime? _mobileConnectionWarmupUntil;
  bool _isChecking = false;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  bool get _hasActiveMobileProxy => _isMobile && globalState.isStart;

  void _handleCoreSwitchChanged() {
    if (!_isMobile) return;
    final stage = globalState.coreSwitchStatusNotifier.value.stage;
    if (stage == CoreSwitchStage.connected) {
      _beginMobileConnectionWarmup();
      return;
    }
    if (stage == CoreSwitchStage.stopping || stage == CoreSwitchStage.failed) {
      _mobileConnectionWarmupTimer?.cancel();
      _mobileConnectionWarmupUntil = null;
    }
  }

  void _beginMobileConnectionWarmup() {
    _retryTimer?.cancel();
    _onlineConfirmationTimer?.cancel();
    _mobileConnectionWarmupUntil =
        DateTime.now().add(_mobileConnectionWarmupDuration);
    state = state.copyWith(
      status: ServiceConnectivityStatus.recovering,
      consecutiveFailures: 0,
      consecutiveSuccesses: 0,
      reason: 'mobile_vpn_settling',
      clearCause: true,
    );
    _scheduleMobileWarmupVerification();
  }

  DateTime? _effectiveMobileWarmupUntil() {
    if (!_isMobile) return null;
    final startedAt = globalState.startTime;
    final startedWarmupUntil = startedAt?.add(_mobileConnectionWarmupDuration);
    final explicit = _mobileConnectionWarmupUntil;
    if (explicit == null) return startedWarmupUntil;
    if (startedWarmupUntil == null || explicit.isAfter(startedWarmupUntil)) {
      return explicit;
    }
    return startedWarmupUntil;
  }

  bool _deferForMobileConnectionWarmup() {
    final warmupUntil = _effectiveMobileWarmupUntil();
    if (warmupUntil == null || !warmupUntil.isAfter(DateTime.now())) {
      _mobileConnectionWarmupUntil = null;
      return false;
    }
    state = state.copyWith(
      status: ServiceConnectivityStatus.recovering,
      consecutiveFailures: 0,
      consecutiveSuccesses: 0,
      reason: 'mobile_vpn_settling',
      clearCause: true,
    );
    _scheduleMobileWarmupVerification(warmupUntil: warmupUntil);
    return true;
  }

  void _scheduleMobileWarmupVerification({DateTime? warmupUntil}) {
    final deadline = warmupUntil ?? _effectiveMobileWarmupUntil();
    if (deadline == null) return;
    final remaining = deadline.difference(DateTime.now());
    _mobileConnectionWarmupTimer?.cancel();
    _mobileConnectionWarmupTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => unawaited(verifyNow()),
    );
  }

  Future<void> _bootstrap() async {
    final results = await Connectivity().checkConnectivity();
    await handleConnectivityChanged(results, debounce: false);
  }

  void _handleInitializationChanged(
    InitializationState? previous,
    InitializationState next,
  ) {
    if (next.isFailed) {
      _setOffline(
        next.errorMessage ?? 'initialization_failed',
        cause: ServiceConnectivityCause.initializationFailed,
      );
      unawaited(_refineOfflineCause(
        next.errorMessage ?? 'initialization_failed',
      ));
      _scheduleRetry();
      return;
    }
    if (next.isReady && previous?.isReady != true) {
      unawaited(verifyNow());
    }
  }

  Future<void> handleConnectivityChanged(
    List<ConnectivityResult> results, {
    bool debounce = true,
  }) async {
    final hasNetwork = results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);
    if (!hasNetwork) {
      _recoveryDebounce?.cancel();
      _retryTimer?.cancel();
      _onlineConfirmationTimer?.cancel();
      _networkLossDebounce?.cancel();
      state = state.copyWith(
        status: ServiceConnectivityStatus.recovering,
        consecutiveFailures: 0,
        consecutiveSuccesses: 0,
        reason: 'network_transition',
        clearCause: true,
      );
      final isVpnTransition = globalState.isCoreSwitchingNotifier.value ||
          globalState.coreSwitchStatusNotifier.value.stage ==
              CoreSwitchStage.stopping;
      _networkLossDebounce = Timer(
        Duration(seconds: isVpnTransition ? 5 : 3),
        _confirmNetworkLoss,
      );
      return;
    }

    _networkLossDebounce?.cancel();
    if (state.isOnline && state.consecutiveFailures == 0) return;
    _recoveryDebounce?.cancel();
    if (!debounce) {
      await recover();
      return;
    }
    state = state.copyWith(status: ServiceConnectivityStatus.recovering);
    _recoveryDebounce = Timer(const Duration(seconds: 2), recover);
  }

  Future<void> _confirmNetworkLoss() async {
    final results = await Connectivity().checkConnectivity();
    final hasNetwork = results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);
    final proxyNetworkReachable =
        !hasNetwork && _hasActiveMobileProxy && await _probeActiveProxy();
    if (hasNetwork || proxyNetworkReachable) {
      await recover();
      return;
    }
    _setOffline(
      'no_network',
      cause: ServiceConnectivityCause.noNetwork,
    );
  }

  Future<void> recover() async {
    if (_isChecking) return;
    final initState = ref.read(initializationProvider);
    if (initState.isFailed) {
      try {
        await ref.read(initializationProvider.notifier).refresh();
      } catch (error) {
        _logger.warning('[ServiceConnectivity] 重新初始化失败: $error');
      }
      final refreshedState = ref.read(initializationProvider);
      if (refreshedState.isFailed) {
        final reason = refreshedState.errorMessage ?? 'initialization_failed';
        _setOffline(
          reason,
          cause: ServiceConnectivityCause.initializationFailed,
        );
        unawaited(_refineOfflineCause(reason));
        _scheduleRetry();
        return;
      }
    }
    await verifyNow();
  }

  Future<bool> verifyNow() async {
    if (_isChecking) return state.isOnline;
    if (_deferForMobileConnectionWarmup()) return false;
    _isChecking = true;
    try {
      final results = await Connectivity().checkConnectivity();
      final hasNetwork = results.isNotEmpty &&
          !results.every((result) => result == ConnectivityResult.none);
      var proxyNetworkReachable =
          !hasNetwork && _hasActiveMobileProxy && await _probeActiveProxy();
      if (!hasNetwork && !proxyNetworkReachable) {
        await handleConnectivityChanged(results);
        return false;
      }

      if (!state.isOnline) {
        state = state.copyWith(status: ServiceConnectivityStatus.recovering);
      }
      final reachable = await _probeService();
      if (reachable) {
        reportRequestSuccess(authoritative: false);
        return true;
      }
      final baseNetworkReachable = await _probeBaseNetwork();
      proxyNetworkReachable = proxyNetworkReachable ||
          (!baseNetworkReachable &&
              _hasActiveMobileProxy &&
              await _probeActiveProxy());
      _recordFailure(
        'service_probe_failed',
        cause: classifyServiceConnectivityFailure(
          hasNetworkInterface: true,
          baseNetworkReachable: baseNetworkReachable,
          proxyNetworkReachable: proxyNetworkReachable,
        ),
      );
      return false;
    } catch (error) {
      final proxyNetworkReachable =
          _hasActiveMobileProxy && await _probeActiveProxy();
      _recordFailure(
        error.toString(),
        cause: proxyNetworkReachable
            ? ServiceConnectivityCause.gatewayUnavailable
            : ServiceConnectivityCause.networkRestricted,
      );
      return false;
    } finally {
      _isChecking = false;
    }
  }

  void reportRequestSuccess({bool authoritative = true}) {
    _retryTimer?.cancel();
    final now = DateTime.now();
    if (state.isOnline) {
      state = state.copyWith(
        consecutiveFailures: 0,
        consecutiveSuccesses: 2,
        lastOnlineAt: now,
        lastCheckedAt: now,
        clearReason: true,
        clearCause: true,
      );
      return;
    }

    final successes = state.consecutiveSuccesses + 1;
    final confirmedOnline = authoritative || successes >= 2;
    if (confirmedOnline) {
      _onlineConfirmationTimer?.cancel();
    }
    state = state.copyWith(
      status: confirmedOnline
          ? ServiceConnectivityStatus.online
          : ServiceConnectivityStatus.recovering,
      consecutiveFailures: confirmedOnline ? 0 : state.consecutiveFailures,
      consecutiveSuccesses: successes,
      lastOnlineAt: confirmedOnline ? now : state.lastOnlineAt,
      lastCheckedAt: now,
      clearReason: true,
      clearCause: confirmedOnline,
    );
    if (!confirmedOnline) {
      _onlineConfirmationTimer?.cancel();
      _onlineConfirmationTimer = Timer(
        const Duration(seconds: 2),
        verifyNow,
      );
    }
  }

  void reportRequestFailure(Object error) {
    if (state.isOffline || _isChecking) return;
    state = state.copyWith(
      status: ServiceConnectivityStatus.degraded,
      consecutiveSuccesses: 0,
      reason: error.toString(),
    );
    unawaited(verifyNow());
  }

  void _recordFailure(
    String reason, {
    ServiceConnectivityCause cause =
        ServiceConnectivityCause.gatewayUnavailable,
  }) {
    final failures = state.consecutiveFailures + 1;
    state = state.copyWith(
      status: failures >= 2
          ? ServiceConnectivityStatus.offline
          : ServiceConnectivityStatus.degraded,
      consecutiveFailures: failures,
      consecutiveSuccesses: 0,
      lastCheckedAt: DateTime.now(),
      reason: reason,
      cause: cause,
    );
    _scheduleRetry();
  }

  void _setOffline(
    String reason, {
    required ServiceConnectivityCause cause,
  }) {
    _onlineConfirmationTimer?.cancel();
    state = state.copyWith(
      status: ServiceConnectivityStatus.offline,
      consecutiveFailures:
          state.consecutiveFailures < 2 ? 2 : state.consecutiveFailures,
      consecutiveSuccesses: 0,
      lastCheckedAt: DateTime.now(),
      reason: reason,
      cause: cause,
    );
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _onlineConfirmationTimer?.cancel();
    final failures = state.consecutiveFailures;
    final delay = switch (failures) {
      <= 1 => const Duration(seconds: 5),
      2 => const Duration(seconds: 15),
      3 => const Duration(seconds: 30),
      _ => const Duration(minutes: 1),
    };
    _retryTimer = Timer(delay, recover);
  }

  Future<bool> _probeService() async {
    final gatewayCandidates = allGatewayUrls;
    final candidates = gatewayCandidates.isNotEmpty
        ? gatewayCandidates
        : XBoardConfig.allPanelUrls;
    if (candidates.isEmpty) return false;

    final apiPrefix = gatewayCandidates.isNotEmpty
        ? currentGatewayApiPrefix
        : XBoardConfig.provider.getApiPrefix();
    final uniqueCandidates = candidates.toSet();
    final completer = Completer<bool>();
    var remaining = uniqueCandidates.length;
    for (final baseUrl in uniqueCandidates) {
      unawaited(_probeEndpoint(baseUrl, apiPrefix).then((reachable) {
        if (reachable && !completer.isCompleted) {
          completer.complete(true);
          return;
        }
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(false);
        }
      }));
    }
    return completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => false,
    );
  }

  Future<void> _refineOfflineCause(String reason) async {
    try {
      final results = await Connectivity().checkConnectivity();
      final hasNetworkInterface = results.isNotEmpty &&
          !results.every((result) => result == ConnectivityResult.none);
      final baseNetworkReachable =
          hasNetworkInterface && await _probeBaseNetwork();
      final proxyNetworkReachable = !baseNetworkReachable &&
          _hasActiveMobileProxy &&
          await _probeActiveProxy();
      if (!state.isOffline || state.reason != reason) return;
      _setOffline(
        reason,
        cause: classifyServiceConnectivityFailure(
          hasNetworkInterface: hasNetworkInterface,
          baseNetworkReachable: baseNetworkReachable,
          proxyNetworkReachable: proxyNetworkReachable,
        ),
      );
    } catch (error) {
      _logger.warning('[ServiceConnectivity] 离线原因复核失败: $error');
      if (!state.isOffline || state.reason != reason) return;
      _setOffline(
        reason,
        cause: ServiceConnectivityCause.networkRestricted,
      );
    }
  }

  Future<bool> _probeBaseNetwork() async {
    final completer = Completer<bool>();
    var remaining = _baseNetworkProbeUrls.length;
    for (final url in _baseNetworkProbeUrls) {
      unawaited(_probeBaseEndpoint(url).then((reachable) {
        if (reachable && !completer.isCompleted) {
          completer.complete(true);
          return;
        }
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(false);
        }
      }));
    }
    return completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => false,
    );
  }

  Future<bool> _probeActiveProxy() async {
    if (!globalState.isInit || !globalState.isStart) return false;
    try {
      final controller = globalState.appController;
      for (var attempt = 0; attempt < 3; attempt++) {
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
          final proxyState = controller.getProxyCardState(candidate);
          final proxyName =
              proxyState.proxyName.isEmpty ? candidate : proxyState.proxyName;
          final testUrl = controller.getRealTestUrl(proxyState.testUrl);
          final delay = await clashCore
              .getDelay(testUrl, proxyName)
              .timeout(const Duration(seconds: 6));
          return (delay.value ?? -1) > 0;
        }
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    } catch (error) {
      _logger.warning('[ServiceConnectivity] 代理出口复核失败: $error');
    }
    return false;
  }

  Future<bool> _probeBaseEndpoint(String url) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, globalState.ua);
      final response = await request.close().timeout(
            const Duration(seconds: 5),
          );
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _probeEndpoint(String baseUrl, String apiPrefix) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 4);
      final normalizedBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final normalizedPrefix =
          apiPrefix.startsWith('/') ? apiPrefix : '/$apiPrefix';
      final uri = Uri.parse(
        '$normalizedBase$normalizedPrefix/guest/comm/config',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, globalState.ua);
      final response = await request.close().timeout(
            const Duration(seconds: 5),
          );
      await response.drain<void>();
      return isHealthyGatewayStatusCode(response.statusCode);
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  @override
  void dispose() {
    _recoveryDebounce?.cancel();
    _networkLossDebounce?.cancel();
    _retryTimer?.cancel();
    _onlineConfirmationTimer?.cancel();
    _mobileConnectionWarmupTimer?.cancel();
    _connectivitySubscription?.cancel();
    globalState.coreSwitchStatusNotifier
        .removeListener(_handleCoreSwitchChanged);
    super.dispose();
  }
}

final serviceConnectivityProvider = StateNotifierProvider<
    ServiceConnectivityNotifier, ServiceConnectivityState>(
  ServiceConnectivityNotifier.new,
);
