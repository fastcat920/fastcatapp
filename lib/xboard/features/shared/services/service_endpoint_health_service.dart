import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ServiceEndpointState {
  healthy,
  recovering,
  circuitOpen,
  timeout,
  serviceError,
  unreachable,
  unavailable,
  unsupported,
  unknown,
}

class ServiceEndpointHealthItem {
  const ServiceEndpointHealthItem({
    required this.index,
    required this.address,
    required this.active,
    required this.primary,
    required this.state,
    required this.checkedAt,
    this.latencyMs,
    this.statusCode,
    this.failureCount = 0,
    this.recoverySuccessCount = 0,
    this.recoveryRequired = 0,
    this.circuitRemainingSeconds = 0,
  });

  final int index;
  final String address;
  final bool active;
  final bool primary;
  final ServiceEndpointState state;
  final DateTime checkedAt;
  final int? latencyMs;
  final int? statusCode;
  final int failureCount;
  final int recoverySuccessCount;
  final int recoveryRequired;
  final int circuitRemainingSeconds;

  bool get healthy =>
      state == ServiceEndpointState.healthy ||
      state == ServiceEndpointState.recovering;
}

class ServiceEndpointHealthSnapshot {
  const ServiceEndpointHealthSnapshot({
    required this.checkedAt,
    required this.gateways,
    required this.businessApis,
    required this.businessStatusSupported,
    this.businessStatusSource = '',
    this.businessStatusError,
  });

  final DateTime checkedAt;
  final List<ServiceEndpointHealthItem> gateways;
  final List<ServiceEndpointHealthItem> businessApis;
  final bool businessStatusSupported;
  final String businessStatusSource;
  final ServiceEndpointState? businessStatusError;

  int get healthyGatewayCount => gateways.where((item) => item.healthy).length;
  int get healthyBusinessCount =>
      businessApis.where((item) => item.healthy).length;
}

final serviceEndpointHealthProvider =
    FutureProvider.autoDispose<ServiceEndpointHealthSnapshot>((ref) async {
  return ServiceEndpointHealthService.collect(ref);
});

class ServiceEndpointHealthService {
  const ServiceEndpointHealthService._();

  static Future<ServiceEndpointHealthSnapshot> collect(Ref ref) async {
    final runtime = GatewayRuntimeService.instance..syncFromCurrentConfig();
    final candidates =
        List<GatewayEndpointConfig>.from(runtime.configuredPriorityCandidates);
    final active = runtime.activeConfig;

    final tokenFuture = _loadDeviceToken(ref);
    final gatewayFuture = Future.wait(
      [
        for (var index = 0; index < candidates.length; index++)
          _probeGateway(candidates[index], index, active),
      ],
    );
    final businessFuture = tokenFuture.then(
      (token) => _loadBusinessStatus(candidates, active, token),
    );

    final gateways = await gatewayFuture;
    final business = await businessFuture;
    return ServiceEndpointHealthSnapshot(
      checkedAt: DateTime.now(),
      gateways: gateways,
      businessApis: business.items,
      businessStatusSupported: business.supported,
      businessStatusSource: business.sourceGateway,
      businessStatusError: business.error,
    );
  }

  static Future<String?> _loadDeviceToken(Ref ref) async {
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final token = await sdk.getToken();
      if (token == null || token.isEmpty || !token.contains('dg_')) return null;
      return token;
    } catch (_) {
      return null;
    }
  }

  static Future<ServiceEndpointHealthItem> _probeGateway(
    GatewayEndpointConfig candidate,
    int index,
    GatewayEndpointConfig? active,
  ) async {
    HttpClient? client;
    final checkedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 4);
      final target = Uri.parse(
        '${candidate.baseUrl}${candidate.apiPrefix}/guest/comm/config',
      );
      final request = await client.getUrl(target);
      if (globalState.ua.isNotEmpty) {
        request.headers.set(HttpHeaders.userAgentHeader, globalState.ua);
      }
      final response =
          await request.close().timeout(const Duration(seconds: 4));
      await response.drain<void>();
      stopwatch.stop();
      final healthy = response.statusCode >= 200 && response.statusCode < 300;
      final state = healthy
          ? (candidate.isCircuitOpen || candidate.failureCount > 0
              ? ServiceEndpointState.recovering
              : ServiceEndpointState.healthy)
          : candidate.isCircuitOpen
              ? ServiceEndpointState.circuitOpen
              : response.statusCode >= 500
                  ? ServiceEndpointState.serviceError
                  : ServiceEndpointState.unavailable;
      return ServiceEndpointHealthItem(
        index: index + 1,
        address: SensitiveMasker.maskEndpoint(candidate.baseUrl),
        active: active?.baseUrl == candidate.baseUrl,
        primary: index == 0,
        state: state,
        checkedAt: checkedAt,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        failureCount: candidate.failureCount,
        circuitRemainingSeconds: _remainingCircuitSeconds(candidate),
      );
    } on TimeoutException {
      return _failedGatewayItem(
        candidate,
        index,
        active,
        ServiceEndpointState.timeout,
        stopwatch,
        checkedAt,
      );
    } on SocketException {
      return _failedGatewayItem(
        candidate,
        index,
        active,
        candidate.isCircuitOpen
            ? ServiceEndpointState.circuitOpen
            : ServiceEndpointState.unreachable,
        stopwatch,
        checkedAt,
      );
    } catch (_) {
      return _failedGatewayItem(
        candidate,
        index,
        active,
        candidate.isCircuitOpen
            ? ServiceEndpointState.circuitOpen
            : ServiceEndpointState.unreachable,
        stopwatch,
        checkedAt,
      );
    } finally {
      client?.close(force: true);
    }
  }

  static ServiceEndpointHealthItem _failedGatewayItem(
    GatewayEndpointConfig candidate,
    int index,
    GatewayEndpointConfig? active,
    ServiceEndpointState state,
    Stopwatch stopwatch,
    DateTime checkedAt,
  ) {
    stopwatch.stop();
    return ServiceEndpointHealthItem(
      index: index + 1,
      address: SensitiveMasker.maskEndpoint(candidate.baseUrl),
      active: active?.baseUrl == candidate.baseUrl,
      primary: index == 0,
      state: state,
      checkedAt: checkedAt,
      latencyMs: stopwatch.elapsedMilliseconds,
      failureCount: candidate.failureCount,
      circuitRemainingSeconds: _remainingCircuitSeconds(candidate),
    );
  }

  static int _remainingCircuitSeconds(GatewayEndpointConfig candidate) {
    final disabledUntil = candidate.disabledUntil;
    if (disabledUntil == null || !disabledUntil.isAfter(DateTime.now())) {
      return 0;
    }
    return disabledUntil.difference(DateTime.now()).inSeconds.clamp(1, 86400);
  }

  static Future<_BusinessStatusResult> _loadBusinessStatus(
    List<GatewayEndpointConfig> candidates,
    GatewayEndpointConfig? active,
    String? token,
  ) async {
    if (token == null || candidates.isEmpty) {
      return const _BusinessStatusResult(
        items: [],
        supported: false,
        error: ServiceEndpointState.unavailable,
      );
    }

    final ordered = <GatewayEndpointConfig>[
      if (active != null) active,
      ...candidates.where((item) => item.baseUrl != active?.baseUrl),
    ];
    final results = await Future.wait([
      for (final candidate in ordered) _requestBusinessStatus(candidate, token),
    ]);
    for (final result in results) {
      if (result.supported && result.items.isNotEmpty) return result;
    }
    if (results.any((item) => item.supported)) {
      return results.firstWhere((item) => item.supported);
    }
    if (results.isNotEmpty &&
        results
            .every((item) => item.error == ServiceEndpointState.unsupported)) {
      return const _BusinessStatusResult(
        items: [],
        supported: false,
        error: ServiceEndpointState.unsupported,
      );
    }
    return const _BusinessStatusResult(
      items: [],
      supported: false,
      error: ServiceEndpointState.unreachable,
    );
  }

  static Future<_BusinessStatusResult> _requestBusinessStatus(
    GatewayEndpointConfig gateway,
    String token,
  ) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse(
        '${gateway.baseUrl}${gateway.apiPrefix}/user/service-status',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, token);
      if (globalState.ua.isNotEmpty) {
        request.headers.set(HttpHeaders.userAgentHeader, globalState.ua);
      }
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode == HttpStatus.notFound) {
        return const _BusinessStatusResult(
          items: [],
          supported: false,
          error: ServiceEndpointState.unsupported,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const _BusinessStatusResult(
          items: [],
          supported: true,
          error: ServiceEndpointState.unavailable,
        );
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('invalid response');
      final data = decoded['data'];
      if (data is! Map) throw const FormatException('missing data');
      final rawItems = data['backends'];
      final items = <ServiceEndpointHealthItem>[];
      if (rawItems is List) {
        for (final raw in rawItems) {
          if (raw is! Map) continue;
          items.add(_businessItemFromMap(raw));
        }
      }
      return _BusinessStatusResult(
        items: items,
        supported: true,
        sourceGateway: _keepMaskedEndpoint(
          data['source_gateway']?.toString() ??
              SensitiveMasker.maskEndpoint(gateway.baseUrl),
        ),
      );
    } on TimeoutException {
      return const _BusinessStatusResult(
        items: [],
        supported: true,
        error: ServiceEndpointState.timeout,
      );
    } catch (_) {
      return const _BusinessStatusResult(
        items: [],
        supported: true,
        error: ServiceEndpointState.unreachable,
      );
    } finally {
      client?.close(force: true);
    }
  }

  static ServiceEndpointHealthItem _businessItemFromMap(Map raw) {
    final status = raw['status']?.toString() ?? 'unknown';
    return ServiceEndpointHealthItem(
      index: _asInt(raw['index'], 1),
      address: _keepMaskedEndpoint(raw['address']?.toString() ?? ''),
      active: raw['active'] == true,
      primary: raw['role'] == 'primary',
      state: _parseState(status),
      checkedAt: DateTime.tryParse(raw['checked_at']?.toString() ?? '') ??
          DateTime.now(),
      latencyMs: _nullableInt(raw['latency_ms']),
      statusCode: _nullableInt(raw['status_code']),
      failureCount: _asInt(raw['failure_count']),
      recoverySuccessCount: _asInt(raw['recovery_success_count']),
      recoveryRequired: _asInt(raw['recovery_required']),
      circuitRemainingSeconds: _asInt(raw['circuit_remaining_seconds']),
    );
  }

  static ServiceEndpointState _parseState(String value) {
    return switch (value) {
      'healthy' => ServiceEndpointState.healthy,
      'recovering' => ServiceEndpointState.recovering,
      'circuit_open' => ServiceEndpointState.circuitOpen,
      'timeout' => ServiceEndpointState.timeout,
      'service_error' => ServiceEndpointState.serviceError,
      'unreachable' => ServiceEndpointState.unreachable,
      'unavailable' => ServiceEndpointState.unavailable,
      _ => ServiceEndpointState.unknown,
    };
  }

  static int _asInt(Object? value, [int fallback = 0]) {
    return value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  }

  static int? _nullableInt(Object? value) {
    if (value == null) return null;
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  static String _keepMaskedEndpoint(String value) {
    if (value.contains('*') || value.contains('[redacted')) return value;
    return SensitiveMasker.maskEndpoint(value);
  }
}

class _BusinessStatusResult {
  const _BusinessStatusResult({
    required this.items,
    required this.supported,
    this.sourceGateway = '',
    this.error,
  });

  final List<ServiceEndpointHealthItem> items;
  final bool supported;
  final String sourceGateway;
  final ServiceEndpointState? error;
}
