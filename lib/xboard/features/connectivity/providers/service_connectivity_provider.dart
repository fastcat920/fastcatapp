import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/features/initialization/models/initialization_state.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_connectivity_state.dart';

const _logger = FileLogger('service_connectivity_provider.dart');

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
    unawaited(_bootstrap());
  }

  final Ref ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _recoveryDebounce;
  Timer? _retryTimer;
  Timer? _onlineConfirmationTimer;
  bool _isChecking = false;

  Future<void> _bootstrap() async {
    final results = await Connectivity().checkConnectivity();
    await handleConnectivityChanged(results, debounce: false);
  }

  void _handleInitializationChanged(
    InitializationState? previous,
    InitializationState next,
  ) {
    if (next.isFailed) {
      _setOffline(next.errorMessage ?? 'initialization_failed');
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
      _setOffline('no_network');
      return;
    }

    if (state.isOnline && state.consecutiveFailures == 0) return;
    _recoveryDebounce?.cancel();
    if (!debounce) {
      await recover();
      return;
    }
    state = state.copyWith(status: ServiceConnectivityStatus.recovering);
    _recoveryDebounce = Timer(const Duration(seconds: 2), recover);
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
        _setOffline(
          refreshedState.errorMessage ?? 'initialization_failed',
        );
        _scheduleRetry();
        return;
      }
    }
    await verifyNow();
  }

  Future<bool> verifyNow() async {
    if (_isChecking) return state.isOnline;
    _isChecking = true;
    try {
      final results = await Connectivity().checkConnectivity();
      final hasNetwork = results.isNotEmpty &&
          !results.every((result) => result == ConnectivityResult.none);
      if (!hasNetwork) {
        _setOffline('no_network');
        return false;
      }

      if (!state.isOnline) {
        state = state.copyWith(status: ServiceConnectivityStatus.recovering);
      }
      final reachable = await _probeService();
      if (reachable) {
        reportRequestSuccess();
        return true;
      }
      _recordFailure('service_probe_failed');
      return false;
    } catch (error) {
      _recordFailure(error.toString());
      return false;
    } finally {
      _isChecking = false;
    }
  }

  void reportRequestSuccess() {
    _retryTimer?.cancel();
    final now = DateTime.now();
    if (state.isOnline) {
      state = state.copyWith(
        consecutiveFailures: 0,
        consecutiveSuccesses: 2,
        lastOnlineAt: now,
        lastCheckedAt: now,
        clearReason: true,
      );
      return;
    }

    final successes = state.consecutiveSuccesses + 1;
    final confirmedOnline = successes >= 2;
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

  void _recordFailure(String reason) {
    final failures = state.consecutiveFailures + 1;
    state = state.copyWith(
      status: failures >= 2
          ? ServiceConnectivityStatus.offline
          : ServiceConnectivityStatus.degraded,
      consecutiveFailures: failures,
      consecutiveSuccesses: 0,
      lastCheckedAt: DateTime.now(),
      reason: reason,
    );
    _scheduleRetry();
  }

  void _setOffline(String reason) {
    _onlineConfirmationTimer?.cancel();
    state = state.copyWith(
      status: ServiceConnectivityStatus.offline,
      consecutiveFailures:
          state.consecutiveFailures < 2 ? 2 : state.consecutiveFailures,
      consecutiveSuccesses: 0,
      lastCheckedAt: DateTime.now(),
      reason: reason,
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
      4 => const Duration(minutes: 1),
      _ => const Duration(minutes: 5),
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
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  @override
  void dispose() {
    _recoveryDebounce?.cancel();
    _retryTimer?.cancel();
    _onlineConfirmationTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

final serviceConnectivityProvider = StateNotifierProvider<
    ServiceConnectivityNotifier, ServiceConnectivityState>(
  ServiceConnectivityNotifier.new,
);
